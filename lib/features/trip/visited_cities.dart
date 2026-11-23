import '../korea_map/geo_projection.dart';
import '../korea_map/korea_map_data.dart';
import 'trip_models.dart';

/// 도·광역시 전체로 만든 여행에서 실제로 다녀온 시·군·구(내 지도 도 상세에 칠한다).
///
/// 체크인한 장소가 가볼 곳에 좌표와 함께 담겨 있으면 그 좌표가 든 시·군·구. 좌표를 모르는 체크인은 건너뛴다
/// (그 여행은 전국 지도에서 도 단위로만 칠해진다).
Set<String> citiesFromWholeProvinceTrips(KoreaMapData data, Iterable<Trip> trips) {
  final out = <String>{};
  for (final t in trips) {
    if (!t.isWholeProvince || t.checkIns.isEmpty) continue;
    final detail = data.details[t.cityId];
    if (detail == null) continue;
    final where = {for (final p in t.planned) if (p.location != null) p.id: p.location!};
    for (final c in t.checkIns) {
      final at = where[c.id];
      if (at == null) continue;
      final point = projectToDetail(detail.code, at.lat, at.lng);
      if (point == null) continue;
      for (final city in detail.cities) {
        if (city.path.contains(point)) {
          out.add(city.id);
          break;
        }
      }
    }
  }
  return out;
}
