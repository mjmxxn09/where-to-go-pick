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
  // 놀거리 (타워·케이블카를 놀이공원보다 먼저: "롯데월드타워", "청풍호반케이블카")
  (['케이블카', '모노레일', '곤돌라', '레일바이크', '레일웨이', '기차마을', '짚라인'], 'place_leisure_cablecar'),
  (['타워', '전망대', '스카이워크', '스페이스워크', '엑스더스카이', '서울스카이', '스카이밸리'], 'place_leisure_tower'),
  (['놀이공원', '테마파크', '어드벤처', '에버랜드', '서울랜드', '반디랜드', '캐리비안', '루지', '동물원', '아쿠아리움'],
      'place_leisure_themepark'),
  // 문화시설
  (['박물관', '미술관', '과학관', '뮤지엄', '기념관', '역사관', '전시관', '문화전당', '갤러리', '아트센터', '엑스포', '박람회'],
      'place_culture_museum'),
  (['골목', '벽화', '거리', '예술마을', '문화마을', '차이나타운', '독일마을', '황리단길', '로데오', '광장'],
      'place_culture_street'),
  // 시장
  (['야시장', '포장마차', '먹자골목', '푸드트럭'], 'place_market_foodcart'),
  (['청과', '과일', '농산물'], 'place_market_produce'),
  (['시장', '장터'], 'place_market_gate'),
  // 바닷가 바위·등대 (공원보다 먼저: "대왕암공원")
  (['등대', '곶', '태종대', '대왕암', '해안절벽'], 'place_beach_lighthouse'),
  // 자연
  (['대나무', '대숲', '죽녹원', '죽림'], 'place_nature_bamboo'),
  (['폭포', '계곡'], 'place_nature_waterfall'),
  (['호수', '저수지', '늪', '습지', '두물머리', '댐', '주산지'], 'place_nature_lake'),
  (['출렁다리', '흔들다리', '구름다리', '현수교', '잔도', '부채길', '주상절리'], 'place_nature_bridge'),
  (['국립공원', '도립공원', '군립공원', '알프스', '오름', '일출봉', '등산', '설악산', '한라산', '지리산', '북한산', '대관령'],
      'place_nature_mountain'),
  (['수목원', '식물원', '휴양림', '숲', '산림', '비자림', '제림'], 'place_nature_forest'),
  (['공원', '정원', '들판', '초원', '목장', '억새', '평원', '꽃밭', '매화', '매실', '파크'], 'place_nature_meadow'),
  // 강: '강' 한 글자로는 강릉·강원·강화가 걸려 강 이름·강변 말만 본다. 이름이 …강으로 끝나면 아래 규칙으로.
  // 들판보다 뒤: "태화강 국가정원"은 정원, "여의도한강공원"은 공원이 흔한 말이라 강.
  (['한강', '북한강', '남한강', '낙동강', '금강', '섬진강', '영산강', '태화강', '임진강', '강변', '강가', '강둑', '물길', '하천', '천변'],
      'place_nature_river'),
  // 해변
  (['워터파크', '튜브'], 'place_beach_tube'),
  (['해수욕장', '해변', '비치', '해안', 'SUP', '서핑'], 'place_beach_parasol'),
  (['섬', '독도', '울릉도', '우도', '제부도'], 'place_beach_island'),
  // 문화유산
  (['왕릉', '고분', '첨성대', '유적', '월지', '릉원', '능원', '광한루', '현충사'], 'place_heritage_tomb'),
  (['탑', '사찰', '암자', '대웅전', '석굴암'], 'place_heritage_pagoda'),
  (['산성', '읍성', '성곽', '성벽', '화성', '요새', '진주성'], 'place_heritage_fortress'),
  (['한옥', '고택', '향교', '서원', '종택', '궁', '민속촌', '하회마을', '서촌'], 'place_heritage_hanok'),
];

/// 이름에 흔히 붙는 말. 다른 또렷한 말이 없을 때만 쓴다("○○공원", "○○거리", "○○숲").
const weakPlaceWords = {'공원', '파크', '거리', '숲', '광장'};

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
  PlaceType.leisure: 'place_leisure_themepark',
  PlaceType.culture: 'place_culture_museum',
};

/// 장소에 어울리는 스티커를 고른다.
///
/// 1. 이름에 든 말이 그 장소 종류의 스티커와 맞으면 그것(예: 초당순두부마을 → 찌개, 주문진 수산시장 → 회)
/// 2. 종류가 달라도 이름에 든 말이 맞으면 그것(예: 맛집으로 저장된 "OO 횟집" → 회)
///    단 "공원·거리·숲" 같은 흔한 말([weakPlaceWords])은 또렷한 말이 하나도 없을 때만 본다.
/// 3. 절 이름(…사)은 탑, 자연에서 산 이름(…산·…봉)은 산
/// 4. 아니면 종류 대표 스티커. 같은 카드에 이미 쓴 그림([used])이면 같은 종류의 다른 그림
///
/// [has]로 실제 그림이 있는 것만 고른다. 없으면 null.
String? stickerForPlace(CheckIn place, {required bool Function(String name) has, Set<String> used = const {}}) {
  final name = place.placeName.replaceAll(' ', '');
  final own = StickerBook.placeStickers[place.type] ?? const <String>[];
  String? byKeyword({required bool ownTypeOnly, required bool weak}) {
    for (final (words, sticker) in placeNameKeywords) {
      if (ownTypeOnly && !own.contains(sticker)) continue;
      if (!has(sticker)) continue;
      final hit = words.where((w) => name.contains(w.replaceAll(' ', '')));
      if (hit.any((w) => weak || !weakPlaceWords.contains(w))) return sticker;
    }
    return null;
  }

  // 또렷한 말 먼저(제 종류 → 다른 종류), 흔한 말은 나중에: "대왕암공원"은 공원(들판)보다 대왕암(등대).
  final matched = byKeyword(ownTypeOnly: true, weak: false) ??
      byKeyword(ownTypeOnly: false, weak: false) ??
      byKeyword(ownTypeOnly: true, weak: true) ??
      byKeyword(ownTypeOnly: false, weak: true);
  if (matched != null) return matched;
  if (place.type == PlaceType.heritage && name.endsWith('사') && has('place_heritage_pagoda')) {
    return 'place_heritage_pagoda';
  }
  // 강 이름(…강)은 강 — 자연·기타로 저장된 곳만
  if ((place.type == PlaceType.nature || place.type == PlaceType.other) && name.endsWith('강') && has('place_nature_river')) {
    return 'place_nature_river';
  }
  // 산 이름(…산, …봉)은 산 — 자연·기타로 저장된 곳만("부산"처럼 지명에 '산'이 든 맛집이 산이 되지 않게)
  if ((place.type == PlaceType.nature || place.type == PlaceType.other) &&
      (name.endsWith('산') || name.endsWith('봉')) &&
      has('place_nature_mountain')) {
    return 'place_nature_mountain';
  }

  final fallback = placeTypeDefaults[place.type];
  final options = [if (fallback != null) fallback, ...own.where((s) => s != fallback)].where(has).toList();
  if (options.isEmpty) return null;
  return options.firstWhere((s) => !used.contains(s), orElse: () => options.first);
}
