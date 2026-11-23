import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'trip_models.dart';

/// 폰에 남기는 여행 기록: 모든 여행과 지금 진행 중인 여행 id.
class TripLog {
  const TripLog({this.trips = const [], this.currentId, this.deletedTrips = const {}, this.deletedCheckIns = const {}});

  final List<Trip> trips;
  final String? currentId;

  /// 지웠지만 아직 서버에서 지우지 못한 여행 id. 서버 기록과 합칠 때 되살아나지 않게 한다.
  final Set<String> deletedTrips;

  /// 지웠지만 아직 서버에서 지우지 못한 체크인. [checkInKey] 형식.
  final Set<String> deletedCheckIns;

  bool get isEmpty => trips.isEmpty;
}

/// 지운 체크인 기록용 키.
String checkInKey(String tripId, String checkInId) => '$tripId|$checkInId';

/// 예시 여행(서버 없이 화면을 채우는 강릉 여행 등)은 저장하거나 올리지 않는다.
bool isSampleTrip(Trip trip) => trip.id.startsWith('sample-');

String _date(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// `2026-11-13` → 그 날 0시(기기 시간). 읽을 수 없으면 null.
DateTime? parseDateOnly(Object? value) {
  if (value is! String) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(value);
  if (m == null) return null;
  return DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
}

String formatDateOnly(DateTime d) => _date(d);

PlaceType placeTypeFromName(Object? name) => PlaceType.values.asNameMap()[name] ?? PlaceType.other;

Map<String, Object?> checkInToJson(CheckIn c) => {
      'id': c.id,
      'placeName': c.placeName,
      'type': c.type.name,
      'at': c.at.toUtc().toIso8601String(),
    };

CheckIn? checkInFromJson(Object? json) {
  if (json is! Map<String, dynamic>) return null;
  final id = json['id'];
  final name = json['placeName'];
  final at = json['at'] is String ? DateTime.tryParse(json['at'] as String) : null;
  if (id is! String || name is! String || at == null) return null;
  return CheckIn(id: id, placeName: name, type: placeTypeFromName(json['type']), at: at.toLocal());
}

Map<String, Object?> plannedToJson(PlannedPlace p) => {
      'id': p.id,
      'name': p.name,
      'type': p.type.name,
      'meta': p.meta,
      if (p.url != null) 'url': p.url,
      if (p.location case final at?) ...{'lat': at.lat, 'lng': at.lng},
      if (p.day != null) 'day': p.day,
    };

PlannedPlace? plannedFromJson(Object? json) {
  if (json is! Map<String, dynamic>) return null;
  final id = json['id'];
  final name = json['name'];
  if (id is! String || name is! String) return null;
  final meta = json['meta'];
  final url = json['url'];
  return PlannedPlace(
    id: id,
    name: name,
    type: placeTypeFromName(json['type']),
    meta: meta is String ? meta : '',
    url: url is String && url.startsWith('http') ? url : null,
    location: GeoPoint.tryFrom(json['lat'], json['lng']),
    day: switch (json['day']) { final int d when d >= 0 && d < 30 => d, _ => null },
  );
}

List<PlannedPlace> plannedListFromJson(Object? list) => [
      if (list is List<dynamic>) ...list.map(plannedFromJson).whereType<PlannedPlace>(),
    ];

Map<String, Object?> tripToJson(Trip t) => {
      'id': t.id,
      'cityId': t.cityId,
      'cityName': t.cityName,
      'provinceName': t.provinceName,
      'startDate': _date(t.startDate),
      'checkIns': [for (final c in t.checkIns) checkInToJson(c)],
      'planned': [for (final p in t.planned) plannedToJson(p)],
      if (t.endedAt != null) 'endedAt': t.endedAt!.toUtc().toIso8601String(),
      if (t.plannedDays != null) 'plannedDays': t.plannedDays,
    };

Trip? tripFromJson(Object? json) {
  if (json is! Map<String, dynamic>) return null;
  final id = json['id'];
  final cityId = json['cityId'];
  final cityName = json['cityName'];
  final provinceName = json['provinceName'];
  final start = parseDateOnly(json['startDate']);
  if (id is! String || cityId is! String || cityName is! String || provinceName is! String || start == null) {
    return null;
  }
  final list = json['checkIns'];
  return Trip(
    id: id,
    cityId: cityId,
    cityName: cityName,
    provinceName: provinceName,
    startDate: start,
    checkIns: [if (list is List<dynamic>) ...list.map(checkInFromJson).whereType<CheckIn>()],
    planned: plannedListFromJson(json['planned']),
    endedAt: json['endedAt'] is String ? DateTime.tryParse(json['endedAt'] as String)?.toLocal() : null,
    plannedDays: plannedDaysFrom(json['plannedDays']),
  );
}

/// 1~30일만 받는다(그 밖은 정하지 않음).
int? plannedDaysFrom(Object? v) => v is num && v >= 1 && v <= 30 ? v.toInt() : null;

String encodeTripLog(TripLog log) => jsonEncode({
      'currentId': log.currentId,
      'trips': [for (final t in log.trips) tripToJson(t)],
      if (log.deletedTrips.isNotEmpty) 'deletedTrips': log.deletedTrips.toList(),
      if (log.deletedCheckIns.isNotEmpty) 'deletedCheckIns': log.deletedCheckIns.toList(),
    });

Set<String> _stringSet(Object? v) => {if (v is List<dynamic>) ...v.whereType<String>()};

TripLog decodeTripLog(String? raw) {
  if (raw == null || raw.isEmpty) return const TripLog();
  try {
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic>) return const TripLog();
    final list = json['trips'];
    final trips = [if (list is List<dynamic>) ...list.map(tripFromJson).whereType<Trip>()];
    final current = json['currentId'];
    return TripLog(
      trips: trips,
      currentId: current is String && trips.any((t) => t.id == current) ? current : null,
      deletedTrips: _stringSet(json['deletedTrips']),
      deletedCheckIns: _stringSet(json['deletedCheckIns']),
    );
  } on FormatException {
    return const TripLog();
  }
}

