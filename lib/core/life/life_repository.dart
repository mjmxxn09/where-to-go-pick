import '../../features/trip/trip_models.dart';
import '../votes/vote_repository.dart';

/// 하늘 상태(기상청 단기예보 SKY·PTY를 앱용으로 단순화).
enum Sky { sunny, cloudy, rainy, snowy }

class HourlyWeather {
  const HourlyWeather({required this.hour, required this.temperature, required this.sky});

  final int hour;
  final int temperature;
  final Sky sky;
}

class DayWeather {
  const DayWeather({
    required this.sky,
    required this.temperature,
    required this.min,
    required this.max,
    required this.hourly,
    this.tip,
  });

  final Sky sky;
  final int temperature;
  final int min;
  final int max;
  final List<HourlyWeather> hourly;
  final String? tip;
}

/// 명소·맛집 추천 한 건(TourAPI + 픽클 '다녀온 사람 표' 순위를 생활 서버가 합쳐서 내려줄 형태).
class PlaceSuggestion {
  const PlaceSuggestion({
    required this.id,
    required this.name,
    required this.type,
    required this.meta,
    this.visitorRank,
    this.url,
    this.location,
  });

  final String id;
  final String name;
  final PlaceType type;
  final String meta;

  /// 장소 상세 페이지(카카오맵). 누르면 사진·리뷰·길찾기를 볼 수 있다. 없으면 null.
  final String? url;

  /// 픽클 "다녀온 사람 표" 순위. 표가 아직 없으면 null.
  final VisitorRank? visitorRank;

  /// 장소 좌표(가볼 곳 지도용). 없으면 null.
  final GeoPoint? location;

  bool get isFood => type == PlaceType.food || type == PlaceType.market || type == PlaceType.seafood || type == PlaceType.cafe;
}

/// 인기 장소 한 칸: "명소" 5곳, "맛집" 5곳 …
class PlaceSection {
  const PlaceSection({required this.key, required this.label, required this.places});

  final String key;
  final String label;
  final List<PlaceSuggestion> places;
}

/// 장소 정보를 어디서 가져왔는지(화면 아래 출처 표시).
enum PlaceSource {
  kakao('카카오맵'),
  tour('한국관광공사'),
  sample('예시');

  const PlaceSource(this.label);

  final String label;
}

class PopularPlaces {
  const PopularPlaces({required this.sections, required this.source});

  final List<PlaceSection> sections;
  final PlaceSource source;
}

class PlaceSearchResult {
  const PlaceSearchResult({required this.places, required this.source, this.hasMore = false, this.outside = false});

  final List<PlaceSuggestion> places;
  final PlaceSource source;

  /// 다음 쪽이 있다(카카오는 한 검색어에 3쪽까지).
  final bool hasMore;

  /// 이 지역에서 못 찾아 전국에서 찾은 결과.
  final bool outside;
}

/// 여행지 정보 경계. 공공 API 키는 서버(Supabase Edge Function `life`)에만 두고, 앱은 이 경계만 본다.
/// - 날씨: 기상청 단기예보(위경도 → 격자 변환·캐시는 서버 책임)
/// - 인기 장소·검색: 카카오맵(키가 없으면 한국관광공사 TourAPI) + 픽클 투표
abstract interface class LifeRepository {
  Future<DayWeather> weather({required String cityId, required DateTime date});
  Future<List<PlaceSuggestion>> places({required String cityId, required List<String> interestKeys});

  /// 지역별·종류별 인기 장소(명소·맛집·카페·문화, 칸마다 5곳 안팎).
  Future<PopularPlaces> popular({required String cityId});

  /// 이름으로 찾기(그 시·군·구 안, 없으면 더 넓게). [page]는 1부터.
  Future<PlaceSearchResult> search({required String cityId, required String query, int page = 1});
}

/// 서버가 생기기 전까지 쓰는 강릉 예시 데이터. 숫자는 모두 예시다.
class FixtureLifeRepository implements LifeRepository {
  const FixtureLifeRepository();

