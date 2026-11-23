import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:where_to_go_pick/features/korea_map/geo_projection.dart';
import 'package:where_to_go_pick/features/korea_map/korea_map_data.dart';
import 'package:where_to_go_pick/features/trip/planned_map.dart';

void main() {
  final data = KoreaMapData.fromJson(
    jsonDecode(File(KoreaMapData.assetPath).readAsStringSync()) as Map<String, dynamic>,
  );

  MapRegion city(String id) => data.details[id.substring(0, 2)]!.cities.firstWhere((c) => c.id == id);

  test('위경도가 앱 지도의 그 시·군·구 안에 찍힌다', () {
    // (시·군·구 코드, 위도, 경도, 장소) — 해안선에서 떨어진 곳들
    const places = [
      ('11010', 37.5796, 126.9770, '경복궁'),
      ('21090', 35.1587, 129.1604, '해운대해수욕장'),
      ('29010', 36.4800, 127.2890, '세종시청'),
      ('35:전주시', 35.8151, 127.1530, '전주 한옥마을'),
      ('31:수원시', 37.2819, 127.0137, '화성행궁'),
      ('37020', 35.8350, 129.2190, '경주 대릉원'),
      ('38050', 34.8400, 128.4230, '통영'),
      ('23310', 37.6213, 126.4923, '강화 전등사'),
    ];
    for (final (id, lat, lng, name) in places) {
      final at = projectToDetail(id.substring(0, 2), lat, lng);
      expect(at, isNotNull, reason: name);
      expect(city(id).path.contains(at!), isTrue, reason: '$name → $at');
    }
  });

  test('바닷가 장소도 그 시·군·구 가까이(경포해변 → 강릉)', () {
    final at = projectToDetail('32', 37.8055, 128.9087)!;
    expect(city('32030').path.getBounds().inflate(3).contains(at), isTrue);
  });

  test('도 값이 없으면 null', () {
    expect(projectToDetail('99', 37, 127), isNull);
  });

  test('지도 칸 맞추기: 멀리 떨어진 핀은 빼고 세고, 칸 안에 들어온다', () {
    const cityBox = Rect.fromLTWH(100, 100, 60, 40);
    final layout = PlannedMapLayout.fit(
      city: cityBox,
      points: const {1: Offset(110, 110), 2: Offset(170, 130), 3: Offset(400, 400)},
      size: const Size(300, 190),
    );
    expect(layout.outside, 1);
    expect(layout.pins.keys, [1, 2]);
    for (final p in layout.pins.values) {
      expect(const Rect.fromLTWH(0, 0, 300, 190).contains(p), isTrue);
    }
    expect(layout.pinAt(layout.pins[2]! + const Offset(5, 5)), 2);
    expect(layout.pinAt(const Offset(-50, -50)), isNull);
  });
}
