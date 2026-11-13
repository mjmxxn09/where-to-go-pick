/// 여행 카드 꾸미기: 유저가 붙인 스티커와 옮긴 장소 막대.
///
/// - 카드는 길·시간·장소 이름만 그리고, 스티커는 유저가 직접 붙인다(빈 카드로 시작).
/// - 좌표는 카드 좌표계(가로 358 기준, [TripCardLayoutConfig.pageWidth])의 스티커 **중심**이다.
/// - 카드 한 장(페이지)마다 따로 저장한다. "한 장에 모아보기"와 "하루씩 나눠보기"는 배치가 달라 서로 다른 장으로 본다.
/// - 지금은 기기에만 저장(shared_preferences). 생활 서버가 생기면 여행과 함께 서버에 올린다.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../trip/trip_models.dart';
import 'sticker_book.dart';
import 'trip_card_layout.dart';

const defaultStickerSize = 72.0;
const minStickerSize = 28.0;
const maxStickerSize = 240.0;

class PlacedSticker {
  const PlacedSticker({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    this.size = defaultStickerSize,
    this.rotation = 0,
  });

  final String id;

  /// 스티커 파일 이름(확장자 없이), 예: `place_food_chicken`.
  final String name;
  final double x;
  final double y;

  /// 정사각형 한 변 길이(카드 좌표).
  final double size;

  /// 라디안, 시계 방향이 +.
  final double rotation;

  PlacedSticker copyWith({double? x, double? y, double? size, double? rotation}) => PlacedSticker(
        id: id,
        name: name,
        x: x ?? this.x,
        y: y ?? this.y,
        size: size ?? this.size,
        rotation: rotation ?? this.rotation,
      );

  /// 점 (px, py)가 스티커 그림 안에 있는지. 회전을 고려하고, 그림 둘레의 투명 여백(약 6%)은 뺀다.
  bool contains(double px, double py) {
    final dx = px - x;
    final dy = py - y;
    final c = math.cos(-rotation);
    final s = math.sin(-rotation);
    final lx = dx * c - dy * s;
    final ly = dx * s + dy * c;
    final half = size / 2 * 0.9;
    return lx.abs() <= half && ly.abs() <= half;
  }

  Map<String, Object> toJson() => {'id': id, 'name': name, 'x': x, 'y': y, 'size': size, 'rot': rotation};

  static PlacedSticker? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final id = json['id'];
    final name = json['name'];
    final x = json['x'];
    final y = json['y'];
    if (id is! String || name is! String || x is! num || y is! num) return null;
    final size = json['size'];
    final rot = json['rot'];
    return PlacedSticker(
      id: id,
      name: name,
      x: x.toDouble(),
      y: y.toDouble(),
      size: size is num ? size.toDouble() : defaultStickerSize,
      rotation: rot is num ? rot.toDouble() : 0,
    );
  }
}

/// 맨 위(나중에 붙인 것)부터 찾아 (px, py)에 있는 스티커를 돌려준다.
PlacedSticker? stickerAt(List<PlacedSticker> stickers, double px, double py) {
  for (var i = stickers.length - 1; i >= 0; i--) {
    if (stickers[i].contains(px, py)) return stickers[i];
  }
  return null;
}

/// 카드 한 장을 가리키는 저장 키.
String cardPageKey(Trip trip, TripCardMode mode, TripCardPage page) {
  if (mode == TripCardMode.onePage || trip.days.length <= 1 || page.days.isEmpty) return '${trip.id}:all';
  return '${trip.id}:day${page.days.first.index}';
}

/// "자동으로 꾸미기": 길이 꺾이는 반원 안쪽에 그 줄 마지막 장소의 스티커, 출발 아래 자동차, 끝 깃발 위 발자국.
/// [has]로 실제 그림이 있는 스티커만 고른다.
List<PlacedSticker> autoDecorate(
  TripCardLayout layout,
  List<CheckIn> checkIns, {
  required bool Function(String name) has,
  required String Function() newId,
}) {
  final result = <PlacedSticker>[];
  for (final slot in layout.stickers) {
    if (slot.stopIndex >= checkIns.length) continue;
    final place = checkIns[slot.stopIndex];
    final options = (StickerBook.placeStickers[place.type] ?? const <String>[]).where(has).toList();
    final name = pickVariant(options, place.placeName);
    if (name == null) continue;
    // 살짝 기울여 손으로 붙인 느낌(장소 이름으로 고정).
    final tilt = ((place.placeName.length % 5) - 2) * 0.04;
    result.add(PlacedSticker(
      id: newId(),
      name: name,
      x: slot.centerX,
      y: slot.centerY,
      size: slot.maxWidth + 10,
      rotation: tilt,
    ));
  }
  if (has('move_car')) {
    result.add(PlacedSticker(id: newId(), name: 'move_car', x: 36, y: layout.startY + 46, size: 64));
  }
  if (has('move_walk')) {
    result.add(PlacedSticker(id: newId(), name: 'move_walk', x: layout.endX, y: layout.endY - 67, size: 58));
  }
  return result;
}

String encodeStickerPages(Map<String, List<PlacedSticker>> pages) => jsonEncode({
      for (final e in pages.entries)
        if (e.value.isNotEmpty) e.key: [for (final s in e.value) s.toJson()],
    });

