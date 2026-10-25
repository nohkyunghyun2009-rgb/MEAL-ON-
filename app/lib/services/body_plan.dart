import 'dart:math';

import '../models/body_profile.dart';
import '../models/nutrition.dart';

/// ═══════════════════════════════════════════════════════════
///  인바디 → "이번 끼니에서 뭘 챙길지" 번역기
///
///  인바디 숫자(체형 C/I/D, 골격근 막대, 체지방 판정, 체수분)와
///  오늘 먹은 것을 보고, 이번 끼니의 방향을 "말로" 정해요.
///   - 자체 추천 엔진은 이 방향으로 점수를 주고
///   - AI(Gemini/Claude)에게는 이 방향을 그대로 보여줘서
///     "왜 이 메뉴인지"를 인바디 수치에 연결해 말하게 해요.
/// ═══════════════════════════════════════════════════════════
class MealPlan {
  final String meal; // 아침/점심/저녁/야식/간식
  final double mealKcal; // 이번 끼니 목표 에너지
  final double mealProtein; // 이번 끼니 목표 단백질(g)
  final bool needProtein; // 골격근 표준 이하 / 근육 비율 낮음 → 단백질 우선
  final bool limitFried; // C형 또는 체지방 높음 → 튀김·크림·단 음료 피하기
  final bool needEnergy; // 체지방 낮음 / 체중 표준 이하 → 끼니 든든히
  final bool needCarb; // D형(운동형) + 활동 많음 → 탄수화물 충분히
  final bool needWater; // 체수분 부족 → 국물·물
  final bool sodiumHigh; // 오늘 나트륨 80% 넘음 → 덜 짜게
  final List<String> reasons; // 사람이 읽는 이유 (인바디 수치 → 할 일)
  final String bodyLine; // 인바디 한 줄 요약
  final String proteinWhy; // 메뉴 이유 앞머리: "골격근이 표준보다 적어서" / "근육 비율이 낮은 편이라"
  final String fatWhy; // 메뉴 이유 앞머리: "체지방이 높은 편이라" 등

  const MealPlan({
    required this.meal,
    required this.mealKcal,
    required this.mealProtein,
    required this.needProtein,
    required this.limitFried,
    required this.needEnergy,
    required this.needCarb,
    required this.needWater,
    required this.sodiumHigh,
    required this.reasons,
    required this.bodyLine,
    this.proteinWhy = '',
    this.fatWhy = '',
  });

  /// 끼니별로 하루 목표의 몇 %를 먹는 게 보통인지
  static double shareOf(String meal) => switch (meal) {
        '아침' => 0.25,
        '점심' => 0.35,
        '저녁' => 0.35,
        '간식' => 0.10,
        _ => 0.15, // 야식
      };

