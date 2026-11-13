import 'dart:ui';

/// 지도 데이터의 경로 문자열(`M x y L x y … Z`, 절대좌표만)을 다룬다.
/// 순수 Dart 단계([parseSvgPathCommands])와 Flutter [Path] 변환을 나눠 테스트하기 쉽게 했다.
sealed class PathCommand {
  const PathCommand();
}

class MoveTo extends PathCommand {
  const MoveTo(this.x, this.y);
  final double x;
  final double y;
}

class LineTo extends PathCommand {
  const LineTo(this.x, this.y);
  final double x;
  final double y;
}

class ClosePath extends PathCommand {
  const ClosePath();
}

final _token = RegExp(r'[MLZmlz]|-?\d+(?:\.\d+)?');

List<PathCommand> parseSvgPathCommands(String d) {
  final tokens = _token.allMatches(d).map((m) => m.group(0)!).toList();
  final out = <PathCommand>[];
  var cmd = 'M';
  var i = 0;
  while (i < tokens.length) {
    final t = tokens[i];
    if (t == 'Z' || t == 'z') {
      out.add(const ClosePath());
      i++;
      continue;
    }
    if (t == 'M' || t == 'L' || t == 'm' || t == 'l') {
      cmd = t.toUpperCase();
      i++;
      continue;
    }
    if (i + 1 >= tokens.length) break;
    final x = double.parse(tokens[i]);
    final y = double.parse(tokens[i + 1]);
    i += 2;
    if (cmd == 'M') {
      out.add(MoveTo(x, y));
      cmd = 'L'; // SVG 규칙: M 뒤에 이어지는 좌표는 L로 해석
    } else {
      out.add(LineTo(x, y));
    }
  }
  return out;
}

Path pathFromSvg(String d) {
  final path = Path();
  for (final c in parseSvgPathCommands(d)) {
    switch (c) {
      case MoveTo(:final x, :final y):
        path.moveTo(x, y);
      case LineTo(:final x, :final y):
        path.lineTo(x, y);
      case ClosePath():
        path.close();
    }
  }
  return path;
}
