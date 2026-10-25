import 'package:flutter_test/flutter_test.dart';
import 'package:hankki/models/body_profile.dart';
import 'package:hankki/models/nutrition.dart';
import 'package:hankki/services/body_plan.dart';

BodyProfile profile({required double weight, required double fat, required double smm, ActivityLevel act = ActivityLevel.normal}) =>
    BodyProfile(
      nickname: '테스트',
      sex: Sex.male,
      age: 16,
      heightCm: 172,
      weightKg: weight,
      bodyFatPercent: fat,
      skeletalMuscleKg: smm,
      activity: act,
      measuredAt: DateTime(2026, 10, 1),
    );

void main() {
  group('인바디 → 끼니 방향', () {
    test('C형(지방 많고 근육 적음)은 단백질 우선 + 튀김 제한', () {
      final p = profile(weight: 78, fat: 29, smm: 25);
      final plan = MealPlan.from(p: p, t: NutritionTargets.forProfile(p), today: const NutritionTotals(), meal: '저녁');
      expect(p.analysis.shape, BodyShape.c);
      expect(plan.needProtein, isTrue);
      expect(plan.limitFried, isTrue);
      expect(plan.needEnergy, isFalse);
      expect(plan.mealProtein, greaterThanOrEqualTo(25));
      expect(plan.reasons.join(), contains('단백질'));
      expect(plan.reasons.join(), contains('튀김'));
      expect(plan.bodyLine, contains('C형'));
    });

    test('D형(운동형)은 탄수화물 충분히, 튀김 제한 없음', () {
      final p = profile(weight: 66, fat: 11, smm: 33, act: ActivityLevel.high);
      final plan = MealPlan.from(p: p, t: NutritionTargets.forProfile(p), today: const NutritionTotals(), meal: '점심');
      expect(p.analysis.shape, BodyShape.d);
      expect(plan.needCarb, isTrue);
      expect(plan.limitFried, isFalse);
      expect(plan.reasons.join(), contains('탄수화물'));
    });

    test('이미 많이 먹었으면 끼니 예산이 줄고, 나트륨 많이 먹었으면 덜 짜게', () {
      final p = profile(weight: 66, fat: 15, smm: 30);
      final t = NutritionTargets.forProfile(p);
      final plan = MealPlan.from(p: p, t: t, today: NutritionTotals(kcal: t.kcal - 350, proteinG: 50, sodiumMg: 1900), meal: '저녁');
      expect(plan.mealKcal, 350);
      expect(plan.sodiumHigh, isTrue);
      expect(plan.reasons.join(), contains('나트륨'));
    });

    test('프롬프트 글에 몸 한 줄과 끼니 목표가 들어가요', () {
      final p = profile(weight: 78, fat: 29, smm: 25);
      final text = MealPlan.from(p: p, t: NutritionTargets.forProfile(p), today: const NutritionTotals(), meal: '저녁').toPromptText();
      expect(text, contains('- 몸: C형'));
      expect(text, contains('이번 끼니(저녁) 목표'));
    });
  });
}
