import 'package:flutter/painting.dart';

import '../../core/theme/app_theme.dart';
import '../trip/trip_models.dart';

/// 장소 종류별 손그림 아이콘(기본 56×42 상자, [scale]로 줄인다). 선은 잉크색, 면은 파스텔.
const doodleSize = Size(56, 42);

void drawDoodle(Canvas canvas, PlaceType type, Offset topLeft, {double scale = 1}) {
  canvas.save();
  canvas.translate(topLeft.dx, topLeft.dy);
  if (scale != 1) canvas.scale(scale);
  switch (type) {
    case PlaceType.beach:
      _beach(canvas);
    case PlaceType.cafe:
      _cafe(canvas);
    case PlaceType.heritage:
      _heritage(canvas);
    case PlaceType.market:
      _market(canvas);
    case PlaceType.food:
      _food(canvas);
    case PlaceType.seafood:
      _seafood(canvas);
    case PlaceType.nature:
      _nature(canvas);
    case PlaceType.lodging:
      _heritage(canvas);
    case PlaceType.other:
      _star(canvas);
  }
  canvas.restore();
}

const _sky = Color(0xFF6FA7C7);
const _steam = Color(0xFFB9A6E8);
const _wood = Color(0xFFC9935B);
const _leaf = Color(0xFF9ED4A0);

Paint _fill(Color c) => Paint()..color = c;

Paint _line([double w = 1.6, Color c = AppColors.ink]) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

void _shape(Canvas canvas, Path p, Color fill, [double w = 1.6]) {
  canvas.drawPath(p, _fill(fill));
  canvas.drawPath(p, _line(w));
}

void _waves(Canvas canvas, double x, double y, int count) {
  final p = Path()..moveTo(x, y);
  for (var i = 0; i < count; i++) {
    final sx = x + i * 10;
    p
      ..quadraticBezierTo(sx + 2.5, y - 4, sx + 5, y)
      ..quadraticBezierTo(sx + 7.5, y + 4, sx + 10, y);
  }
  canvas.drawPath(p, _line(2, _sky));
}

void _steamLines(Canvas canvas, List<double> xs, double y) {
  for (final x in xs) {
    final p = Path()
      ..moveTo(x, y)
      ..quadraticBezierTo(x - 2, y - 3, x, y - 6);
    canvas.drawPath(p, _line(1.6, _steam));
  }
}

void _beach(Canvas canvas) {
  final umbrella = Path()
    ..moveTo(9, 20)
    ..quadraticBezierTo(28, 0, 47, 20)
    ..close();
  _shape(canvas, umbrella, const Color(0xFFFFD3E2));
  final stripe = Path()
    ..moveTo(21, 20)
    ..quadraticBezierTo(24, 9, 28, 6)
    ..quadraticBezierTo(32, 9, 35, 20);
  _shape(canvas, stripe, const Color(0xFFFFFFFF), 1.2);
  canvas.drawLine(const Offset(28, 20), const Offset(28, 35), _line());
  _waves(canvas, 4, 39, 5);
}

void _cafe(Canvas canvas) {
  _steamLines(canvas, const [22, 28], 11);
  final cup = Path()
    ..moveTo(16, 16)
    ..lineTo(36, 16)
    ..lineTo(36, 26)
    ..arcToPoint(const Offset(28, 34), radius: const Radius.circular(8))
    ..lineTo(24, 34)
    ..arcToPoint(const Offset(16, 26), radius: const Radius.circular(8))
    ..close();
  _shape(canvas, cup, const Color(0xFFF1DFC8));
  final handle = Path()
    ..moveTo(36, 19)
    ..lineTo(39, 19)
    ..arcToPoint(const Offset(39, 27), radius: const Radius.circular(4))
    ..lineTo(36, 27);
  canvas.drawPath(handle, _line());
  canvas.drawLine(const Offset(12, 38), const Offset(42, 38), _line());
}

void _heritage(Canvas canvas) {
  final roof = Path()
    ..moveTo(4, 16)
    ..quadraticBezierTo(14, 18, 27, 8)
    ..quadraticBezierTo(40, 18, 50, 16)
    ..lineTo(46, 20)
    ..lineTo(8, 20)
    ..close();
  _shape(canvas, roof, const Color(0xFF6B6880), 1.4);
  _shape(canvas, Path()..addRect(const Rect.fromLTWH(12, 20, 30, 16)), const Color(0xFFFFF6E3), 1.4);
  _shape(canvas, Path()..addRect(const Rect.fromLTWH(23, 25, 8, 11)), const Color(0xFFE9C9A0), 1.2);
  canvas
    ..drawLine(const Offset(48, 38), const Offset(48, 12), _line(2.2))
    ..drawLine(const Offset(52, 38), const Offset(52, 18), _line(2.2))
    ..drawLine(const Offset(48, 16), const Offset(53, 13), _line(2, const Color(0xFF7FB77E)))
    ..drawLine(const Offset(52, 22), const Offset(55, 19), _line(2, const Color(0xFF7FB77E)))
    ..drawLine(const Offset(2, 38), const Offset(54, 38), _line(1.4));
}

