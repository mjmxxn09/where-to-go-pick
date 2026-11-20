import 'dart:convert';

import 'package:http/http.dart' as http;

import 'cloud_session.dart';

/// 로그인 수단이 없어서(픽클 로그인 전 등) 서버에 올릴 수 없다.
class CloudSignedOut implements Exception {
  const CloudSignedOut();

  @override
  String toString() => 'CloudSignedOut';
}

class CloudRequestException implements Exception {
  const CloudRequestException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'CloudRequestException($statusCode): $body';
}

/// Supabase Data API(PostgREST)를 `http`로 직접 부른다. 필요한 것만: 읽기와 upsert.
class SupabaseRest {
  SupabaseRest(this.session, {http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final CloudSession session;
  final http.Client _http;

  /// 지금 토큰의 주인(행의 user_id). 로그인 수단이 없으면 null.
  Future<String?> userId() async => (await session.current())?.userId;

  /// [query]는 PostgREST 그대로. 예: `{'select': 'id,name', 'order': 'id.asc'}`
  Future<List<Map<String, dynamic>>> select(String table, Map<String, String> query) async {
    final res = await _send((auth) => _http.get(
          session.endpoint('/rest/v1/$table', query),
          headers: _headers(auth),
        ));
    final json = jsonDecode(utf8.decode(res.bodyBytes));
    return [for (final row in json as List<dynamic>) row as Map<String, dynamic>];
  }

  /// 기본 키가 같으면 덮어쓴다. 모든 행은 같은 키를 가져야 한다(PostgREST 일괄 입력 규칙).
  Future<void> upsert(String table, List<Map<String, Object?>> rows, {required String onConflict}) async {
    if (rows.isEmpty) return;
    await _send((auth) => _http.post(
          session.endpoint('/rest/v1/$table', {'on_conflict': onConflict}),
          headers: {
            ..._headers(auth),
            'Content-Type': 'application/json',
            'Prefer': 'resolution=merge-duplicates,return=minimal',
          },
          body: jsonEncode(rows),
        ));
  }

  /// [filters](PostgREST 그대로, 예: `{'id': 'eq.t1'}`)에 맞는 행을 지운다. RLS로 내 행만 지워진다.
  /// 조건 없이 부르면 거절한다(실수로 전부 지우지 않게).
  Future<void> delete(String table, Map<String, String> filters) async {
    if (filters.isEmpty) throw ArgumentError.value(filters, 'filters', '지울 조건이 없어요');
    await _send((auth) => _http.delete(
          session.endpoint('/rest/v1/$table', filters),
          headers: {..._headers(auth), 'Prefer': 'return=minimal'},
        ));
  }

  /// Edge Function을 부른다(POST JSON). 응답 JSON 객체를 돌려준다.
  Future<Map<String, dynamic>> invoke(String function, Map<String, Object?> body) async {
    final res = await _send((auth) => _http.post(
          session.endpoint('/functions/v1/$function'),
          headers: {..._headers(auth), 'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ));
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  Map<String, String> _headers(CloudAuth auth) => {
        'apikey': session.publishableKey,
        'Authorization': 'Bearer ${auth.accessToken}',
        'Accept': 'application/json',
      };

  /// 401이면 토큰을 버리고 한 번만 다시 보낸다.
  Future<http.Response> _send(Future<http.Response> Function(CloudAuth auth) request) async {
    var auth = await session.current();
    if (auth == null) throw const CloudSignedOut();
    var res = await request(auth);
    if (res.statusCode == 401) {
      session.invalidate();
      auth = await session.current();
      if (auth == null) throw const CloudSignedOut();
      res = await request(auth);
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw CloudRequestException(res.statusCode, utf8.decode(res.bodyBytes));
    }
    return res;
  }
}
