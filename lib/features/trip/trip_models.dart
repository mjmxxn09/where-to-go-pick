/// 여행·체크인 모델. 체크인은 항상 시간 순서로 다룬다.
library;

import 'dart:math' as math;

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

/// 장소 좌표(위도·경도). 폰 위치가 아니라 장소 자체의 공개 좌표(카카오·관광공사).
class GeoPoint {
  const GeoPoint(this.lat, this.lng);

  final double lat;
  final double lng;

  /// 한국 언저리 좌표만 받는다(0,0 같은 빈 값·뒤바뀐 값은 null).
  static GeoPoint? tryFrom(Object? lat, Object? lng) {
    if (lat is! num || lng is! num) return null;
    final a = lat.toDouble(), b = lng.toDouble();
    if (a <= 32 || a >= 39.5 || b <= 124 || b >= 132.5) return null;
    return GeoPoint(a, b);
  }

  @override
  bool operator ==(Object other) => other is GeoPoint && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);
}

/// 여행 전·중에 "가볼 곳"으로 담아 둔 장소. 체크인은 여기서 하거나 추천·검색에서 바로 해도 된다.
class PlannedPlace {
  const PlannedPlace({
    required this.id,
    required this.name,
    required this.type,
    this.meta = '',
    this.url,
    this.location,
    this.day,
  });

  final String id;
  final String name;
  final PlaceType type;
  final String meta;

  /// 카카오맵 장소 페이지. 없으면 null.
  final String? url;

  /// 가볼 곳 지도에 찍을 좌표. 없으면 목록에만 나온다.
  final GeoPoint? location;

  /// 가려는 날(0 = 1일차). null이면 날짜 미정.
  final int? day;

  PlannedPlace withDay(int? day) =>
      PlannedPlace(id: id, name: name, type: type, meta: meta, url: url, location: location, day: day);
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
    this.plannedDays,
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

  /// 여행을 만들 때 정한 기간(일 수). 1 = 당일, 3 = 2박 3일. null이면 정하지 않음(다녀온 날로 정해짐).
  final int? plannedDays;

  /// 마지막 날(날짜만). 기간을 정하지 않았으면 체크인한 마지막 날.
  DateTime get lastDate => dateOnly(startDate).add(Duration(days: totalDays - 1));

  /// [at]이 여행 며칠째인지(0부터). 출발 전이면 음수.
  int dayIndexOf(DateTime at) => daysBetween(startDate, at);

  /// 정한 기간과 실제로 체크인한 날 중 긴 쪽(일 수).
  int get totalDays => math.max(plannedDays ?? 1, dayCount);

  /// 지금 상태 한 마디: "D-3", "오늘 2일차", "여행 기간이 지났어요"(정한 기간을 넘겼을 때).
  String statusOn(DateTime now) {
    final i = dayIndexOf(now);
    if (i < 0) return 'D-${-i}';
    final planned = plannedDays;
    if (planned != null && i >= planned) return '여행 기간이 지났어요';
    return '오늘 ${i + 1}일차';
  }

  /// 출발 전인지(오늘이 출발일보다 앞).
  bool isBeforeStart(DateTime now) => dayIndexOf(now) < 0;

  String get title => '${regionShortName(cityName)} 여행';

  /// 시·군·구를 고르지 않고 도·광역시 전체로 만든 여행(cityId가 도 코드 두 자리).
  bool get isWholeProvince => isProvinceId(cityId);

