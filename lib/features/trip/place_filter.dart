import 'trip_models.dart';

/// 여행 중 화면 추천 목록의 칩. 한 장소가 여러 칩에 들어갈 수 있다(명소 ⊃ 자연·문화·놀거리).
enum PlaceFilter {
  all('전체'),
  sights('명소'),
  nature('자연'),
  culture('문화'),
  leisure('놀거리'),
  food('맛집'),
  cafe('카페');

  const PlaceFilter(this.label);

  final String label;

  bool matches(PlaceType type) => switch (this) {
        PlaceFilter.all => true,
        PlaceFilter.sights => !_foodTypes.contains(type) && type != PlaceType.cafe,
        PlaceFilter.nature => type == PlaceType.nature || type == PlaceType.beach,
        PlaceFilter.culture => type == PlaceType.heritage || type == PlaceType.culture,
        PlaceFilter.leisure => type == PlaceType.leisure,
        PlaceFilter.food => _foodTypes.contains(type),
        PlaceFilter.cafe => type == PlaceType.cafe,
      };

  static const _foodTypes = {PlaceType.food, PlaceType.seafood, PlaceType.market};

  /// 장소가 하나라도 있는 칩만(전체는 늘). 순서는 enum 순서.
  static List<PlaceFilter> available(Iterable<PlaceType> types) {
    final list = types.toList();
    return [
      for (final f in PlaceFilter.values)
        if (f == PlaceFilter.all || list.any(f.matches)) f,
    ];
  }
}
