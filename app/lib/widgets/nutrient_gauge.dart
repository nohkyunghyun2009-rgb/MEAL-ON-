import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 하루 권장량을 얼마나 채웠는지 보여주는 "캡슐 게이지"
/// 말투가 중요해요: "부족해요/초과했어요" 대신 "조금 더/좋아요/충분해요"
class NutrientGauge extends StatelessWidget {
  final String label;
  final double value; // 지금까지 먹은 양
  final double target; // 하루 목표
  final String unit;
  final Color color;
  final bool lessIsBetter; // 나트륨처럼 "적을수록 좋은" 것

  const NutrientGauge({
    super.key,
    required this.label,
    required this.value,
    required this.target,
    required this.unit,
    required this.color,
    this.lessIsBetter = false,
  });

  double get ratio => target <= 0 ? 0 : value / target;

  (String, Color) get status {
    if (lessIsBetter) {
      if (ratio < 0.7) return ('좋아요', AppColors.green);
      if (ratio <= 1.0) return ('슬슬 조심', AppColors.sun);
      return ('짠 음식은 줄여봐요', AppColors.coral);
    }
    if (ratio < 0.4) return ('아직 많이 남았어요', AppColors.muted);
    if (ratio < 0.8) return ('조금 더 채워요', AppColors.sun);
    if (ratio <= 1.15) return ('좋아요', AppColors.green);
    return ('충분해요', AppColors.coral);
  }

  @override
  Widget build(BuildContext context) {
    final (statusText, statusColor) = status;
    final fill = ratio.clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Text(
                '${value.round()} / ${target.round()} $unit',
                style: const TextStyle(fontSize: 13, color: AppColors.muted, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 캡슐 모양 막대
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 14,
              child: Stack(
                children: [
                  Container(color: AppColors.paper),
                  AnimatedFractionallySizedBox(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    widthFactor: fill == 0 ? 0.001 : fill,
                    alignment: Alignment.centerLeft,
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(statusText, style: TextStyle(fontSize: 13, color: statusColor, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}
