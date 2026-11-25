import 'package:flutter/material.dart';

import '../../core/pickle/pickle_models.dart';
import '../../core/theme/app_theme.dart';
import 'splash_character.dart';

/// 픽클 친구 종류 → 얼굴 그림(스플래시와 같은 그림).
SplashCharacter characterOfSpecies(PickleSpecies species) => switch (species) {
      PickleSpecies.duck => SplashCharacter.pickle,
      PickleSpecies.otter => SplashCharacter.bori,
      PickleSpecies.rabbit => SplashCharacter.tori,
      PickleSpecies.fox => SplashCharacter.moa,
      PickleSpecies.owl => SplashCharacter.yieldy,
      PickleSpecies.droplet => SplashCharacter.rhythmi,
    };

/// 흰 동그라미 안에 픽클 친구 얼굴. 친구를 모르면(픽클 로그인 전) 픽클이.
/// 그림 파일이 없으면(공개 저장소엔 없다) 이름 첫 글자로 대신 그린다.
class PickleFaceAvatar extends StatelessWidget {
  const PickleFaceAvatar({super.key, this.friend, this.size = 48});

  final PickleFriend? friend;
  final double size;

  @override
  Widget build(BuildContext context) {
    final f = friend;
    final c = f == null ? SplashCharacter.pickle : characterOfSpecies(f.species);
    final name = f?.name ?? c.label;
    return Tooltip(
      message: f == null ? '픽클 친구' : '${f.name} · ${f.stage.label}',
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Color(0x1F4A35C8), blurRadius: 16, offset: Offset(0, 6))],
        ),
        child: Padding(
          padding: EdgeInsets.only(top: size * 0.1),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Image.asset(
              c.asset,
              height: size * 0.9,
              fit: BoxFit.contain,
              semanticLabel: '$name 얼굴',
              errorBuilder: (_, _, _) => SizedBox.expand(
                child: Center(
                  child: Text(
                    name.characters.first,
                    style: TextStyle(fontFamily: AppFonts.title, fontSize: size * 0.42, color: AppColors.primaryDeep),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
