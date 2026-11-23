import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Supabase에 보낼 토큰과 그 주인.
class CloudAuth {
  const CloudAuth({required this.accessToken, required this.userId, required this.expiresAt});

  final String accessToken;

  /// 토큰의 sub. 픽클 계정은 `pickle:<subjectId>`, 카카오·게스트는 Supabase 사용자 UUID.
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

/// Supabase refresh token 보관함(게스트, 카카오 등 계정 로그인 따로).
abstract interface class CloudSecretStore {
  Future<String?> read();
  Future<void> write(String? value);
}

class SecureCloudSecretStore implements CloudSecretStore {
  SecureCloudSecretStore([FlutterSecureStorage? storage, this._key = guestKey])
      : _storage = storage ?? const FlutterSecureStorage();

  /// 게스트(익명) 세션.
  static const guestKey = 'supabase.guest_refresh.v1';

  /// 카카오 등 계정 로그인 세션.
  static const accountKey = 'supabase.account_refresh.v1';

  /// 카카오 등 계정 세션을 마지막으로 쓴 시각(밀리초). 오래 안 쓰면 로그아웃한다.
  static const accountUsedKey = 'supabase.account_used.v1';

  final String _key;
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

/// 로그인 페이지([url])를 브라우저로 열고, [callbackScheme]://… 로 돌아온 주소를 준다.
/// 사용자가 닫으면 [OAuthCanceled]를 던진다.
typedef OAuthBrowser = Future<Uri> Function(Uri url, String callbackScheme);

/// 사용자가 로그인 창을 닫았다.
class OAuthCanceled implements Exception {
  const OAuthCanceled();
}

/// Supabase 토큰을 마련한다.
///
/// 1. 픽클에 로그인돼 있으면 Edge Function `pickle-exchange`로 픽클 토큰을 Supabase 토큰으로 바꾼다.
/// 2. 아니고 카카오로 로그인해 둔 적이 있으면([signInWithKakao]) 그 계정 세션을 이어 쓴다.
/// 3. 아니고 [allowGuest]면(픽클 서버 없이 개발할 때) Supabase 익명 로그인으로 게스트 토큰을 받는다.
///    대시보드에서 Anonymous sign-ins를 켜야 한다.
/// 4. 다 아니면 null — 기록은 폰에만 남는다.
///
/// 계정이 바뀌어도(게스트 → 카카오) 폰에 있는 기록은 다음 sync 때 새 계정으로 올라간다.
///
/// 카카오 등 계정 세션은 [accountIdleLimit](30일) 동안 쓰지 않으면 끝난다(다시 로그인).
/// Supabase 무료 요금제는 서버 쪽 세션 기간 설정이 없어(refresh token은 만료되지 않음) 앱에서 정한다.
/// 토큰을 받을 때마다(앱을 열 때, 쓰는 동안 1시간마다) 마지막 사용 시각을 새로 적는다.
///
/// 여러 곳에서 동시에 불러도 토큰 요청은 한 번만 나간다.
class CloudSession {
  CloudSession({
    required String url,
    required this.publishableKey,
    this.pickleToken,
    this.allowGuest = false,
    CloudSecretStore? guestStore,
    CloudSecretStore? accountStore,
    CloudSecretStore? accountUsedStore,
    this.accountIdleLimit = const Duration(days: 30),
    http.Client? httpClient,
    DateTime Function()? clock,
    Random? random,
  })  : baseUri = Uri.parse(url.endsWith('/') ? url.substring(0, url.length - 1) : url),
        _guestStore = guestStore ?? SecureCloudSecretStore(),
        _accountStore = accountStore ?? SecureCloudSecretStore(null, SecureCloudSecretStore.accountKey),
        _accountUsedStore = accountUsedStore ?? SecureCloudSecretStore(null, SecureCloudSecretStore.accountUsedKey),
        _random = random ?? Random.secure(),
        _http = httpClient ?? http.Client(),
        _clock = clock ?? DateTime.now;

  final Uri baseUri;
  final String publishableKey;
  final PickleTokenSource? pickleToken;
  final bool allowGuest;
  final CloudSecretStore _guestStore;
  final CloudSecretStore _accountStore;
  final CloudSecretStore _accountUsedStore;

  /// 이만큼 안 쓰면 카카오 등 계정 세션을 끝낸다.
  final Duration accountIdleLimit;
  final Random _random;

