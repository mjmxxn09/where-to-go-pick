import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'korea_map_data.dart';

enum KoreaMapMode {
  /// 여행지 고르기: 모든 지역에 색이 있고, 시·군·구를 고르면 [KoreaMapView.onCityChanged]로 알린다.
  explore,

  /// 내 여행 지도: 다녀온 곳만 색칠하고 나머지는 회색.
  visited,
}

class SelectedCity {
  const SelectedCity({
    required this.id,
    required this.name,
    required this.provinceCode,
    required this.provinceName,
  });

  final String id;
  final String name;
  final String provinceCode;
  final String provinceName;
}

/// 귀여운 대한민국 지도. 도(광역시)를 누르면 그 도의 시·군·구 지도로 들어가고, "전국"으로 돌아온다.
///
/// 클레이 느낌: 파스텔 면 + 흰 경계선 + 아래로 5px 내린 보라 그림자. 고른 지역은 4px 떠오른다.
class KoreaMapView extends StatefulWidget {
  const KoreaMapView({
    super.key,
    required this.data,
    this.mode = KoreaMapMode.explore,
    this.visitedCityIds = const <String>{},
    this.initialProvince,
    this.initialCity,
    this.onCityChanged,
    this.height = 460,
  });

  final KoreaMapData data;
  final KoreaMapMode mode;
  final Set<String> visitedCityIds;
  final String? initialProvince;
  final String? initialCity;
  final ValueChanged<SelectedCity?>? onCityChanged;
  final double height;

  @override
  State<KoreaMapView> createState() => _KoreaMapViewState();
}

class _KoreaMapViewState extends State<KoreaMapView> {
  String? _province;
  String? _city;

  @override
  void initState() {
    super.initState();
    _province = widget.initialProvince;
    _city = widget.initialCity;
  }

  bool _provinceVisited(String code) => widget.visitedCityIds.any((id) => id.startsWith(code));

  void _goOverview() {
    setState(() {
      _province = null;
      _city = null;
    });
    widget.onCityChanged?.call(null);
  }

  void _openProvince(String code) {
    if (!widget.data.details.containsKey(code)) return;
    setState(() {
      _province = code;
      _city = null;
    });
    widget.onCityChanged?.call(null);
  }

  void _handleTap(Offset p) {
    final detail = _province == null ? null : widget.data.details[_province];
    if (detail == null) {
      final inset = widget.data.overviewInset;
      if (inset != null && inset.bounds.inflate(6).contains(p)) {
        _openProvince('37');
        return;
      }
      for (final r in widget.data.provinces.reversed) {
        if (r.path.contains(p)) {
          _openProvince(r.id);
          return;
        }
      }
      return;
    }
    for (final c in detail.cities.reversed) {
      if (c.path.contains(p)) {
        setState(() => _city = c.id);
        widget.onCityChanged?.call(SelectedCity(
          id: c.id,
          name: c.name,
          provinceCode: detail.code,
          provinceName: detail.name,
        ));
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final detail = _province == null ? null : data.details[_province];
    final logical = detail == null ? data.overviewSize : KoreaMapData.detailSize;
    final visitedMode = widget.mode == KoreaMapMode.visited;

    final regions = <_PaintRegion>[];
    if (detail == null) {
      for (final r in data.provinces) {
        final on = !visitedMode || _provinceVisited(r.id);
        regions.add(_PaintRegion(
          region: r,
          fill: on ? r.fill : AppColors.mapUnvisited,
          label: r.shortName,
          labelSize: r.small ? 11 : 14,
          showLabel: true,
          dimmed: !on,
          selected: false,
          visited: visitedMode && on,
        ));
      }
    } else {
      for (final c in detail.cities) {
        final selected = c.id == _city;
        final on = !visitedMode || widget.visitedCityIds.contains(c.id);
        regions.add(_PaintRegion(
          region: c,
          fill: selected ? AppColors.primary : (on ? c.fill : AppColors.mapUnvisited),
          label: c.name,
          labelSize: selected ? 13 : 11,
          showLabel: c.showLabel || selected || (visitedMode && on),
          dimmed: !on,
          selected: selected,
          visited: visitedMode && on,
        ));
      }
    }

    final title = detail?.name ?? (visitedMode ? '내가 다녀온 곳' : '지역을 눌러 봐!');

    return Container(
      height: widget.height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: AppColors.mapSea, borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(
              children: [
                if (detail != null)
                  _Chip(
                    onTap: _goOverview,
                    icon: Icons.chevron_left,
                    label: '전국',
                    background: AppColors.surface,
                    foreground: AppColors.primaryDeep,
                  )
                else
                  const _Chip(label: '전국 지도', background: AppColors.surface, foreground: AppColors.primaryDeep),
                const Spacer(),
                _Chip(label: title, background: AppColors.primary, foreground: Colors.white),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final scale = math.min(
                  constraints.maxWidth / logical.width,
                  constraints.maxHeight / logical.height,
                );
                final offset = Offset(
                  (constraints.maxWidth - logical.width * scale) / 2,
                  (constraints.maxHeight - logical.height * scale) / 2,
                );
                return Semantics(
                  label: detail == null
                      ? '대한민국 지도. 도를 누르면 시·군·구 지도로 들어가요.'
                      : '${detail.name} 지도. 시·군·구를 눌러 골라요.',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (d) => _handleTap((d.localPosition - offset) / scale),
                    child: CustomPaint(
                      size: Size(constraints.maxWidth, constraints.maxHeight),
                      painter: _KoreaMapPainter(
                        regions: regions,
                        context: detail?.context,
                        inset: detail == null ? data.overviewInset : detail.inset,
                        insetFill: detail == null && visitedMode && !_provinceVisited('37')
                            ? AppColors.mapUnvisited
                            : const Color(0xFFFFE7A8),
                        scale: scale,
                        offset: offset,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.background, required this.foreground, this.icon, this.onTap});

  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      height: 32,
      padding: EdgeInsets.only(left: icon == null ? 12 : 6, right: 12),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) Icon(icon, size: 18, color: foreground),
          Text(label, style: TextStyle(fontFamily: AppFonts.title, fontSize: 14, color: foreground)),
        ],
      ),
    );
    if (onTap == null) return body;
    return Semantics(
      button: true,
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: body),
    );
  }
}

class _PaintRegion {
  const _PaintRegion({
    required this.region,
    required this.fill,
    required this.label,
    required this.labelSize,
    required this.showLabel,
    required this.dimmed,
    required this.selected,
    required this.visited,
  });

