import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:where_to_go_pick/features/korea_map/svg_path.dart';

void main() {
  test('M/L/Z 절대좌표와 음수를 읽는다', () {
    final cmds = parseSvgPathCommands('M10.5 -2.0L20 30L-5.25 4ZM1 2L3 4Z');
    expect(cmds, hasLength(7));
    expect(cmds[0], isA<MoveTo>().having((c) => c.y, 'y', -2.0));
    expect(cmds[2], isA<LineTo>().having((c) => c.x, 'x', -5.25));
    expect(cmds[3], isA<ClosePath>());
    expect(cmds[4], isA<MoveTo>());
  });

  test('M 뒤에 이어지는 좌표는 LineTo로 본다', () {
    final cmds = parseSvgPathCommands('M0 0 10 10 20 0Z');
    expect(cmds.whereType<LineTo>(), hasLength(2));
  });

  test('Flutter Path로 바꾸면 내부 점을 포함한다', () {
    final path = pathFromSvg('M0 0L10 0L10 10L0 10Z');
    expect(path.contains(const Offset(5, 5)), isTrue);
    expect(path.contains(const Offset(15, 5)), isFalse);
  });
}