void _market(Canvas canvas) {
  canvas
    ..drawLine(const Offset(12, 18), const Offset(12, 37), _line(1.4))
    ..drawLine(const Offset(44, 18), const Offset(44, 37), _line(1.4));
  final awning = Path()
    ..moveTo(9, 10)
    ..lineTo(47, 10)
    ..lineTo(47, 16);
  for (var i = 0; i < 5; i++) {
    final x = 47 - i * 7.6;
    awning.quadraticBezierTo(x - 3.8, 20, x - 7.6, 16);
  }
  awning.close();
  _shape(canvas, awning, const Color(0xFFFFB4B4), 1.4);
  for (final x in const [21.0, 28.0, 35.0]) {
    canvas
      ..drawCircle(Offset(x, 24), 3, _fill(const Color(0xFFE8A15C)))
      ..drawCircle(Offset(x, 24), 3, _line(1));
  }
  _shape(
    canvas,
    Path()..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(12, 27, 32, 10), const Radius.circular(2))),
    const Color(0xFFFFE7A8),
    1.4,
  );
}

void _food(Canvas canvas) {
  _steamLines(canvas, const [22, 31], 9);
  _shape(canvas, Path()..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(19, 13, 9, 7), const Radius.circular(1.5))), const Color(0xFFFFFFFF), 1.2);
  _shape(canvas, Path()..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(27, 14, 9, 6), const Radius.circular(1.5))), const Color(0xFFFFFFFF), 1.2);
  final bowl = Path()
    ..moveTo(11, 19)
    ..lineTo(45, 19)
    ..cubicTo(45, 29, 38, 35, 28, 35)
    ..cubicTo(18, 35, 11, 29, 11, 19)
    ..close();
  _shape(canvas, bowl, const Color(0xFFCFE3FF));
  canvas
    ..drawLine(const Offset(40, 6), const Offset(48, 30), _line(1.6, _wood))
    ..drawLine(const Offset(44, 5), const Offset(50, 29), _line(1.6, _wood));
}

void _seafood(Canvas canvas) {
  final tail = Path()
    ..moveTo(37, 20)
    ..lineTo(47, 12)
    ..lineTo(45, 20)
    ..lineTo(47, 28)
    ..close();
  _shape(canvas, tail, const Color(0xFFFFC9AE));
  final body = Path()
    ..moveTo(9, 20)
    ..quadraticBezierTo(22, 8, 37, 20)
    ..quadraticBezierTo(22, 32, 9, 20)
    ..close();
  _shape(canvas, body, const Color(0xFF9FD0F0));
  canvas.drawCircle(const Offset(16, 18), 1.6, _fill(AppColors.ink));
  final gill = Path()
    ..moveTo(21, 15)
    ..quadraticBezierTo(24, 20, 21, 25);
  canvas.drawPath(gill, _line(1.2));
  _waves(canvas, 6, 38, 4);
}

void _nature(Canvas canvas) {
  Path tree(double cx, double top, double w) => Path()
    ..moveTo(cx, top)
    ..lineTo(cx + w * 0.55, top + 13)
    ..lineTo(cx - w * 0.55, top + 13)
    ..close()
    ..moveTo(cx, top + 7)
    ..lineTo(cx + w * 0.75, top + 23)
    ..lineTo(cx - w * 0.75, top + 23)
    ..close();
  _shape(canvas, tree(18, 4, 16), _leaf, 1.5);
  _shape(canvas, Path()..addRect(const Rect.fromLTWH(16, 27, 4, 8)), _wood, 1.2);
  _shape(canvas, tree(38, 12, 14), const Color(0xFF7FC48A), 1.5);
  _shape(canvas, Path()..addRect(const Rect.fromLTWH(36, 35, 4, 3)), _wood, 1.2);
  canvas.drawLine(const Offset(3, 38), const Offset(53, 38), _line(1.4));
}

void _star(Canvas canvas) {
  final p = Path();
  const c = Offset(28, 20);
  for (var i = 0; i < 10; i++) {
    final r = i.isEven ? 14.0 : 6.0;
    final a = -1.5708 + i * 0.6283;
    final pt = c + Offset.fromDirection(a, r);
    if (i == 0) {
      p.moveTo(pt.dx, pt.dy);
    } else {
      p.lineTo(pt.dx, pt.dy);
    }
  }
  p.close();
  _shape(canvas, p, const Color(0xFFFFE7A8));
}
