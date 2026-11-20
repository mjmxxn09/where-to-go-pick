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
    expect(pick('양산 통도사', PlaceType.heritage), 'landmark_temple');
    expect(pick('양산 통도사', PlaceType.heritage, has: (n) => !n.startsWith('landmark_')), 'place_heritage_pagoda');
  });

  test('성당·절·교회는 명소 스티커', () {
    expect(pick('명동성당', PlaceType.heritage), 'landmark_cathedral');
    expect(pick('전주 전동성당', PlaceType.culture), 'landmark_cathedral');
    expect(pick('해미순교성지', PlaceType.other), 'landmark_cathedral');
    expect(pick('강경 북옥감리교회', PlaceType.heritage), 'landmark_church');
    expect(pick('여수 향일암', PlaceType.heritage), 'landmark_temple');
    expect(pick('월정사 템플스테이', PlaceType.leisure), 'landmark_temple');
    expect(pick('공주 마곡사', PlaceType.heritage), 'landmark_temple');
    expect(pick('부산 해동용궁사', PlaceType.heritage), 'landmark_haedong_yonggungsa');
    expect(pick('강릉 선교장', PlaceType.heritage), isNot('landmark_church'));
  });

  test('한국관광 100선으로 더한 스티커', () {
    expect(pick('동해 도째비골 해랑전망대', PlaceType.leisure), 'place_leisure_tower');
    expect(pick('에버랜드', PlaceType.leisure), 'place_leisure_themepark');
    expect(pick('목포 해상케이블카', PlaceType.leisure), 'place_leisure_cablecar');
    expect(pick('제천 청풍호반케이블카', PlaceType.nature), 'place_leisure_cablecar');
    expect(pick('국립중앙박물관', PlaceType.culture), 'place_culture_museum');
    expect(pick('파주 헤이리 예술마을', PlaceType.culture), 'place_culture_street');
    expect(pick('정읍 내장산국립공원', PlaceType.nature), 'place_nature_mountain');
    expect(pick('무등산', PlaceType.nature), 'place_nature_mountain');
    expect(pick('부산 돼지국밥', PlaceType.food), 'place_food_stew');
    expect(pick('창녕 우포늪', PlaceType.nature), 'place_nature_lake');
    expect(pick('예산 예당호 출렁다리', PlaceType.nature), 'place_nature_bridge');
    expect(pick('울산 대왕암공원', PlaceType.nature), 'place_beach_lighthouse');
    expect(pick('공주 무령왕릉과 왕릉원', PlaceType.heritage), 'place_heritage_tomb');
    expect(pick('서울 여의도한강공원', PlaceType.nature), 'place_nature_river');
    expect(pick('북한강', PlaceType.nature), 'place_nature_river');
    expect(pick('동강', PlaceType.nature), 'place_nature_river');
    expect(pick('태화강 국가정원', PlaceType.nature), 'place_nature_meadow');
    expect(pick('곡성 섬진강기차마을', PlaceType.leisure), 'place_leisure_cablecar');
    expect(pick('강릉 경포해변', PlaceType.beach), 'place_beach_parasol');
    expect(pick('망상', PlaceType.beach, used: {'place_beach_parasol', 'place_beach_island', 'place_beach_tube'}),
        'place_beach_lighthouse');
  });

  test('명소 이름이면 명소 전용 스티커가 먼저', () {
    expect(pick('남산서울타워', PlaceType.leisure), 'landmark_namsan_tower');
    expect(pick('경복궁', PlaceType.heritage), 'landmark_gwanghwamun');
    expect(pick('수원화성 관광특구', PlaceType.heritage), 'landmark_suwon_hwaseong');
    expect(pick('경주 동궁과 월지', PlaceType.heritage), 'landmark_donggung_wolji');
    expect(pick('불국사', PlaceType.heritage), 'landmark_dabotap');
    expect(pick('성산일출봉', PlaceType.nature), 'landmark_seongsan');
    expect(pick('울릉 독도', PlaceType.beach), 'landmark_dokdo');
    expect(pick('부산 광안리해수욕장', PlaceType.beach), 'landmark_gwangan_bridge');
    expect(pick('부산 해동 용궁사', PlaceType.heritage), 'landmark_haedong_yonggungsa');
    expect(pick('부산 감천문화마을', PlaceType.culture), 'landmark_gamcheon');
    expect(pick('안동 하회마을', PlaceType.heritage), 'landmark_hahoe_mask');
    expect(pick('춘천 남이섬', PlaceType.nature), 'landmark_namiseom');
    expect(pick('순천만습지', PlaceType.nature), 'landmark_suncheonman');
    expect(pick('단양 도담삼봉', PlaceType.nature), 'landmark_dodamsambong');
    expect(pick('평창 대관령 관광특구', PlaceType.nature), 'landmark_daegwallyeong');
    expect(pick('전주 한옥마을', PlaceType.heritage), 'landmark_jeonju_hanok');
    expect(pick('완주 오성한옥마을', PlaceType.heritage), 'place_heritage_hanok');
    expect(pick('포항 스페이스워크', PlaceType.leisure), 'landmark_pohang_spacewalk');
    expect(pick('속초 설악산 국립공원(외설악)', PlaceType.nature), 'landmark_ulsanbawi');
    expect(pick('여수 엑스포박람회장', PlaceType.culture), 'landmark_yeosu_night');
    expect(pick('인천 차이나타운', PlaceType.culture), 'landmark_chinatown');
    expect(pick('제주올레길', PlaceType.nature), 'landmark_dolhareubang');
    expect(pick('한라산', PlaceType.nature), 'landmark_hallasan');
    expect(pick('우도', PlaceType.beach), 'landmark_udo');
    expect(pick('경주 첨성대', PlaceType.heritage), 'landmark_cheomseongdae');
    expect(pick('단양 만천하 스카이워크', PlaceType.leisure), 'landmark_mancheonha');
    expect(pick('롯데월드타워 서울스카이', PlaceType.leisure), 'landmark_lotte_tower');
    expect(pick('보성 대한다원', PlaceType.nature), 'landmark_boseong_tea');
    expect(pick('진해 여좌천', PlaceType.nature), 'landmark_jinhae_cherry');
    expect(pick('정동진', PlaceType.beach), 'landmark_jeongdongjin');
    expect(pick('경포대', PlaceType.heritage), 'landmark_gyeongpodae');
    expect(pick('경포해변', PlaceType.beach), 'place_beach_parasol');
    expect(pick('오죽헌', PlaceType.heritage), 'landmark_ojukheon');
    expect(pick('통영 동피랑 벽화마을', PlaceType.culture), 'landmark_dongpirang');
    expect(pick('경주 황리단길', PlaceType.culture), 'landmark_hwangnidan');
    expect(pick('부산 해운대 블루라인파크 스카이캡슐', PlaceType.leisure), 'landmark_haeundae_capsule');
    expect(pick('태안 꽃지해수욕장', PlaceType.beach), 'landmark_kkotji');
    expect(pick('북촌한옥마을', PlaceType.heritage), 'landmark_bukchon');
    expect(pick('경주 대릉원', PlaceType.heritage), 'landmark_daereungwon');
    expect(pick('안동 월정교', PlaceType.heritage), 'landmark_woljeonggyo');
    expect(pick('협재해수욕장', PlaceType.beach), 'landmark_hyeopjae');
    expect(pick('속초 아바이마을', PlaceType.culture), 'landmark_abai_gaetbae');
    expect(pick('반포한강공원', PlaceType.nature), 'landmark_banpo_rainbow');
    expect(pick('남해 독일마을', PlaceType.culture), 'landmark_german_village');
    expect(pick('거제 바람의 언덕', PlaceType.nature), 'landmark_windy_hill');
    expect(pick('광명동굴', PlaceType.leisure), 'landmark_gwangmyeong_cave');
    expect(pick('단양 고수동굴', PlaceType.nature), 'landmark_gwangmyeong_cave');
    expect(pick('파주 임진각', PlaceType.heritage), 'landmark_imjingak');
    // 그림이 없으면 원래 규칙으로
    expect(pick('남산서울타워', PlaceType.leisure, has: (n) => !n.startsWith('landmark_')), 'place_leisure_tower');
  });

  test('종류가 달라도 이름이 더 정확하면 이름을 따른다', () {
    expect(pick('사천 바다 횟집', PlaceType.food), 'place_seafood_sashimi');
    expect(pick('바닷가 생선구이', PlaceType.food), 'place_seafood_grilled');
  });

  test('이름으로 모르면 종류 대표, 이미 쓴 그림이면 같은 종류의 다른 그림', () {
    expect(pick('망상', PlaceType.beach), 'place_beach_parasol');
    expect(pick('망상', PlaceType.beach, used: {'place_beach_parasol'}), 'place_beach_island');
    expect(pick('엄지네', PlaceType.food), 'place_food_stew');
  });

  test('그림이 없으면 고르지 않는다', () {
    expect(pick('경포해변', PlaceType.beach, has: (_) => false), isNull);
    expect(pick('초당순두부마을', PlaceType.food, has: (n) => n == 'place_food_noodle'), 'place_food_noodle');
  });
}
