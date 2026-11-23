import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:where_to_go_pick/core/life/life_repository.dart';
import 'package:where_to_go_pick/core/text/josa.dart';
import 'package:where_to_go_pick/features/explore/trip_candidates.dart';
import 'package:where_to_go_pick/features/korea_map/korea_map_view.dart';
import 'package:where_to_go_pick/features/trip/trip_cloud.dart';
import 'package:where_to_go_pick/features/trip/trip_controller.dart';
import 'package:where_to_go_pick/features/trip/trip_models.dart';
import 'package:where_to_go_pick/features/trip/trip_screen.dart';

/// 올리기를 손으로 끝내는 가짜 서버: 동시에 몇 개가 올라가는지, 어떤 상태가 마지막에 남는지 본다.
class _SlowCloud implements TripCloud {
  final waiting = <Completer<void>>[];
  final pushedPlanned = <List<String>>[];
  var inFlight = 0;
  var maxInFlight = 0;

  @override
  Future<List<Trip>> pull() async => const [];

  @override
  Future<void> push(List<Trip> trips) async {
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    final done = Completer<void>();
    waiting.add(done);
    await done.future;
    pushedPlanned.add([for (final p in trips.single.planned) p.id]);
    inFlight--;
  }

  @override
  Future<void> deleteTrip(String tripId) async {}

  @override
  Future<void> deleteCheckIn(String tripId, String checkInId) async {}
}

const _a = PlaceSuggestion(id: 'a', name: '경포해변', type: PlaceType.beach, meta: '');
const _b = PlaceSuggestion(id: 'b', name: '오죽헌', type: PlaceType.heritage, meta: '');
const _c = PlaceSuggestion(id: 'c', name: '중앙시장', type: PlaceType.market, meta: '');

void main() {
  test('지역 이름: 한 글자만 남는 구는 그대로, 두 글자 구에는 도 이름', () {
    expect(regionShortName('강릉시'), '강릉');
    expect(regionShortName('중구'), '중구');
    expect(regionShortName('대전광역시'), '대전');
    expect(regionLabel('중구', '대전광역시'), '대전 중구');
    expect(regionLabel('동구', '부산광역시'), '부산 동구');
    expect(regionLabel('미추홀구', '인천광역시'), '미추홀');
    expect(regionLabel('대전광역시', '대전광역시'), '대전');
    final trip = Trip(id: 't', cityId: '25010', cityName: '중구', provinceName: '대전광역시', startDate: DateTime(2026, 11, 23));
    expect(trip.title, '대전 중구 여행');
  });

  test('조사: 받침에 맞춰', () {
    expect(withEun('강릉'), '강릉은');
    expect(withEun('속초시'), '속초시는');
    expect(withRo('양양군'), '양양군으로');
    expect(withRo('속초시'), '속초시로');
    expect(withRo('서울'), '서울로');
    expect(withRang('보리'), '보리랑');
    expect(withRang('픽클이'), '픽클이랑');
    expect(withRang('오죽헌'), '오죽헌이랑');
  });

  test('후보: 다섯 번째를 담으면 빠진 후보를 알려 주고, 하나씩 뺄 수 있다', () {
    SelectedCity city(String id) => SelectedCity(id: id, name: '$id시', provinceCode: '32', provinceName: '강원특별자치도');
    final store = TripCandidates.memory();
    for (final id in ['a', 'b', 'c', 'd']) {
      expect(store.toggle(city(id)), isNull);
    }
    expect(store.toggle(city('e'))?.id, 'a');
    store.remove('c');
    expect(store.items.map((c) => c.id), ['b', 'd', 'e']);
  });

  test('정한 기간이 지나면 여행 마치기를 권한다', () {
    final trip = Trip(
        id: 't', cityId: '32030', cityName: '강릉시', provinceName: '강원특별자치도', startDate: DateTime(2026, 11, 20), plannedDays: 2);
    expect(isPastPlannedEnd(trip, DateTime(2026, 11, 21, 23)), isFalse, reason: '마지막 날 당일');
    expect(isPastPlannedEnd(trip, DateTime(2026, 11, 22, 9)), isTrue);
    expect(isPastPlannedEnd(trip.copyWith(setPlannedDays: true, plannedDays: null), DateTime(2026, 11, 30)), isFalse);
  });

  test('서버에 올리기는 한 번에 하나씩, 마지막엔 가장 최근 상태가 남는다', () async {
    final cloud = _SlowCloud();
    final controller = TripController(clock: () => DateTime(2026, 11, 23, 10), cloud: cloud);
    controller.startTrip(cityId: '32030', cityName: '강릉시', provinceName: '강원특별자치도');
    controller.togglePlanned(_a);
    controller.togglePlanned(_b);
    controller.togglePlanned(_c);
    await Future<void>.delayed(Duration.zero);
    expect(cloud.inFlight, 1, reason: '먼저 보낸 것이 끝나기 전엔 다음 것을 보내지 않는다');
    while (cloud.waiting.isNotEmpty) {
      cloud.waiting.removeAt(0).complete();
      await Future<void>.delayed(Duration.zero);
    }
    expect(cloud.maxInFlight, 1);
    expect(cloud.pushedPlanned.last, ['a', 'b', 'c']);
    expect(cloud.pushedPlanned.length, lessThanOrEqualTo(2), reason: '기다리는 동안 바뀐 것은 한 번에 모아 보낸다');
    expect(controller.allSynced, isTrue);
  });
}
