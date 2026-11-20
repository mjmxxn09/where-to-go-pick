import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:where_to_go_pick/core/cloud/cloud_session.dart';
import 'package:where_to_go_pick/core/cloud/supabase_rest.dart';
import 'package:where_to_go_pick/features/trip_card/card_cloud.dart';
import 'package:where_to_go_pick/features/trip_card/card_stickers.dart';

const _url = 'https://demo.supabase.co';
const _key = 'sb_publishable_test';

/// 본문 {sub}만 든 가짜 JWT(서명은 확인하지 않는다).
String _jwt(String sub) {
  String part(Object json) => base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'ES256'})}.${part({'sub': sub})}.sig';
}

http.Response _json(Object body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json'});

void main() {
  final now = DateTime(2026, 11, 20, 12);

  test('JWT 본문에서 sub를 읽는다', () {
    expect(jwtSubject(_jwt('pickle:u1')), 'pickle:u1');
    expect(jwtSubject('nope'), isNull);
    expect(jwtSubject('a.!!!.c'), isNull);
  });

  group('픽클 토큰 교환', () {
    test('픽클 토큰을 보내 Supabase 토큰을 받고, 만료 전까지 다시 묻지 않는다', () async {
      final requests = <http.Request>[];
      final session = CloudSession(
        url: '$_url/',
        publishableKey: _key,
        pickleToken: ({bool refresh = false}) async => 'pickle-access',
        guestStore: MemoryCloudSecretStore(),
        clock: () => now,
        httpClient: MockClient((req) async {
          requests.add(req);
          return _json({
            'access_token': _jwt('pickle:u1'),
            'user_id': 'pickle:u1',
            'expires_at': now.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
          });
        }),
      );
      final results = await Future.wait([session.current(), session.current()]);
      expect(results.map((a) => a!.userId), ['pickle:u1', 'pickle:u1']);
      await session.current();
      expect(requests, hasLength(1), reason: '동시에 불러도, 다시 불러도 한 번만');
      expect(requests.single.url.toString(), '$_url/functions/v1/pickle-exchange');
      expect(requests.single.headers['apikey'], _key);
      expect(jsonDecode(requests.single.body), {'pickleAccessToken': 'pickle-access'});
    });

    test('교환이 401이면 픽클 토큰을 새로 받아 한 번 더 해 본다', () async {
      final sent = <String>[];
      final refreshes = <bool>[];
      final session = CloudSession(
        url: _url,
        publishableKey: _key,
        pickleToken: ({bool refresh = false}) async {
          refreshes.add(refresh);
          return refresh ? 'fresh' : 'stale';
        },
        guestStore: MemoryCloudSecretStore(),
        clock: () => now,
        httpClient: MockClient((req) async {
          final token = (jsonDecode(req.body) as Map<String, dynamic>)['pickleAccessToken'] as String;
          sent.add(token);
          if (token == 'stale') return _json({'code': 'PICKLE_UNAUTHENTICATED'}, 401);
          return _json({'access_token': _jwt('pickle:u1'), 'expires_at': 9999999999});
        }),
      );
      final auth = await session.current();
      expect(auth!.userId, 'pickle:u1', reason: 'user_id가 없으면 토큰의 sub');
      expect(sent, ['stale', 'fresh']);
      expect(refreshes, [false, true]);
    });

    test('픽클 로그인 전이고 게스트도 막혀 있으면 null', () async {
      final session = CloudSession(
        url: _url,
        publishableKey: _key,
        pickleToken: ({bool refresh = false}) async => null,
        guestStore: MemoryCloudSecretStore(),
        httpClient: MockClient((req) async => fail('요청을 보내면 안 돼요')),
      );
      expect(await session.current(), isNull);
    });
  });

  group('게스트(익명) 로그인', () {
    test('처음엔 가입하고 refresh token을 보관, 다음엔 그걸로 새 토큰을 받는다', () async {
      final store = MemoryCloudSecretStore();
      final paths = <String>[];
      var t = now;
      final session = CloudSession(
        url: _url,
        publishableKey: _key,
        allowGuest: true,
        guestStore: store,
        clock: () => t,
        httpClient: MockClient((req) async {
          paths.add('${req.url.path}${req.url.hasQuery ? '?${req.url.query}' : ''}');
          return _json({
            'access_token': _jwt('guest-uuid'),
            'expires_in': 3600,
            'refresh_token': 'r${paths.length}',
            'user': {'id': 'guest-uuid'},
          });
        }),
      );
      expect((await session.current())!.userId, 'guest-uuid');
      expect(store.value, 'r1');
      t = now.add(const Duration(minutes: 59)); // 만료 2분 전 안쪽
      await session.current();
      expect(paths, ['/auth/v1/signup', '/auth/v1/token?grant_type=refresh_token']);
      expect(store.value, 'r2');
    });

    test('보관한 refresh token이 거절되면 새 게스트로 가입한다', () async {
      final store = MemoryCloudSecretStore()..value = 'old';
      final paths = <String>[];
      final session = CloudSession(
        url: _url,
        publishableKey: _key,
        allowGuest: true,
        guestStore: store,
        httpClient: MockClient((req) async {
          paths.add(req.url.path);
          if (req.url.path == '/auth/v1/token') return _json({'error': 'invalid_grant'}, 400);
          return _json({'access_token': _jwt('g2'), 'expires_in': 3600, 'refresh_token': 'new'});
        }),
      );
      expect((await session.current())!.userId, 'g2');
      expect(paths, ['/auth/v1/token', '/auth/v1/signup']);
      expect(store.value, 'new');
    });
  });

  group('Data API', () {
    CloudSession guest(http.Client client) => CloudSession(
          url: _url,
          publishableKey: _key,
          allowGuest: true,
          guestStore: MemoryCloudSecretStore(),
          httpClient: client,
        );

    test('upsert는 on_conflict와 merge-duplicates로 보낸다', () async {
      late http.Request sent;
      final client = MockClient((req) async {
        if (req.url.path.startsWith('/auth/')) {
          return _json({'access_token': _jwt('g'), 'expires_in': 3600, 'refresh_token': 'r'});
        }
        sent = req;
        return http.Response('', 201);
      });
      final rest = SupabaseRest(guest(client), httpClient: client);
      await rest.upsert('trips', [
        {'user_id': 'g', 'id': 't1'},
      ], onConflict: 'user_id,id');
      expect(sent.url.path, '/rest/v1/trips');
      expect(sent.url.queryParameters, {'on_conflict': 'user_id,id'});
      expect(sent.headers['Prefer'], 'resolution=merge-duplicates,return=minimal');
      expect(sent.headers['Authorization'], 'Bearer ${_jwt('g')}');
      expect(sent.headers['apikey'], _key);
      expect(jsonDecode(sent.body), [
        {'user_id': 'g', 'id': 't1'},
      ]);
    });

    test('401이면 토큰을 새로 받아 한 번만 다시 보낸다', () async {
      var signups = 0;
      var reads = 0;
      final client = MockClient((req) async {
        if (req.url.path.startsWith('/auth/')) {
          signups++;
          return _json({'access_token': _jwt('g$signups'), 'expires_in': 3600});
        }
        reads++;
        if (reads == 1) return _json({'message': 'JWT expired'}, 401);
        return _json([
          {'id': 't1'},
        ]);
      });
      final rest = SupabaseRest(guest(client), httpClient: client);
      final rows = await rest.select('trips', {'select': 'id'});
      expect(rows.single['id'], 't1');
      expect(signups, 2);
      expect(reads, 2);
    });

    test('로그인 수단이 없으면 CloudSignedOut', () async {
      final session = CloudSession(url: _url, publishableKey: _key, guestStore: MemoryCloudSecretStore());
      final rest = SupabaseRest(session, httpClient: MockClient((_) async => fail('보내면 안 돼요')));
      expect(() => rest.select('trips', {}), throwsA(isA<CloudSignedOut>()));
    });
  });

  test('카드 꾸미기는 서버 행과 오간다', () {
    const page = CardDecoration(
      pageKey: 't1|all|0',
      stickers: [PlacedSticker(id: 's1', name: 'place_beach_parasol', x: 10, y: 20, size: 54, rotation: 0.1)],
      stopEdits: {},
    );
    final row = cardDecorationToRow(page, 'pickle:u1');
    expect(row['page_key'], 't1|all|0');
    final back = cardDecorationFromRow(jsonDecode(jsonEncode(row)) as Map<String, dynamic>)!;
    expect(back.stickers.single.name, 'place_beach_parasol');
    expect(back.stickers.single.x, 10);
    expect(back.stopEdits, isEmpty);
    expect(cardDecorationFromRow({'page_key': 3}), isNull);
  });
}