  /// 지금 토큰이 카카오 등 계정 세션에서 왔는지(로그아웃 때 서버 세션을 폐기하려고).
  bool _authIsAccount = false;
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
    var fromAccount = false;
    if (next == null) {
      next = await _account();
      fromAccount = next != null;
    }
    if (next == null && allowGuest) next = await _guest();
    _auth = next;
    _authIsAccount = fromAccount;
    return next;
  }

  /// 앱이 돌아올 주소. 대시보드 Authentication → URL Configuration → Redirect URLs에 넣어야 한다.
  static const redirectScheme = 'wheretogopick';
  static const redirectUrl = '$redirectScheme://login-callback';

  /// 카카오(등) 계정으로 로그인해 둔 세션이 있는지. 시작 화면에서 바로 홈으로 갈지 정할 때 쓴다.
  /// [accountIdleLimit] 넘게 안 썼으면 여기서 로그아웃 처리하고 false.
  Future<bool> get hasAccount async => (await _savedAccount())?.isNotEmpty ?? false;

  /// 보관함을 못 읽으면(보안 저장소 오류 등) 계정 세션이 없는 것으로 본다 — 게스트·폰 저장은 그대로 된다.
  /// 오래 안 쓴 세션이면 서버 세션을 폐기하고 지운 뒤 null.
  Future<String?> _savedAccount() async {
    String? saved;
    try {
      saved = await _accountStore.read();
    } on Object {
      return null;
    }
    if (saved == null || saved.isEmpty) return null;
    if (await _accountIdleTooLong()) {
      await _endAccount(saved);
      return null;
    }
    return saved;
  }

  Future<bool> _accountIdleTooLong() async {
    String? raw;
    try {
      raw = await _accountUsedStore.read();
    } on Object {
      return false;
    }
    final ms = int.tryParse(raw ?? '');
    if (ms == null) return false; // 기록이 없으면(이 기능 전에 로그인) 지금부터 센다
    return _clock().difference(DateTime.fromMillisecondsSinceEpoch(ms)) > accountIdleLimit;
  }

  Future<void> _markAccountUsed() async {
    try {
      await _accountUsedStore.write('${_clock().millisecondsSinceEpoch}');
    } on Object {
      // 못 적어도 로그인은 그대로
    }
  }

  /// 계정 세션 끝내기: 서버의 그 세션을 폐기(가능하면)하고 폰에서 지운다.
  Future<void> _endAccount(String refreshToken, {String? accessToken}) async {
    try {
      var token = accessToken;
      if (token == null) {
        // 폐기하려면 access token이 필요하다 — refresh로 하나 받아서 바로 폐기한다.
        final res = await _http.post(
          endpoint('/auth/v1/token', {'grant_type': 'refresh_token'}),
          headers: _headers,
          body: jsonEncode({'refresh_token': refreshToken}),
        );
        if (res.statusCode == 200) {
          token = (jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>)['access_token'] as String?;
        }
      }
      if (token != null) {
        await _http.post(
          endpoint('/auth/v1/logout', {'scope': 'local'}),
          headers: {..._headers, 'Authorization': 'Bearer $token'},
        );
      }
    } on Object {
      // 서버에 못 닿아도 폰에서는 로그아웃한다(그 refresh token은 이제 아무도 갖고 있지 않다).
    }
    try {
      await _accountStore.write(null);
      await _accountUsedStore.write(null);
    } on Object {
      // 보관함 오류는 무시
    }
    if (_authIsAccount) {
      _auth = null;
      _authIsAccount = false;
    }
  }

  /// 카카오 로그인: Supabase Auth의 카카오 제공자(PKCE). 브라우저에서 카카오 로그인 → 앱으로 돌아온 code를 세션으로 바꾼다.
  /// 대시보드 Authentication → Providers → Kakao를 켜야 한다(docs/kakao-login.md).
  Future<CloudAuth> signInWithKakao(OAuthBrowser browser) => signInWithProvider('kakao', browser);