  static MealPlan from({
    required BodyProfile p,
    required NutritionTargets t,
    required NutritionTotals today,
    required String meal,
  }) {
    final a = p.analysis;
    final share = shareOf(meal);

    // ── 1) 이번 끼니 예산: 하루 목표의 끼니 몫, 단 오늘 남은 양을 넘지 않게 ──
    final remainKcal = max(0.0, t.kcal - today.kcal);
    final remainProtein = max(0.0, t.proteinG - today.proteinG);
    var mealKcal = min(t.kcal * share, remainKcal);
    mealKcal = mealKcal.clamp(300.0, 900.0);
    var mealProtein = min(t.proteinG * max(share, 0.3), remainProtein);
    mealProtein = mealProtein.clamp(12.0, 40.0);

    // ── 2) 인바디 판정 → 깃발 ──
    final smmBar = a.bars[1]; // 골격근량 막대
    final weightBar = a.bars[0]; // 체중 막대
    final (mGood, mOk) = p.isMale ? (40.0, 35.0) : (34.0, 30.0);
    final needProtein = smmBar.judge == '표준 이하' || p.muscleRatioPercent < mOk;
    final limitFried = a.shape == BodyShape.c || a.fatJudge == '높음' || a.fatJudge == '살짝 높음';
    final needEnergy = a.fatJudge == '낮음' || weightBar.judge == '표준 이하';
    final needCarb = a.shape == BodyShape.d || p.activity == ActivityLevel.high;
    final needWater = a.waterJudge != null && a.waterJudge!.startsWith('부족');
    final sodiumHigh = today.sodiumMg > t.sodiumMg * 0.8;

    if (needProtein) mealProtein = max(mealProtein, 25);
    if (needEnergy) mealKcal = max(mealKcal, 550);

    // ── 3) 사람이 읽는 이유 (숫자 → 할 일) ──
    final reasons = <String>[];
    if (needProtein) {
      reasons.add('골격근량 ${p.skeletalMuscleKg.toStringAsFixed(1)}kg (표준의 ${smmBar.percent.round()}%, 근육 비율 ${p.muscleRatioPercent.round()}%) → 단백질 ${mealProtein.round()}g 이상');
    }
    if (limitFried) {
      reasons.add('체지방률 ${p.bodyFatPercent.toStringAsFixed(1)}% (${a.fatJudge}${a.shape == BodyShape.c ? ', C형' : ''}) → 튀김·크림·단 음료 대신 구이·찜·국·채소');
    }
    if (needEnergy) {
      reasons.add('체지방·체중이 표준보다 낮음 → 끼니 거르지 말고 ${mealKcal.round()}kcal 든든히');
    }
    if (needCarb) {
      reasons.add('${a.shape == BodyShape.d ? '운동형(D형)' : '활동량 많음'} → 밥·면 탄수화물 충분히 (근육 유지)');
    }
    if (needWater) reasons.add('체수분 부족 → 국·탕 또는 물 한 컵 같이');
    if (sodiumHigh) reasons.add('오늘 나트륨 ${today.sodiumMg.round()}mg / ${t.sodiumMg.round()}mg → 덜 짠 메뉴, 국물은 반만');
    if (reasons.isEmpty) {
      reasons.add('${a.shape.label}(${a.shape.title}) → 골고루, 단백질 ${mealProtein.round()}g 유지');
    }

    final bodyLine = '${a.shape.label} · 골격근 ${smmBar.judge} · 체지방 ${a.fatJudge} · 또래 BMI ${a.bmiPercentile.round()}번째'
        '${a.waterJudge == null ? '' : ' · 체수분 ${a.waterJudge}'}';

    // 메뉴 이유에 붙일 앞머리 — 인바디 판정과 정확히 맞는 말로
    final proteinWhy = smmBar.judge == '표준 이하'
        ? '골격근이 표준보다 적어서'
        : '근육 비율(${p.muscleRatioPercent.round()}%)이 낮은 편이라';
    final fatWhy = switch (a.fatJudge) {
      '높음' => '체지방이 높은 편이라',
      '살짝 높음' => '체지방이 살짝 높은 편이라',
      _ => 'C형(지방이 근육보다 앞서서)',
    };

    return MealPlan(
      meal: meal,
      mealKcal: mealKcal,
      mealProtein: mealProtein,
      needProtein: needProtein,
      limitFried: limitFried,
      needEnergy: needEnergy,
      needCarb: needCarb,
      needWater: needWater,
      sodiumHigh: sodiumHigh,
      reasons: reasons,
      bodyLine: bodyLine,
      proteinWhy: proteinWhy,
      fatWhy: fatWhy,
    );
  }

  /// AI 프롬프트용 글
  String toPromptText() {
    final buf = StringBuffer();
    buf.writeln('- 몸: $bodyLine');
    for (final r in reasons) {
      buf.writeln('- $r');
    }
    buf.write('- 이번 끼니($meal) 목표: 약 ${mealKcal.round()}kcal, 단백질 ${mealProtein.round()}g 이상');
    return buf.toString();
  }
}
