import 'trip_models.dart';

/// 화면 확인용 예시 여행: 강릉 2박 3일, 체크인 9곳. 시간·장소 구성은 예시다.
Trip sampleGangneungTrip() {
  DateTime t(int day, int h, int m) => DateTime(2026, 11, 13 + day, h, m);
  return Trip(
    id: 'sample-gangneung',
    cityId: '32030',
    cityName: '강릉시',
    provinceName: '강원특별자치도',
    startDate: DateTime(2026, 11, 13),
    plannedDays: 3,
    // 가볼 곳 지도 예시(좌표는 대략).
    planned: const [
      PlannedPlace(id: 'gyeongpo', name: '경포해변', type: PlaceType.beach, meta: '해변 · 자연', location: GeoPoint(37.8055, 128.9087)),
      PlannedPlace(id: 'ojukheon', name: '오죽헌', type: PlaceType.heritage, meta: '역사', location: GeoPoint(37.7792, 128.8786)),
      PlannedPlace(id: 'chodang', name: '초당순두부마을', type: PlaceType.food, meta: '맛집', location: GeoPoint(37.7914, 128.9149)),
      PlannedPlace(id: 'jeongdongjin', name: '정동진', type: PlaceType.beach, meta: '해변', location: GeoPoint(37.6905, 129.0343)),
      PlannedPlace(id: 'jumunjin', name: '주문진 수산시장', type: PlaceType.seafood, meta: '시장 · 해산물', location: GeoPoint(37.8930, 128.8263)),
      PlannedPlace(id: 'terarosa', name: '테라로사 커피공장', type: PlaceType.cafe, meta: '카페', location: GeoPoint(37.7175, 128.8770)),
    ],
    checkIns: [
      CheckIn(id: 'gyeongpo', placeName: '경포해변', type: PlaceType.beach, at: t(0, 10, 20)),
      CheckIn(id: 'anmok', placeName: '안목 커피거리', type: PlaceType.cafe, at: t(0, 13, 40)),
      CheckIn(id: 'ojukheon', placeName: '오죽헌', type: PlaceType.heritage, at: t(0, 15, 10)),
      CheckIn(id: 'jungang-market', placeName: '강릉중앙시장', type: PlaceType.market, at: t(0, 18, 30)),
      CheckIn(id: 'chodang', placeName: '초당순두부마을', type: PlaceType.food, at: t(1, 8, 30)),
      CheckIn(id: 'jumunjin', placeName: '주문진 수산시장', type: PlaceType.seafood, at: t(1, 11, 0)),
      CheckIn(id: 'jeongdongjin', placeName: '정동진', type: PlaceType.beach, at: t(1, 16, 20)),
      CheckIn(id: 'seongyojang', placeName: '선교장', type: PlaceType.heritage, at: t(2, 9, 30)),
      CheckIn(id: 'solhyang', placeName: '솔향수목원', type: PlaceType.nature, at: t(2, 12, 10)),
    ],
  );
}

/// 내 여행 지도에 색칠할 예시 방문 지역(시·군·구 코드, 통계청 2018 기준).
const sampleVisitedCityIds = <String>{'32030', '32060', '32410', '39010', '39020', '21090', '21140', '11010'};