  Future<CloudAuth> signInWithProvider(String provider, OAuthBrowser browser) async {
    final verifier = _codeVerifier();
    final challenge = pkceChallengeOf(verifier);
    final url = endpoint('/auth/v1/authorize', {
      'provider': provider,
      'redirect_to': redirectUrl,
      'code_challenge': challenge,
      'code_challenge_method': 's256',
    });
    final back = await browser(url, redirectScheme);
    // 오류는 ?error=…, 또는 #error=…로 돌아온다.
    final params = {...Uri.splitQueryString(back.fragment), ...back.queryParameters};
    final code = params['code'];
    if (code == null || code.isEmpty) {
      throw CloudAuthException('$provider 로그인: ${params['error_description'] ?? params['error'] ?? '돌아온 코드가 없어요'}');
    }
    final res = await _http.post(
      endpoint('/auth/v1/token', {'grant_type': 'pkce'}),
      headers: _headers,
      body: jsonEncode({'auth_code': code, 'code_verifier': verifier}),
    );
    if (res.statusCode != 200) {
      final body = utf8.decode(res.bodyBytes);
      throw CloudAuthException(
        '$provider 로그인 ${res.statusCode}: ${body.length > 200 ? body.substring(0, 200) : body}',
        statusCode: res.statusCode,
      );
    }
    final auth = await _sessionFrom(res, _accountStore);
    await _markAccountUsed();
    _auth = auth;
    _authIsAccount = true;
    return auth;
  }

  /// 카카오 등 계정 로그아웃: 서버의 그 세션을 폐기하고 폰에서 지운다. 폰에 있는 여행 기록은 부르는 쪽에서 정리한다.
  Future<void> signOutAccount() async {
    String? saved;
    try {
      saved = await _accountStore.read();
    } on Object {
      saved = null;
    }
    final access = _authIsAccount ? _auth?.accessToken : null;
    _authIsAccount = true; // _endAccount가 지금 토큰도 지우게
    if (saved != null && saved.isNotEmpty) {
      await _endAccount(saved, accessToken: access);
    } else {
      await _accountStore.write(null);
      _auth = null;
      _authIsAccount = false;
    }
  }

  Future<CloudAuth?> _account() async {
    final saved = await _savedAccount();
    if (saved == null || saved.isEmpty) return null;
    final res = await _http.post(
      endpoint('/auth/v1/token', {'grant_type': 'refresh_token'}),
      headers: _headers,
      body: jsonEncode({'refresh_token': saved}),
    );
    if (res.statusCode == 200) {
      final auth = await _sessionFrom(res, _accountStore);
      await _markAccountUsed();
      return auth;
    }
    if (res.statusCode >= 500) throw CloudAuthException('account refresh ${res.statusCode}', statusCode: res.statusCode);
    // 세션이 만료·폐기됐다 → 다시 로그인해야 한다.
    await _accountStore.write(null);
    return null;
  }

  /// PKCE code verifier: 43~128자 [A-Za-z0-9-._~]. 32바이트 무작위를 base64url로.
  String _codeVerifier() =>
      base64Url.encode(List<int>.generate(32, (_) => _random.nextInt(256))).replaceAll('=', '');

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
      if (res.statusCode == 200) return _sessionFrom(res, _guestStore);
      // refresh token이 만료·폐기됐으면 새 게스트로 시작한다(이전 게스트 기록은 이 기기에만 남는다).
      if (res.statusCode >= 500) throw CloudAuthException('guest refresh ${res.statusCode}', statusCode: res.statusCode);
    }
    final res = await _http.post(endpoint('/auth/v1/signup'), headers: _headers, body: jsonEncode({'data': {}}));
    if (res.statusCode != 200) {
      // 422 anonymous_provider_disabled: 대시보드 Authentication에서 Allow anonymous sign-ins가 꺼져 있다.
      final body = utf8.decode(res.bodyBytes);
      throw CloudAuthException(
        'guest sign-in ${res.statusCode}: ${body.length > 200 ? body.substring(0, 200) : body}',
        statusCode: res.statusCode,
      );
    }
    return _sessionFrom(res, _guestStore);
  }

  /// Supabase Auth 세션 응답 → 토큰. refresh token은 [store]에 보관한다.
  Future<CloudAuth> _sessionFrom(http.Response res, CloudSecretStore store) async {
    final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final token = json['access_token'] as String;
    final refresh = json['refresh_token'] as String?;
    if (refresh != null) await store.write(refresh);
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

/// PKCE code_challenge(S256): base64url(sha256(verifier)), 끝의 = 없이.
String pkceChallengeOf(String verifier) => base64Url.encode(sha256.convert(utf8.encode(verifier)).bytes).replaceAll('=', '');

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
