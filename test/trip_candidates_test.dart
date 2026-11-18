import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:where_to_go_pick/features/explore/trip_candidates.dart';
import 'package:where_to_go_pick/features/korea_map/korea_map_view.dart';

SelectedCity city(String id, String name) =>
    SelectedCity(id: id, name: name, provinceCode: '32', provinceName: '강원특별자치도');

void main() {
  final gangneung = city('32030', '강릉시');
  final sokcho = city('32060', '속초시');
  final yangyang = city('32410', '양양군');

  test('담기·빼기, 다섯 번째를 담으면 가장 먼저 담은 후보가 빠진다', () {
    final store = TripCandidates.memory();
    store.toggle(gangneung);
    store.toggle(sokcho);
    expect(store.contains('32030'), isTrue);
    store.toggle(gangneung);
    expect(store.items.map((c) => c.id), ['32060']);

    for (var i = 0; i < 5; i++) {
      store.toggle(city('x$i', '도시$i'));
    }
    expect(store.items.length, TripCandidates.maxCandidates);
    expect(store.contains('32060'), isFalse);
  });

  test('여행을 시작하면 비우고, 되돌릴 수 있다. 물어본 투표는 남는다', () {
    final store = TripCandidates.memory(items: [sokcho, yangyang]);
    store.addPoll(AskedPoll(id: 'poll-1', cities: [sokcho, yangyang]));
    final removed = store.clear();
    expect(store.items, isEmpty);
    expect(store.polls.single.id, 'poll-1');
    store.restore(removed);
    expect(store.items.map((c) => c.name), ['속초시', '양양군']);
    expect(TripCandidates.memory().clear(), isEmpty);
  });

  test('물어본 투표는 최근 것부터 최대 5개', () {
    final store = TripCandidates.memory();
    for (var i = 1; i <= 7; i++) {
      store.addPoll(AskedPoll(id: 'p$i', cities: const []));
    }
    store.addPoll(const AskedPoll(id: 'p4', cities: []));
    expect(store.polls.map((p) => p.id), ['p4', 'p7', 'p6', 'p5', 'p3']);
  });

  test('저장 형식: 되읽기, 깨진 값은 빈 목록', () {
    final raw = encodeCities([gangneung, sokcho]);
    expect(decodeCities(raw).map((c) => c.provinceName), ['강원특별자치도', '강원특별자치도']);
    expect(decodeCities('{'), isEmpty);
    expect(decodeCities('[{"id": 1}]'), isEmpty);
    final polls = decodeAskedPolls(encodeAskedPolls([AskedPoll(id: 'p', cities: [yangyang])]));
    expect(polls.single.cities.single.name, '양양군');
    expect(decodeAskedPolls(null), isEmpty);
  });

  test('기기에 저장해서 다시 켜도 남는다', () async {
    SharedPreferences.setMockInitialValues({});
    final first = await TripCandidates.load();
    first.toggle(gangneung);
    first.addPoll(AskedPoll(id: 'poll-9', cities: [gangneung, sokcho]));
    await Future<void>.delayed(Duration.zero);
    final again = await TripCandidates.load();
    expect(again.items.single.id, '32030');
    expect(again.polls.single.cities.length, 2);
  });
}
