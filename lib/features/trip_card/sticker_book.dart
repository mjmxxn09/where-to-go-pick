import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import '../trip/trip_models.dart';

/// 여행 노트에 붙이는 스티커 그림(assets/stickers/*.png).
///
/// - 유저가 스티커 서랍에서 골라 카드에 붙인다([catalog]). "자동으로 꾸미기"는 장소 종류로 골라 붙인다.
/// - 장소 종류마다 그림이 여러 장이면, 장소 이름으로 하나를 골라 같은 장소는 늘 같은 그림이 나온다.
/// - 파일이 없거나 읽지 못한 그림은 서랍에 나오지 않는다.
/// - 그림 출처: Gemini로 만든 시안(2026-11-13). 정식 출시 전 이용 약관·저작권 확인 필요(docs/stickers.md).
class StickerBook {
  StickerBook(this._images);

  /// 빈 책 — 서랍에 아무 스티커도 나오지 않는다.
  StickerBook.empty() : _images = const {};

  static const folder = 'assets/stickers';

  static const placeStickers = <PlaceType, List<String>>{
    PlaceType.beach: ['place_beach_parasol', 'place_beach_island', 'place_beach_tube', 'place_beach_lighthouse'],
    PlaceType.cafe: ['place_cafe_coffee', 'place_cafe_terrace', 'place_cafe_store'],
    PlaceType.heritage: ['place_heritage_hanok', 'place_heritage_pagoda', 'place_heritage_fortress', 'place_heritage_tomb'],
    PlaceType.market: ['place_market_gate', 'place_market_produce', 'place_market_foodcart'],
    PlaceType.food: [
      'place_food_stew', 'place_food_noodle', 'place_food_bbq',
      'place_food_chicken', 'place_food_beer', 'place_food_jajangmyeon',
    ],
    PlaceType.seafood: ['place_seafood_sashimi', 'place_seafood_grilled'],
    PlaceType.nature: [
      'place_nature_forest', 'place_nature_waterfall', 'place_nature_meadow',
      'place_nature_bamboo', 'place_nature_mountain', 'place_nature_lake', 'place_nature_bridge',
      'place_nature_river',
    ],
    PlaceType.lodging: [
      'place_lodging_hanok', 'place_lodging_hotel', 'place_lodging_resort', 'place_lodging_camping',
    ],
    // 2026-11-20 한국관광 100선 분류로 모자란 그림을 직접 그려 더함(docs/stickers.md)
    PlaceType.leisure: ['place_leisure_themepark', 'place_leisure_cablecar', 'place_leisure_tower'],
    PlaceType.culture: ['place_culture_museum', 'place_culture_street'],
    PlaceType.other: [],
  };

  /// 명소 전용 스티커(손그림). 장소 이름이 맞으면 종류별 스티커보다 먼저 쓴다([landmarkKeywords]).
  static const landmarkStickers = [
    'landmark_namsan_tower', 'landmark_gwanghwamun', 'landmark_suwon_hwaseong', 'landmark_donggung_wolji',
    'landmark_dabotap', 'landmark_seongsan', 'landmark_dokdo', 'landmark_gwangan_bridge',
    'landmark_haedong_yonggungsa', 'landmark_gamcheon', 'landmark_hahoe_mask', 'landmark_namiseom',
    'landmark_suncheonman', 'landmark_dodamsambong', 'landmark_daegwallyeong',
    'landmark_jeonju_hanok',
    'landmark_pohang_spacewalk',
    'landmark_ulsanbawi',
    'landmark_yeosu_night',
    'landmark_chinatown',
    'landmark_dolhareubang',
    'landmark_hallasan',
    'landmark_udo',
    'landmark_cheomseongdae',
    'landmark_mancheonha',
    'landmark_lotte_tower',
    'landmark_boseong_tea',
    'landmark_jinhae_cherry',
    'landmark_jeongdongjin',
    'landmark_gyeongpodae',
    'landmark_ojukheon',
    'landmark_dongpirang',
    'landmark_hwangnidan',
    'landmark_haeundae_capsule',
    'landmark_kkotji',
    'landmark_bukchon',
    'landmark_daereungwon',
    'landmark_woljeonggyo',
    'landmark_hyeopjae',
    'landmark_abai_gaetbae',
    'landmark_banpo_rainbow',
    'landmark_german_village',
    'landmark_windy_hill',
    'landmark_gwangmyeong_cave',
    'landmark_imjingak',
  ];

  static const moveStickers = ['move_bus', 'move_car', 'move_bike', 'move_plane', 'move_ship', 'move_walk'];

  /// 투표 스티커. [votePin]("한 표 핀")을 장소 옆에 붙이면 그 장소가 투표 후보가 된다(card_stickers.dart [voteCandidates]).
  static const votePin = 'vote_pick';
  static const voteStickers = [votePin, 'vote_vs', 'vote_box'];

  /// 스티커 서랍 분류(장소 종류 + 투표 + 이동). 그림이 없는 분류도 포함하므로 화면에서 [has]로 거른다.
  static List<({String label, List<String> names})> get catalog => [
        for (final e in placeStickers.entries)
          if (e.value.isNotEmpty) (label: e.key.label, names: e.value),
        (label: '명소', names: landmarkStickers),
        (label: '투표', names: voteStickers),
        (label: '이동', names: moveStickers),
      ];

  final Map<String, ui.Image> _images;

  bool has(String name) => _images.containsKey(name);

  ui.Image? image(String name) => _images[name];

  bool get isEmpty => _images.isEmpty;

  static Future<StickerBook> load(AssetBundle bundle, {int decodeWidth = 256}) async {
    final names = [
      for (final list in placeStickers.values) ...list,
      ...landmarkStickers,
      ...voteStickers,
      ...moveStickers,
    ];
    final images = <String, ui.Image>{};
    for (final name in names) {
      try {
        final data = await bundle.load('$folder/$name.png');
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: decodeWidth);
        images[name] = (await codec.getNextFrame()).image;
      } on Object {
        // 파일이 없으면 건너뛴다(선 그림으로 대체).
      }
    }
    return StickerBook(images);
  }

  /// 장소 종류에 맞는 그림. [seed](보통 장소 이름)로 여러 장 중 하나를 고른다.
  ui.Image? forPlace(PlaceType type, String seed) {
    final available = (placeStickers[type] ?? const <String>[]).where(_images.containsKey).toList();
    final name = pickVariant(available, seed);
    return name == null ? null : _images[name];
  }

  ui.Image? move(String name) => _images[name];

  void dispose() {
    for (final image in _images.values) {
      image.dispose();
    }
  }
}

/// 같은 [seed]면 늘 같은 항목을 고른다(순수 함수, 테스트용으로 공개).
String? pickVariant(List<String> options, String seed) {
  if (options.isEmpty) return null;
  var h = 0;
  for (final c in seed.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return options[h % options.length];
}
