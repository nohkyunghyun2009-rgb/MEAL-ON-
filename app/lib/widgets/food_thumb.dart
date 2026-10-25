import 'package:flutter/material.dart';

import 'app_icon.dart';

/// 사진 대신 쓰는 썸네일. 가게 종류에 따라 아이콘과 색이 정해져요.
/// (예전엔 이모지였는데, 폰·PC마다 모양이 달라서 아이콘 배지로 바꿨어요)
class FoodThumb extends StatelessWidget {
  final String category; // 예: "음식점 > 한식 > 덮밥", "샐러드", "패스트푸드"
  final double size;
  final double radius;

  const FoodThumb({super.key, required this.category, this.size = 64, this.radius = 18});

  @override
  Widget build(BuildContext context) {
    final (icon, colors) = FoodIcon.of(category);
    return IconBadge(icon: icon, colors: colors, size: size, radius: radius);
  }
}