Map<String, List<PlacedSticker>> decodeStickerPages(String? raw) {
  if (raw == null || raw.isEmpty) return {};
  try {
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic>) return {};
    final pages = <String, List<PlacedSticker>>{};
    for (final e in json.entries) {
      final list = e.value;
      if (list is! List<dynamic>) continue;
      final stickers = [for (final item in list) PlacedSticker.fromJson(item)].whereType<PlacedSticker>().toList();
      if (stickers.isNotEmpty) pages[e.key] = stickers;
    }
    return pages;
  } on FormatException {
    return {};
  }
}

String encodeStopEdits(Map<String, Map<String, StopEdit>> pages) => jsonEncode({
      for (final page in pages.entries)
        if (page.value.isNotEmpty) page.key: {for (final e in page.value.entries) e.key: e.value.toJson()},
    });

Map<String, Map<String, StopEdit>> decodeStopEdits(String? raw) {
  if (raw == null || raw.isEmpty) return {};
  try {
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic>) return {};
    final pages = <String, Map<String, StopEdit>>{};
    for (final page in json.entries) {
      final edits = page.value;
      if (edits is! Map<String, dynamic>) continue;
      final map = <String, StopEdit>{};
      for (final e in edits.entries) {
        final edit = StopEdit.fromJson(e.value);
        if (edit != null) map[e.key] = edit;
      }
      if (map.isNotEmpty) pages[page.key] = map;
    }
    return pages;
  } on FormatException {
    return {};
  }
}

/// 카드별 꾸미기 상태: 붙인 스티커와 옮긴 장소 막대([StopEdit], 체크인 id별). 바뀔 때마다 알리고 기기에 저장한다.
class CardStickerStore extends ChangeNotifier {
  CardStickerStore._(this._prefs, this._pages, this._stops);

  /// 저장하지 않는 메모리 전용(테스트·저장소를 못 열었을 때).
  factory CardStickerStore.memory([Map<String, List<PlacedSticker>>? pages]) =>
      CardStickerStore._(null, {for (final e in (pages ?? const {}).entries) e.key: [...e.value]}, {});

  static const prefsKey = 'trip_card_stickers.v1';
  static const stopsPrefsKey = 'trip_card_stops.v1';

  static Future<CardStickerStore> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return CardStickerStore._(
        prefs,
        decodeStickerPages(prefs.getString(prefsKey)),
        decodeStopEdits(prefs.getString(stopsPrefsKey)),
      );
    } on Object {
      return CardStickerStore.memory();
    }
  }

  final SharedPreferences? _prefs;
  final Map<String, List<PlacedSticker>> _pages;
  final Map<String, Map<String, StopEdit>> _stops;
  var _seq = 0;

  /// 이 카드에서 옮긴 장소 막대들(체크인 id → 편집).
  Map<String, StopEdit> stopEditsOf(String pageKey) => Map.unmodifiable(_stops[pageKey] ?? const <String, StopEdit>{});

  /// [edit]이 null이거나 비었으면 원래 자리로 되돌린다. [save]는 [update]와 같다.
  void setStopEdit(String pageKey, String checkInId, StopEdit? edit, {bool save = true}) {
    if (edit == null || edit.isEmpty) {
      final page = _stops[pageKey];
      page?.remove(checkInId);
      if (page != null && page.isEmpty) _stops.remove(pageKey);
    } else {
      (_stops[pageKey] ??= {})[checkInId] = edit;
    }
    _changed(save: save);
  }

  List<PlacedSticker> stickersOf(String pageKey) => List.unmodifiable(_pages[pageKey] ?? const <PlacedSticker>[]);

  String newId() => '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${_seq++}';

  void add(String pageKey, PlacedSticker sticker) {
    (_pages[pageKey] ??= []).add(sticker);
    _changed();
  }

  /// [save]=false면 화면만 갱신하고 저장은 미룬다(끌어서 옮기는 중). 끝나면 [persist]를 부른다.
  void update(String pageKey, PlacedSticker sticker, {bool save = true}) {
    final list = _pages[pageKey];
    final i = list?.indexWhere((s) => s.id == sticker.id) ?? -1;
    if (list == null || i < 0) return;
    list[i] = sticker;
    _changed(save: save);
  }

  void remove(String pageKey, String id) {
    final list = _pages[pageKey];
    if (list == null) return;
    list.removeWhere((s) => s.id == id);
    if (list.isEmpty) _pages.remove(pageKey);
    _changed();
  }

  /// 맨 위로 올린다(가장 나중에 그린다).
  void bringToFront(String pageKey, String id) {
    final list = _pages[pageKey];
    final i = list?.indexWhere((s) => s.id == id) ?? -1;
    if (list == null || i < 0 || i == list.length - 1) return;
    list.add(list.removeAt(i));
    _changed();
  }

  void replaceAll(String pageKey, List<PlacedSticker> stickers) {
    if (stickers.isEmpty) {
      _pages.remove(pageKey);
    } else {
      _pages[pageKey] = [...stickers];
    }
    _changed();
  }

  void clear(String pageKey) => replaceAll(pageKey, const []);

  Future<void> persist() async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setString(prefsKey, encodeStickerPages(_pages));
    await prefs.setString(stopsPrefsKey, encodeStopEdits(_stops));
  }

  void _changed({bool save = true}) {
    notifyListeners();
    if (save) unawaited(persist());
  }
}
