import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../korea_map/geo_projection.dart';
import '../korea_map/korea_map_data.dart';
import 'trip_models.dart';

/// 가볼 곳 지도에 찍을 핀 하나. [number]는 아래 목록의 번호와 같다.
class PlannedPin {
  const PlannedPin({required this.number, required this.name, required this.at, this.done = false});

  final int number;
  final String name;
  final GeoPoint at;
  final bool done;
}

/// 지도 칸에 무엇을 어디에 그릴지(그리기와 떼어 두어 시험하기 쉽게).
class PlannedMapLayout {
  PlannedMapLayout._(this.view, this.scale, this.offset, this.pins, this.outside);

  /// [city] 경계(도 상세 지도 좌표)와 핀 자리로 [size] 칸에 맞춘다.
  /// 시·군·구에서 많이 떨어진 핀(크기의 40% 넘게 밖)은 그리지 않고 [outside]로 센다 — 검색에서 다른 지역 장소를 담은 경우.
  factory PlannedMapLayout.fit({
    required Rect city,
    required Map<int, Offset> points,
    required Size size,
    double padding = 14,
  }) {
    final reach = city.inflate(math.max(city.width, city.height) * 0.4);
    final pins = <int, Offset>{};
    var outside = 0;
    points.forEach((n, p) {
      if (reach.contains(p)) {
        pins[n] = p;
      } else {
        outside++;
      }
    });
    var view = city;
    for (final p in pins.values) {
      view = view.expandToInclude(Rect.fromCenter(center: p, width: 0, height: 0));
    }
    // 아주 작은 구(부산 중구 등)도 너무 크게 키우지 않게 최소 크기를 둔다.
    const minSide = 36.0;
    if (view.width < minSide || view.height < minSide) {
      view = Rect.fromCenter(
        center: view.center,
        width: math.max(view.width, minSide),
        height: math.max(view.height, minSide),
      );
    }
    final inner = Size(math.max(1, size.width - padding * 2), math.max(1, size.height - padding * 2));
    final scale = math.min(inner.width / view.width, inner.height / view.height);
    final offset = Offset(
      (size.width - view.width * scale) / 2 - view.left * scale,
      (size.height - view.height * scale) / 2 - view.top * scale,
    );
    return PlannedMapLayout._(view, scale, offset, {for (final e in pins.entries) e.key: e.value * scale + offset}, outside);
  }

  final Rect view;
  final double scale;
  final Offset offset;

  /// 칸 좌표의 핀 자리(확대 전), 번호 → 자리.
  final Map<int, Offset> pins;

  /// 지도 칸 밖이라 못 그린 핀 수.
  final int outside;

  /// 지도 좌표 → 칸 좌표(확대 전).
  Offset toBox(Offset map) => map * scale + offset;

  /// [at]에서 가장 가까운 핀 번호(반지름 [radius] 안). [zoom]·[pan]은 크게 보기의 확대 배율·이동.
  int? pinAt(Offset at, {double radius = 22, double zoom = 1, Offset pan = Offset.zero}) {
    int? best;
    var bestD = radius;
    pins.forEach((n, p) {
      final d = (p * zoom + pan - at).distance;
      if (d <= bestD) {
        bestD = d;
        best = n;
      }
    });
    return best;
  }
}

/// 확대 배율·이동을 칸 안으로: 배율 1~[maxZoom], 지도가 칸 밖으로 밀려나지 않게.
({double zoom, Offset pan}) clampView(double zoom, Offset pan, Size size, {double maxZoom = 8}) {
  final z = _between(zoom, 1, maxZoom);
  final dx = _between(pan.dx, size.width * (1 - z), 0);
  final dy = _between(pan.dy, size.height * (1 - z), 0);
  return (zoom: z, pan: Offset(dx, dy));
}

double _between(double v, double low, double high) => math.max(low, math.min(high, v));

/// 지도에 그릴 재료: 도 상세, 여행지 시·군·구, 경계 상자, 핀 자리(지도 좌표).
class PlannedMapScene {
  PlannedMapScene._({
    required this.detail,
    required this.shown,
    required this.bounds,
    required this.placeName,
    required this.points,
  });

