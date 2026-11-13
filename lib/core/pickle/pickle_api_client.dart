import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:http/http.dart' as http;

import '../auth/token_store.dart';
import '../network/api_exception.dart';
import 'pickle_models.dart';

/// 픽클(VoteLock) Backend `/v1` 클라이언트. 이 앱은 읽기 위주로 쓴다.
///
/// - 인증: `Authorization: Bearer <accessToken>`
/// - 401이면 refresh를 **한 번에 하나만** 보낸다(single-flight). 이미 회전된 refresh를 다시 보내면 서버가
///   탈취로 보고 모든 세션을 폐기하므로, 동시에 401을 받은 요청은 진행 중인 refresh 결과를 함께 기다린다.
class PickleApiClient {
  PickleApiClient({
    required String baseUrl,
    required TokenStore tokenStore,
    http.Client? httpClient,
    this.appVersion = '0.1.0',
    this.deviceId,
  })  : _baseUri = Uri.parse(baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl),
        _tokens = tokenStore,
        _http = httpClient ?? http.Client();

  final Uri _baseUri;
  final TokenStore _tokens;
  final http.Client _http;
  final String appVersion;
  final String? deviceId;

  Future<AuthTokens>? _refreshing;

  Uri _uri(String path) => _baseUri.replace(path: '${_baseUri.path}$path');

  static String get _platform {
    try {
      if (Platform.isAndroid) return 'ANDROID';
      if (Platform.isIOS) return 'IOS';
    } on Object {
      // 웹·테스트 환경
    }
    return 'UNKNOWN';
  }

  Map<String, String> get _jsonHeaders => const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  // ---------------------------------------------------------------- 인증

  /// 이메일 로그인. 다른 기기·픽클 앱에 활성 세션이 있으면 [SessionConflictException].
  /// [replaceExistingSession]은 사용자가 화면에서 직접 동의했을 때만 true로 보낸다.
  Future<AuthTokens> login({
    required String email,
    required String password,
    bool replaceExistingSession = false,
  }) async {
    final res = await _http.post(
      _uri('/v1/auth/login'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'email': email,
        'password': password,
        'devicePlatform': _platform,
        'appVersion': appVersion,
        if (deviceId != null) 'deviceId': deviceId,
        'replaceExistingSession': replaceExistingSession,
      }),
    );
    if (res.statusCode == 200) {
      final tokens = AuthTokens.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
      await _tokens.write(tokens);
      return tokens;
    }
    if (res.statusCode == 409) {
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final active = json['activeSession'] as Map<String, dynamic>?;
      throw SessionConflictException(
        statusCode: 409,
        code: json['code'] as String? ?? 'SESSION_REPLACEMENT_REQUIRED',
        message: json['message'] as String? ?? '다른 기기에서 사용 중이에요.',
        requestId: json['requestId'] as String?,
        activePlatformLabel: active?['platformLabel'] as String?,
      );
    }
    throw ApiException.fromResponse(res.statusCode, res.body);
  }

  Future<void> signOutLocally() => _tokens.clear();

  Future<bool> get hasSession async => (await _tokens.read()) != null;

  Future<AuthTokens> _refresh() {
    return _refreshing ??= (() async {
      try {
        final current = await _tokens.read();
        if (current == null) {
          throw const ApiException(statusCode: 401, code: 'UNAUTHENTICATED', message: '다시 로그인해 주세요.');
        }
        final res = await _http.post(
          _uri('/v1/auth/refresh'),
          headers: _jsonHeaders,
          body: jsonEncode({
            'refreshToken': current.refreshToken,
            if (deviceId != null) 'deviceId': deviceId,
          }),
        );
        if (res.statusCode != 200) {
          await _tokens.clear();
          throw ApiException.fromResponse(res.statusCode, res.body);
        }
        final next = AuthTokens.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
        await _tokens.write(next);
        return next;
      } finally {
        _refreshing = null;
      }
    })();
  }

  Future<dynamic> _getJson(String path, {bool authenticated = true}) async {
    Future<http.Response> send(String? token) => _http.get(
          _uri(path),
          headers: {
            'Accept': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        );

    String? token;
    if (authenticated) {
      token = (await _tokens.read())?.accessToken;
      if (token == null) {
        throw const ApiException(statusCode: 401, code: 'UNAUTHENTICATED', message: '로그인이 필요해요.');
      }
    }
    var res = await send(token);
    if (authenticated && res.statusCode == 401) {
      final refreshed = await _refresh();
      res = await send(refreshed.accessToken);
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    throw ApiException.fromResponse(res.statusCode, utf8.decode(res.bodyBytes));
  }

  // ---------------------------------------------------------------- 조회

  Future<UserProfile> getMyProfile() async =>
      UserProfile.fromJson(await _getJson('/v1/me') as Map<String, dynamic>);

  Future<List<String>> getMyInterestKeys() async {
    final json = await _getJson('/v1/me/interests') as Map<String, dynamic>;
    return (json['categoryKeys'] as List<dynamic>).cast<String>();
  }

  /// 공개 카탈로그(인증 불필요).
  Future<List<InterestCategory>> listInterestCategories() async {
    final json = await _getJson('/v1/interests', authenticated: false) as Map<String, dynamic>;
    final list = (json['categories'] as List<dynamic>)
        .map((e) => InterestCategory.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  /// 마을이 꺼져 있거나(enabled=false) 아직 입양 전이면 null.
  Future<PickleFriend?> getMyFirstFriend() async {
    final json = await _getJson('/v1/me/companion/village') as Map<String, dynamic>;
    if (json['enabled'] != true) return null;
    final characters = json['characters'] as List<dynamic>? ?? const [];
    if (characters.isEmpty) return null;
    return PickleFriend.fromJson(characters.first as Map<String, dynamic>);
  }
}
