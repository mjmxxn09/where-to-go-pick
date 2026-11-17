import 'package:flutter/material.dart';

/// 픽클 앱 테마 5(바이올렛) 라이트 토큰을 따른다. 정본: VoteLock `docs/design/tokens/product-tokens.json`.
abstract final class AppColors {
  static const primary = Color(0xFF6A4CF5);
  static const primaryDeep = Color(0xFF5638E0);
  static const primaryContainer = Color(0xFFF0EDFF);
  static const secondary = Color(0xFFC02E7C);
  static const secondaryContainer = Color(0xFFFCEEF5);
  static const accent = Color(0xFF0F7B8A);
  static const tertiaryContainer = Color(0xFFE8F5F7);
  static const background = Color(0xFFF7F7FB);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF0F0F7);
  static const border = Color(0xFFE4E4EE);
  static const textPrimary = Color(0xFF1B1B2A);
  static const textSecondary = Color(0xFF5E6072);

  /// 지도·여행 노트 전용
  static const mapSea = Color(0xFFEEEAFE);
  static const mapShadow = Color(0xFFC8BCF2);
  static const mapContext = Color(0xFFE1DBF5);
  static const mapUnvisited = Color(0xFFE6E2F2);
  static const mapLabel = Color(0xFF2E2650);
  static const road = Color(0xFFDAD6E6);
  static const paperGrid = Color(0xFFE6EAF3);
  static const ink = Color(0xFF3B3360);

  /// 2026-11 UI 정리(디자인 캔버스 시안 A "포근한 카드" + B 하단 메뉴)
  static const titleInk = Color(0xFF2F4A85); // 제목(블랙한산스) 남색 — 스플래시와 같음
  static const bgTop = Color(0xFFF7F4FF);
  static const bgBottom = Color(0xFFEFE9FF);
  static const blush = Color(0xFFFFCDE8); // 배경 오른쪽 위 분홍 번짐
  static const muted = Color(0xFF8C89A3); // 하단 메뉴 비활성
  static const hairline = Color(0xFFEEECF5);
  static const chipTrack = Color(0xFFE6DFFF); // 알약 모양 탭의 바탕
}

/// 제목체·손글씨체(모두 assets/fonts에 포함).
abstract final class AppFonts {
  /// 화면 제목: 블랙한산스(앱 이름과 같은 글꼴).
  static const title = 'BlackHanSans';
  /// 여행 노트 손글씨: 감자꽃(Gamja Flower).
  static const handwriting = 'GamjaFlower';

  /// 앱 이름 "어디갈지 PICK!": 블랙한산스(Black Han Sans).
  static const logo = 'BlackHanSans';
}

/// 레이아웃은 8dp 계열을 쓴다(픽클 디자인 규칙).
abstract final class Gap {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 16.0;
  static const l = 24.0;
}

/// 카드·그림자 공통값.
abstract final class AppDecorations {
  static const cardShadow = [BoxShadow(color: Color(0x144A35C8), blurRadius: 24, offset: Offset(0, 8))];
  static const floatShadow = [BoxShadow(color: Color(0x294A35C8), blurRadius: 28, offset: Offset(0, 10))];
  static const buttonShadow = [BoxShadow(color: Color(0x4D6A4CF5), blurRadius: 18, offset: Offset(0, 8))];

  /// 흰 둥근 카드(반경 24).
  static const card = BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.all(Radius.circular(24)),
    boxShadow: cardShadow,
  );
}

/// 화면 제목 글자: 블랙한산스 + 남색.
TextStyle titleStyle(double size) =>
    TextStyle(fontFamily: AppFonts.title, fontSize: size, height: 1.15, color: AppColors.titleInk);

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.primary,
    secondary: AppColors.secondary,
    surface: AppColors.surface,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bgTop,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontFamily: AppFonts.title, fontSize: 22, color: AppColors.titleInk),
    ),
    cardTheme: const CardThemeData(
      color: AppColors.surface,
      elevation: 3,
      shadowColor: Color(0x404A35C8),
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: const StadiumBorder(),
        minimumSize: const Size(48, 46),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: const StadiumBorder(),
        minimumSize: const Size(48, 46),
        backgroundColor: AppColors.surface,
        side: BorderSide.none,
        foregroundColor: AppColors.primaryDeep,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        shape: const StadiumBorder(),
        backgroundColor: AppColors.chipTrack,
        selectedBackgroundColor: AppColors.surface,
        selectedForegroundColor: AppColors.textPrimary,
        foregroundColor: const Color(0xFF4A3BA6),
        side: BorderSide.none,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: BorderSide.none,
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.primary,
      checkmarkColor: Colors.white,
      // 고르면 흰 글자, 아니면 진한 보라 회색
      labelStyle: TextStyle(
        fontWeight: FontWeight.w800,
        color: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected) ? Colors.white : const Color(0xFF4A4670),
        ),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: Color(0xFFEFEBFF),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
