import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../trip/trip_models.dart';
import 'doodles.dart';
import 'trip_card_layout.dart';

enum PaperStyle { grid, dot, plain }

const _dayColors = [Color(0xFF5638E0), Color(0xFFA3245F), Color(0xFF0B6B78)];
const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

String _ymd(DateTime d) => '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
String _md(DateTime d) => '${d.month}.${d.day.toString().padLeft(2, '0')}';
String _hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// 모눈종이 여행 노트 한 장의 바탕: 종이·길·시간·장소 이름만 그린다.
/// 스티커는 유저가 붙이며 `TripCardEditor`가 이 위에 올린다. 크기는 [pageSize]로 고정(카드 좌표).
class TripNoteView extends StatelessWidget {
  const TripNoteView({
    super.key,
    required this.trip,
    required this.page,
    this.paper = PaperStyle.grid,
  });

  final Trip trip;
  final TripCardPage page;
  final PaperStyle paper;

  static const config = TripCardLayoutConfig();

  static TripCardLayout layoutOf(TripCardPage page) => layoutTripCard(page.checkIns.length, config: config);

  static Size pageSize(TripCardPage page) => Size(config.pageWidth, layoutOf(page).pageHeight);

  @override
  Widget build(BuildContext context) {
    final checkIns = page.checkIns;
    final layout = layoutOf(page);
    return Semantics(
      label: '${_title()} 여행 노트: ${checkIns.map((c) => '${_hm(c.at)} ${c.placeName}').join(', ')}',
      child: CustomPaint(
        size: Size(config.pageWidth, layout.pageHeight),
        painter: _TripNotePainter(
          trip: trip,
          page: page,
          layout: layout,
          paper: paper,
          title: _title(),
          subtitle: _subtitle(),
        ),
      ),
    );
  }

  bool get _isDayPage => page.isSingleDay && trip.days.length > 1;

  String _title() {
    final city = trip.cityName.replaceAll(RegExp(r'(시|군|구)$'), '');
    return _isDayPage ? '$city ${page.days.first.label}' : trip.title;
  }

  String _subtitle() {
    if (page.days.isEmpty) return _ymd(trip.startDate);
    if (_isDayPage || trip.days.length == 1) {
      final d = page.days.first.date;
      final suffix = trip.days.length == 1 ? ' · 당일 여행' : '';
      return '${_ymd(d)} (${_weekdays[d.weekday - 1]})$suffix';
    }
    return '${_ymd(page.days.first.date)} – ${_md(page.days.last.date)} · ${trip.lengthLabel}';
  }
}

class _TripNotePainter extends CustomPainter {
  _TripNotePainter({
    required this.trip,
    required this.page,
    required this.layout,
    required this.paper,
    required this.title,
    required this.subtitle,
  });

  final Trip trip;
  final TripCardPage page;
  final TripCardLayout layout;
  final PaperStyle paper;
  final String title;
  final String subtitle;

