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
    const other = PlaceSuggestion(id: 'tour:2', name: '테라로사', type: PlaceType.cafe, meta: '카페');
    controller.togglePlanned(other);
    expect(controller.trip!.planned.map((p) => p.id), ['gyeongpo', 'tour:2']);
    expect(controller.isPlanned('tour:2'), isTrue);
    controller.togglePlanned(_place);
    expect(controller.trip!.planned.map((p) => p.name), ['테라로사']);
    await Future<void>.delayed(Duration.zero);

    final saved = decodeTripLog(encodeTripLog(store.log)).trips.single;
    expect(saved.planned.single.type, PlaceType.cafe);
    expect(saved.planned.single.meta, '카페');

    final row = tripToRow(saved, 'g');
    expect(row['planned'], [
      {'id': 'tour:2', 'name': '테라로사', 'type': 'cafe', 'meta': '카페'},
    ]);
    expect(tripFromRow({...row, 'check_ins': <Object>[]})!.planned.single.id, 'tour:2');
  });

  test('합칠 때 가볼 곳은 기기 쪽 목록을 그대로 쓴다', () {
    final local = _trip('t1').copyWith(planned: const []);
    final remote = _trip('t1').copyWith(planned: const [PlannedPlace(id: 'x', name: 'X', type: PlaceType.other)]);
    expect(mergeTrips([local], [remote]).single.planned, isEmpty);
  });
}
