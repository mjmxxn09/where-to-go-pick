import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Supabase에 보낼 토큰과 그 주인.
class CloudAuth {
  const CloudAuth({required this.accessToken, required this.userId, required this.expiresAt});

  final String accessToken;

  /// 토큰의 sub. 픽클 계정은 `pickle:<subjectId>`, 게스트는 Supabase 사용자 UUID.
  final String userId;
  final DateTime expiresAt;

  /// 만료 2분 전부터는 새로 받는다.
  bool isFreshAt(DateTime now) => now.isBefore(expiresAt.subtract(const Duration(minutes: 2)));
}

class CloudAuthException implements Exception {
  const CloudAuthException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'CloudAuthException($statusCode): $message';
}

/// 게스트 로그인의 refresh token 보관함.
abstract interface class CloudSecretStore {
  Future<String?> read();
  Future<void> write(String? value);
}

class SecureCloudSecretStore implements CloudSecretStore {
  SecureCloudSecretStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'supabase.guest_refresh.v1';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String? value) => value == null ? _storage.delete(key: _key) : _storage.write(key: _key, value: value);
}

class MemoryCloudSecretStore implements CloudSecretStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String? value) async => this.value = value;
}

/// 픽클 access token을 준다. [refresh]면 픽클 refresh를 거친 새 토큰. 로그인 전이면 null.
typedef PickleTokenSource = Future<String?> Function({bool refresh});

/// Supabase 토큰을 마련한다.
///
/// 1. 픽클에 로그인돼 있으면 Edge Function `pickle-exchange`로 픽클 토큰을 Supabase 토큰으로 바꾼다.
/// 2. 아니고 [allowGuest]면(픽클 서버 없이 개발할 때) Supabase 익명 로그인으로 게스트 토큰을 받는다.
///    대시보드에서 Anonymous sign-ins를 켜야 한다. 게스트 기록은 나중에 픽클 계정과 합쳐지지 않는다.
/// 3. 둘 다 아니면 null — 기록은 폰에만 남는다.
///
/// 여러 곳에서 동시에 불러도 토큰 요청은 한 번만 나간다.
class CloudSession {
  CloudSession({
    required String url,
    required this.publishableKey,
    this.pickleToken,
    this.allowGuest = false,
    CloudSecretStore? guestStore,
    http.Client? httpClient,
    DateTime Function()? clock,
  })  : baseUri = Uri.parse(url.endsWith('/') ? url.substring(0, url.length - 1) : url),
        _guestStore = guestStore ?? SecureCloudSecretStore(),
        _http = httpClient ?? http.Client(),
        _clock = clock ?? DateTime.now;

  final Uri baseUri;
  final String publishableKey;
  final PickleTokenSource? pickleToken;
  final bool allowGuest;
  final CloudSecretStore _guestStore;
  final http.Client _http;
  final DateTime Function() _clock;

  CloudAuth? _auth;
  Future<CloudAuth?>? _pending;

  Uri endpoint(String path, [Map<String, String>? query]) =>
      baseUri.replace(path: '${baseUri.path}$path', queryParameters: query);

  /// 쓸 수 있는 토큰. 로그인 수단이 없으면 null, 서버 오류면 [CloudAuthException] 등 예외.
  Future<CloudAuth?> current() {
    final auth = _auth;
    if (auth != null && auth.isFreshAt(_clock())) return Future.value(auth);
    return _pending ??= _obtain().whenComplete(() => _pending = null);
  }

  /// 서버가 토큰을 거절했을 때(401) 다음 요청에서 새로 받게 한다.
  void invalidate() => _auth = null;

  Future<CloudAuth?> _obtain() async {
    CloudAuth? next;
    final source = pickleToken;
    if (source != null) {
      final token = await source(refresh: false);
      if (token != null) next = await _exchange(token, source);
    }
    if (next == null && allowGuest) next = await _guest();
    _auth = next;
    return next;
  }

  Map<String, String> get _headers => {
        'apikey': publishableKey,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  Future<CloudAuth?> _exchange(String pickleToken, PickleTokenSource source) async {
    Future<http.Response> send(String token) => _http.post(
          endpoint('/functions/v1/pickle-exchange'),
          headers: _headers,
          body: jsonEncode({'pickleAccessToken': token}),
        );

    var res = await send(pickleToken);
    if (res.statusCode == 401) {
      // 픽클 access token이 만료됐을 수 있다. 픽클 refresh는 픽클 클라이언트가 한 번만 보낸다.
      String? refreshed;
      try {
        refreshed = await source(refresh: true);
      } on Object {
        refreshed = null;
      }
      if (refreshed == null) return null; // 픽클 로그인이 끝났다
      res = await send(refreshed);
      if (res.statusCode == 401) return null;
    }
    if (res.statusCode != 200) {
      throw CloudAuthException('pickle-exchange ${res.statusCode}', statusCode: res.statusCode);
    }
    final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final token = json['access_token'] as String;
    return CloudAuth(
      accessToken: token,
      userId: json['user_id'] as String? ?? jwtSubject(token) ?? '',
      expiresAt: _expiry(json),
    );
  }

  Future<CloudAuth?> _guest() async {
    final saved = await _guestStore.read();
    if (saved != null && saved.isNotEmpty) {
      final res = await _http.post(
        endpoint('/auth/v1/token', {'grant_type': 'refresh_token'}),
        headers: _headers,
        body: jsonEncode({'refresh_token': saved}),
      );
      if (res.statusCode == 200) return _guestFrom(res);
      // refresh token이 만료·폐기됐으면 새 게스트로 시작한다(이전 게스트 기록은 이 기기에만 남는다).
      if (res.statusCode >= 500) throw CloudAuthException('guest refresh ${res.statusCode}', statusCode: res.statusCode);
    }
    final res = await _http.post(endpoint('/auth/v1/signup'), headers: _headers, body: jsonEncode({'data': {}}));
    if (res.statusCode != 200) {
      throw CloudAuthException('guest sign-in ${res.statusCode}', statusCode: res.statusCode);
    }
    return _guestFrom(res);
  }

  Future<CloudAuth> _guestFrom(http.Response res) async {
    final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final token = json['access_token'] as String;
    final refresh = json['refresh_token'] as String?;
    if (refresh != null) await _guestStore.write(refresh);
    final user = json['user'];
    return CloudAuth(
      accessToken: token,
      userId: (user is Map<String, dynamic> ? user['id'] as String? : null) ?? jwtSubject(token) ?? '',
      expiresAt: _expiry(json),
    );
  }

  DateTime _expiry(Map<String, dynamic> json) {
    final at = json['expires_at'];
    if (at is num) return DateTime.fromMillisecondsSinceEpoch(at.toInt() * 1000);
    final inSeconds = json['expires_in'];
    return _clock().add(Duration(seconds: inSeconds is num ? inSeconds.toInt() : 3600));
  }
}

/// JWT 본문의 sub. 서명은 확인하지 않는다(서버가 확인한다). 읽을 수 없으면 null.
String? jwtSubject(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
    return payload is Map<String, dynamic> ? payload['sub'] as String? : null;
  } on FormatException {
    return null;
  }
}
