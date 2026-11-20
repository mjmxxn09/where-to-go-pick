import 'package:flutter_test/flutter_test.dart';
import 'package:where_to_go_pick/features/trip/place_filter.dart';
import 'package:where_to_go_pick/features/trip/trip_models.dart';

void main() {
  test('칩별로 들어가는 장소 종류', () {
    expect(PlaceFilter.sights.matches(PlaceType.beach), isTrue);
    expect(PlaceFilter.sights.matches(PlaceType.cafe), isFalse);
    expect(PlaceFilter.sights.matches(PlaceType.market), isFalse);
    expect(PlaceFilter.nature.matches(PlaceType.beach), isTrue);
    expect(PlaceFilter.culture.matches(PlaceType.heritage), isTrue);
    expect(PlaceFilter.culture.matches(PlaceType.culture), isTrue);
    expect(PlaceFilter.food.matches(PlaceType.seafood), isTrue);
    expect(PlaceFilter.food.matches(PlaceType.cafe), isFalse);
    expect(PlaceFilter.cafe.matches(PlaceType.cafe), isTrue);
    expect(PlaceFilter.all.matches(PlaceType.lodging), isTrue);
  });

  test('장소가 있는 칩만 보인다(전체는 늘)', () {
    expect(PlaceFilter.available([PlaceType.beach, PlaceType.food]),
        [PlaceFilter.all, PlaceFilter.sights, PlaceFilter.nature, PlaceFilter.food]);
    expect(PlaceFilter.available(const []), [PlaceFilter.all]);
  });
}