  final MapRegion region;
  final Color fill;
  final String label;
  final double labelSize;
  final bool showLabel;
  final bool dimmed;
  final bool selected;
  final bool visited;
}

class _KoreaMapPainter extends CustomPainter {
  _KoreaMapPainter({
    required this.regions,
    required this.context,
    required this.inset,
    required this.insetFill,
    required this.scale,
    required this.offset,
  });

  final List<_PaintRegion> regions;
  final Path? context;
  final MapInset? inset;
  final Color insetFill;
  final double scale;
  final Offset offset;

  static const _lift = Offset(0, -4);
  static const _shadowDrop = Offset(0, 5);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale);

    final white = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round;

    final ctx = context;
    if (ctx != null) {
      canvas.drawPath(ctx, Paint()..color = AppColors.mapContext);
      canvas.drawPath(ctx, white..strokeWidth = 1.5);
      white.strokeWidth = 1.8;
    }

    // 1) 그림자(전부 먼저) 2) 면 3) 라벨 — 순서를 지켜야 그림자가 옆 지역 위로 올라오지 않는다.
    for (final r in regions) {
      final color = r.selected ? AppColors.primaryDeep : AppColors.mapShadow;
      canvas.save();
      canvas.translate(_shadowDrop.dx, _shadowDrop.dy);
      canvas.drawPath(r.region.path, Paint()..color = color);
      canvas.drawPath(
        r.region.path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.restore();
    }
    for (final r in regions) {
      canvas.save();
      if (r.selected) canvas.translate(_lift.dx, _lift.dy);
      canvas.drawPath(r.region.path, Paint()..color = r.fill);
      canvas.drawPath(r.region.path, white);
      canvas.restore();
    }

    final ins = inset;
    if (ins != null) {
      final frame = RRect.fromRectAndRadius(ins.bounds.inflate(6), const Radius.circular(10));
      canvas.drawRRect(frame, Paint()..color = const Color(0xFFF6F3FF));
      canvas.drawRRect(
        frame,
        Paint()
          ..color = const Color(0xFFB3A6EC)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      canvas.drawPath(ins.path, Paint()..color = insetFill);
      canvas.drawPath(ins.path, white..strokeWidth = 1);
      _drawText(canvas, ins.label, Offset(ins.bounds.center.dx, ins.bounds.bottom + 12), 9, AppColors.ink);
    }

    for (final r in regions) {
      if (!r.showLabel) continue;
      final pos = r.region.label + (r.selected ? _lift : Offset.zero);
      final color = r.selected ? Colors.white : (r.dimmed ? const Color(0xFF6B6880) : AppColors.mapLabel);
      final width = _drawText(canvas, r.label, pos, r.labelSize, color, halo: !r.selected);
      if (r.visited) _drawCheck(canvas, pos + Offset(width / 2 + 7, 0));
      if (r.selected) _drawPin(canvas, pos + const Offset(0, -24));
    }
    canvas.restore();
  }

  double _drawText(Canvas canvas, String text, Offset center, double size, Color color, {bool halo = true}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: AppFonts.title,
          fontSize: size,
          height: 1,
          color: color,
          shadows: halo
              ? const [Shadow(color: Colors.white, blurRadius: 3), Shadow(color: Colors.white, blurRadius: 2)]
              : null,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    return tp.width;
  }

  void _drawCheck(Canvas canvas, Offset c) {
    canvas.drawCircle(c, 6, Paint()..color = AppColors.primary);
    final p = Path()
      ..moveTo(c.dx - 3, c.dy + 0.2)
      ..lineTo(c.dx - 0.8, c.dy + 2.4)
      ..lineTo(c.dx + 3, c.dy - 2);
    canvas.drawPath(
      p,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawPin(Canvas canvas, Offset c) {
    final body = Path()
      ..moveTo(c.dx, c.dy + 14)
      ..quadraticBezierTo(c.dx - 10, c.dy + 3, c.dx - 10, c.dy - 3)
      ..arcToPoint(Offset(c.dx + 10, c.dy - 3), radius: const Radius.circular(10))
      ..quadraticBezierTo(c.dx + 10, c.dy + 3, c.dx, c.dy + 14)
      ..close();
    canvas.drawPath(body, Paint()..color = AppColors.secondary);
    canvas.drawPath(
      body,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(c + const Offset(0, -3), 3.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _KoreaMapPainter old) => true;
}
