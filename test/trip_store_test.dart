import 'package:flutter_test/flutter_test.dart';
import 'package:where_to_go_pick/core/life/life_repository.dart';
import 'package:where_to_go_pick/features/trip/trip_cloud.dart';
import 'package:where_to_go_pick/features/trip/trip_controller.dart';
import 'package:where_to_go_pick/features/trip/trip_models.dart';
import 'package:where_to_go_pick/features/trip/trip_store.dart';

Trip _trip(String id, {int day = 13, List<CheckIn> checkIns = const []}) => Trip(
      id: id,
      cityId: '32030',
      cityName: '강릉시',
      provinceName: '강원특별자치도',
      startDate: DateTime(2026, 11, day),
      checkIns: checkIns,
    );

CheckIn _c(String id, int hour) =>
    CheckIn(id: id, placeName: '장소 $id', type: PlaceType.cafe, at: DateTime(2026, 11, 13, hour));

class _FakeCloud implements TripCloud {
  _FakeCloud([this.remote = const []]);

  List<Trip> remote;
  final pushed = <List<String>>[];
  var failPush = false;

  @override
  Future<List<Trip>> pull() async => remote;

  @override
  Future<void> push(List<Trip> trips) async {
    if (failPush) throw StateError('offline');
    pushed.add([for (final t in trips) t.id]);
    remote = mergeTrips(trips, remote);
  }

  final deleted = <String>[];

  @override
  Future<void> deleteTrip(String tripId) async {
    if (failPush) throw StateError('offline');
    deleted.add(tripId);
    remote = [for (final t in remote) if (t.id != tripId) t];
  }

  @override
  Future<void> deleteCheckIn(String tripId, String checkInId) async {
    if (failPush) throw StateError('offline');
    deleted.add('$tripId/$checkInId');
    remote = [
      for (final t in remote)
        t.id == tripId ? t.copyWith(checkIns: [for (final c in t.checkIns) if (c.id != checkInId) c]) : t,
    ];
  }
}

const _place = PlaceSuggestion(id: 'gyeongpo', name: '경포해변', type: PlaceType.beach, meta: '해변');

