import 'package:flutter/material.dart';

import '../models/body_profile.dart';
import '../theme/app_theme.dart';

/// 인바디 숫자 4개를 한눈에 보여주는 카드 (그라데이션)
class BodySummaryCard extends StatelessWidget {
  final BodyProfile profile;
  final bool compact;

  const BodySummaryCard({super.key, required this.profile, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final tiles = [
      _Stat('몸무게', p.weightKg.toStringAsFixed(1), 'kg'),
      _Stat('골격근', p.skeletalMuscleKg.toStringAsFixed(1), 'kg'),
      _Stat('체지방', p.bodyFatPercent.toStringAsFixed(1), '%'),
      _Stat('BMI', p.bmi.toStringAsFixed(1), ''),
    ];

    return Container(
      padding: EdgeInsets.all(compact ? 18 : 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF12A58A), Color(0xFF1FC6A6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [BoxShadow(color: AppColors.green.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fitness_center_rounded, size: 20, color: Colors.white),
              const SizedBox(width: 8),
              Text('${p.nickname}의 몸', style: TextStyle(color: Colors.white, fontSize: compact ? 15 : 18, fontWeight: FontWeight.w900)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(999)),
                child: Text(
                  '${p.isMale ? '남' : '여'} · ${p.age}세 · ${p.heightCm.round()}cm',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 14 : 20),
          Row(
            children: tiles
                .map((t) => Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          RichText(
                            text: TextSpan(
                              text: t.value,
                              style: TextStyle(color: Colors.white, fontSize: compact ? 20 : 26, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                              children: [
                                TextSpan(
                                  text: t.unit.isEmpty ? '' : ' ${t.unit}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _Stat {
  final String label, value, unit;
  const _Stat(this.label, this.value, this.unit);
}
