import 'package:flutter_test/flutter_test.dart';
import 'package:where_to_go_pick/features/trip/trip_models.dart';
import 'package:where_to_go_pick/features/trip_card/place_sticker_match.dart';

String? pick(String name, PlaceType type, {Set<String> used = const {}, bool Function(String)? has}) =>
    stickerForPlace(CheckIn(id: name, placeName: name, type: type, at: DateTime(2026, 11, 13)),
        has: has ?? (_) => true, used: used);

void main() {
  test('이름에 든 말로 어울리는 스티커', () {
    expect(pick('초당순두부마을', PlaceType.food), 'place_food_stew');
    expect(pick('주문진 수산시장', PlaceType.seafood), 'place_seafood_sashimi');
    expect(pick('안목 커피거리', PlaceType.cafe), 'place_cafe_coffee');
    expect(pick('강릉중앙시장', PlaceType.market), 'place_market_gate');
    expect(pick('속초 닭강정 골목', PlaceType.food), 'place_food_chicken');
    expect(pick('삼교리 동치미막국수', PlaceType.food), 'place_food_noodle');
    expect(pick('솔향수목원', PlaceType.nature), 'place_nature_forest');
    expect(pick('담양 죽녹원', PlaceType.nature), 'place_nature_bamboo');
    expect(pick('남한산성', PlaceType.heritage), 'place_heritage_fortress');
    expect(pick('불국사', PlaceType.heritage), 'place_heritage_pagoda');
  });

  test('종류가 달라도 이름이 더 정확하면 이름을 따른다', () {
    expect(pick('사천 바다 횟집', PlaceType.food), 'place_seafood_sashimi');
    expect(pick('바닷가 생선구이', PlaceType.food), 'place_seafood_grilled');
  });

  test('이름으로 모르면 종류 대표, 이미 쓴 그림이면 같은 종류의 다른 그림', () {
    expect(pick('정동진', PlaceType.beach), 'place_beach_parasol');
    expect(pick('정동진', PlaceType.beach, used: {'place_beach_parasol'}), 'place_beach_island');
    expect(pick('엄지네', PlaceType.food), 'place_food_stew');
  });

  test('그림이 없으면 고르지 않는다', () {
    expect(pick('경포해변', PlaceType.beach, has: (_) => false), isNull);
    expect(pick('초당순두부마을', PlaceType.food, has: (n) => n == 'place_food_noodle'), 'place_food_noodle');
  });
}
