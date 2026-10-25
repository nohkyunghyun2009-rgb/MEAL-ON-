import 'package:flutter/material.dart';

/// 앱 전체에서 쓰는 색깔 모음.
/// Grab 느낌: 싱싱한 초록 + 청록 그라데이션 + 노란 쿠폰 + 진한 글자.
/// "ON" 컨셉 = 초록불이 켜지는 느낌이에요.
class AppColors {
  static const primary = Color(0xFF00B14F); // 메인 초록 (버튼, 강조)
  static const primaryDark = Color(0xFF008A3E); // 진한 초록 (글자용)
  static const teal = Color(0xFF3DBFB0); // 청록 (헤더 그라데이션 시작)
  static const peach = Color(0xFFE6F7EC); // 연한 초록 (배경) — 이름은 옛날 그대로 둬서 다른 파일이 안 깨져요
  static const green = Color(0xFF00875A); // 짙은 초록 (성공, 보조)
  static const mint = Color(0xFFE6F7EC); // 연한 민트 (배경 카드)
  static const tile = Color(0xFFEAF7F6); // 서비스 타일 배경 (연한 하늘민트)
  static const ink = Color(0xFF1F1F24); // 글자색
  static const muted = Color(0xFF7A7F8A); // 흐린 글자
  static const paper = Color(0xFFF6F7F9); // 화면 바탕
  static const line = Color(0xFFE8EAEE); // 테두리
  static const sun = Color(0xFFFFC533); // 노랑 (쿠폰)
  static const coral = Color(0xFFFF6B4A); // 주황 (경고, 나트륨 등 호환용)
  static const sky = Color(0xFF3B82F6); // 파랑
  static const plum = Color(0xFF8B5CF6); // 보라

  /// 카드에 살짝 얹는 그림자
  static List<BoxShadow> get cardShadow => [
        BoxShadow(color: const Color(0xFF1F1F24).withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 6)),
      ];
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    surface: Colors.white,
    onSurface: AppColors.ink,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.paper,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.paper,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(color: AppColors.ink, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.ink, height: 1.2, letterSpacing: -0.8),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.ink, letterSpacing: -0.5),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.3),
      bodyLarge: TextStyle(fontSize: 16, color: AppColors.ink, height: 1.5),
      bodyMedium: TextStyle(fontSize: 14, color: AppColors.ink, height: 1.5),
      bodySmall: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      labelStyle: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600),
      hintStyle: const TextStyle(color: AppColors.muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: AppColors.ink,
        backgroundColor: Colors.white,
        side: const BorderSide(color: AppColors.line, width: 1.5),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: Colors.white,
        selectedBackgroundColor: AppColors.ink,
        selectedForegroundColor: Colors.white,
        side: const BorderSide(color: AppColors.line),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: AppColors.peach,
      height: 72,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: states.contains(WidgetState.selected) ? AppColors.primary : AppColors.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(color: states.contains(WidgetState.selected) ? AppColors.primary : AppColors.muted),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: AppColors.ink,
      side: const BorderSide(color: AppColors.line),
      labelStyle: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700),
      secondaryLabelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    dividerColor: AppColors.line,
  );
}
