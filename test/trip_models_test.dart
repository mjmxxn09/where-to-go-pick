import 'package:flutter_test/flutter_test.dart';
import 'package:where_to_go_pick/core/life/life_repository.dart';
import 'package:where_to_go_pick/features/trip/trip_controller.dart';
import 'package:where_to_go_pick/features/trip/trip_models.dart';

void main() {
  test('체크인은 넣은 순서와 상관없이 시간순으로 정렬된다', () {
    final trip = Trip(
      id: 't',
      cityId: '32030',
      cityName: '강릉시',
      provinceName: '강원특별자치도',
      startDate: DateTime(2026, 11, 13),
      checkIns: [
        CheckIn(id: 'b', placeName: 'B', type: PlaceType.cafe, at: DateTime(2026, 11, 13, 15)),
        CheckIn(id: 'a', placeName: 'A', type: PlaceType.beach, at: DateTime(2026, 11, 13, 9)),
        CheckIn(id: 'c', placeName: 'C', type: PlaceType.food, at: DateTime(2026, 11, 14, 8)),
      ],
    );
    expect(trip.checkIns.map((c) => c.id), ['a', 'b', 'c']);
    expect(trip.days.map((d) => d.label), ['1일차', '2일차']);
    expect(trip.lengthLabel, '1박 2일');
    expect(trip.title, '강릉 여행');
  });

  test('같은 장소는 두 번 체크인되지 않는다', () {
    var now = DateTime(2026, 11, 13, 10);
    final controller = TripController(clock: () => now)
      ..startTrip(cityId: '32030', cityName: '강릉시', provinceName: '강원특별자치도');
    const place = PlaceSuggestion(id: 'p', name: '경포해변', type: PlaceType.beach, meta: '해변');
    controller.checkIn(place);
    now = DateTime(2026, 11, 13, 11);
    controller.checkIn(place);
    expect(controller.trip!.checkIns, hasLength(1));
  });
}
