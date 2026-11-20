import '../../core/cloud/supabase_rest.dart';
import 'trip_models.dart';
import 'trip_store.dart';

/// 여행 기록을 서버에 올리고 받아 온다.
abstract interface class TripCloud {
  Future<List<Trip>> pull();

  /// 같은 여행·체크인은 덮어쓴다(여러 번 보내도 안전).
  Future<void> push(List<Trip> trips);
}

/// Supabase 테이블 `trips`, `check_ins` (supabase/migrations 참고).
class SupabaseTripCloud implements TripCloud {
  SupabaseTripCloud(this._rest);

  final SupabaseRest _rest;

  static const _select =
      'id,city_id,city_name,province_name,start_date,planned,check_ins(id,place_name,place_type,checked_in_at)';

  @override
  Future<List<Trip>> pull() async {
    final rows = await _rest.select('trips', {'select': _select, 'order': 'start_date.desc'});
    return rows.map(tripFromRow).whereType<Trip>().toList();
  }

  @override
  Future<void> push(List<Trip> trips) async {
    final real = trips.where((t) => !isSampleTrip(t)).toList();
    if (real.isEmpty) return;
    final userId = await _rest.userId();
    if (userId == null) throw const CloudSignedOut();
    await _rest.upsert('trips', [for (final t in real) tripToRow(t, userId)], onConflict: 'user_id,id');
    await _rest.upsert(
      'check_ins',
      [
        for (final t in real)
          for (final c in t.checkIns) checkInToRow(t.id, c, userId),
      ],
      onConflict: 'user_id,trip_id,id',
    );
  }
}

Map<String, Object?> tripToRow(Trip t, String userId) => {
      'user_id': userId,
      'id': t.id,
      'city_id': t.cityId,
      'city_name': t.cityName,
      'province_name': t.provinceName,
      'start_date': formatDateOnly(t.startDate),
      'planned': [for (final p in t.planned) plannedToJson(p)],
    };

Map<String, Object?> checkInToRow(String tripId, CheckIn c, String userId) => {
      'user_id': userId,
      'trip_id': tripId,
      'id': c.id,
      'place_name': c.placeName,
      'place_type': c.type.name,
      'checked_in_at': c.at.toUtc().toIso8601String(),
    };

Trip? tripFromRow(Map<String, dynamic> row) {
  final id = row['id'];
  final cityId = row['city_id'];
  final cityName = row['city_name'];
  final provinceName = row['province_name'];
  final start = parseDateOnly(row['start_date']);
  if (id is! String || cityId is! String || cityName is! String || provinceName is! String || start == null) {
    return null;
  }
  final list = row['check_ins'];
  return Trip(
    id: id,
    cityId: cityId,
    cityName: cityName,
    provinceName: provinceName,
    startDate: start,
    checkIns: [
      if (list is List<dynamic>)
        for (final c in list)
          if (_checkInFromRow(c) case final checkIn?) checkIn,
    ],
    planned: plannedListFromJson(row['planned']),
  );
}

CheckIn? _checkInFromRow(Object? row) {
  if (row is! Map<String, dynamic>) return null;
  final id = row['id'];
  final name = row['place_name'];
  final at = row['checked_in_at'] is String ? DateTime.tryParse(row['checked_in_at'] as String) : null;
  if (id is! String || name is! String || at == null) return null;
  return CheckIn(id: id, placeName: name, type: placeTypeFromName(row['place_type']), at: at.toLocal());
}
