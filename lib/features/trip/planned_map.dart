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

  /// 화면(칸) 좌표의 핀 자리, 번호 → 자리.
  final Map<int, Offset> pins;

  /// 지도 칸 밖이라 못 그린 핀 수.
  final int outside;

  /// [at]에서 가장 가까운 핀 번호(반지름 [radius] 안). 없으면 null.
  int? pinAt(Offset at, {double radius = 22}) {
    int? best;
    var bestD = radius;
    pins.forEach((n, p) {
      final d = (p - at).distance;
      if (d <= bestD) {
        bestD = d;
        best = n;
      }
    });
    return best;
  }
}

/// 가볼 곳 위에 놓는 작은 지도: 이 시·군·구 모양(주변 시·군·구는 흐리게) + 담은 곳 번호 핀.
/// 핀을 누르면 이름이 뜬다. 지도 그림은 앱에 든 통계청 경계라 인터넷·지도 키가 필요 없다.
class PlannedMap extends StatefulWidget {
  const PlannedMap({
    super.key,
    required this.mapData,
    required this.cityId,
    required this.pins,
    this.missing = 0,
    this.height = 190,
  });

  final Future<KoreaMapData> mapData;
  final String cityId;
  final List<PlannedPin> pins;

  /// 좌표가 없어 목록에만 있는 가볼 곳 수.
  final int missing;
  final double height;

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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<KoreaMapData>(
      future: widget.mapData,
      builder: (context, snap) {
        final data = snap.data;
        if (data == null) return SizedBox(height: widget.height);
        final province = widget.cityId.substring(0, 2);
        final detail = data.details[province];
        final city = _cityOf(detail, widget.cityId);
        if (detail == null || city == null) return const SizedBox.shrink();
        final points = <int, Offset>{
          for (final p in widget.pins)
            if (projectToDetail(province, p.at.lat, p.at.lng) case final at?) p.number: at,
        };
        return LayoutBuilder(builder: (context, box) {
          final size = Size(box.maxWidth, widget.height);
          final layout = PlannedMapLayout.fit(city: city.path.getBounds(), points: points, size: size);
          final byNumber = {for (final p in widget.pins) p.number: p};
          final selected = byNumber[_selected];
          final notShown = layout.outside + widget.missing + (widget.pins.length - points.length);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                label: '가볼 곳 지도, ${city.name}에 ${layout.pins.length}곳',
                child: GestureDetector(
                  onTapUp: (d) => setState(() {
                    final n = layout.pinAt(d.localPosition);
                    _selected = n == _selected ? null : n;
                  }),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: CustomPaint(
                      size: size,
                      painter: _PlannedMapPainter(
                        layout: layout,
                        city: city,
                        neighbors: detail.cities,
                        pins: byNumber,
                        selected: _selected,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      selected != null
                          ? '${selected.number}. ${selected.name}${selected.done ? ' · 다녀옴' : ''}'
                          : notShown > 0
                              ? '핀을 누르면 이름이 보여요 · 지도에 없는 곳 $notShown곳'
                              : '핀을 누르면 이름이 보여요',
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

MapRegion? _cityOf(ProvinceDetail? detail, String id) {
  for (final c in detail?.cities ?? const <MapRegion>[]) {
    if (c.id == id) return c;
  }
  return null;
}

class _PlannedMapPainter extends CustomPainter {
  _PlannedMapPainter({
    required this.layout,
    required this.city,
    required this.neighbors,
    required this.pins,
    required this.selected,
  });

  final PlannedMapLayout layout;
  final MapRegion city;
  final List<MapRegion> neighbors;
  final Map<int, PlannedPin> pins;
  final int? selected;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.mapSea);

    canvas.save();
    canvas.translate(layout.offset.dx, layout.offset.dy);
    canvas.scale(layout.scale);
    final s = layout.scale;
    final white = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 / s
      ..strokeJoin = StrokeJoin.round;
    // 주변 시·군·구는 흐리게(위치감), 이 시·군·구는 그림자를 깔고 제 색으로.
    for (final r in neighbors) {
      if (r.id == city.id) continue;
      canvas.drawPath(r.path, Paint()..color = AppColors.mapUnvisited);
      canvas.drawPath(r.path, white);
    }
    canvas.save();
    canvas.translate(0, 4 / s);
    canvas.drawPath(city.path, Paint()..color = AppColors.mapShadow);
    canvas.restore();
    canvas.drawPath(city.path, Paint()..color = city.fill);
    canvas.drawPath(city.path, white..strokeWidth = 2 / s);
    canvas.restore();

    // 핀: 번호 작은 것이 아래, 고른 핀은 맨 위.
    final order = layout.pins.keys.toList()..sort();
    if (selected != null && order.remove(selected)) order.add(selected!);
    for (final n in order) {
      final pin = pins[n];
      if (pin == null) continue;
      _drawPin(canvas, layout.pins[n]!, n, done: pin.done, selected: n == selected);
    }
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
  bool shouldRepaint(_PlannedMapPainter old) =>
      old.layout.view != layout.view ||
      old.layout.scale != layout.scale ||
      old.city != city ||
      old.selected != selected ||
      old.pins.length != pins.length ||
      old.pins.entries.any((e) => pins[e.key]?.done != e.value.done || pins[e.key]?.at != e.value.at);
}
