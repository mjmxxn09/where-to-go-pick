/// 여행·체크인 모델. 체크인은 항상 시간 순서로 다룬다.
library;

/// 장소 종류. 여행 노트의 손그림 아이콘이 이 값으로 정해진다.
enum PlaceType {
  beach('해변'),
  cafe('카페'),
  heritage('문화유산'),
  market('시장'),
  food('맛집'),
  seafood('수산시장'),
  nature('자연'),
  lodging('숙소'),
  leisure('놀거리'),
  culture('문화시설'),
  other('기타');

  const PlaceType(this.label);

  final String label;
}

class CheckIn {
  const CheckIn({required this.id, required this.placeName, required this.type, required this.at});

  final String id;
  final String placeName;
  final PlaceType type;
  final DateTime at;
}

/// 여행 전·중에 "가볼 곳"으로 담아 둔 장소. 체크인은 여기서 하거나 추천·검색에서 바로 해도 된다.
class PlannedPlace {
  const PlannedPlace({required this.id, required this.name, required this.type, this.meta = ''});

  final String id;
  final String name;
  final PlaceType type;
  final String meta;
}

class TripDay {
  const TripDay({required this.index, required this.date, required this.checkIns});

  /// 0부터 시작. 화면 표시는 `index + 1`일차.
  final int index;
  final DateTime date;
  final List<CheckIn> checkIns;

  String get label => '${index + 1}일차';
}

class Trip {
  Trip({
    required this.id,
    required this.cityId,
    required this.cityName,
    required this.provinceName,
    required this.startDate,
    List<CheckIn> checkIns = const [],
    List<PlannedPlace> planned = const [],
    this.endedAt,
  })  : checkIns = List.unmodifiable([...checkIns]..sort((a, b) => a.at.compareTo(b.at))),
        planned = List.unmodifiable(planned);

  final String id;
  final String cityId;
  final String cityName;
  final String provinceName;

  /// 여행 첫날(날짜만 의미 있음).
  final DateTime startDate;

  /// 시간 오름차순.
  final List<CheckIn> checkIns;

  /// 가볼 곳(담은 순서).
  final List<PlannedPlace> planned;

  /// "여행 마치기"를 누른 때. null이면 아직 진행 중.
  final DateTime? endedAt;

  bool get isEnded => endedAt != null;

  String get title => '${cityName.replaceAll(RegExp(r'(시|군|구)$'), '')} 여행';

  /// [ended]: null이면 그대로, false면 다시 진행 중으로, true면 [endedAt]으로 마침.
  Trip copyWith({List<CheckIn>? checkIns, List<PlannedPlace>? planned, bool? ended, DateTime? endedAt}) => Trip(
        id: id,
        cityId: cityId,
        cityName: cityName,
        provinceName: provinceName,
        startDate: startDate,
        checkIns: checkIns ?? this.checkIns,
        planned: planned ?? this.planned,
        endedAt: switch (ended) {
          null => this.endedAt,
          false => null,
          true => endedAt ?? this.endedAt ?? DateTime.now(),
        },
      );

  /// 체크인을 날짜별로 묶는다. 체크인이 없는 날은 만들지 않는다.
  List<TripDay> get days {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final byIndex = <int, List<CheckIn>>{};
    for (final c in checkIns) {
      final day = DateTime(c.at.year, c.at.month, c.at.day);
      final index = day.difference(start).inDays;
      byIndex.putIfAbsent(index < 0 ? 0 : index, () => []).add(c);
    }
    final keys = byIndex.keys.toList()..sort();
    return [
      for (final k in keys)
        TripDay(index: k, date: start.add(Duration(days: k)), checkIns: byIndex[k]!),
    ];
  }

  int get dayCount => days.isEmpty ? 1 : days.last.index + 1;

  /// "당일", "1박 2일", "2박 3일" …
  String get lengthLabel => dayCount <= 1 ? '당일 여행' : '${dayCount - 1}박 $dayCount일';
}