  /// [cityId]가 도 코드(두 자리)면 그 도의 시·군·구 전부가 여행지.
  static PlannedMapScene? of(KoreaMapData data, String cityId, List<PlannedPin> pins) {
    final province = cityId.substring(0, 2);
    final detail = data.details[province];
    if (detail == null) return null;
    final whole = isProvinceId(cityId);
    MapRegion? city;
    for (final c in detail.cities) {
      if (c.id == cityId) city = c;
    }
    if (!whole && city == null) return null;
    final shown = whole ? detail.cities : [city!];
    var bounds = shown.first.path.getBounds();
    for (final r in shown.skip(1)) {
      bounds = bounds.expandToInclude(r.path.getBounds());
    }
    return PlannedMapScene._(
      detail: detail,
      shown: {for (final r in shown) r.id},
      bounds: bounds,
      placeName: whole ? detail.name : city!.name,
      points: {
        for (final p in pins)
          if (projectToDetail(province, p.at.lat, p.at.lng) case final at?) p.number: at,
      },
    );
  }

  final ProvinceDetail detail;
  final Set<String> shown;
  final Rect bounds;
  final String placeName;
  final Map<int, Offset> points;
}

/// 가볼 곳 위에 놓는 작은 지도: 이 시·군·구 모양(주변 시·군·구는 흐리게) + 담은 곳 번호 핀.
/// 도·광역시 전체 여행([cityId]가 도 코드)이면 그 도의 시·군·구를 모두 제 색으로 그린다.
/// 오른쪽 위 버튼(또는 두 번 누르기)으로 크게 보기 — 손가락으로 확대·이동, 확대하면 시·군·구 이름.
class PlannedMap extends StatefulWidget {
  const PlannedMap({
    super.key,
    required this.mapData,
    required this.cityId,
    required this.pins,
    this.missing = 0,
    this.height = 190,
    this.title = '가볼 곳 지도',
    this.connect = false,
  });

  final Future<KoreaMapData> mapData;
  final String cityId;
  final List<PlannedPin> pins;

  /// 좌표가 없어 목록에만 있는 가볼 곳 수.
  final int missing;
  final double height;

  /// 크게 보기 화면 제목.
  final String title;

  /// 핀을 번호 순서대로 점선으로 잇는다(하루 동선).
  final bool connect;

  @override
  State<PlannedMap> createState() => _PlannedMapState();
}

class _PlannedMapState extends State<PlannedMap> {
  int? _selected;

  @override
  void didUpdateWidget(PlannedMap old) {
    super.didUpdateWidget(old);
    if (_selected != null && !widget.pins.any((p) => p.number == _selected)) _selected = null;
  }

  void _openLarge(KoreaMapData data) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PlannedMapPage(
        data: data,
        cityId: widget.cityId,
        pins: widget.pins,
        title: widget.title,
        connect: widget.connect,
        missing: widget.missing,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<KoreaMapData>(
      future: widget.mapData,
      builder: (context, snap) {
        final data = snap.data;
        if (data == null) return SizedBox(height: widget.height);
        final scene = PlannedMapScene.of(data, widget.cityId, widget.pins);
        if (scene == null) return const SizedBox.shrink();
        return LayoutBuilder(builder: (context, box) {
          final size = Size(box.maxWidth, widget.height);
          final layout = PlannedMapLayout.fit(city: scene.bounds, points: scene.points, size: size);
          final byNumber = {for (final p in widget.pins) p.number: p};
          final selected = byNumber[_selected];
          final notShown = layout.outside + widget.missing + (widget.pins.length - scene.points.length);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  Semantics(
                    label: '가볼 곳 지도, ${scene.placeName}에 ${layout.pins.length}곳. 두 번 누르면 크게 봐요.',
                    child: GestureDetector(
                      onTapUp: (d) => setState(() {
                        final n = layout.pinAt(d.localPosition);
                        _selected = n == _selected ? null : n;
                      }),
                      onDoubleTap: () => _openLarge(data),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: CustomPaint(
                          size: size,
                          painter: PlannedMapPainter(
                            layout: layout,
                            scene: scene,
                            pins: byNumber,
                            selected: _selected,
                            connect: widget.connect,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      elevation: 1,
                      child: IconButton(
                        tooltip: '지도 크게 보기',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.open_in_full, size: 18, color: AppColors.primaryDeep),
                        onPressed: () => _openLarge(data),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      selected != null
                          ? '${selected.number}. ${selected.name}${selected.done ? ' · 다녀옴' : ''}'
                          : notShown > 0
                              ? '핀을 누르면 이름 · ⤢ 크게 보기 · 지도에 없는 곳 $notShown곳'
                              : '핀을 누르면 이름 · ⤢ 크게 보면 확대할 수 있어요',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: selected != null ? FontWeight.w700 : FontWeight.w500,
                        color: selected != null ? AppColors.primaryDeep : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const Text('지도: 통계청 SGIS', style: TextStyle(fontSize: 10, color: AppColors.muted)),
                ],
              ),
            ],
          );
        });
      },
    );
  }
}

