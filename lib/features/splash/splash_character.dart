import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

/// 스플래시에 얼굴을 내미는 픽클 친구 6명.
///
/// 이미지(`assets/characters/splash/face_<key>.png`)는 픽클 회사 캐릭터라 공개 저장소에 올리지 않는다
/// (.gitignore). 파일이 없으면 화면은 이름 첫 글자가 들어간 동그라미로 대신 그린다.
/// 이미지 준비 방법: assets/characters/splash/README.md
///
/// 크기는 디자인 기준 화면(가로 390)에서의 값이다. 화면 폭에 비례해 키운다.
enum SplashCharacter {
  pickle('픽클이', width: 351, aspect: 261 / 323, hide: 29),
  bori('보리', width: 255, aspect: 192 / 222),
  moa('모아', width: 224, aspect: 222 / 206),
  tori('토리', width: 209, aspect: 284 / 207, hide: 22, ears: 0.3),
  yieldy('일디', width: 289, aspect: 245 / 306, hide: 18),
  rhythmi('리듬이', width: 177, aspect: 384 / 302);

  const SplashCharacter(this.label, {required this.width, required this.aspect, this.hide = 0, this.ears = 0});

  final String label;

  /// 기준 화면에서의 그림 폭.
  final double width;

  /// 높이 / 폭.
  final double aspect;

  /// 아래쪽 몸통을 로그인 창 뒤로 더 숨길 길이(기준 화면 px).
  final double hide;

  /// 그림 위쪽에서 귀가 차지하는 비율. 후광 가운데를 얼굴에 맞출 때 뺀다.
  final double ears;

  String get asset => 'assets/characters/splash/face_$name.png';

  double get height => width * aspect;

  /// 그림 위에서부터 얼굴 가운데까지 비율(후광 위치).
  double get faceCenter => ears + (1 - ears) * 0.42;
}

/// 6명 중 한 명을 무작위로 고른다. 바로 전에 보여 준 친구([last])는 뺀다.
SplashCharacter pickSplashCharacter({SplashCharacter? last, math.Random? random}) {
  final pool = SplashCharacter.values.where((c) => c != last).toList();
  return pool[(random ?? math.Random()).nextInt(pool.length)];
}

/// 실행할 때마다 다음 친구를 고르고, 고른 친구를 기기에 기억한다.
class SplashCharacterPicker {
  SplashCharacterPicker({math.Random? random}) : _random = random;

  static const prefsKey = 'splash.last';

  final math.Random? _random;

  Future<SplashCharacter> next() async {
    SharedPreferences? prefs;
    SplashCharacter? last;
    try {
      prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(prefsKey);
      for (final c in SplashCharacter.values) {
        if (c.name == saved) last = c;
      }
    } on Object {
      prefs = null; // 저장소를 못 열면 기억 없이 고른다.
    }
    final picked = pickSplashCharacter(last: last, random: _random);
    try {
      await prefs?.setString(prefsKey, picked.name);
    } on Object {
      // 기억하지 못해도 화면에는 지장 없다.
    }
    return picked;
  }
}
