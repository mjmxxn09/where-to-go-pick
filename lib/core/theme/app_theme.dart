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
}

/// 둥근 제목체·손글씨체. 글꼴 파일이 없으면 Flutter가 시스템 글꼴로 대체한다(pubspec 주석 참고).
abstract final class AppFonts {
  static const title = 'Jua';
  static const handwriting = 'NanumPenScript';
}

/// 레이아웃은 8dp 계열을 쓴다(픽클 디자인 규칙).
abstract final class Gap {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 16.0;
  static const l = 24.0;
}

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
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: false,
    ),
  );
}
