import 'package:flutter/foundation.dart';

import '../../features/trip/trip_models.dart';
import '../cloud/supabase_rest.dart';
import 'life_repository.dart';

/// 앱 지도 id(통계청) → 도 코드와 시·군·구 이름. 지도 데이터에서 찾는다.
typedef CityLookup = Future<({String provinceCode, String cityName})?> Function(String cityId);

/// 여행지 정보를 Supabase Edge Function `life`에서 받는다(카카오맵·한국관광공사 TourAPI · 기상청 단기예보).
///
/// - 같은 도시 장소는 앱이 켜져 있는 동안 한 번만, 날씨는 한 시간에 한 번만 묻는다.
/// - 실패한 요청은 담아 두지 않아서 다시 부르면 다시 묻는다.
class SupabaseLifeRepository implements LifeRepository {
  SupabaseLifeRepository(this._rest, this._lookup, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final SupabaseRest _rest;
  final CityLookup _lookup;
  final DateTime Function() _clock;
  final _places = <String, Future<List<PlaceSuggestion>>>{};
  final _weather = <String, Future<DayWeather>>{};
  final _search = <String, Future<PlaceSearchResult>>{};
  final _popular = <String, Future<PopularPlaces>>{};

  @override
  Future<PopularPlaces> popular({required String cityId}) => _memo(_popular, cityId, () async {
        final json = await _rest.invoke('life', {'action': 'popular', ...await _city(cityId)});
        final sections = json['sections'];
        return PopularPlaces(
          source: placeSourceFrom(json['source']),
          sections: [
            if (sections is List<dynamic>)
              for (final s in sections)
                if (s is Map<String, dynamic> && s['key'] is String && s['label'] is String)
                  PlaceSection(key: s['key'] as String, label: s['label'] as String, places: _placeList(s['places'])),
          ],
        );
      });

  @override
  Future<List<PlaceSuggestion>> places({required String cityId, required List<String> interestKeys}) =>
      _memo(_places, cityId, () async {
        final json = await _rest.invoke('life', {'action': 'places', ...await _city(cityId)});
        return _placeList(json['places']);
      });

  List<PlaceSuggestion> _placeList(Object? list) => [
        if (list is List<dynamic>)
          for (final item in list)
            if (placeSuggestionFromJson(item) case final place?) place,
      ];

  @override
  Future<PlaceSearchResult> search({required String cityId, required String query, int page = 1}) =>
      _memo(_search, '$cityId|${query.trim()}|$page', () async {
        final json = await _rest.invoke(
          'life',
          {'action': 'search', 'query': query.trim(), 'page': page, ...await _city(cityId)},
        );
        return PlaceSearchResult(
          source: placeSourceFrom(json['source']),
          places: _placeList(json['places']),
          hasMore: json['hasMore'] == true,
          outside: json['outside'] == true,
        );
      });

  @override
  Future<DayWeather> weather({required String cityId, required DateTime date}) {
    final now = _clock();
    final day = _ymd(date);
    return _memo(_weather, '$cityId|$day|${now.hour}', () async {
      final json = await _rest.invoke('life', {'action': 'weather', 'date': day, ...await _city(cityId)});
      final weather = dayWeatherFromJson(json['weather']);
      if (weather == null) throw const FormatException('날씨 응답을 읽지 못했어요.');
      return weather;
    });
  }

  Future<Map<String, String>> _city(String cityId) async {
    final city = await _lookup(cityId);
    if (city == null) throw ArgumentError.value(cityId, 'cityId', '지도에 없는 시·군·구');
    return {'provinceCode': city.provinceCode, 'cityName': city.cityName};
  }

  Future<T> _memo<T>(Map<String, Future<T>> cache, String key, Future<T> Function() load) {
    final hit = cache[key];
    if (hit != null) return hit;
    final future = load();
    cache[key] = future;
    // 실패하면 담아 둔 것을 지운다. (onError가 값을 돌려주면 then의 타입과 안 맞아 오류가 나므로 블록으로)
    future.then((_) {}, onError: (Object e) {
      cache.remove(key);
      debugPrint('여행지 정보를 못 불러왔어요($key): $e');
    });
    return future;
  }
}

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

PlaceSuggestion? placeSuggestionFromJson(Object? json) {
  if (json is! Map<String, dynamic>) return null;
  final id = json['id'];
  final name = json['name'];
  if (id is! String || name is! String || id.isEmpty || name.isEmpty) return null;
  final meta = json['meta'];
  final url = json['url'];
  return PlaceSuggestion(
    id: id,
    name: name,
    type: PlaceType.values.asNameMap()[json['type']] ?? PlaceType.other,
    meta: meta is String ? meta : '',
    // 카카오 장소 페이지만 연다(다른 주소는 무시).
    url: url is String && RegExp(r'^https?://place\.map\.kakao\.com/').hasMatch(url) ? url : null,
    location: GeoPoint.tryFrom(json['lat'], json['lng']),
  );
}

PlaceSource placeSourceFrom(Object? v) => v == 'kakao' ? PlaceSource.kakao : PlaceSource.tour;

DayWeather? dayWeatherFromJson(Object? json) {
  if (json is! Map<String, dynamic>) return null;
  int? n(Object? v) => v is num ? v.round() : null;
  Sky sky(Object? v) => Sky.values.asNameMap()[v] ?? Sky.cloudy;
  final temperature = n(json['temperature']);
  final min = n(json['min']);
  final max = n(json['max']);
  if (temperature == null || min == null || max == null) return null;
  final hourly = json['hourly'];
  final tip = json['tip'];
  return DayWeather(
    sky: sky(json['sky']),
    temperature: temperature,
    min: min,
    max: max,
    hourly: [
      if (hourly is List<dynamic>)
        for (final h in hourly)
          if (h is Map<String, dynamic> && n(h['hour']) != null && n(h['temperature']) != null)
            HourlyWeather(hour: n(h['hour'])!, temperature: n(h['temperature'])!, sky: sky(h['sky'])),
    ],
    tip: tip is String ? tip : null,
  );
}