  @override
  void paint(Canvas canvas, Size size) {
    _paper(canvas, size);
    _tape(canvas, size);
    _text(canvas, title, const Offset(52, 24), 42, AppColors.mapLabel, font: AppFonts.handwriting);
    _text(canvas, subtitle, const Offset(54, 68), 20, AppColors.textSecondary, font: AppFonts.handwriting);
    drawDoodle(canvas, PlaceType.nature, const Offset(-2, 20));

    _road(canvas);

    final checkIns = page.checkIns;
    final multiDay = page.days.length > 1;
    final firstOfDay = <String>{for (final d in page.days) if (d.checkIns.isNotEmpty) d.checkIns.first.id};
    final dayOf = <String, int>{for (final d in page.days) for (final c in d.checkIns) c.id: d.index};

    for (final slot in layout.stops) {
      final c = checkIns[slot.index];
      final color = _dayColors[(dayOf[c.id] ?? 0) % _dayColors.length];
      final dir = slot.labelAbove ? -1.0 : 1.0;
      // 길을 가로지르는 눈금 + 이름 쪽으로 조금 더 나온 꼬리
      canvas.drawLine(
        Offset(slot.x, slot.y - 11 * dir),
        Offset(slot.x, slot.y + 17 * dir),
        Paint()
          ..color = color
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
      final time = multiDay && firstOfDay.contains(c.id) ? '${(dayOf[c.id] ?? 0) + 1}일차 ${_hm(c.at)}' : _hm(c.at);
      final timeTp = _layoutText(time, 10, color, weight: FontWeight.w700);
      final nameTp = _layoutPlaceName(c.placeName, layout.labelMaxWidth);
      if (slot.labelAbove) {
        // 위쪽: [시간] [이름] [눈금] 순서로 아래에서 위로 쌓는다.
        final nameTop = slot.y - 20 - nameTp.height;
        nameTp.paint(canvas, Offset(slot.x - nameTp.width / 2, nameTop));
        timeTp.paint(canvas, Offset(slot.x - timeTp.width / 2, nameTop - timeTp.height - 1));
      } else {
        // 아래쪽: [눈금] [시간] [이름]
        timeTp.paint(canvas, Offset(slot.x - timeTp.width / 2, slot.y + 20));
        nameTp.paint(canvas, Offset(slot.x - nameTp.width / 2, slot.y + 20 + timeTp.height + 1));
      }
    }

    _startPin(canvas);
    _endFlag(canvas);
    _footer(canvas, size, checkIns.length);
  }

  void _paper(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    canvas.drawRRect(rrect, Paint()..color = Colors.white);
    canvas.save();
    canvas.clipRRect(rrect);
    final p = Paint()..color = AppColors.paperGrid;
    const step = 14.0;
    switch (paper) {
      case PaperStyle.grid:
        p.strokeWidth = 1;
        for (var x = 0.0; x <= size.width; x += step) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
        }
        for (var y = 0.0; y <= size.height; y += step) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
        }
      case PaperStyle.dot:
        p.color = const Color(0xFFD6DBE8);
        for (var x = step / 2; x <= size.width; x += step) {
          for (var y = step / 2; y <= size.height; y += step) {
            canvas.drawCircle(Offset(x, y), 1.2, p);
          }
        }
      case PaperStyle.plain:
        break;
    }
    canvas.restore();
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = AppColors.border
        ..style = PaintingStyle.stroke,
    );
  }

  void _tape(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, 2);
    canvas.rotate(-0.05);
    canvas.drawRect(const Rect.fromLTWH(-55, -12, 110, 24), Paint()..color = const Color(0xBFC4B6FF));
    canvas.restore();
  }

  void _road(Canvas canvas) {
    final path = Path();
    for (final s in layout.road) {
      switch (s) {
        case RoadMove(:final x, :final y):
          path.moveTo(x, y);
        case RoadLine(:final x, :final y):
          path.lineTo(x, y);
        case RoadArc(:final x, :final y, :final radius, :final clockwise):
          path.arcToPoint(Offset(x, y), radius: Radius.circular(radius), clockwise: clockwise);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.road
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    // 가운데 흰 점선
    final dash = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 13) {
        canvas.drawPath(metric.extractPath(d, d + 6), dash);
      }
    }
  }

  void _startPin(Canvas canvas) {
    final c = Offset(layout.startX, layout.startY - 20);
    final pin = Path()
      ..moveTo(c.dx, c.dy + 16)
      ..cubicTo(c.dx - 7, c.dy + 8, c.dx - 10, c.dy + 4, c.dx - 10, c.dy)
      ..arcToPoint(Offset(c.dx + 10, c.dy), radius: const Radius.circular(10))
      ..cubicTo(c.dx + 10, c.dy + 4, c.dx + 7, c.dy + 8, c.dx, c.dy + 16)
      ..close();
    canvas
      ..drawPath(pin, Paint()..color = AppColors.secondary)
      ..drawPath(
        pin,
        Paint()
          ..color = AppColors.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      )
      ..drawCircle(c, 3.5, Paint()..color = Colors.white);
    final label = page.isSingleDay && trip.days.length > 1 && page.days.first.index > 0 ? '숙소 출발' : '출발';
    _text(canvas, label, Offset(layout.startX + 12, layout.startY - 52), 19, const Color(0xFFA3245F), font: AppFonts.handwriting);
  }

  void _endFlag(Canvas canvas) {
    final x = layout.endX;
    final y = layout.endY;
    canvas.drawLine(Offset(x, y), Offset(x, y - 34), Paint()
      ..color = AppColors.ink
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round);
    final flag = Path()
      ..moveTo(x, y - 33)
      ..lineTo(x + (layout.endsOnRight ? -20 : 20), y - 26)
      ..lineTo(x, y - 19)
      ..close();
    canvas
      ..drawPath(flag, Paint()..color = AppColors.primary)
      ..drawPath(
        flag,
        Paint()
          ..color = AppColors.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeJoin = StrokeJoin.round,
      );
  }

  void _footer(Canvas canvas, Size size, int count) {
    final y = size.height - 44;
    final dash = Paint()
      ..color = const Color(0xFFC9C3DD)
      ..strokeWidth = 1.5;
    for (var x = 16.0; x < size.width - 16; x += 8) {
      canvas.drawLine(Offset(x, y), Offset(x + 4, y), dash);
    }
    final days = page.days.length;
    final text = days > 1 ? '다녀온 곳 $count곳 · $days일 동안' : '다녀온 곳 $count곳';
    _text(canvas, text, Offset(16, y + 10), 20, AppColors.mapLabel, font: AppFonts.handwriting);
  }

  /// 장소 이름: 띄어쓰기 단위로 최대 2줄([wrapByWords]). 안 들어가면 15px → 12px까지 줄이고,
  /// 그래도 안 되면(띄어쓰기 없는 아주 긴 이름) 2줄 말줄임(…).
  TextPainter _layoutPlaceName(String text, double maxWidth) {
    TextPainter make(String t, double size, {TextAlign align = TextAlign.center, bool clip = false}) => TextPainter(
          text: TextSpan(
            text: t,
            style: TextStyle(fontFamily: AppFonts.handwriting, fontSize: size, height: 1.05, color: AppColors.mapLabel),
          ),
          textAlign: align,
          textDirection: TextDirection.ltr,
          maxLines: clip ? 2 : null,
          ellipsis: clip ? '…' : null,
        );
    for (var size = 15.0; size >= 12; size -= 1) {
      final lines = wrapByWords(text, maxWidth, (line) => (make(line, size, align: TextAlign.left)..layout()).width);
      if (lines != null) return make(lines.join('\n'), size)..layout(maxWidth: maxWidth + 1);
    }
    return make(text, 12, clip: true)..layout(maxWidth: maxWidth);
  }

  TextPainter _layoutText(String text, double size, Color color, {FontWeight weight = FontWeight.w400}) =>
      TextPainter(
        text: TextSpan(text: text, style: TextStyle(fontSize: size, height: 1.1, color: color, fontWeight: weight)),
        textDirection: TextDirection.ltr,
      )..layout();

  void _text(
    Canvas canvas,
    String text,
    Offset at,
    double size,
    Color color, {
    bool center = false,
    String? font,
    FontWeight weight = FontWeight.w400,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontFamily: font, fontSize: size, height: 1.1, color: color, fontWeight: weight),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center ? at - Offset(tp.width / 2, 0) : at);
  }

  @override
  bool shouldRepaint(covariant _TripNotePainter old) =>
      old.page != page || old.paper != paper || old.trip != trip || old.title != title;
}
