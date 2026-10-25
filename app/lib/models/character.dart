import '../models/body_profile.dart';
import '../models/nutrition.dart';

/// ═══════════════════════════════════════════════════════════
///  밀온이 (다마고치 캐릭터)
///  - 건강한 끼니를 기록할수록 경험치가 쌓여 레벨업(모습·호칭 변화)
///  - 오늘 먹은 것에 따라 표정이 바뀌어요
/// ═══════════════════════════════════════════════════════════

/// 표정 4종 — assets/characters/milon_○○.png 와 이름이 같아요
enum MilonFace { hello, think, happy, cheer }

extension MilonFaceAsset on MilonFace {
  String get asset => 'assets/characters/milon_$name.png';
}

/// 성장 단계 (경험치로 결정)
class MilonStage {
  final int level; // 1~5
  final String title; // 호칭
  final String emoji; // 단계 뱃지
  final double scale; // 캐릭터를 얼마나 크게 그릴지
  const MilonStage(this.level, this.title, this.emoji, this.scale);
}

class MilonState {
  final int exp; // 총 경험치
  final int level; // 현재 레벨 (1~5)
  final int expInLevel; // 이번 레벨에서 모은 경험치
  final int expForNext; // 다음 레벨까지 필요한 경험치
  final MilonStage stage;
  final MilonFace face; // 지금 표정
  final String message; // 말풍선 한마디

  const MilonState({
    required this.exp,
    required this.level,
    required this.expInLevel,
    required this.expForNext,
    required this.stage,
    required this.face,
    required this.message,
  });

  double get progress => expForNext == 0 ? 1 : (expInLevel / expForNext).clamp(0.0, 1.0);

  // 레벨별 필요 경험치 (누적) — 뒤로 갈수록 조금씩 많이
  static const _thresholds = [0, 100, 300, 600, 1000];
  static const _stages = [
    MilonStage(1, '갓 깨어난 밀온이', '🥚', 0.72),
    MilonStage(2, '아기 밀온이', '🐣', 0.82),
    MilonStage(3, '쑥쑥 밀온이', '🌱', 0.92),
    MilonStage(4, '든든 밀온이', '💪', 1.0),
    MilonStage(5, '건강 마스터 밀온이', '👑', 1.08),
  ];

  /// 끼니 한 번의 "건강 점수" → 경험치
  /// 단백질 풍부 + 안 짜고 + 채소면 높고, 튀김·단 음료 위주면 낮아요.
  static int expForMeal(FoodItem f, double servings) {
    var pts = 8.0; // 뭐든 챙겨 먹으면 기본 점수 (성장기엔 굶는 게 제일 나빠요)
    if (f.proteinG >= 25) {
      pts += 12;
    } else if (f.proteinG >= 15) {
      pts += 7;
    } else if (f.proteinG >= 8) pts += 3;
    if (f.category == '샐러드' || f.name.contains('비빔') || f.name.contains('채소')) pts += 6;
    if (f.sodiumMg <= 800) {
      pts += 4;
    } else if (f.sodiumMg >= 1800) pts -= 4;
    if (f.name.contains('튀김') || f.name.contains('세트') || f.fatG >= 35) pts -= 4;
    if (f.category == '음료' && f.carbG >= 30) pts -= 5; // 단 음료
    if (f.category == '간식') pts -= 2;
    pts *= (servings >= 1 ? 1.0 : 0.7); // 반 그릇은 조금 덜
    return pts.clamp(2, 30).round();
  }

  /// 지금까지 먹은 모든 끼니로 총 경험치 계산
  static int totalExp(List<MealEntry> entries) =>
      entries.fold(0, (s, e) => s + expForMeal(e.food, e.servings));

  /// 오늘 먹은 것 + 몸 상태로 현재 밀온이 상태를 만들어요
  static MilonState build({
    required List<MealEntry> allEntries,
    required List<MealEntry> todayEntries,
    required NutritionTargets? targets,
    required NutritionTotals todayTotals,
    required BodyProfile? profile,
    bool justAte = false, // 방금 먹었을 때 잠깐 기뻐하게
  }) {
    final exp = totalExp(allEntries);

    // 레벨 찾기
    var level = 1;
    for (var i = 0; i < _thresholds.length; i++) {
      if (exp >= _thresholds[i]) level = i + 1;
    }
    final stage = _stages[level - 1];
    final base = _thresholds[level - 1];
    final next = level < _thresholds.length ? _thresholds[level] : _thresholds.last;
    final expInLevel = exp - base;
    final expForNext = level < _thresholds.length ? next - base : 0;

    // ── 표정 + 한마디 정하기 ──
    final (face, message) = _mood(
      justAte: justAte,
      todayEntries: todayEntries,
      targets: targets,
      todayTotals: todayTotals,
      profile: profile,
      level: level,
    );

    return MilonState(
      exp: exp,
      level: level,
      expInLevel: expInLevel,
      expForNext: expForNext,
      stage: stage,
      face: face,
      message: message,
    );
  }

  static (MilonFace, String) _mood({
    required bool justAte,
    required List<MealEntry> todayEntries,
    required NutritionTargets? targets,
    required NutritionTotals todayTotals,
    required BodyProfile? profile,
    required int level,
  }) {
    final name = profile?.nickname ?? '친구';

    // 아직 몸 정보/기록이 없을 때
    if (targets == null) return (MilonFace.hello, '안녕 $name! 인바디를 적어주면 너에게 딱 맞게 도와줄게 😊');
    if (todayEntries.isEmpty) {
      return (MilonFace.hello, '오늘 아직 아무것도 안 먹었네. 뭐라도 챙겨 먹자! 굶으면 나도 기운 없어…');
    }

    final kcalPct = todayTotals.kcal / targets.kcal;
    final proteinPct = todayTotals.proteinG / targets.proteinG;
    final sodiumOver = todayTotals.sodiumMg > targets.sodiumMg;

    // 방금 먹었으면 잠깐 기뻐하기
    if (justAte) return (MilonFace.cheer, '잘 먹었어! 방금 그 한 끼로 내가 조금 자랐어 🌱');

    // 나트륨 초과 → 걱정 표정
    if (sodiumOver) return (MilonFace.think, '오늘 좀 짜게 먹었어. 다음 끼니는 국물 남기고 물 많이 마시자!');

    // 목표를 잘 채웠고 단백질도 좋으면 → 최고 표정
    if (kcalPct >= 0.8 && kcalPct <= 1.15 && proteinPct >= 0.8) {
      return (MilonFace.happy, '오늘 균형 완벽해! 이렇게만 먹으면 쑥쑥 클 거야 💪');
    }
    // 단백질이 부족하면 → 응원(하트) 표정으로 권유
    if (proteinPct < 0.6) {
      return (MilonFace.cheer, '단백질이 조금 부족해. 계란·두부·닭가슴살 같은 거 하나 더 어때?');
    }
    // 너무 적게 먹었으면
    if (kcalPct < 0.5 && DateTime.now().hour >= 16) {
      return (MilonFace.think, '오늘 너무 적게 먹었어. 성장기엔 잘 먹는 게 진짜 중요해!');
    }
    // 너무 많이 먹었으면
    if (kcalPct > 1.25) {
      return (MilonFace.think, '오늘은 충분히 먹었어. 출출하면 가벼운 걸로 골라줄게!');
    }
    // 그럭저럭 좋음
    return (MilonFace.happy, '좋은 흐름이야 $name! 남은 끼니도 같이 골라줄게 😋');
  }
}
