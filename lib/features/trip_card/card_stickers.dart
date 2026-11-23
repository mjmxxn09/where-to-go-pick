/// 여행 카드 꾸미기: 유저가 붙인 스티커와 옮긴 장소 막대.
///
/// - 카드는 길·시간·장소 이름만 그리고, 스티커는 유저가 직접 붙인다(빈 카드로 시작).
/// - 좌표는 카드 좌표계(가로 358 기준, [TripCardLayoutConfig.pageWidth])의 스티커 **중심**이다.
/// - 카드 한 장(페이지)마다 따로 저장한다. "한 장에 모아보기"와 "하루씩 나눠보기"는 배치가 달라 서로 다른 장으로 본다.
/// - 기기에 저장(shared_preferences)하고, Supabase가 설정돼 있으면 바뀐 쪽만 서버에도 올린다([CardCloud]).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../trip/trip_models.dart';
import 'card_cloud.dart';
import 'place_sticker_match.dart';
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

/// "한 표 핀"이 붙은 자리에서 가장 가까운 장소 = 투표 후보. 붙인 순서대로, 같은 장소는 한 번만.
/// [stops]는 편집을 적용한 장소 칸(체크인 id + 막대 위치). [maxDistance]보다 멀면 후보로 보지 않는다.
List<String> voteCandidates(
  List<PlacedSticker> stickers,
  List<({String id, double x, double y})> stops, {
  String pinName = 'vote_pick',
  double maxDistance = 90,
}) {
  final out = <String>[];
  for (final s in stickers) {
    if (s.name != pinName) continue;
    String? best;
    var bestDistance = double.infinity;
    for (final p in stops) {
      final dx = p.x - s.x, dy = p.y - s.y;
      final d = dx * dx + dy * dy;
      if (d < bestDistance) {
        bestDistance = d;
        best = p.id;
      }
    }
    if (best != null && bestDistance <= maxDistance * maxDistance && !out.contains(best)) out.add(best);
  }
  return out;
}

/// 카드 한 장을 가리키는 저장 키.
String cardPageKey(Trip trip, TripCardMode mode, TripCardPage page) {
  if (mode == TripCardMode.onePage || !page.dayPage || page.days.isEmpty) return '${trip.id}:all';
  return '${trip.id}:day${page.days.first.index}';
}

/// "자동으로 꾸미기"가 붙이는 스티커 크기(카드 좌표).
const autoStickerSize = 54.0;