/// 가볼 곳 지도 크게 보기: 두 손가락으로 확대·이동, 두 번 누르면 확대/처음 크기, +/- 버튼.
/// 확대하면 시·군·구 이름(구까지)이 보이고, 더 확대하면 핀 옆에 장소 이름이 붙는다.
class PlannedMapPage extends StatefulWidget {
  const PlannedMapPage({
    super.key,
    required this.data,
    required this.cityId,
    required this.pins,
    required this.title,
    this.connect = false,
    this.missing = 0,
  });

  final KoreaMapData data;
  final String cityId;
  final List<PlannedPin> pins;
  final String title;
  final bool connect;
  final int missing;

  @override
  State<PlannedMapPage> createState() => _PlannedMapPageState();
}

class _PlannedMapPageState extends State<PlannedMapPage> {
  static const _maxZoom = 8.0;

  double _zoom = 1;
  Offset _pan = Offset.zero;
  int? _selected;

  double _startZoom = 1;
  Offset _startPan = Offset.zero;
  Offset _startFocal = Offset.zero;
  Offset? _doubleTapAt;

  void _set(double zoom, Offset pan, Size size) {
    final v = clampView(zoom, pan, size, maxZoom: _maxZoom);
    setState(() {
      _zoom = v.zoom;
      _pan = v.pan;
    });
  }

  /// [focal]을 그 자리에 둔 채 배율만 바꾼다.
  void _zoomAt(double zoom, Offset focal, Size size) {
    final z = _between(zoom, 1, _maxZoom);
    final content = (focal - _pan) / _zoom;
    _set(z, focal - content * z, size);
  }