  @override
  Future<DayWeather> weather({required String cityId, required DateTime date}) async => const DayWeather(
        sky: Sky.sunny,
        temperature: 14,
        min: 6,
        max: 15,
        hourly: [
          HourlyWeather(hour: 15, temperature: 15, sky: Sky.sunny),
          HourlyWeather(hour: 18, temperature: 11, sky: Sky.cloudy),
          HourlyWeather(hour: 21, temperature: 8, sky: Sky.cloudy),
        ],
        tip: '저녁엔 쌀쌀해. 겉옷 챙겨!',
      );

  @override
  Future<List<PlaceSuggestion>> places({required String cityId, required List<String> interestKeys}) async => const [
        PlaceSuggestion(
          id: 'gyeongpo', name: '경포해변', type: PlaceType.beach, meta: '해변 · 자연', location: GeoPoint(37.8055, 128.9087),
          visitorRank: VisitorRank(rank: 1, voters: 1240, scope: '해변'),
        ),
        PlaceSuggestion(
          id: 'anmok', name: '안목 커피거리', type: PlaceType.cafe, meta: '해변 · 카페', location: GeoPoint(37.7724, 128.9478),
          visitorRank: VisitorRank(rank: 1, voters: 860, scope: '카페'),
        ),
        PlaceSuggestion(
          id: 'ojukheon', name: '오죽헌', type: PlaceType.heritage, meta: '역사', location: GeoPoint(37.7792, 128.8786),
          visitorRank: VisitorRank(rank: 2, voters: 410, scope: '역사'),
        ),
        PlaceSuggestion(
          id: 'jungang-market', name: '강릉중앙시장', type: PlaceType.market, meta: '시장 · 맛집', location: GeoPoint(37.7545, 128.8990),
          visitorRank: VisitorRank(rank: 1, voters: 312, scope: '시장'),
        ),
        PlaceSuggestion(
          id: 'chodang', name: '초당순두부마을', type: PlaceType.food, meta: '맛집', location: GeoPoint(37.7914, 128.9149),
          visitorRank: VisitorRank(rank: 1, voters: 528, scope: '순두부'),
        ),
        PlaceSuggestion(
          id: 'jumunjin', name: '주문진 수산시장', type: PlaceType.seafood, meta: '시장 · 해산물', location: GeoPoint(37.8930, 128.8263),
        ),
      ];

  /// 예시 장소는 강릉 것뿐이라, 다른 지역(대전 등)에는 내놓지 않는다(엉뚱한 지역 장소가 보이지 않게).
  static const sampleCityId = '32030';

  @override
  Future<PopularPlaces> popular({required String cityId}) async {
    if (cityId != sampleCityId) return const PopularPlaces(source: PlaceSource.sample, sections: []);
    final all = await places(cityId: cityId, interestKeys: const []);
    return PopularPlaces(source: PlaceSource.sample, sections: popularFrom(all));
  }

  @override
  Future<PlaceSearchResult> search({required String cityId, required String query, int page = 1}) async {
    if (cityId != sampleCityId) return const PlaceSearchResult(source: PlaceSource.sample, places: []);
    final q = query.replaceAll(' ', '');
    final all = await places(cityId: cityId, interestKeys: const []);
    return PlaceSearchResult(
      source: PlaceSource.sample,
      places: [for (final p in all) if (p.name.replaceAll(' ', '').contains(q)) p],
    );
  }
}

/// 장소 목록을 인기 장소 칸(명소·맛집·카페·문화)으로 나눈다. 칸마다 앞에서 [per]곳, 빈 칸은 뺀다.
List<PlaceSection> popularFrom(List<PlaceSuggestion> places, {int per = 5}) {
  List<PlaceSuggestion> pick(Set<PlaceType> types) => places.where((p) => types.contains(p.type)).take(per).toList();
  final sections = [
    PlaceSection(
      key: 'sights',
      label: '명소',
      places: pick({PlaceType.nature, PlaceType.beach, PlaceType.heritage, PlaceType.leisure, PlaceType.other}),
    ),
    PlaceSection(key: 'food', label: '맛집', places: pick({PlaceType.food, PlaceType.seafood, PlaceType.market})),
    PlaceSection(key: 'cafe', label: '카페', places: pick({PlaceType.cafe})),
    PlaceSection(key: 'culture', label: '문화', places: pick({PlaceType.culture})),
  ];
  return [for (final s in sections) if (s.places.isNotEmpty) s];
}
