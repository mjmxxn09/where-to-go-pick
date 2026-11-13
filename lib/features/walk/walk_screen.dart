import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 5 · 동네 산책(2차 범위). 여행이 없는 날에도 앱을 열 이유를 만드는 기능.
/// 위치 기록은 위치기반서비스사업 신고와 보호조치가 끝난 뒤에 붙인다(docs/launch-checklist.md).
class WalkScreen extends StatelessWidget {
  const WalkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(Gap.m),
      children: [
        const Text('동네 산책', style: TextStyle(fontFamily: AppFonts.title, fontSize: 24)),
        const SizedBox(height: Gap.m),
        Container(
          padding: const EdgeInsets.all(Gap.m),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('준비 중이에요', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              SizedBox(height: Gap.s),
              Text('산책을 켜면 걸은 길과 거리를 기록하고, 이번 주 걸음을 모아 보여 줄 거예요. '
                  '위치는 켜 둔 동안에만 쓰고, 끄면 바로 멈춰요.'),
            ],
          ),
        ),
      ],
    );
  }
}
