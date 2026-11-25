import 'package:flutter_test/flutter_test.dart';
import 'package:where_to_go_pick/core/pickle/pickle_models.dart';
import 'package:where_to_go_pick/features/splash/pickle_face_avatar.dart';
import 'package:where_to_go_pick/features/splash/splash_character.dart';

void main() {
  test('픽클 친구 종류마다 얼굴 그림이 하나씩, 이름도 같다', () {
    final faces = {for (final s in PickleSpecies.values) s: characterOfSpecies(s)};
    expect(faces.values.toSet(), SplashCharacter.values.toSet(), reason: '6종 모두 다른 그림');
    for (final e in faces.entries) {
      expect(e.value.label, e.key.familyName, reason: '${e.key} 이름');
    }
  });
}
