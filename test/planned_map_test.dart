import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:where_to_go_pick/features/korea_map/geo_projection.dart';
import 'package:where_to_go_pick/features/korea_map/korea_map_data.dart';
import 'package:where_to_go_pick/features/trip/planned_map.dart';
import 'package:where_to_go_pick/features/trip/trip_models.dart';
import 'package:where_to_go_pick/features/trip/visited_cities.dart';

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
    // 크게 보기에서 2배 확대·이동한 뒤에도 핀을 누를 수 있다
    const pan = Offset(-100, -40);
    expect(layout.pinAt(layout.pins[1]! * 2 + pan, zoom: 2, pan: pan), 1);
  });

  test('크게 보기 배율·이동은 칸 안으로', () {
    const size = Size(300, 500);
    var v = clampView(0.5, const Offset(30, 30), size);
    expect(v.zoom, 1);
    expect(v.pan, Offset.zero, reason: '처음 크기에선 움직이지 않는다');
    v = clampView(20, const Offset(-5000, 10), size);
    expect(v.zoom, 8);
    expect(v.pan, const Offset(-2100, 0), reason: '지도 끝이 칸 안쪽으로 들어오지 않게');
  });

  test('도 전체 여행: 체크인한 가볼 곳이 든 시·군·구를 내 지도에 칠한다', () {
    final trip = Trip(
      id: 't',
      cityId: '25',
      cityName: '대전광역시',
      provinceName: '대전광역시',
      startDate: DateTime(2026, 11, 20),
      planned: const [
        PlannedPlace(id: 'a', name: '성심당 본점', type: PlaceType.food, location: GeoPoint(36.3276, 127.4273)),
        PlannedPlace(id: 'b', name: '안 간 곳', type: PlaceType.food, location: GeoPoint(36.3624, 127.3565)),
      ],
      checkIns: [
        CheckIn(id: 'a', placeName: '성심당 본점', type: PlaceType.food, at: DateTime(2026, 11, 20, 10)),
        CheckIn(id: 'x', placeName: '좌표 모르는 곳', type: PlaceType.cafe, at: DateTime(2026, 11, 20, 12)),
      ],
    );
    final daejeonJung = data.details['25']!.cities.firstWhere((c) => c.name == '중구').id;
    expect(citiesFromWholeProvinceTrips(data, [trip]), {daejeonJung});
    expect(trip.isWholeProvince, isTrue);
    expect(trip.title, '대전 여행');
  });

  test('짧은 지역 이름', () {
    expect(regionShortName('강원특별자치도'), '강원');
    expect(regionShortName('충청북도'), '충북');
    expect(regionShortName('강릉시'), '강릉');
    expect(regionShortName('양양군'), '양양');
    expect(isProvinceId('25'), isTrue);
    expect(isProvinceId('31:수원시'), isFalse);
  });
}
