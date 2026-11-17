import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../splash/splash_character.dart';

/// 체크인 직후 픽클이가 말풍선으로 하나 묻는다: "방금 간 곳 vs 그 전에 간 곳, 어디가 더 좋았어?"
/// 고른 답은 픽클의 "다녀온 사람 표"가 된다. 답하면 고맙다는 말과 받은 포인트를 보여 준다.
class PickleAskBubble extends StatelessWidget {
  const PickleAskBubble({
    super.key,
    required this.justVisited,
    required this.other,
    required this.onPick,
    required this.onClose,
    this.picked,
    this.points,
  });

  /// 방금 체크인한 곳 이름.
  final String justVisited;

  /// 그 전에 체크인한 곳 이름.
  final String other;

  /// true면 [justVisited], false면 [other]를 골랐다.
  final ValueChanged<bool> onPick;
  final VoidCallback onClose;

  /// 고른 곳 이름. null이면 아직 묻는 중.
  final String? picked;

  /// 받은 픽클 포인트(0이면 표시하지 않음).
  final int? points;

  @override
  Widget build(BuildContext context) {
    final asking = picked == null;
    return Semantics(
      container: true,
      label: '픽클이의 질문',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Transform.translate(
            offset: const Offset(0, 10),
            child: Image.asset(
              SplashCharacter.pickle.asset,
              width: 72,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => const CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primaryContainer,
                child: Text('픽', style: TextStyle(fontFamily: AppFonts.title, fontSize: 22, color: AppColors.primaryDeep)),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: CustomPaint(
              painter: const _TailPainter(),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [BoxShadow(color: Color(0x382F4A85), blurRadius: 34, offset: Offset(0, 14))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('픽클이 · 방금 $justVisited 체크인!',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    if (asking) ..._question(context) else ..._thanks(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _question(BuildContext context) => [
        Text('${withRang(justVisited)} $other, 어디가 더 좋았어?',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, height: 1.3)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _Choice(label: justVisited, onTap: () => onPick(true))),
            const SizedBox(width: 6),
            Expanded(child: _Choice(label: other, onTap: () => onPick(false))),
          ],
        ),
        Row(
          children: [
            const Expanded(
              child: Text("답은 '다녀온 사람 표'로 픽클에 모여요",
                  style: TextStyle(fontSize: 11, color: AppColors.muted)),
            ),
            TextButton(
              onPressed: onClose,
              style: TextButton.styleFrom(foregroundColor: AppColors.muted, visualDensity: VisualDensity.compact),
              child: const Text('다음에', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ];

  List<Widget> _thanks() => [
        Text('고마워! $picked에 한 표 넣었어', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, height: 1.3)),
        const SizedBox(height: 4),
        const Text('다음 여행자 추천에 쓰이고, 픽클 잠금화면에도 이 질문이 떠요',
            style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Row(
          children: [
            if ((points ?? 0) > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFFFF4D6), borderRadius: BorderRadius.circular(99)),
                child: Text('+${points}P 픽클 포인트',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF8A5A00))),
              ),
            const Spacer(),
            FilledButton(
              onPressed: onClose,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 18),
              ),
              child: const Text('좋아'),
            ),
          ],
        ),
      ];
}

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFFF1ECFF),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, height: 1.2, color: AppColors.primaryDeep),
                ),
              ),
            ),
          ),
        ),
      );
}

/// 말풍선 왼쪽 아래 꼬리(캐릭터 쪽).
class _TailPainter extends CustomPainter {
  const _TailPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height - 34;
    final path = Path()
      ..moveTo(1, y)
      ..lineTo(-8, y + 9)
      ..lineTo(1, y + 16)
      ..close();
    canvas.drawPath(path, Paint()..color = AppColors.surface);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// "경포해변" → "경포해변이랑", "안목 커피거리" → "안목 커피거리랑" (받침 있으면 '이랑').
String withRang(String word) {
  if (word.isEmpty) return word;
  final c = word.codeUnitAt(word.length - 1) - 0xAC00;
  final hasBatchim = c >= 0 && c <= 11171 && c % 28 != 0;
  return '$word${hasBatchim ? '이랑' : '랑'}';
}
