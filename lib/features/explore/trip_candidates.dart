import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../korea_map/korea_map_view.dart';

/// ♡로 담은 "갈까 말까" 여행지 후보와, 친구한테 물어본 투표 기록.
///
/// - 후보는 기기에 저장한다. 고민 중이면 앱을 다시 켜도 남아 있다.
/// - 후보 중 한 곳으로 여행을 시작하면 고민이 끝난 것 → [clear]로 비운다(되돌리기는 [restore]).
/// - 물어본 투표는 후보를 비워도 따로 남긴다([polls], 최근 것부터 [maxPolls]개).
class TripCandidates extends ChangeNotifier {
  TripCandidates._(this._prefs, this._items, this._polls);

  /// 저장하지 않는 메모리 전용(테스트·저장소를 못 열었을 때).
  factory TripCandidates.memory({List<SelectedCity>? items, List<AskedPoll>? polls}) =>
      TripCandidates._(null, [...?items], [...?polls]);

  static const prefsKey = 'explore.candidates.v1';
  static const pollsPrefsKey = 'explore.polls.v1';
  static const maxCandidates = 4;
  static const maxPolls = 5;

  static Future<TripCandidates> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return TripCandidates._(
        prefs,
        decodeCities(prefs.getString(prefsKey)),
        decodeAskedPolls(prefs.getString(pollsPrefsKey)),
      );
    } on Object {
      return TripCandidates.memory();
    }
  }

  final SharedPreferences? _prefs;
  final List<SelectedCity> _items;
  final List<AskedPoll> _polls;

  List<SelectedCity> get items => List.unmodifiable(_items);

  /// 물어본 투표(최근 것부터).
  List<AskedPoll> get polls => List.unmodifiable(_polls);

  bool contains(String cityId) => _items.any((c) => c.id == cityId);

  /// 담기/빼기. 다섯 번째를 담으면 가장 먼저 담은 후보가 빠진다 — 그 후보를 돌려준다(알림용).
  SelectedCity? toggle(SelectedCity city) {
    SelectedCity? dropped;
    if (contains(city.id)) {
      _items.removeWhere((c) => c.id == city.id);
    } else {
      _items.add(city);
      if (_items.length > maxCandidates) dropped = _items.removeAt(0);
    }
    _changed();
    return dropped;
  }

  /// 후보 하나 빼기(후보 줄의 ✕).
  void remove(String cityId) {
    final before = _items.length;
    _items.removeWhere((c) => c.id == cityId);
    if (_items.length != before) _changed();
  }

  /// 후보를 모두 비우고, 되돌릴 수 있게 비운 목록을 돌려준다.
  List<SelectedCity> clear() {
    final removed = List.of(_items);
    if (removed.isEmpty) return removed;
    _items.clear();
    _changed();
    return removed;
  }

  void restore(List<SelectedCity> cities) {
    _items
      ..clear()
      ..addAll(cities.take(maxCandidates));
    _changed();
  }

  void addPoll(AskedPoll poll) {
    _polls
      ..removeWhere((p) => p.id == poll.id)
      ..insert(0, poll);
    if (_polls.length > maxPolls) _polls.removeRange(maxPolls, _polls.length);
    _changed();
  }

  void _changed() {
    notifyListeners();
    final prefs = _prefs;
    if (prefs == null) return;
    // 저장에 실패해도 화면에는 지장 없다.
    prefs.setString(prefsKey, encodeCities(_items)).ignore();
    prefs.setString(pollsPrefsKey, encodeAskedPolls(_polls)).ignore();
  }
}

/// 물어본 투표 한 건. 결과에서 "○○로 여행 만들기"를 하려고 후보 지역도 함께 남긴다.
class AskedPoll {
  const AskedPoll({required this.id, required this.cities});

  final String id;
  final List<SelectedCity> cities;
}

Map<String, Object?> _cityJson(SelectedCity c) =>
    {'id': c.id, 'name': c.name, 'provinceCode': c.provinceCode, 'provinceName': c.provinceName};

SelectedCity? _cityFrom(Object? json) {
  if (json is! Map) return null;
  final id = json['id'], name = json['name'], code = json['provinceCode'], province = json['provinceName'];
  if (id is! String || name is! String || code is! String || province is! String) return null;
  return SelectedCity(id: id, name: name, provinceCode: code, provinceName: province);
}

String encodeCities(List<SelectedCity> cities) => jsonEncode([for (final c in cities) _cityJson(c)]);

List<SelectedCity> decodeCities(String? raw) {
  if (raw == null || raw.isEmpty) return [];
  try {
    final list = jsonDecode(raw);
    if (list is! List) return [];
    return list.map(_cityFrom).whereType<SelectedCity>().toList();
  } on FormatException {
    return [];
  }
}

String encodeAskedPolls(List<AskedPoll> polls) => jsonEncode([
      for (final p in polls) {'id': p.id, 'cities': [for (final c in p.cities) _cityJson(c)]},
    ]);

List<AskedPoll> decodeAskedPolls(String? raw) {
  if (raw == null || raw.isEmpty) return [];
  try {
    final list = jsonDecode(raw);
    if (list is! List) return [];
    return [
      for (final e in list)
        if (e is Map && e['id'] is String && e['cities'] is List)
          AskedPoll(
            id: e['id'] as String,
            cities: (e['cities'] as List).map(_cityFrom).whereType<SelectedCity>().toList(),
          ),
    ];
  } on FormatException {
    return [];
  }
}
