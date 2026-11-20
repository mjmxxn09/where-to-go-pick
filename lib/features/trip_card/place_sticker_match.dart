import '../trip/trip_models.dart';
import 'sticker_book.dart';

/// 장소 이름에 이 말이 들어 있으면 이 스티커. 위에서부터 먼저 맞는 것을 쓴다(구체적인 말을 위에).
const placeNameKeywords = <(List<String>, String)>[
  // 맛집
  (['순두부', '찌개', '국밥', '해장국', '곰탕', '설렁탕', '감자탕', '전골'], 'place_food_stew'),
  (['칼국수', '국수', '냉면', '막국수', '우동', '라멘', '소바', '쌀국수'], 'place_food_noodle'),
  (['짜장', '짬뽕', '중화', '중국집', '반점', '마라'], 'place_food_jajangmyeon'),
  (['치킨', '닭강정', '통닭', '후라이드'], 'place_food_chicken'),
  (['맥주', '브루어리', '브루잉', '호프', '펍', '비어'], 'place_food_beer'),
  (['생선구이', '장어', '고등어', '조개구이'], 'place_seafood_grilled'),
  (['갈비', '삼겹', '고기', '숯불', '한우', '정육', '바베큐', '바비큐', '닭갈비'], 'place_food_bbq'),
  // 수산
  (['횟집', '회센터', '수산', '어시장', '물회', '어판장'], 'place_seafood_sashimi'),
  // 카페
  (['베이커리', '빵집', '제과'], 'place_cafe_store'),
  (['테라스', '루프탑'], 'place_cafe_terrace'),
  (['커피', '카페', '로스터리', '로스터스', '다방', '찻집'], 'place_cafe_coffee'),
  // 숙소
  (['캠핑', '글램핑', '야영', '오토캠핑'], 'place_lodging_camping'),
  (['리조트', '콘도'], 'place_lodging_resort'),
  (['호텔'], 'place_lodging_hotel'),
  (['한옥스테이', '한옥 스테이', '고택 스테이'], 'place_lodging_hanok'),
  // 시장
  (['야시장', '포장마차', '먹자골목', '푸드트럭'], 'place_market_foodcart'),
  (['청과', '과일', '농산물'], 'place_market_produce'),
  (['시장'], 'place_market_gate'),
  // 자연
  (['대나무', '대숲', '죽녹원', '죽림'], 'place_nature_bamboo'),
  (['폭포', '계곡'], 'place_nature_waterfall'),
  (['수목원', '휴양림', '숲', '산림'], 'place_nature_forest'),
  (['공원', '정원', '들판', '초원', '목장', '억새', '평원', '꽃밭', '습지'], 'place_nature_meadow'),
  // 해변
  (['워터파크', '튜브'], 'place_beach_tube'),
  (['해수욕장', '해변', '비치', '해안'], 'place_beach_parasol'),
  (['섬'], 'place_beach_island'),
  // 문화유산
  (['탑', '사찰', '암자', '대웅전'], 'place_heritage_pagoda'),
  (['산성', '읍성', '성곽', '성벽', '화성', '요새'], 'place_heritage_fortress'),
  (['한옥', '고택', '향교', '서원', '종택', '궁'], 'place_heritage_hanok'),
];

/// 장소 종류만 알 때 쓰는 대표 스티커(가장 무난한 그림).
const placeTypeDefaults = <PlaceType, String>{
  PlaceType.beach: 'place_beach_parasol',
  PlaceType.cafe: 'place_cafe_coffee',
  PlaceType.heritage: 'place_heritage_hanok',
  PlaceType.market: 'place_market_gate',
  PlaceType.food: 'place_food_stew',
  PlaceType.seafood: 'place_seafood_sashimi',
  PlaceType.nature: 'place_nature_forest',
  PlaceType.lodging: 'place_lodging_hotel',
};

/// 장소에 어울리는 스티커를 고른다.
///
/// 1. 이름에 든 말이 그 장소 종류의 스티커와 맞으면 그것(예: 초당순두부마을 → 찌개, 주문진 수산시장 → 회)
/// 2. 종류가 달라도 이름에 든 말이 맞으면 그것(예: 맛집으로 저장된 "OO 횟집" → 회)
/// 3. 절 이름(…사)은 탑
/// 4. 아니면 종류 대표 스티커. 같은 카드에 이미 쓴 그림([used])이면 같은 종류의 다른 그림
///
/// [has]로 실제 그림이 있는 것만 고른다. 없으면 null.
String? stickerForPlace(CheckIn place, {required bool Function(String name) has, Set<String> used = const {}}) {
  final name = place.placeName.replaceAll(' ', '');
  final own = StickerBook.placeStickers[place.type] ?? const <String>[];
  String? byKeyword({required bool ownTypeOnly}) {
    for (final (words, sticker) in placeNameKeywords) {
      if (ownTypeOnly && !own.contains(sticker)) continue;
      if (!has(sticker)) continue;
      if (words.any((w) => name.contains(w.replaceAll(' ', '')))) return sticker;
    }
    return null;
  }

  final matched = byKeyword(ownTypeOnly: true) ?? byKeyword(ownTypeOnly: false);
  if (matched != null) return matched;
  if (place.type == PlaceType.heritage && name.endsWith('사') && has('place_heritage_pagoda')) {
    return 'place_heritage_pagoda';
  }

  final fallback = placeTypeDefaults[place.type];
  final options = [if (fallback != null) fallback, ...own.where((s) => s != fallback)].where(has).toList();
  if (options.isEmpty) return null;
  return options.firstWhere((s) => !used.contains(s), orElse: () => options.first);
}