void main() {
  test('여행 기록은 JSON으로 저장했다가 그대로 불러온다', () {
    final log = TripLog(trips: [_trip('t1', checkIns: [_c('a', 9), _c('b', 15)])], currentId: 't1');
    final back = decodeTripLog(encodeTripLog(log));
    expect(back.currentId, 't1');
    expect(back.trips.single.startDate, DateTime(2026, 11, 13));
    expect(back.trips.single.checkIns.map((c) => c.id), ['a', 'b']);
    expect(back.trips.single.checkIns.first.at, DateTime(2026, 11, 13, 9));
    expect(back.trips.single.checkIns.first.type, PlaceType.cafe);
  });

  test('깨진 기록이나 없는 현재 여행 id는 무시한다', () {
    expect(decodeTripLog('not json').isEmpty, isTrue);
    expect(decodeTripLog(null).isEmpty, isTrue);
    final log = decodeTripLog('{"currentId":"gone","trips":[{"id":"x"}]}');
    expect(log.trips, isEmpty);
    expect(log.currentId, isNull);
    expect(placeTypeFromName('unknown'), PlaceType.other);
  });

  test('합치면 같은 여행의 체크인은 장소 id로 모이고, 최신 여행이 앞에 온다', () {
    final merged = mergeTrips(
      [_trip('t1', checkIns: [_c('a', 9)])],
      [_trip('t1', checkIns: [_c('a', 10), _c('b', 15)]), _trip('t0', day: 1)],
    );
    expect(merged.map((t) => t.id), ['t1', 't0']);
    expect(merged.first.checkIns.map((c) => c.id), ['a', 'b']);
    expect(merged.first.checkIns.first.at.hour, 9, reason: '둘 다 있으면 앞쪽(기기) 것을 남긴다');
  });

  test('여행을 시작하고 체크인하면 폰에 저장되고, 다시 열면 이어진다', () async {
    final store = MemoryTripStore();
    final now = DateTime(2026, 11, 20, 10);
    final first = TripController(clock: () => now, store: store)
      ..startTrip(cityId: '32030', cityName: '강릉시', provinceName: '강원특별자치도');
    first.checkIn(_place);
    await Future<void>.delayed(Duration.zero);
    expect(store.log.currentId, first.trip!.id);
    expect(store.log.trips.single.checkIns.single.id, 'gyeongpo');

    final second = TripController(initial: _trip('sample-gangneung'), store: store);
    await second.restore();
    expect(second.trip!.id, first.trip!.id, reason: '저장된 여행이 예시 여행보다 먼저');
    expect(second.visitedCityIds, {'32030'});
  });

  test('예시 여행은 체크인해도 저장하거나 올리지 않는다', () async {
    final store = MemoryTripStore();
    final cloud = _FakeCloud();
    final controller = TripController(initial: _trip('sample-gangneung'), store: store, cloud: cloud);
    await controller.restore();
    controller.checkIn(_place);
    await Future<void>.delayed(Duration.zero);
    expect(controller.trip!.checkIns, hasLength(1));
    expect(store.saves, 0);
    expect(cloud.pushed, isEmpty);
    expect(controller.trips, isEmpty);
  });

  test('열 때 서버 기록을 받아 합치고, 서버에 없는 여행은 올린다', () async {
    final store = MemoryTripStore(TripLog(trips: [_trip('local', day: 20)], currentId: 'local'));
    final cloud = _FakeCloud([_trip('remote', day: 1, checkIns: [_c('a', 9)])]);
    final controller = TripController(store: store, cloud: cloud);
    await controller.restore();
    expect(controller.trips.map((t) => t.id), ['local', 'remote']);
    expect(controller.trip!.id, 'local');
    expect(store.log.trips, hasLength(2));
    expect(cloud.pushed.last, containsAll(['local', 'remote']));
  });

  test('올리지 못해도 기록은 폰에 남고, 다음 sync 때 다시 올린다', () async {
    final store = MemoryTripStore();
    final cloud = _FakeCloud()..failPush = true;
    final controller = TripController(clock: () => DateTime(2026, 11, 20), store: store, cloud: cloud)
      ..startTrip(cityId: '32030', cityName: '강릉시', provinceName: '강원특별자치도');
    await Future<void>.delayed(Duration.zero);
    expect(store.log.trips, hasLength(1));
    expect(cloud.remote, isEmpty);

    cloud.failPush = false;
    await controller.sync();
    expect(cloud.remote.single.id, controller.trip!.id);
  });

  test('서버 행과 여행 모델을 오간다', () {
    final trip = _trip('t1', checkIns: [_c('a', 9)]);
    final row = {
      ...tripToRow(trip, 'pickle:u1'),
      'check_ins': [checkInToRow('t1', trip.checkIns.single, 'pickle:u1')],
    };
    expect(row['user_id'], 'pickle:u1');
    expect(row['start_date'], '2026-11-13');
    final back = tripFromRow(row)!;
    expect(back.id, 't1');
    expect(back.startDate, DateTime(2026, 11, 13));
    expect(back.checkIns.single.at, DateTime(2026, 11, 13, 9));
    expect(back.checkIns.single.type, PlaceType.cafe);
    expect(tripFromRow({'id': 1}), isNull);
  });

  test('가볼 곳은 담고 빼고, 저장·서버 행에도 남는다', () async {
    final store = MemoryTripStore();
    final controller = TripController(clock: () => DateTime(2026, 11, 20), store: store)
      ..startTrip(cityId: '32030', cityName: '강릉시', provinceName: '강원특별자치도');
    controller.togglePlanned(_place);
    const other = PlaceSuggestion(
      id: 'tour:2',
      name: '테라로사',
      type: PlaceType.cafe,
      meta: '카페',
      url: 'http://place.map.kakao.com/2',
      location: GeoPoint(37.7175, 128.877),
    );
    controller.togglePlanned(other);
    expect(controller.trip!.planned.map((p) => p.id), ['gyeongpo', 'tour:2']);
    expect(controller.isPlanned('tour:2'), isTrue);
    controller.togglePlanned(_place);
    expect(controller.trip!.planned.map((p) => p.name), ['테라로사']);
    await Future<void>.delayed(Duration.zero);

    final saved = decodeTripLog(encodeTripLog(store.log)).trips.single;
    expect(saved.planned.single.type, PlaceType.cafe);
    expect(saved.planned.single.meta, '카페');
    expect(saved.planned.single.location, const GeoPoint(37.7175, 128.877), reason: '가볼 곳 지도용 좌표도 저장');

    final row = tripToRow(saved, 'g');
    expect(row['planned'], [
      {
        'id': 'tour:2',
        'name': '테라로사',
        'type': 'cafe',
        'meta': '카페',
        'url': 'http://place.map.kakao.com/2',
        'lat': 37.7175,
        'lng': 128.877,
      },
    ]);
    final back = tripFromRow({...row, 'check_ins': <Object>[]})!.planned.single;
    expect(back.id, 'tour:2');
    expect(back.location, const GeoPoint(37.7175, 128.877));
    expect(plannedFromJson({'id': 'a', 'name': 'A', 'lat': 0, 'lng': 0})!.location, isNull, reason: '빈 좌표는 버린다');
  });

  test('합칠 때 가볼 곳은 기기 쪽 목록을 그대로 쓴다', () {
    final local = _trip('t1').copyWith(planned: const []);
    final remote = _trip('t1').copyWith(planned: const [PlannedPlace(id: 'x', name: 'X', type: PlaceType.other)]);
    expect(mergeTrips([local], [remote]).single.planned, isEmpty);
  });

  test('여행 마치기 → 지난 여행, 되돌리기·다시 이어가기, 새 여행은 이전 여행을 마친다', () async {
    final store = MemoryTripStore();
    var now = DateTime(2026, 11, 20, 18);
    final controller = TripController(clock: () => now, store: store)
      ..startTrip(cityId: '32030', cityName: '강릉시', provinceName: '강원특별자치도');
    final first = controller.trip!;
    controller.checkIn(_place);

    final ended = controller.endTrip()!;
    expect(controller.trip, isNull);
    expect(ended.endedAt, now);
    expect(controller.pastTrips.single.isEnded, isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(store.log.currentId, isNull);
    expect(store.log.trips.single.endedAt, now);

    controller.resumeTrip(first.id);
    expect(controller.trip!.id, first.id);
    expect(controller.trip!.isEnded, isFalse);
    expect(controller.pastTrips, isEmpty);

    now = DateTime(2026, 11, 21, 9);
    controller.startTrip(cityId: '39010', cityName: '제주시', provinceName: '제주특별자치도');
    expect(controller.trip!.cityId, '39010');
    expect(controller.pastTrips.single.id, first.id);
    expect(controller.pastTrips.single.endedAt, now, reason: '진행 중이던 여행은 새 여행 시작 때 마친다');

    controller.resumeTrip(first.id);
    expect(controller.trip!.id, first.id);
    expect(controller.pastTrips.single.cityId, '39010');
    expect(controller.pastTrips.single.isEnded, isTrue);
  });

  test('마친 시각은 저장·서버 행에 남고, 마친 여행은 다시 열 때 지금 여행이 되지 않는다', () async {
    final endedAt = DateTime(2026, 11, 20, 18, 30);
    final trip = _trip('t1', checkIns: [_c('a', 9)]).copyWith(ended: true, endedAt: endedAt);
    expect(decodeTripLog(encodeTripLog(TripLog(trips: [trip]))).trips.single.endedAt, endedAt);
    final row = tripToRow(trip, 'g');
    expect(tripFromRow({...row, 'check_ins': <Object>[]})!.endedAt, endedAt);
    expect(tripToRow(_trip('t2'), 'g')['ended_at'], isNull);

    final store = MemoryTripStore(TripLog(trips: [trip], currentId: 't1'));
    final controller = TripController(store: store);
    await controller.restore();
    expect(controller.trip, isNull);
    expect(controller.pastTrips.single.id, 't1');
  });

  test('여행 기간: 며칠째·D-n·기간 지남, 길이 표시, 날짜 줄', () {
    final trip = Trip(
      id: 't',
      cityId: '39010',
      cityName: '제주시',
      provinceName: '제주특별자치도',
      startDate: DateTime(2026, 11, 30),
      plannedDays: 3,
    );
    expect(trip.lengthLabel, '2박 3일');
    expect(trip.lastDate, DateTime(2026, 12, 2));
    expect(trip.statusOn(DateTime(2026, 11, 27, 9)), 'D-3');
    expect(trip.isBeforeStart(DateTime(2026, 11, 29, 23)), isTrue);
    expect(trip.statusOn(DateTime(2026, 11, 30, 0, 1)), '오늘 1일차');
    expect(trip.statusOn(DateTime(2026, 12, 1, 23, 59)), '오늘 2일차');
    expect(trip.statusOn(DateTime(2026, 12, 3)), '여행 기간이 지났어요');
    expect(dateRangeLabel(trip.startDate, trip.lastDate), '11월 30일 – 12월 2일');
    expect(monthDayLabel(DateTime(2026, 11, 20)), '11월 20일 (금)');
    expect(lengthLabelOf(1), '당일 여행');

    // 정한 기간보다 오래 체크인하면 그만큼 늘어난다.
    final longer = trip.copyWith(checkIns: [
      CheckIn(id: 'a', placeName: 'A', type: PlaceType.beach, at: DateTime(2026, 12, 3, 10)),
    ]);
    expect(longer.lengthLabel, '3박 4일');
    // 기간을 정하지 않으면 다녀온 날로.
    final open = longer.copyWith(setPlannedDays: true, plannedDays: null);
    expect(open.plannedDays, isNull);
    expect(open.statusOn(DateTime(2026, 12, 9)), '오늘 10일차');
  });

  test('출발일·기간을 정해 시작하고 바꾸면 저장·서버 행에 남는다', () async {
    final store = MemoryTripStore();
    final controller = TripController(clock: () => DateTime(2026, 11, 20, 10), store: store)
      ..startTrip(
        cityId: '39010',
        cityName: '제주시',
        provinceName: '제주특별자치도',
        startDate: DateTime(2026, 11, 28, 15),
        plannedDays: 3,
      );
    expect(controller.trip!.startDate, DateTime(2026, 11, 28));
    expect(controller.trip!.plannedDays, 3);
    controller.updateDates(startDate: DateTime(2026, 11, 29), plannedDays: 2);
    await Future<void>.delayed(Duration.zero);
    final saved = decodeTripLog(encodeTripLog(store.log)).trips.single;
    expect(saved.startDate, DateTime(2026, 11, 29));
    expect(saved.plannedDays, 2);
    final row = tripToRow(saved, 'g');
    expect(row['planned_days'], 2);
    expect(tripFromRow({...row, 'check_ins': <Object>[]})!.plannedDays, 2);
    expect(plannedDaysFrom(99), isNull);
  });

  test('체크인 시각 고치기·지우기·되돌리기, 지운 체크인은 서버에서 되살아나지 않는다', () async {
    final store = MemoryTripStore();
    final cloud = _FakeCloud();
    final controller = TripController(clock: () => DateTime(2026, 11, 20, 10), store: store, cloud: cloud)
      ..startTrip(cityId: '32030', cityName: '강릉시', provinceName: '강원특별자치도');
    final tripId = controller.trip!.id;
    controller.checkIn(_place);
    await Future<void>.delayed(Duration.zero);
    expect(cloud.remote.single.checkIns, hasLength(1));

    controller.updateCheckIn('gyeongpo', DateTime(2026, 11, 21, 9));
    expect(controller.trip!.days.single.label, '2일차');

    cloud.failPush = true; // 지울 때 서버에 닿지 않아도
    final removed = controller.removeCheckIn('gyeongpo')!;
    await Future<void>.delayed(Duration.zero);
    expect(controller.trip!.checkIns, isEmpty);
    expect(store.log.deletedCheckIns, {'$tripId|gyeongpo'});

    // 서버에는 아직 남아 있지만 합칠 때 되살아나지 않고, 다음 sync에서 지운다.
    cloud.failPush = false;
    await controller.sync();
    expect(controller.trip!.checkIns, isEmpty);
    expect(cloud.deleted, contains('$tripId/gyeongpo'));
    expect(cloud.remote.single.checkIns, isEmpty);

    controller.restoreCheckIn(removed);
    expect(controller.trip!.checkIns.single.id, 'gyeongpo');
  });

  test('여행 지우기: 목록과 서버에서 빠지고, 지금 여행이면 여행 중이 빈다', () async {
    final store = MemoryTripStore();
    final cloud = _FakeCloud();
    final controller = TripController(clock: () => DateTime(2026, 11, 20, 10), store: store, cloud: cloud)
      ..startTrip(cityId: '32030', cityName: '강릉시', provinceName: '강원특별자치도');
    final id = controller.trip!.id;
    await Future<void>.delayed(Duration.zero);
    controller.deleteTrip(id);
    expect(controller.trip, isNull);
    expect(controller.trips, isEmpty);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(cloud.deleted, [id]);
    expect(cloud.remote, isEmpty);
    expect(store.log.deletedTrips, isEmpty, reason: '서버에서 지웠으면 기록을 비운다');
  });

  test('가볼 곳을 날짜별로: 고른 날로 담고, 날 바꾸고, 기간을 줄이면 밖의 날은 날짜 미정', () async {
    final store = MemoryTripStore();
    final controller = TripController(clock: () => DateTime(2026, 11, 20, 10), store: store)
      ..startTrip(cityId: '32030', cityName: '강릉시', provinceName: '강원특별자치도', plannedDays: 3);
    controller.togglePlanned(_place, day: 1);
    const other = PlaceSuggestion(id: 'tour:2', name: '테라로사', type: PlaceType.cafe, meta: '카페');
    controller.togglePlanned(other, day: 2);
    expect(controller.trip!.planned.map((p) => p.day), [1, 2]);

    controller.setPlannedDay('gyeongpo', 0);
    expect(controller.trip!.planned.first.day, 0);
    controller.setPlannedDay('gyeongpo', null);
    expect(controller.trip!.planned.first.day, isNull);
    controller.setPlannedDay('gyeongpo', 1);

    await Future<void>.delayed(Duration.zero);
    final saved = decodeTripLog(encodeTripLog(store.log)).trips.single;
    expect(saved.planned.map((p) => p.day), [1, 2], reason: '폰 저장에도 날이 남는다');
    expect(tripToRow(saved, 'g')['planned'], [
      {'id': 'gyeongpo', 'name': '경포해변', 'type': 'beach', 'meta': '해변', 'day': 1},
      {'id': 'tour:2', 'name': '테라로사', 'type': 'cafe', 'meta': '카페', 'day': 2},
    ]);

    controller.updateDates(startDate: DateTime(2026, 11, 20), plannedDays: 2);
    expect(controller.trip!.planned.map((p) => p.day), [1, null], reason: '3일차는 없어졌으니 날짜 미정');
    expect(plannedFromJson({'id': 'a', 'name': 'A', 'day': 99})!.day, isNull, reason: '이상한 값은 버린다');
  });

  test('가볼 곳 순서 바꾸기: 보이던 것끼리만, 다른 날 장소 자리는 그대로', () async {
    PlannedPlace pl(String id, int? day) => PlannedPlace(id: id, name: id, type: PlaceType.other, day: day);
    final all = [pl('a', 0), pl('b', 1), pl('c', 0), pl('d', 0)];
    // 1일차(a, c, d)만 보고 d를 맨 앞으로
    expect(reorderSubset(all, ['d', 'a', 'c']).map((p) => p.id), ['d', 'b', 'a', 'c']);
    // 전체를 보고 바꾸기
    expect(reorderSubset(all, ['b', 'a', 'd', 'c']).map((p) => p.id), ['b', 'a', 'd', 'c']);
    // 이상한 목록이면 그대로
    expect(reorderSubset(all, ['a', 'a']), same(all));
    expect(reorderSubset(all, ['z']), same(all));

    final store = MemoryTripStore();
    final controller = TripController(clock: () => DateTime(2026, 11, 20, 10), store: store)
      ..startTrip(cityId: '32030', cityName: '강릉시', provinceName: '강원특별자치도');
    controller.togglePlanned(_place);
    controller.togglePlanned(const PlaceSuggestion(id: 'tour:2', name: '테라로사', type: PlaceType.cafe, meta: '카페'));
    controller.reorderPlanned(['tour:2', 'gyeongpo']);
    expect(controller.trip!.planned.map((p) => p.id), ['tour:2', 'gyeongpo']);
    await Future<void>.delayed(Duration.zero);
    expect(decodeTripLog(encodeTripLog(store.log)).trips.single.planned.map((p) => p.id), ['tour:2', 'gyeongpo'],
        reason: '바꾼 순서가 저장된다');
  });
}
