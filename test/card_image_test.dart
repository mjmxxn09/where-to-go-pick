import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:where_to_go_pick/features/trip/trip_models.dart';
import 'package:where_to_go_pick/features/trip_card/export/card_image.dart';
import 'package:where_to_go_pick/features/trip_card/trip_card_layout.dart';

void main() {
  test('카드 파일 이름: 앱·여행 제목(+ 나눠 보기면 그 날), 공백은 _', () {
    final trip = Trip(
      id: 't',
      cityId: '32030',
      cityName: '강릉시',
      provinceName: '강원특별자치도',
      startDate: DateTime(2026, 11, 13),
      checkIns: [
        CheckIn(id: 'a', placeName: 'A', type: PlaceType.beach, at: DateTime(2026, 11, 13, 9)),
        CheckIn(id: 'b', placeName: 'B', type: PlaceType.cafe, at: DateTime(2026, 11, 14, 9)),
      ],
    );
    final one = paginateTrip(trip, TripCardMode.onePage).single;
    final days = paginateTrip(trip, TripCardMode.perDay);
    expect(cardBaseName(trip, one, folder: false), '어디갈지Pick_강릉_여행');
    expect(cardBaseName(trip, days[1], folder: true), '어디갈지Pick_강릉_여행_2일차');
    expect(CardImage(bytes: Uint8List(0), baseName: 'x').fileName, 'x.png');
  });
}