  @override
  Widget build(BuildContext context) {
    final scene = PlannedMapScene.of(widget.data, widget.cityId, widget.pins);
    final byNumber = {for (final p in widget.pins) p.number: p};
    final selected = byNumber[_selected];
    return Scaffold(
      backgroundColor: AppColors.mapSea,
      appBar: AppBar(title: Text(widget.title), backgroundColor: AppColors.surface),
      body: scene == null
          ? const Center(child: Text('지도를 그릴 수 없어요.'))
          : LayoutBuilder(builder: (context, box) {
              final size = Size(box.maxWidth, box.maxHeight);
              final layout = PlannedMapLayout.fit(city: scene.bounds, points: scene.points, size: size, padding: 28);
              final hidden = layout.outside + widget.missing + (widget.pins.length - scene.points.length);
              return Stack(
                children: [
                  GestureDetector(
                    onScaleStart: (d) {
                      _startZoom = _zoom;
                      _startPan = _pan;
                      _startFocal = d.localFocalPoint;
                    },
                    onScaleUpdate: (d) {
                      final zoom = _between(_startZoom * d.scale, 1, _maxZoom);
                      final content = (_startFocal - _startPan) / _startZoom;
                      _set(zoom, d.localFocalPoint - content * zoom, size);
                    },
                    onTapUp: (d) => setState(() {
                      final n = layout.pinAt(d.localPosition, zoom: _zoom, pan: _pan);
                      _selected = n == _selected ? null : n;
                    }),
                    onDoubleTapDown: (d) => _doubleTapAt = d.localPosition,
                    onDoubleTap: () {
                      final at = _doubleTapAt ?? size.center(Offset.zero);
                      if (_zoom > 1.5) {
                        _set(1, Offset.zero, size);
                      } else {
                        _zoomAt(3, at, size);
                      }
                    },
                    child: CustomPaint(
                      size: size,
                      painter: PlannedMapPainter(
                        layout: layout,
                        scene: scene,
                        pins: byNumber,
                        selected: _selected,
                        connect: widget.connect,
                        zoom: _zoom,
                        pan: _pan,
                        labels: true,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 12,
                    bottom: 96,
                    child: Column(
                      children: [
                        _RoundButton(
                          icon: Icons.add,
                          tooltip: '확대',
                          onTap: () => _zoomAt(_zoom * 1.6, size.center(Offset.zero), size),
                        ),
                        const SizedBox(height: 8),
                        _RoundButton(
                          icon: Icons.remove,
                          tooltip: '축소',
                          onTap: () => _zoomAt(_zoom / 1.6, size.center(Offset.zero), size),
                        ),
                        const SizedBox(height: 8),
                        _RoundButton(
                          icon: Icons.fit_screen_outlined,
                          tooltip: '처음 크기',
                          onTap: () => _set(1, Offset.zero, size),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: AppDecorations.card,
                      child: Text(
                        selected != null
                            ? '${selected.number}. ${selected.name}${selected.done ? ' · 다녀옴' : ''}'
                            : _zoom < 1.6
                                ? '두 손가락으로 벌리거나 두 번 누르면 확대돼요. 확대하면 시·군·구 이름이 보여요.'
                                : '핀을 누르면 장소 이름이 보여요.${hidden > 0 ? ' 지도에 없는 곳 $hidden곳.' : ''}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected != null ? FontWeight.w800 : FontWeight.w500,
                          color: selected != null ? AppColors.primaryDeep : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 2,
        child: IconButton(tooltip: tooltip, icon: Icon(icon, color: AppColors.primaryDeep), onPressed: onTap),
      );
}

/// 지도 그리기. 지도 그림은 [zoom]·[pan]으로 확대·이동하고, 핀과 글자는 확대해도 같은 크기.
class PlannedMapPainter extends CustomPainter {
  PlannedMapPainter({
    required this.layout,
    required this.scene,
    required this.pins,
    required this.selected,
    this.connect = false,
    this.zoom = 1,
    this.pan = Offset.zero,
    this.labels = false,
  });

  final PlannedMapLayout layout;
  final PlannedMapScene scene;
  final Map<int, PlannedPin> pins;
  final int? selected;
  final bool connect;
  final double zoom;
  final Offset pan;

  /// 시·군·구 이름과 (많이 확대하면) 핀 옆 장소 이름을 쓴다.
  final bool labels;

  Offset _screen(Offset box) => box * zoom + pan;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.mapSea);
    final regions = scene.detail.cities;
    final shown = scene.shown;

    canvas.save();
    canvas.translate(pan.dx, pan.dy);
    canvas.scale(zoom);
    canvas.translate(layout.offset.dx, layout.offset.dy);
    canvas.scale(layout.scale);
    final s = layout.scale * zoom;
    final white = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 / s
      ..strokeJoin = StrokeJoin.round;
    // 주변 시·군·구는 흐리게(위치감), 여행지는 그림자를 깔고 제 색으로.
    final mine = [for (final r in regions) if (shown.contains(r.id)) r];
    for (final r in regions) {
      if (shown.contains(r.id)) continue;
      canvas.drawPath(r.path, Paint()..color = AppColors.mapUnvisited);
      canvas.drawPath(r.path, white);
    }
    canvas.save();
    canvas.translate(0, 4 / s);
    for (final r in mine) {
      canvas.drawPath(r.path, Paint()..color = AppColors.mapShadow);
    }
    canvas.restore();
    white.strokeWidth = (mine.length > 1 ? 1.4 : 2) / s;
    for (final r in mine) {
      canvas.drawPath(r.path, Paint()..color = r.fill);
      canvas.drawPath(r.path, white);
    }
    canvas.restore();

    // 시·군·구 이름(크게 보기): 여행지 이름은 처음부터, 주변·작은 구는 1.6배 넘게 확대했을 때.
    if (labels) {
      final screen = (Offset.zero & size).inflate(40);
      for (final r in regions) {
        final isMine = shown.contains(r.id);
        final visible = zoom >= 1.6 || (isMine && (r.showLabel || shown.length == 1));
        if (!visible) continue;
        final at = _screen(layout.toBox(r.label));
        if (!screen.contains(at)) continue;
        _text(canvas, r.name, at,
            size: isMine ? 12 : 11,
            color: isMine ? AppColors.mapLabel : const Color(0xFF8A86A3),
            weight: isMine ? FontWeight.w800 : FontWeight.w600);
      }
    }

    // 하루 동선: 번호 순서대로 점선.
    final order = layout.pins.keys.toList()..sort();
    if (connect && order.length > 1) {
      final line = Paint()
        ..color = AppColors.primary.withValues(alpha: 0.55)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i + 1 < order.length; i++) {
        _dashed(canvas, _screen(layout.pins[order[i]]!), _screen(layout.pins[order[i + 1]]!), line);
      }
    }

    // 핀: 번호 작은 것이 아래, 고른 핀은 맨 위. 많이 확대하면(또는 고른 핀은) 아래에 장소 이름.
    if (selected != null && order.remove(selected)) order.add(selected!);
    for (final n in order) {
      final pin = pins[n];
      if (pin == null) continue;
      final at = _screen(layout.pins[n]!);
      _drawPin(canvas, at, n, done: pin.done, selected: n == selected);
      if (labels && (zoom >= 2.2 || n == selected)) {
        _text(canvas, pin.name, at + const Offset(0, 22), size: 11.5, color: AppColors.ink, weight: FontWeight.w800);
      }
    }
  }

  void _dashed(Canvas canvas, Offset a, Offset b, Paint paint) {
    final d = b - a;
    final len = d.distance;
    if (len < 1) return;
    final dir = d / len;
    const dash = 6.0, gap = 5.0;
    for (var t = 0.0; t < len; t += dash + gap) {
      canvas.drawLine(a + dir * t, a + dir * math.min(t + dash, len), paint);
    }
  }

  /// 흰 테두리를 두른 글자(지도 위에서도 읽히게), [center] 가운데 맞춤.
  void _text(Canvas canvas, String text, Offset center,
      {required double size, required Color color, required FontWeight weight}) {
    TextPainter make(TextStyle style) => TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: 140);
    final base = TextStyle(fontSize: size, fontWeight: weight, height: 1.1);
    final halo = make(base.copyWith(
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white.withValues(alpha: 0.9),
    ));
    final main = make(base.copyWith(color: color));
    final at = center - Offset(main.width / 2, main.height / 2);
    halo.paint(canvas, at);
    main.paint(canvas, at);
  }

  void _drawPin(Canvas canvas, Offset at, int n, {required bool done, required bool selected}) {
    final r = selected ? 13.0 : 11.0;
    final fill = done ? AppColors.accent : AppColors.primary;
    canvas.drawCircle(at + const Offset(0, 2), r + 2, Paint()..color = const Color(0x334A35C8));
    canvas.drawCircle(at, r + 2, Paint()..color = Colors.white);
    canvas.drawCircle(at, r, Paint()..color = selected ? AppColors.secondary : fill);
    final text = TextPainter(
      text: TextSpan(
        text: '$n',
        style: TextStyle(fontFamily: AppFonts.title, fontSize: n > 9 ? 10 : 12, color: Colors.white, height: 1),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, at - Offset(text.width / 2, text.height / 2));
  }

  @override
  bool shouldRepaint(PlannedMapPainter old) =>
      old.layout.view != layout.view ||
      old.layout.scale != layout.scale ||
      old.layout.offset != layout.offset ||
      old.scene.shown.length != scene.shown.length ||
      !old.scene.shown.containsAll(scene.shown) ||
      old.selected != selected ||
      old.connect != connect ||
      old.zoom != zoom ||
      old.pan != pan ||
      old.labels != labels ||
      old.pins.length != pins.length ||
      old.pins.entries.any((e) => pins[e.key]?.done != e.value.done || pins[e.key]?.at != e.value.at);
}
