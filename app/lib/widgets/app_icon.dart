import 'package:flutter/material.dart';

import '../models/nutrition.dart';
import '../theme/app_theme.dart';

/// ═══════════════════════════════════════════════════════════
///  앱 공용 아이콘 배지
///  이모지는 폰·PC마다 모양이 달라서 지저분해 보여요.
///  대신 "그라데이션 둥근 네모 + 흰 아이콘"으로 통일해요.
/// ═══════════════════════════════════════════════════════════
class IconBadge extends StatelessWidget {
  final IconData icon;
  final List<Color> colors; // 그라데이션 색 2개
  final double size;
  final double? radius;
  final Color iconColor;
  final bool shadow;

  const IconBadge({
    super.key,
    required this.icon,
    required this.colors,
    this.size = 52,
    this.radius,
    this.iconColor = Colors.white,
    this.shadow = true,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(radius ?? size * 0.32),
          boxShadow: shadow
              ? [BoxShadow(color: colors.last.withOpacity(0.35), blurRadius: size * 0.3, offset: Offset(0, size * 0.12))]
              : null,
        ),
        child: Icon(icon, color: iconColor, size: size * 0.52),
      );
}

/// 자주 쓰는 그라데이션 색 묶음 (앱 색상과 어울리게)
class Grad {
  static const green = [Color(0xFF34D27B), Color(0xFF00B14F)];
  static const teal = [Color(0xFF5ED8CB), Color(0xFF2BB3A3)];
  static const orange = [Color(0xFFFFB457), Color(0xFFFF7A3D)];
  static const coral = [Color(0xFFFF8F7A), Color(0xFFFF5A4A)];
  static const sky = [Color(0xFF6FB1FF), Color(0xFF3B82F6)];
  static const plum = [Color(0xFFB08CFF), Color(0xFF8B5CF6)];
  static const sun = [Color(0xFFFFD95A), Color(0xFFFFB020)];
  static const pink = [Color(0xFFFF9BC6), Color(0xFFF2588F)];
  static const brown = [Color(0xFFC89B74), Color(0xFF9A6B45)];
  static const slate = [Color(0xFF9AA4B2), Color(0xFF6B7280)];
}

/// 끼니(아침·점심·저녁·간식) 아이콘
class MealIcon {
  static IconData of(MealType m) => switch (m) {
        MealType.breakfast => Icons.wb_twilight_rounded,
        MealType.lunch => Icons.wb_sunny_rounded,
        MealType.dinner => Icons.nightlight_round,
        MealType.snack => Icons.cookie_rounded,
      };
  static List<Color> colorsOf(MealType m) => switch (m) {
        MealType.breakfast => Grad.sun,
        MealType.lunch => Grad.orange,
        MealType.dinner => Grad.sky,
        MealType.snack => Grad.plum,
      };
}

/// 가게 종류(카카오 category 글자 / 메뉴 종류) → 아이콘 + 색
class FoodIcon {
  static (IconData, List<Color>) of(String category) {
    final c = category;
    if (c.contains('샐러드') || c.contains('포케') || c.contains('채소')) return (Icons.eco_rounded, Grad.green);
    if (c.contains('치킨')) return (Icons.kebab_dining_rounded, Grad.orange);
    if (c.contains('피자')) return (Icons.local_pizza_rounded, Grad.coral);
    if (c.contains('버거') || c.contains('햄버거') || c.contains('패스트')) return (Icons.lunch_dining_rounded, Grad.orange);
    if (c.contains('분식') || c.contains('떡볶이')) return (Icons.tapas_rounded, Grad.pink);
    if (c.contains('중식') || c.contains('중국')) return (Icons.takeout_dining_rounded, Grad.coral);
    if (c.contains('일식') || c.contains('초밥') || c.contains('돈까스') || c.contains('돈가스')) return (Icons.set_meal_rounded, Grad.sky);
    if (c.contains('국수') || c.contains('면') || c.contains('우동') || c.contains('냉면') || c.contains('라면')) return (Icons.ramen_dining_rounded, Grad.sun);
    if (c.contains('카페') || c.contains('커피') || c.contains('디저트') || c.contains('베이커리') || c.contains('제과')) return (Icons.local_cafe_rounded, Grad.brown);
    if (c.contains('고기') || c.contains('육류') || c.contains('구이') || c.contains('갈비')) return (Icons.outdoor_grill_rounded, Grad.coral);
    if (c.contains('국밥') || c.contains('찌개') || c.contains('탕') || c.contains('죽')) return (Icons.soup_kitchen_rounded, Grad.orange);
    if (c.contains('양식') || c.contains('파스타')) return (Icons.dinner_dining_rounded, Grad.pink);
    if (c.contains('편의점')) return (Icons.storefront_rounded, Grad.sky);
    if (c.contains('밥') || c.contains('한식') || c.contains('덮밥') || c.contains('김밥')) return (Icons.rice_bowl_rounded, Grad.sun);
    if (c.contains('음료') || c.contains('주스')) return (Icons.local_drink_rounded, Grad.teal);
    if (c.contains('간식') || c.contains('빵')) return (Icons.bakery_dining_rounded, Grad.plum);
    if (c.contains('술') || c.contains('호프')) return (Icons.sports_bar_rounded, Grad.slate);
    return (Icons.restaurant_rounded, Grad.teal);
  }

  /// 둥근 아이콘 배지로 바로 만들기
  static Widget badge(String category, {double size = 56}) {
    final (icon, colors) = of(category);
    return IconBadge(icon: icon, colors: colors, size: size);
  }
}

/// 넓은 화면(PC·태블릿)에서 앱을 가운데 폰 폭으로 모아 보여주는 틀.
/// 폰에서는 아무 일도 안 해요. 박람회 노트북·빔 화면에서 훨씬 예쁘게 보여요.
class PhoneFrame extends StatelessWidget {
  final Widget child;
  static const maxWidth = 560.0;
  const PhoneFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w <= maxWidth + 80) return child;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFE3F6EA), Color(0xFFD5F0F2)]),
      ),
      alignment: Alignment.center,
      child: Container(
        width: maxWidth,
        margin: const EdgeInsets.symmetric(vertical: 24),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 40, offset: const Offset(0, 16))],
        ),
        child: child,
      ),
    );
  }
}
