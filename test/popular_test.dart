import 'package:flutter_test/flutter_test.dart';
import 'package:where_to_go_pick/core/life/life_repository.dart';
import 'package:where_to_go_pick/features/trip/trip_models.dart';

void main() {
  test('장소 목록을 인기 장소 칸으로: 칸마다 앞에서 5곳, 빈 칸은 뺀다', () {
    final places = [
      for (var i = 0; i < 7; i++) PlaceSuggestion(id: 'b$i', name: '해변 $i', type: PlaceType.beach, meta: ''),
      const PlaceSuggestion(id: 'f', name: '순두부', type: PlaceType.food, meta: ''),
      const PlaceSuggestion(id: 'm', name: '시장', type: PlaceType.market, meta: ''),
    ];
    final sections = popularFrom(places);
    expect(sections.map((s) => s.key), ['sights', 'food']);
    expect(sections.first.places, hasLength(5));
    expect(sections.last.places.map((p) => p.id), ['f', 'm']);
  });

  test('예시 데이터도 인기 장소·검색을 준다', () async {
    const life = FixtureLifeRepository();
    final popular = await life.popular(cityId: '32030');
    expect(popular.source, PlaceSource.sample);
    expect(popular.sections, isNotEmpty);
    final found = await life.search(cityId: '32030', query: '순두부');
    expect(found.places.single.name, '초당순두부마을');
  });
}
