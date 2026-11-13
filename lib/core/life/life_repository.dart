import '../../features/trip/trip_models.dart';

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

/// 명소·맛집 추천 한 건(TourAPI + 픽클 투표 결과를 생활 서버가 합쳐서 내려줄 형태).
class PlaceSuggestion {
  const PlaceSuggestion({
    required this.id,
    required this.name,
    required this.type,
    required this.meta,
    this.pickleVoteBadge,
  });

  final String id;
  final String name;
  final PlaceType type;
  final String meta;

  /// 예: "픽클 투표 1위". 투표 결과가 없으면 null.
  final String? pickleVoteBadge;

  bool get isFood => type == PlaceType.food || type == PlaceType.market || type == PlaceType.seafood || type == PlaceType.cafe;
}

/// 생활 서버(신규) 경계. 공공 API 키는 서버에만 두고, 앱은 이 서버만 호출한다.
/// - 날씨: 기상청 단기예보(위경도 → 격자 변환·캐시는 서버 책임)
/// - 명소·맛집: 한국관광공사 TourAPI + 픽클 투표
abstract interface class LifeRepository {
  Future<DayWeather> weather({required String cityId, required DateTime date});
  Future<List<PlaceSuggestion>> places({required String cityId, required List<String> interestKeys});
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
        PlaceSuggestion(id: 'gyeongpo', name: '경포해변', type: PlaceType.beach, meta: '해변 · 자연'),
        PlaceSuggestion(id: 'anmok', name: '안목 커피거리', type: PlaceType.cafe, meta: '해변 · 카페'),
        PlaceSuggestion(id: 'ojukheon', name: '오죽헌', type: PlaceType.heritage, meta: '역사'),
        PlaceSuggestion(
          id: 'jungang-market',
          name: '강릉중앙시장',
          type: PlaceType.market,
          meta: '시장 · 맛집',
          pickleVoteBadge: '픽클 투표 1위',
        ),
        PlaceSuggestion(id: 'chodang', name: '초당순두부마을', type: PlaceType.food, meta: '맛집'),
        PlaceSuggestion(id: 'jumunjin', name: '주문진 수산시장', type: PlaceType.seafood, meta: '시장 · 해산물'),
      ];
}