  /// [ended]: null이면 그대로, false면 다시 진행 중으로, true면 [endedAt]으로 마침.
  /// [plannedDays]를 바꿀 때는 [setPlannedDays]를 true로(그래야 null로도 바꿀 수 있다).
  Trip copyWith({
    List<CheckIn>? checkIns,
    List<PlannedPlace>? planned,
    bool? ended,
    DateTime? endedAt,
    DateTime? startDate,
    bool setPlannedDays = false,
    int? plannedDays,
  }) =>
      Trip(
        id: id,
        cityId: cityId,
        cityName: cityName,
        provinceName: provinceName,
        startDate: startDate == null ? this.startDate : dateOnly(startDate),
        plannedDays: setPlannedDays ? plannedDays : this.plannedDays,
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
    final start = dateOnly(startDate);
    final byIndex = <int, List<CheckIn>>{};
    for (final c in checkIns) {
      final index = daysBetween(start, c.at);
      byIndex.putIfAbsent(index < 0 ? 0 : index, () => []).add(c);
    }
    final keys = byIndex.keys.toList()..sort();
    return [
      for (final k in keys)
        TripDay(index: k, date: start.add(Duration(days: k)), checkIns: byIndex[k]!),
    ];
  }

  int get dayCount => days.isEmpty ? 1 : days.last.index + 1;

  /// "당일 여행", "1박 2일", "2박 3일" … 정한 기간이 있으면 그것(체크인이 더 길어지면 그만큼).
  String get lengthLabel => lengthLabelOf(totalDays);
}

/// 일 수 → "당일 여행" / "n박 n+1일"
String lengthLabelOf(int days) => days <= 1 ? '당일 여행' : '${days - 1}박 $days일';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// 두 날의 날짜 차이(시각은 무시). [to]가 [from]보다 앞이면 음수.
int daysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

/// "11월 20일 (금)"
String monthDayLabel(DateTime d) => '${d.month}월 ${d.day}일 (${_weekdays[d.weekday - 1]})';

/// "11월 20일 – 22일", 달이 바뀌면 "11월 30일 – 12월 1일", 하루면 "11월 20일"
String dateRangeLabel(DateTime start, DateTime end) {
  if (daysBetween(start, end) <= 0) return '${start.month}월 ${start.day}일';
  if (start.month == end.month && start.year == end.year) return '${start.month}월 ${start.day}일 – ${end.day}일';
  return '${start.month}월 ${start.day}일 – ${end.month}월 ${end.day}일';
}

/// 여행지 id가 도·광역시 전체(통계청 도 코드 두 자리, 예: 25 대전)인지. 시·군·구는 다섯 자리나 `31:수원시`.
bool isProvinceId(String id) => id.length == 2;

/// 도·광역시 이름 → 짧은 이름(대전광역시 → 대전, 충청북도 → 충북).
const provinceShortNames = <String, String>{
  '서울특별시': '서울', '부산광역시': '부산', '대구광역시': '대구', '인천광역시': '인천', '광주광역시': '광주',
  '대전광역시': '대전', '울산광역시': '울산', '세종특별자치시': '세종', '경기도': '경기', '강원특별자치도': '강원',
  '충청북도': '충북', '충청남도': '충남', '전북특별자치도': '전북', '전라남도': '전남', '경상북도': '경북',
  '경상남도': '경남', '제주특별자치도': '제주',
};

/// 제목에 쓰는 짧은 지역 이름: 도·광역시는 짧은 이름, 시·군·구는 끝 글자를 뗀다(강릉시 → 강릉).
String regionShortName(String name) => provinceShortNames[name] ?? name.replaceAll(RegExp(r'(시|군|구)$'), '');

/// [all] 가운데 [ids]에 든 것만 [ids] 순서로 바꾼다. 그 장소들이 있던 자리에 차례로 넣고, 나머지는 자리 그대로.
/// [ids]가 [all]에 없는 id를 담고 있거나 겹치면 바꾸지 않는다(같은 목록을 돌려준다).
List<PlannedPlace> reorderSubset(List<PlannedPlace> all, List<String> ids) {
  final byId = {for (final p in all) p.id: p};
  if (ids.toSet().length != ids.length || !ids.every(byId.containsKey)) return all;
  final picked = ids.toSet();
  final queue = [for (final id in ids) byId[id]!];
  var k = 0;
  return [for (final p in all) picked.contains(p.id) ? queue[k++] : p];
}
