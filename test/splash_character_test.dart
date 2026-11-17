import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:where_to_go_pick/features/splash/splash_character.dart';

void main() {
  test('6명 모두 이미지 경로와 크기가 있다', () {
    expect(SplashCharacter.values.length, 6);
    for (final c in SplashCharacter.values) {
      expect(c.asset, 'assets/characters/splash/face_${c.name}.png');
      expect(c.width, greaterThan(100));
      expect(c.height, greaterThan(100));
      expect(c.faceCenter, inInclusiveRange(0.3, 0.7));
    }
  });

  test('바로 전 친구는 다시 고르지 않는다', () {
    final random = math.Random(7);
    for (final last in SplashCharacter.values) {
      for (var i = 0; i < 30; i++) {
        expect(pickSplashCharacter(last: last, random: random), isNot(last));
      }
    }
  });

  test('여러 번 실행하면 여러 친구가 나오고, 연달아 같은 친구는 없다', () async {
    SharedPreferences.setMockInitialValues({});
    final picker = SplashCharacterPicker(random: math.Random(1));
    final seen = <SplashCharacter>[];
    for (var i = 0; i < 40; i++) {
      seen.add(await picker.next());
    }
    for (var i = 1; i < seen.length; i++) {
      expect(seen[i], isNot(seen[i - 1]));
    }
    expect(seen.toSet().length, 6);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(SplashCharacterPicker.prefsKey), seen.last.name);
  });

  test('캐릭터 폴더와 안내 문서가 있다(이미지 자체는 저장소에 없어도 된다)', () {
    expect(File('assets/characters/splash/README.md').existsSync(), isTrue);
  });
}