/// 두 기록을 합친다. 같은 여행은 체크인을 장소 id로 합치고, 둘 다 있으면 [primary] 쪽을 남긴다.
/// 가볼 곳은 [primary] 쪽 목록을 그대로 쓴다(뺀 것이 다시 살아나지 않게).
/// 결과는 시작일 최신순.
/// [deletedTrips]·[deletedCheckIns]에 든 것은 어느 쪽에 있어도 뺀다(지운 것이 서버에서 되살아나지 않게).
List<Trip> mergeTrips(
  List<Trip> primary,
  List<Trip> other, {
  Set<String> deletedTrips = const {},
  Set<String> deletedCheckIns = const {},
}) {
  final byId = <String, Trip>{for (final t in other) t.id: t};
  for (final t in primary) {
    final o = byId[t.id];
    if (o == null) {
      byId[t.id] = t;
      continue;
    }
    final checkIns = <String, CheckIn>{for (final c in o.checkIns) c.id: c, for (final c in t.checkIns) c.id: c};
    byId[t.id] = t.copyWith(checkIns: checkIns.values.toList());
  }
  for (final id in deletedTrips) {
    byId.remove(id);
  }
  if (deletedCheckIns.isNotEmpty) {
    for (final e in byId.entries.toList()) {
      final t = e.value;
      if (t.checkIns.any((c) => deletedCheckIns.contains(checkInKey(t.id, c.id)))) {
        byId[e.key] = t.copyWith(checkIns: [
          for (final c in t.checkIns)
            if (!deletedCheckIns.contains(checkInKey(t.id, c.id))) c,
        ]);
      }
    }
  }
  final merged = byId.values.toList()
    ..sort((a, b) {
      final byDate = b.startDate.compareTo(a.startDate);
      return byDate != 0 ? byDate : b.id.compareTo(a.id);
    });
  return merged;
}

abstract interface class TripStore {
  Future<TripLog> load();
  Future<void> save(TripLog log);
}

class PrefsTripStore implements TripStore {
  static const prefsKey = 'trips.v1';

  @override
  Future<TripLog> load() async {
    final prefs = await SharedPreferences.getInstance();
    return decodeTripLog(prefs.getString(prefsKey));
  }

  @override
  Future<void> save(TripLog log) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, encodeTripLog(log));
  }
}

class MemoryTripStore implements TripStore {
  MemoryTripStore([this.log = const TripLog()]);

  TripLog log;
  var saves = 0;

  @override
  Future<TripLog> load() async => log;

  @override
  Future<void> save(TripLog log) async {
    this.log = log;
    saves++;
  }
}
