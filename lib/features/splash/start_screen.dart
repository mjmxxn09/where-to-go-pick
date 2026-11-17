import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'splash_character.dart';

/// 0 · 시작: 스플래시 겸 로그인 화면(디자인 캔버스 "0 · 시작", 시안 B).
///
/// - 연보라 배경 + 모서리 색 번짐(분홍·하늘·보라)
/// - 픽클 친구 한 명이 로그인 창 위로 얼굴을 내밀고, 뒤에 흰 후광
/// - 머리 위 흰 말풍선 안에 "어디갈지 / PICK!"(블랙한산스)
/// - 로그인 창: 픽클 계정으로 시작하기 · 카카오로 시작하기
///
/// 디자인은 가로 390 기준이고 화면 폭에 비례해 키운다. [busy]면 버튼 대신 불러오는 표시만 둔다
/// (이미 로그인한 사용자가 잠깐 보는 스플래시).
class StartScreen extends StatelessWidget {
  const StartScreen({
    super.key,
    required this.character,
    this.onPickleLogin,
    this.onKakaoLogin,
    this.busy = false,
  });

  final SplashCharacter character;
  final VoidCallback? onPickleLogin;
  final VoidCallback? onKakaoLogin;
  final bool busy;

  static const navy = Color(0xFF2F4A85);
  static const kakaoYellow = Color(0xFFFEE500);

  /// 로그인 창 안쪽 높이(위 22 + 버튼 54 + 8 + 버튼 48 + 아래 28).
  static const _sheetContent = 160.0;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return Scaffold(
      body: LayoutBuilder(builder: (context, box) {
        final s = box.maxWidth / 390;
        final sheetTop = box.maxHeight - _sheetContent - padding.bottom;
        final c = character;
        final w = c.width * s;
        final h = c.height * s;
        final faceTop = sheetTop + 1 + c.hide * s - h;
        final headY = faceTop + h * c.faceCenter;
        final halo = math.max(w, h) * 1.6;
        // 말풍선은 어떤 친구든 같은 높이(기준 화면에서 로그인 창 위 518px)에서 시작한다.
        final bubbleTop = math.max(padding.top + 12, sheetTop - 518 * s);

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            const Positioned.fill(child: _Background()),
            Positioned(
              left: box.maxWidth / 2 - halo / 2,
              top: headY - halo / 2,
              width: halo,
              height: halo,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0xF2FFFFFF), Color(0x99FFFFFF), Color(0x00FFFFFF)],
                    stops: [0, 0.54, 1],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: bubbleTop,
              child: Center(child: _TitleBubble(scale: s)),
            ),
            Positioned(
              left: box.maxWidth / 2 - w / 2,
              top: faceTop,
              width: w,
              height: h,
              child: Image.asset(
                c.asset,
                fit: BoxFit.contain,
                semanticLabel: '${c.label} 얼굴',
                errorBuilder: (_, _, _) => _MissingFace(character: c),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: sheetTop,
              bottom: 0,
              child: _LoginSheet(
                busy: busy,
                onPickleLogin: onPickleLogin,
                onKakaoLogin: onKakaoLogin,
                bottomInset: padding.bottom,
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _Background extends StatelessWidget {
  const _Background();

  @override
  Widget build(BuildContext context) {
    Widget blob(Alignment at, double radius, Color color) => Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: at,
                radius: radius,
                colors: [color, color.withValues(alpha: 0)],
              ),
            ),
          ),
        );
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF8F5FF), Color(0xFFEEE8FF), Color(0xFFDDD3FF)],
                stops: [0, 0.42, 1],
              ),
            ),
          ),
        ),
        blob(const Alignment(-0.88, -0.76), 0.98, const Color(0xCCFFC4E6)),
        blob(const Alignment(1, -0.28), 0.82, const Color(0xE6BACEFF)),
        blob(const Alignment(-1, 0.52), 0.85, const Color(0xD9CEBAFF)),
      ],
    );
  }
}

/// 흰 말풍선 + 아래 가운데 꼬리 + "어디갈지 / PICK!".
class _TitleBubble extends StatelessWidget {
  const _TitleBubble({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    TextStyle style(double size) => TextStyle(
          fontFamily: AppFonts.logo,
          fontSize: size * scale,
          height: 1,
          letterSpacing: scale,
          color: StartScreen.navy,
        );
    return Semantics(
      header: true,
      label: '어디갈지 Pick!',
      child: ExcludeSemantics(
        child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.fromLTRB(30 * scale, 22 * scale, 30 * scale, 20 * scale),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(40 * scale),
                  boxShadow: const [BoxShadow(color: Color(0x294A35C8), blurRadius: 18, offset: Offset(0, 10))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('어디갈지', style: style(56)),
                    SizedBox(height: 4 * scale),
                    Text('PICK!', style: style(100)),
                  ],
                ),
              ),
              CustomPaint(size: Size(44 * scale, 22 * scale), painter: _TailPainter()),
            ],
          ),
      ),
    );
  }
}

class _TailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 44;
    final sy = size.height / 22;
    // 캔버스 시안과 같은 꼬리: 양옆에서 둥글게 모여 아래 가운데에서 끝난다.
    final path = Path()
      ..moveTo(0, -1)
      ..lineTo(44 * sx, -1)
      ..cubicTo(34 * sx, 4 * sy, 27 * sx, 12 * sy, 24 * sx, 21 * sy)
      ..quadraticBezierTo(22 * sx, 25 * sy, 20 * sx, 21 * sy)
      ..cubicTo(17 * sx, 12 * sy, 10 * sx, 4 * sy, 0, -1)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 캐릭터 이미지가 없을 때(공개 저장소에는 넣지 않음) 대신 보여 주는 동그라미.
class _MissingFace extends StatelessWidget {
  const _MissingFace({required this.character});

  final SplashCharacter character;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: FractionallySizedBox(
        widthFactor: 0.7,
        child: AspectRatio(
          aspectRatio: 1,
          child: DecoratedBox(
            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primaryContainer),
            child: Center(
              child: Text(
                character.label,
                style: const TextStyle(fontFamily: AppFonts.title, fontSize: 28, color: AppColors.primaryDeep),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginSheet extends StatelessWidget {
  const _LoginSheet({
    required this.busy,
    required this.onPickleLogin,
    required this.onKakaoLogin,
    required this.bottomInset,
  });

  final bool busy;
  final VoidCallback? onPickleLogin;
  final VoidCallback? onKakaoLogin;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [BoxShadow(color: Color(0x1A2F4A85), blurRadius: 24, offset: Offset(0, -8))],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 22, 24, 28 + bottomInset),
        child: busy
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 54,
                    child: FilledButton(
                      onPressed: onPickleLogin,
                      style: FilledButton.styleFrom(
                        backgroundColor: StartScreen.navy,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            SplashCharacter.pickle.asset,
                            width: 26,
                            height: 28,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                          const SizedBox(width: 8),
                          const Text('픽클 계정으로 시작하기'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: onKakaoLogin,
                      style: FilledButton.styleFrom(
                        backgroundColor: StartScreen.kakaoYellow,
                        foregroundColor: const Color(0xD9000000),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      icon: const Icon(Icons.chat_bubble, size: 18, color: Color(0xFF191919)),
                      label: const Text('카카오로 시작하기'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
