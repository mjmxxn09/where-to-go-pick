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
    this.stopEdits = const {},
  });

  final Trip trip;
  final TripCardPage page;
  final PaperStyle paper;

  /// 유저가 옮긴 장소 막대(체크인 id → 편집).
  final Map<String, StopEdit> stopEdits;

  static const config = TripCardLayoutConfig();

  static TripCardLayout layoutOf(TripCardPage page) => layoutTripCard(page.checkIns.length, config: config);

  static Size pageSize(TripCardPage page) => Size(config.pageWidth, layoutOf(page).pageHeight);

  /// 장소마다 길 위 자리(옮긴 것 반영)와 이름표(시간+이름)가 차지하는 칸.
  /// "자동으로 꾸미기"가 스티커로 이름을 덮지 않게 쓴다. 그리는 것과 같은 글자 크기로 잰다.
  static List<({String id, StopSlot slot, Rect label})> stopBoxes(TripCardPage page, Map<String, StopEdit> stopEdits) {
    final layout = layoutOf(page);
    final checkIns = page.checkIns;
    return [
      for (final base in layout.stops)
        if (base.index < checkIns.length)
          () {
            final c = checkIns[base.index];
            final slot = applyStopEdit(base, stopEdits[c.id], layout.rows, config: config);
            final (time: time, name: name) = _stopLabel(page, c, layout.labelMaxWidth, _dayColors.first);
            return (id: c.id, slot: slot, label: _labelRect(slot, time, name));
          }(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final checkIns = page.checkIns;
    final layout = layoutOf(page);
    final paint = CustomPaint(
      size: Size(config.pageWidth, layout.pageHeight),
      painter: _TripNotePainter(
        trip: trip,
        page: page,
        layout: layout,
        paper: paper,
        title: _title(),
        subtitle: _subtitle(),
        stopEdits: stopEdits,
      ),
    );
    return Semantics(
      label: '${_title()} 여행 노트: ${checkIns.map((c) => '${_hm(c.at)} ${c.placeName}').join(', ')}',
      // 하루 장인데 체크인이 없는 날: 빈 길 위에 안내 한 줄(저장할 때는 빈 날을 뺀다).
      child: checkIns.isEmpty && _isDayPage
          ? Stack(
              children: [
                paint,
                Positioned(
                  left: 0,
                  right: 0,
                  top: config.firstRowY + 34,
                  child: const Text(
                    '이날은 아직 체크인이 없어요',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF8A86A3)),
                  ),
                ),
              ],
            )
          : paint,
    );
  }

  bool get _isDayPage => page.dayPage;

  String _title() {
    final city = trip.placeLabel;
    return _isDayPage ? '$city ${page.days.first.label}' : trip.title;
  }

  String _subtitle() {
    // 하루 장: 그날 날짜. 한 장에 모아보기: 정한 기간(2박 3일이면 3일 전체, 체크인이 더 길면 그만큼).
    if (_isDayPage) {
      final d = page.days.first.date;
      return '${_ymd(d)} (${_weekdays[d.weekday - 1]})';
    }
    final start = dateOnly(trip.startDate);
    if (trip.totalDays <= 1) return '${_ymd(start)} (${_weekdays[start.weekday - 1]}) · 당일 여행';
    return '${_ymd(start)} – ${_md(trip.lastDate)} · ${lengthLabelOf(trip.totalDays)}';
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
    required this.stopEdits,
  });

  final Map<String, StopEdit> stopEdits;
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
    _text(canvas, title, const Offset(52, 26), 29, AppColors.mapLabel, font: AppFonts.handwriting);
    _text(canvas, subtitle, const Offset(54, 67), 15, AppColors.textSecondary, font: AppFonts.handwriting);
    drawDoodle(canvas, PlaceType.nature, const Offset(-2, 20));

    _road(canvas);

    final checkIns = page.checkIns;
    final dayOf = <String, int>{for (final d in page.days) for (final c in d.checkIns) c.id: d.index};

    for (final base in layout.stops) {
      final c = checkIns[base.index];
      final slot = applyStopEdit(base, stopEdits[c.id], layout.rows, config: TripNoteView.config);
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
      final (time: timeTp, name: nameTp) = _stopLabel(page, c, layout.labelMaxWidth, color);
      final (time: timeAt, name: nameAt) = _labelOffsets(slot, timeTp, nameTp);
      timeTp.paint(canvas, timeAt);
      nameTp.paint(canvas, nameAt);
    }

    _startPin(canvas);
    _endFlag(canvas);
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
      old.page != page || old.paper != paper || old.trip != trip || old.title != title || old.stopEdits != stopEdits;
}

/// 장소 하나의 이름표 글자: 시간(여러 날 카드면 그날 첫 장소에 "N일차") + 이름.
({TextPainter time, TextPainter name}) _stopLabel(TripCardPage page, CheckIn c, double labelMaxWidth, Color color) {
  final day = page.days.where((d) => d.checkIns.any((x) => x.id == c.id)).firstOrNull;
  final time = page.days.length > 1 && day != null && day.checkIns.first.id == c.id
      ? '${day.index + 1}일차 ${_hm(c.at)}'
      : _hm(c.at);
  return (
    time: _layoutText(time, 10, color, weight: FontWeight.w700),
    name: _layoutPlaceName(c.placeName, labelMaxWidth),
  );
}

/// 위쪽 이름표는 [시간][이름][눈금] 순서로 아래에서 위로, 아래쪽은 [눈금][시간][이름].
({Offset time, Offset name}) _labelOffsets(StopSlot slot, TextPainter time, TextPainter name) {
  if (slot.labelAbove) {
    final nameTop = slot.y - 20 - name.height;
    return (
      time: Offset(slot.x - time.width / 2, nameTop - time.height - 1),
      name: Offset(slot.x - name.width / 2, nameTop),
    );
  }
  return (
    time: Offset(slot.x - time.width / 2, slot.y + 20),
    name: Offset(slot.x - name.width / 2, slot.y + 20 + time.height + 1),
  );
}

Rect _labelRect(StopSlot slot, TextPainter time, TextPainter name) {
  final (time: t, name: n) = _labelOffsets(slot, time, name);
  return (t & time.size).expandToInclude(n & name.size);
}

/// 장소 이름: 띄어쓰기 단위로 최대 2줄([wrapByWords]). 안 들어가면 13px → 11px까지 줄이고,
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
  for (var size = 13.0; size >= 11; size -= 1) {
    final lines = wrapByWords(text, maxWidth, (line) => (make(line, size, align: TextAlign.left)..layout()).width);
    if (lines != null) return make(lines.join('\n'), size)..layout(maxWidth: maxWidth + 1);
  }
  return make(text, 11, clip: true)..layout(maxWidth: maxWidth);
}

TextPainter _layoutText(String text, double size, Color color, {FontWeight weight = FontWeight.w400}) =>
    TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: size, height: 1.1, color: color, fontWeight: weight)),
      textDirection: TextDirection.ltr,
    )..layout();