/// "자동으로 꾸미기": 장소마다 어울리는 스티커([stickerForPlace])를 그 장소 바로 옆, 이름표 반대쪽 길가에 붙인다.
///
/// - 이름이 길 아래면 스티커는 길 위, 이름이 위면 아래. 장소 막대 가운데에 맞추고 길에서 4만큼 띄운다.
/// - 다른 장소 이름표([avoid]), 제목, 출발 핀·끝 깃발, 먼저 붙인 스티커, 카드 밖과 겹치면 좌우로 조금 비켜 보고,
///   그래도 겹치면 그 장소는 건너뛴다.
/// - [stops]는 유저가 옮긴 장소 막대 자리(없으면 기본 자리). 이동 스티커는 붙이지 않는다.
List<PlacedSticker> autoDecorate(
  TripCardLayout layout,
  List<CheckIn> checkIns, {
  required bool Function(String name) has,
  required String Function() newId,
  List<StopSlot>? stops,
  List<Rect> avoid = const [],
  double size = autoStickerSize,
  double pageWidth = 358,
}) {
  const roadHalf = 8.0, gap = 4.0, titleBottom = 92.0, margin = 4.0;
  // 스티커 그림은 가장자리에 투명한 여백이 있어 겹침은 조금 작게 본다.
  final hit = size * 0.86;
  final blocked = <Rect>[
    for (final r in avoid) r.inflate(3),
    Rect.fromLTWH(layout.startX - 14, layout.startY - 32, 28, 34), // 출발 핀
    Rect.fromLTWH(layout.endX - 24, layout.endY - 38, 48, 40), // 끝 깃발
  ];
  final result = <PlacedSticker>[];
  final used = <String>{};

  for (final slot in stops ?? layout.stops) {
    if (slot.index >= checkIns.length) continue;
    final place = checkIns[slot.index];
    final name = stickerForPlace(place, has: has, used: used);
    if (name == null) continue;
    final dir = slot.labelAbove ? 1.0 : -1.0; // 이름 반대쪽
    final cy = slot.y + dir * (roadHalf + gap + size / 2);
    for (final dx in const [0.0, -10.0, 10.0, -20.0, 20.0]) {
      final box = Rect.fromCenter(center: Offset(slot.x + dx, cy), width: hit, height: hit);
      final inside = box.left >= margin &&
          box.right <= pageWidth - margin &&
          box.top >= titleBottom &&
          box.bottom <= layout.pageHeight - margin;
      if (!inside || blocked.any(box.overlaps)) continue;
      used.add(name);
      blocked.add(box.inflate(2));
      // 살짝 기울여 손으로 붙인 느낌(장소 이름으로 고정).
      final tilt = ((place.placeName.length % 5) - 2) * 0.04;
      result.add(PlacedSticker(id: newId(), name: name, x: slot.x + dx, y: cy, size: size, rotation: tilt));
      break;
    }
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
/// [CardCloud]가 있으면 열 때 서버 것을 받아 기기에 없는 쪽만 채우고, 저장할 때 바뀐 쪽을 올린다.
class CardStickerStore extends ChangeNotifier {
  CardStickerStore._(this._prefs, this._pages, this._stops, [this._cloud]);

  /// 저장하지 않는 메모리 전용(테스트·저장소를 못 열었을 때).
  factory CardStickerStore.memory([Map<String, List<PlacedSticker>>? pages, CardCloud? cloud]) =>
      CardStickerStore._(null, {for (final e in (pages ?? const {}).entries) e.key: [...e.value]}, {}, cloud);

  static const prefsKey = 'trip_card_stickers.v1';
  static const stopsPrefsKey = 'trip_card_stops.v1';

  static Future<CardStickerStore> load({CardCloud? cloud}) async {
    CardStickerStore store;
    try {
      final prefs = await SharedPreferences.getInstance();
      store = CardStickerStore._(
        prefs,
        decodeStickerPages(prefs.getString(prefsKey)),
        decodeStopEdits(prefs.getString(stopsPrefsKey)),
        cloud,
      );
    } on Object {
      store = CardStickerStore.memory(null, cloud);
    }
    unawaited(store.pullFromCloud());
    return store;
  }

  final SharedPreferences? _prefs;
  final Map<String, List<PlacedSticker>> _pages;
  final Map<String, Map<String, StopEdit>> _stops;
  final CardCloud? _cloud;

  /// 서버에 아직 안 올린 쪽.
  final Set<String> _dirty = {};
  var _seq = 0;
  var _disposed = false;

  /// 서버 꾸미기를 받아, 이 기기에 아무것도 없는 쪽만 채운다(기기 쪽이 우선). 못 올린 쪽이 있으면 같이 올린다.
  Future<void> pullFromCloud() async {
    final cloud = _cloud;
    if (cloud == null) return;
    try {
      final remote = await cloud.pull();
      if (_disposed) return;
      var filled = false;
      for (final page in remote) {
        if (page.isEmpty || _pages.containsKey(page.pageKey) || _stops.containsKey(page.pageKey)) continue;
        if (page.stickers.isNotEmpty) _pages[page.pageKey] = [...page.stickers];
        if (page.stopEdits.isNotEmpty) _stops[page.pageKey] = {...page.stopEdits};
        filled = true;
      }
      if (filled) {
        notifyListeners();
        await _saveLocal();
      }
      final remoteKeys = {for (final p in remote) p.pageKey};
      _dirty.addAll({..._pages.keys, ..._stops.keys}.where((k) => !remoteKeys.contains(k)));
      await _pushDirty();
    } on Object catch (e) {
      debugPrint('카드 꾸미기를 서버에서 받지 못했어요(기기에는 남아 있어요): $e');
    }
  }

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
    _changed(pageKey, save: save);
  }

  List<PlacedSticker> stickersOf(String pageKey) => List.unmodifiable(_pages[pageKey] ?? const <PlacedSticker>[]);

  String newId() => '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${_seq++}';

  void add(String pageKey, PlacedSticker sticker) {
    (_pages[pageKey] ??= []).add(sticker);
    _changed(pageKey);
  }

  /// [save]=false면 화면만 갱신하고 저장은 미룬다(끌어서 옮기는 중). 끝나면 [persist]를 부른다.
  void update(String pageKey, PlacedSticker sticker, {bool save = true}) {
    final list = _pages[pageKey];
    final i = list?.indexWhere((s) => s.id == sticker.id) ?? -1;
    if (list == null || i < 0) return;
    list[i] = sticker;
    _changed(pageKey, save: save);
  }

  void remove(String pageKey, String id) {
    final list = _pages[pageKey];
    if (list == null) return;
    list.removeWhere((s) => s.id == id);
    if (list.isEmpty) _pages.remove(pageKey);
    _changed(pageKey);
  }

  /// 맨 위로 올린다(가장 나중에 그린다).
  void bringToFront(String pageKey, String id) {
    final list = _pages[pageKey];
    final i = list?.indexWhere((s) => s.id == id) ?? -1;
    if (list == null || i < 0 || i == list.length - 1) return;
    list.add(list.removeAt(i));
    _changed(pageKey);
  }

  void replaceAll(String pageKey, List<PlacedSticker> stickers) {
    if (stickers.isEmpty) {
      _pages.remove(pageKey);
    } else {
      _pages[pageKey] = [...stickers];
    }
    _changed(pageKey);
  }

  void clear(String pageKey) => replaceAll(pageKey, const []);

  /// 기기에 저장하고, 바뀐 쪽을 서버에 올린다(서버는 실패해도 다음에 다시).
  Future<void> persist() async {
    await _saveLocal();
    await _pushDirty();
  }

  Future<void> _saveLocal() async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setString(prefsKey, encodeStickerPages(_pages));
    await prefs.setString(stopsPrefsKey, encodeStopEdits(_stops));
  }

  Future<void> _pushDirty() async {
    final cloud = _cloud;
    if (cloud == null || _dirty.isEmpty) return;
    final keys = {..._dirty};
    _dirty.clear();
    try {
      await cloud.push([
        for (final k in keys)
          CardDecoration(pageKey: k, stickers: [...?_pages[k]], stopEdits: {...?_stops[k]}),
      ]);
    } on Object catch (e) {
      _dirty.addAll(keys);
      debugPrint('카드 꾸미기를 올리지 못했어요(기기에는 남아 있어요): $e');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _pushTimer?.cancel();
    super.dispose();
  }

  Timer? _pushTimer;

  void _changed(String pageKey, {bool save = true}) {
    _dirty.add(pageKey);
    notifyListeners();
    if (!save) return;
    unawaited(_saveLocal());
    // 스티커를 연달아 붙일 때마다 올리지 않고, 손을 멈추면 한 번에 올린다.
    if (_cloud != null) {
      _pushTimer?.cancel();
      _pushTimer = Timer(const Duration(seconds: 2), () => unawaited(_pushDirty()));
    }
  }
}
