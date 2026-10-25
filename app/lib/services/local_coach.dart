import 'dart:math';

import '../data/food_database.dart';
import '../data/partner_menus.dart';
import '../models/body_profile.dart';
import '../models/nutrition.dart';
import '../state/app_state.dart';
import 'body_plan.dart';
import 'kakao_local_service.dart';
import 'recommendation_memory.dart';

/// AI(Gemini/Claude)에게 넘기는 "후보 메뉴" 한 개
/// 앱이 인바디·오늘 먹은 것·최근 추천을 반영해 미리 골라둔 것이라,
/// AI는 이 안에서 3개를 고르기만 하면 돼요.
class Candidate {
  final FoodItem food;
  final double score;
  final List<String> reasons;
  final List<String> stores; // "★현대옥 (120m)" 같은 글
  const Candidate({required this.food, required this.score, required this.reasons, required this.stores});
}

/// ═══════════════════════════════════════════════════════════
///  MEAL:ON 자체 추천 엔진 v2 (돈도, 인터넷도 필요 없음)
///
///  v1은 "남은 영양소 → 점수 → 상위 3개"라서 매번 똑같은 답이 나왔어요.
///  v2가 달라진 점:
///   ① 질문 이해: 국물/매운/느끼/시원/빨리/야식/아침/기분… 30가지 넘는 힌트
///   ② 상황 인식: 시간대, 오늘 이미 먹은 것(같은 종류 반복 금지), 이번 주 자주 먹은 것
///   ③ 몸 상태: 인바디 체형(C/I/D)·또래 백분위·체지방 판정 반영
///   ④ 다양성: 카테고리 겹치지 않게 + 직전에 추천한 건 빼기 + 살짝 무작위
///   ⑤ 질문 종류 구분: 추천 / "이거 먹어도 돼?" 판정 / 내 상태 / 인사
///   ⑥ 말투: 문장 틀을 여러 개 두고 돌려 써서 답이 매번 달라요
///
///  v3 (같은 가게만 나오던 문제 해결):
///   ⑦ 가게 회전: 메뉴마다 "제일 가까운 가게 2곳"을 고정으로 붙이던 걸
///      → 거리 가중 무작위로 뽑고, 최근 추천한 가게는 빼요 (RecommendationMemory)
///   ⑧ 메뉴 기억: 최근 3일 동안 추천한 메뉴는 얼마나 최근인지에 따라 감점
///   ⑨ 뽑기 방식: 무조건 1등이 아니라 상위 후보 중에서 점수 가중 추첨
/// ═══════════════════════════════════════════════════════════
class LocalCoach {
  static Future<String> reply(String question, AppState app) async {
    await _ensurePlaces(app);

    final q = question.replaceAll(' ', '').toLowerCase();
    final t = app.targets;
    final p = app.profile;

    if (t == null || p == null) {
      return '인바디 결과를 먼저 적어주면 몸에 맞춰서 골라줄게. 홈의 ⚖️ 인바디 타일을 눌러봐.';
    }

    // ───── 0) 질문 종류 나누기 ─────
    if (_isGreeting(q)) return _greet(app);
    if (_isStatusQuestion(q)) return _status(app);
    final checkFood = _findFoodInQuestion(q);
    if (checkFood != null && _isCheckQuestion(q)) return _judgeFood(checkFood, app);

    // ───── 1) 상황 파악 (질문 + 시간 + 오늘 먹은 것 + 인바디 방향) ─────
    final ctx = _Context.from(q, app);

    // ───── 2) 점수 매기기 ─────
    final scored = _scoreAll(ctx, app);
    if (scored.isEmpty) {
      return '그 조건으로는 목록에서 못 찾았어. "편의점", "단백질", "국물", "가볍게", "매운 거" 같은 말로 물어봐줘.';
    }

    // ───── 3) 고르기: 카테고리 안 겹치게 + 살짝 섞기 ─────
    final picks = _pickDiverse(scored, ctx, count: 3);

    // ───── 4) 문장 만들기 ─────
    return _compose(picks, ctx, app);
  }

  /// AI(Gemini/Claude)에게 넘길 후보 메뉴 — 인바디 점수 순, 종류 겹치지 않게, 최근 추천 제외.
  /// (가게 목록은 미리 app.ensureNearbyPlaces()로 받아둔 상태여야 가게 이름이 붙어요)
  static List<Candidate> candidates(String question, AppState app, {int count = 8}) {
    if (app.targets == null || app.profile == null) return const [];
    final q = question.replaceAll(' ', '').toLowerCase();
    final ctx = _Context.from(q, app);
    final scored = _scoreAll(ctx, app);
    final picks = _pickDiverse(scored, ctx, count: count);
    return picks
        .map((s) => Candidate(
              food: s.food,
              score: s.score,
              reasons: s.reasons,
              stores: _nearbyStoresFor(s.food, app.nearbyPlaces, ctx),
            ))
        .toList();
  }

  /// 이번 끼니의 인바디 기반 방향 (화면·프롬프트에서 같이 써요)
  static MealPlan planFor(String question, AppState app) {
    final q = question.replaceAll(' ', '').toLowerCase();
    final meal = app.mealAskedFor(q) ?? MealHint.fromClock(DateTime.now().hour);
    return MealPlan.from(p: app.profile!, t: app.targets!, today: app.todayTotals, meal: meal);
  }

  static List<_Scored> _scoreAll(_Context ctx, AppState app) {
    final scored = <_Scored>[];
    for (final f in FoodDatabase.all) {
      final s = _score(f, ctx, app);
      if (s != null) scored.add(s);
    }
    // 학생이 "매운 거", "건강한 걸로"처럼 조건을 말했으면 그 조건은 가산점이 아니라 "거름망"이에요.
    // (예전엔 가산점만 줘서 나트륨·칼로리 점수에 밀려 흰밥·오트밀이 "매운 거"로 나왔어요)
    final filters = ctx.intentFilters;
    if (filters.isEmpty) return scored;
    final filtered = scored.where((s) => filters.every((ok) => ok(s.food))).toList();
    return filtered.length >= 3 ? filtered : scored; // 조건에 맞는 게 너무 적으면 가산점만으로
  }

  /// 학생의 이번 요청을 짧은 말로 (AI 프롬프트에 "이 조건 지켜"라고 알려주려고)
  static List<String> intentsFor(String question, AppState app) {
    if (app.targets == null || app.profile == null) return const [];
    final q = question.replaceAll(' ', '').toLowerCase();
    return _Context.from(q, app).intentLabels;
  }

  // ─────────────────────────────────────────────────────────
  //  근처 식당 준비
  // ─────────────────────────────────────────────────────────
  static Future<void> _ensurePlaces(AppState app) => app.ensureNearbyPlaces();

  // ─────────────────────────────────────────────────────────
  //  질문 종류
  // ─────────────────────────────────────────────────────────
  static bool _isGreeting(String q) =>
      q.length <= 6 && (q.contains('안녕') || q.contains('하이') || q.contains('ㅎㅇ') || q == '' || q.contains('반가'));

  static bool _isStatusQuestion(String q) =>
      (q.contains('내몸') || q.contains('내상태') || q.contains('오늘어때') || q.contains('얼마나먹') || q.contains('남았') || q.contains('몇칼로리먹')) &&
      !q.contains('추천');

  static bool _isCheckQuestion(String q) =>
      q.contains('먹어도') || q.contains('괜찮') || q.contains('어때') || q.contains('먹을까') || q.contains('먹으면') || q.contains('나빠') || q.contains('살쪄');

  /// 질문 속에 음식 이름이 있으면 찾아줘요 ("라면 먹어도 돼?" → 라면)
  static FoodItem? _findFoodInQuestion(String q) {
    FoodItem? best;
    var bestLen = 0;
    for (final f in FoodDatabase.all) {
      final key = f.name.replaceAll(RegExp(r'[\s\d()+개줄조각봉지컵팩줌mlgL]+'), '');
      if (key.length >= 2 && q.contains(key) && key.length > bestLen) {
        best = f;
        bestLen = key.length;
      }
    }
    return best;
  }

  static String _greet(AppState app) {
    final name = app.profile!.nickname;
    final r = Random().nextInt(3);
    return [
      '안녕 $name! 오늘 뭐 먹을지 고민이면 "지금 뭐 먹지?"라고 물어봐. 국물, 매운 거, 편의점, 가볍게 — 뭐든 말해도 돼.',
      '$name 왔네 👋 오늘 몸 상태 보고 골라줄게. 배고픈 정도나 먹고 싶은 느낌(따뜻한 거, 시원한 거)만 말해줘!',
      '안녕! 지금 ${_mealName(DateTime.now().hour)} 시간이네. "뭐 먹지"라고 하면 근처 가게까지 찾아줄게.',
    ][r];
  }

  static String _status(AppState app) {
    final p = app.profile!;
    final a = p.analysis;
    final t = app.targets!;
    final tot = app.todayTotals;
    final pct = (tot.kcal / t.kcal * 100).round();
    final buf = StringBuffer();
    buf.writeln('${p.nickname}의 오늘 상태 📊\n');
    buf.writeln('• 에너지 ${tot.kcal.round()} / ${t.kcal.round()} kcal ($pct%)');
    buf.writeln('• 단백질 ${tot.proteinG.round()} / ${t.proteinG.round()} g');
    buf.writeln('• 나트륨 ${tot.sodiumMg.round()} / ${t.sodiumMg.round()} mg${tot.sodiumMg > t.sodiumMg ? ' ⚠️ 이미 넘었어' : ''}');
    buf.writeln('\n몸: ${a.shape.label}(${a.shape.title}), 또래 ${a.bmiPercentile.round()}번째, 체지방률 ${a.fatJudge}');
    if (tot.kcal == 0) {
      buf.write('\n아직 기록이 없네. 먹은 걸 적어주면 남은 양에 맞춰 골라줄 수 있어.');
    } else if (pct < 40 && DateTime.now().hour >= 15) {
      buf.write('\n오후인데 절반도 안 채웠어. 성장기엔 끼니 거르면 오히려 몸이 축 처져 — 든든한 거 하나 추천해줄까?');
    } else if (pct > 110) {
      buf.write('\n오늘은 충분히 먹었어. 더 먹고 싶으면 가벼운 걸로 골라줄게.');
    } else {
      buf.write('\n좋은 흐름이야. "뭐 먹지"라고 하면 남은 양에 딱 맞는 걸 골라줄게.');
    }
    return buf.toString();
  }

  /// "라면 먹어도 돼?" 같은 질문에 판정 + 더 잘 먹는 법
  static String _judgeFood(FoodItem f, AppState app) {
    final t = app.targets!;
    final tot = app.todayTotals;
    final a = app.profile!.analysis;
    final remainKcal = (t.kcal - tot.kcal).clamp(0, t.kcal);
    final remainSodium = (t.sodiumMg - tot.sodiumMg).clamp(0, t.sodiumMg);

    final good = <String>[];
    final bad = <String>[];
    if (f.proteinG >= 20) good.add('단백질 ${f.proteinG.round()}g으로 꽤 든든해');
    if (f.kcal <= remainKcal) {
      good.add('오늘 남은 에너지(${remainKcal.round()}kcal) 안에 들어와');
    } else {
      bad.add('오늘 남은 에너지보다 ${(f.kcal - remainKcal).round()}kcal 많아');
    }
    if (f.sodiumMg > remainSodium) bad.add('나트륨이 남은 여유보다 많아');
    if (f.proteinG < 10) bad.add('단백질이 거의 없어');
    if (f.category == '음료' && f.carbG > 30) bad.add('설탕이 ${f.carbG.round()}g — 각설탕 ${(f.carbG / 3).round()}개 분량이야');
    if (a.shape == BodyShape.c && f.fatG > 25) bad.add('지금 체형엔 기름진 건 덜 맞아');

    final verdict = bad.isEmpty
        ? '응, 먹어도 돼 👍'
        : good.isEmpty
            ? '음… 오늘은 다른 게 나을 것 같아'
            : '먹어도 되는데 조금만 바꾸면 훨씬 좋아';

    final tips = _tipsFor(f);
    final buf = StringBuffer('${f.name} — $verdict\n');
    buf.writeln('(${f.kcal.round()}kcal · 탄 ${f.carbG.round()}g · 단 ${f.proteinG.round()}g · 지 ${f.fatG.round()}g · 나트륨 ${f.sodiumMg.round()}mg)\n');
    for (final g in good) {
      buf.writeln('✅ $g');
    }
    for (final b in bad) {
      buf.writeln('⚠️ $b');
    }
    if (tips.isNotEmpty) buf.writeln('\n💡 이렇게 먹으면 더 좋아: ${tips.join(' / ')}');
    if (bad.length >= 2) buf.write('\n대신 뭐가 좋을지 물어보면 비슷한 느낌으로 골라줄게.');
    return buf.toString();
  }

  // ─────────────────────────────────────────────────────────
  //  상황(Context) — 질문 + 시간 + 오늘 먹은 것 + 몸
  // ─────────────────────────────────────────────────────────
  static String _mealName(int h) => h < 10 ? '아침' : (h < 15 ? '점심' : (h < 21 ? '저녁' : '야식'));

  // ─────────────────────────────────────────────────────────
  //  점수
  // ─────────────────────────────────────────────────────────
  static _Scored? _score(FoodItem f, _Context c, AppState app) {
    // ── 거르기 ──
    if (f.kcal < 40 && !c.wantDrink) return null; // 물, 제로콜라
    if (c.category != null && f.category != c.category) return null;
    if (c.wantSnack) {
      if (!(f.category == '간식' || f.category == '편의점' || f.category == '음료')) return null;
    } else if (!c.wantDrink && (f.category == '음료' || f.category == '간식')) {
      return null;
    }
    if (c.wantDrink && f.category != '음료' && !c.wantSnack) return null;
    if (c.budget && !const {'편의점', '분식', '면', '간식'}.contains(f.category) && !f.name.contains('김밥')) return null;
    if (c.noMeat && _hasMeat(f)) return null;
    if (c.excludeNames.contains(f.name)) return null; // 방금 추천한 것 / "말고"
    // 끼니 추천인데 반찬·재료급(흰밥 한 공기, 닭가슴살 100g, 어묵 2개)은 메인으로 뽑지 않아요
    if (!c.wantSnack && !c.wantDrink && f.kcal < (c.light ? 150 : 250)) return null;
    if (!c.wantSnack && (f.name.contains('한 공기') || f.name.contains('추가'))) return null;

    var score = 0.0;
    final reasons = <String>[];

    // ── 1) 남은 영양 채우기 (v1 로직 개선: 넘치면 감점) ──
    double fill(double amt, double remain, double target, double w) {
      if (target <= 0) return 0;
      final useful = min(amt, remain);
      final over = max(0.0, amt - remain);
      return (useful / target - over / target * 0.8) * w;
    }

    score += fill(f.kcal, c.remainKcal, c.t.kcal, 1.0);
    score += fill(f.proteinG, c.remainProtein, c.t.proteinG, 1.6 * c.proteinWeight);
    score += fill(f.carbG, c.remainCarb, c.t.carbG, 0.7 * c.carbWeight);
    score += fill(f.fatG, c.remainFat, c.t.fatG, 0.4);
    if (f.sodiumMg > c.remainSodium) score -= (f.sodiumMg - c.remainSodium) / c.t.sodiumMg * (c.sodiumHigh ? 3.0 : 1.5);

    // (인바디가 단백질 우선이면 2b)에서 더 정확한 이유를 붙이니까 여기선 생략)
    if (f.proteinG >= 25 && !c.plan.needProtein) reasons.add('단백질 ${f.proteinG.round()}g으로 남은 단백질 ${min(f.proteinG, c.remainProtein).round()}g을 한 번에');
    if (f.sodiumMg <= 800) reasons.add('짜지 않아서 부담 없어');

    // ── 2) 몸 상태 (인바디 분석) ──
    final a = c.analysis;
    switch (a.shape) {
      case BodyShape.c:
        if (f.proteinG >= 20 && f.fatG <= 20) {
          score += 0.35;
          reasons.add('근육 키우고 지방은 덜 붙는 조합');
        }
        if (f.fatG > 30 || f.name.contains('튀김') || f.name.contains('세트')) score -= 0.3;
        if (f.category == '샐러드') score += 0.2;
      case BodyShape.d:
        if (f.carbG >= 70 && f.proteinG >= 20) {
          score += 0.3;
          reasons.add('운동형 몸엔 탄수+단백질 같이 있는 게 좋아');
        }
      case BodyShape.i:
        break;
    }
    if (a.fatJudge == '낮음' && f.kcal >= 550) score += 0.25;
    if (a.waterJudge != null && a.waterJudge!.startsWith('부족') && (f.name.contains('국') || f.name.contains('탕') || f.name.contains('찌개'))) {
      score += 0.15;
    }

    // ── 2b) 인바디 기반 방향 (MealPlan) — 여기서 "왜 이 메뉴인지"가 정해져요 ──
    final plan = c.plan;
    if (plan.needProtein) {
      if (f.proteinG >= 20) {
        score += 0.5;
        reasons.insert(0, '${plan.proteinWhy} 단백질 ${f.proteinG.round()}g으로 채움');
      } else if (f.proteinG < 12) {
        score -= 0.4;
      }
    }
    if (plan.limitFried) {
      if (_isFried(f) || f.fatG > 25) {
        score -= 0.7;
      } else if (f.fatG <= 18 && f.proteinG >= 15) {
        score += 0.25;
        reasons.add('${plan.fatWhy} 기름기 적은 걸로');
      }
    }
    if (plan.needEnergy && f.kcal >= 500) {
      score += 0.3;
      reasons.add('체지방이 낮은 편이라 에너지 든든히');
    }
    if (plan.needCarb && f.carbG >= 70 && f.proteinG >= 15) {
      score += 0.25;
      reasons.add('운동형 몸이라 탄수화물도 충분히');
    }
    if (plan.needWater && _isSoup(f)) {
      score += 0.2;
      reasons.add('체수분이 부족해서 국물로 수분 보충');
    }
    // 이번 끼니 예산(인바디·끼니별 몫)에 가까울수록 +, 많이 벗어나면 −
    final kcalGap = (f.kcal - plan.mealKcal).abs() / plan.mealKcal;
    score += (0.35 - kcalGap * 0.7).clamp(-0.5, 0.35);
    // 끼니인데 너무 작은 것(닭가슴살 100g 같은 것)은 메인으로는 뒤로
    if (!c.light && !c.wantSnack && !c.wantDrink && f.kcal < plan.mealKcal * 0.35) score -= 0.3;

    // ── 3) 시간대 ──
    final h = c.hour;
    if (h < 10) {
      // 아침: 가볍고 빠른 것
      if (f.kcal <= 450) score += 0.3;
      if (f.kcal >= 700) score -= 0.4;
      if (f.category == '편의점' || f.name.contains('토스트') || f.name.contains('요거트') || f.name.contains('오트밀') || f.name.contains('샌드위치')) {
        score += 0.25;
      }
      if (f.name.contains('짬뽕') || f.name.contains('마라') || f.name.contains('치킨') || f.name.contains('피자')) score -= 0.5;
    } else if (h >= 21) {
      // 야식: 가볍고 덜 짠 것
      if (f.kcal <= 400) score += 0.35;
      if (f.kcal >= 650) score -= 0.5;
      if (f.sodiumMg >= 1500) score -= 0.3;
    } else if (h >= 15 && h < 17) {
      // 학원 가기 전 간단히
      if (f.kcal <= 550) score += 0.15;
    }

    // ── 4) 오늘 이미 먹은 것과 겹치지 않게 ──
    if (c.eatenCategoriesToday.contains(f.category) && f.category != '편의점') {
      score -= 0.35; // 점심에 면 먹었으면 저녁은 밥으로
    }
    if (c.eatenNamesToday.contains(f.name)) score -= 0.8; // 같은 걸 또?
    final weekCount = c.weekCounts[f.name] ?? 0;
    if (weekCount >= 2) score -= 0.25 * weekCount; // 이번 주에 자주 먹은 건 뒤로
    // 최근에 추천한 메뉴는 "얼마나 최근인지"에 따라 감점 (0 = 직전 답변)
    final rank = c.foodRecency[f.name];
    if (rank != null) {
      score -= rank == 0 ? 1.0 : (rank <= 2 ? 0.6 : 0.3);
    }

    // ── 5) 질문 힌트 ──
    if (c.light) score += (600 - f.kcal) / 900;
    if (c.heavy) score += (f.kcal - 450) / 900;
    if (c.soup && _isSoup(f)) {
      score += 0.6;
      reasons.add('따끈한 국물');
    } else if (c.soup) {
      score -= 0.3;
    }
    if (c.spicy && _isSpicy(f)) {
      score += 0.6;
      reasons.add('매콤한 맛');
    } else if (c.spicy) {
      score -= 0.25;
    }
    if (c.cold && _isCold(f)) {
      score += 0.6;
      reasons.add('시원하게 먹기 좋아');
    } else if (c.cold) {
      score -= 0.2;
    }
    if (c.greasyNo && (f.fatG > 25 || f.name.contains('튀김') || f.name.contains('크림'))) score -= 0.6;
    if (c.quick && !(f.category == '편의점' || f.category == '분식' || f.name.contains('김밥') || f.name.contains('샌드위치') || f.name.contains('토스트'))) {
      score -= 0.4;
    }
    if (c.quick && (f.category == '편의점' || f.name.contains('김밥'))) reasons.add('바로 사서 먹을 수 있어');
    if (c.stressed && (f.name.contains('초코') || f.name.contains('아이스') || f.name.contains('붕어') || f.name.contains('스무디'))) {
      score += 0.3;
      reasons.add('기분 전환용으로 한 번쯤은 괜찮아');
    }
    if (c.exam && (f.proteinG >= 15 && f.kcal <= 600 && f.sodiumMg <= 1300)) {
      score += 0.3;
      reasons.add('시험 전엔 졸리지 않게 적당히');
    }
    if (c.exam && f.kcal >= 800) score -= 0.5;
    if (c.seafood && _isSeafood(f)) score += 0.7;
    if (c.meat && _hasMeat(f) && !_isSeafood(f)) score += 0.5;

    // ── 6) 살짝 무작위 (같은 몸·같은 상황이어도 매번 조금 달라지게) ──
    score += c.rng.nextDouble() * 0.3;

    return _Scored(f, score, reasons);
  }

  static bool _isFried(FoodItem f) =>
      f.name.contains('튀김') || f.name.contains('돈까스') || f.name.contains('치킨') || f.name.contains('핫도그') || f.name.contains('크림') || f.name.contains('피자') || f.name.contains('세트');
  static bool _isSoup(FoodItem f) =>
      f.name.contains('국') || f.name.contains('탕') || f.name.contains('찌개') || f.name.contains('우동') || f.name.contains('라면') || f.name.contains('짬뽕') || f.name.contains('칼국수');
  static bool _isSpicy(FoodItem f) =>
      f.name.contains('김치') || f.name.contains('떡볶이') || f.name.contains('라볶이') || f.name.contains('짬뽕') || f.name.contains('마라') || f.name.contains('제육') || f.name.contains('닭갈비') || f.name.contains('비빔') ||
      f.name.contains('육개장') || f.name.contains('순두부') || f.name.contains('닭볶음탕') || f.name.contains('부대찌개') || f.name.contains('쫄면') || f.name.contains('양념치킨') || f.name.contains('닭강정') ||
      f.name.contains('마파두부') || f.name.contains('라면') || f.name.contains('라멘') || f.name.contains('뼈해장국') || f.name.contains('감자탕') || f.name.contains('매운');
  /// "건강한 걸로": 튀김 아님 + 덜 짬 + 기름 적음 + 단백질 있음 + 과자·음료·패스트푸드 아님
  static bool _isHealthy(FoodItem f) =>
      !_isFried(f) &&
      f.sodiumMg <= 1300 &&
      f.fatG <= 20 &&
      f.proteinG >= 12 &&
      f.kcal >= 250 &&
      (f.category != '패스트푸드' || f.name.contains('샐러드') || f.name.contains('서브웨이') || f.name.contains('그릴')) &&
      f.category != '간식' &&
      f.category != '음료';
  /// "채소 많은 걸로"
  static bool _isVeggie(FoodItem f) =>
      f.category == '샐러드' || f.name.contains('비빔밥') || f.name.contains('곤드레') || f.name.contains('포케') || f.name.contains('두부') || f.name.contains('나물') || f.name.contains('토마토') || f.name.contains('샐러드');
  /// "빨리 먹을 수 있는 걸로"
  static bool _isQuick(FoodItem f) =>
      f.category == '편의점' || f.category == '분식' || f.category == '패스트푸드' || f.name.contains('김밥') || f.name.contains('샌드위치') || f.name.contains('토스트');
  static bool _isCold(FoodItem f) =>
      f.name.contains('냉면') || f.name.contains('소바') || f.name.contains('비빔국수') || f.category == '샐러드' || f.name.contains('포케') || f.name.contains('요거트') || f.name.contains('스무디');
  static bool _isSeafood(FoodItem f) => f.name.contains('연어') || f.name.contains('새우') || f.name.contains('참치') || f.name.contains('생선') || f.name.contains('해물');
  static bool _hasMeat(FoodItem f) =>
      _isSeafood(f) ||
      f.name.contains('고기') || f.name.contains('제육') || f.name.contains('치킨') || f.name.contains('닭') || f.name.contains('돈까스') || f.name.contains('햄') || f.name.contains('스팸') ||
      f.name.contains('오리') || f.name.contains('규동') || f.name.contains('순대') || f.name.contains('핫도그') || f.name.contains('버거') || f.name.contains('피자') || f.name.contains('만두') || f.name.contains('짬뽕') || f.name.contains('마라');

  /// 음식별 "더 잘 먹는 법" 팁
  static List<String> _tipsFor(FoodItem f) {
    final tips = <String>[];
    if (_isSoup(f) && f.sodiumMg >= 1300) tips.add('국물은 반만');
    if (f.name.contains('라면') || f.name.contains('컵라면')) tips.add('계란 하나 넣기');
    if (f.name.contains('떡볶이')) tips.add('계란이나 어묵 추가해서 단백질 채우기');
    if (f.name.contains('김밥')) tips.add('삼각김밥이면 우유나 두유 하나 같이');
    if (f.category == '패스트푸드' && f.name.contains('세트')) tips.add('콜라는 제로로, 감자는 반만');
    if (f.name.contains('버거')) tips.add('세트 대신 단품 + 우유');
    if (f.name.contains('짜장') || f.name.contains('볶음밥')) tips.add('단무지 말고 양파 위주로');
    if (f.name.contains('덮밥')) tips.add('밥은 3분의 2만, 고기는 다');
    if (f.name.contains('샐러드')) tips.add('드레싱은 반만 뿌리기');
    if (f.category == '음료' && f.carbG >= 30) tips.add('작은 사이즈로, 밥 대신은 안 돼');
    if (f.name.contains('치킨')) tips.add('껍질은 조금 남기고 살 위주로');
    if (f.name.contains('마라')) tips.add('국물 안 마시기 + 두부·채소 많이');
    return tips;
  }

  // ─────────────────────────────────────────────────────────
  //  다양하게 3개 고르기
  // ─────────────────────────────────────────────────────────
  static List<_Scored> _pickDiverse(List<_Scored> scored, _Context c, {int count = 3}) {
    scored.sort((a, b) => b.score.compareTo(a.score));
    final picks = <_Scored>[];
    final usedCat = <String>{};
    final keepCategoryUnique = c.category == null && !c.wantSnack;

    List<_Scored> buildPool() {
      final pool = <_Scored>[];
      for (final s in scored) {
        if (picks.contains(s)) continue;
        if (keepCategoryUnique && usedCat.contains(s.food.category)) continue;
        pool.add(s);
        if (pool.length >= 4) break;
      }
      return pool;
    }

    // 자리 하나마다: 조건에 맞는 상위 4개 후보 중에서 점수 가중 추첨
    // (예전엔 무조건 1등 → 몸 상태가 같으면 매번 같은 답이 나왔어요)
    const weights = [0.5, 0.25, 0.15, 0.10];
    while (picks.length < count) {
      var pool = buildPool();
      if (pool.isEmpty && keepCategoryUnique && usedCat.isNotEmpty) {
        usedCat.clear(); // 종류를 한 바퀴 다 썼으면 두 번째 바퀴 허용 (후보 8개 뽑을 때)
        pool = buildPool();
      }
      if (pool.isEmpty) break;
      var roll = c.rng.nextDouble();
      var chosen = pool.length - 1;
      for (var i = 0; i < pool.length; i++) {
        roll -= weights[i];
        if (roll <= 0) {
          chosen = i;
          break;
        }
      }
      picks.add(pool[chosen]);
      usedCat.add(pool[chosen].food.category);
    }
    // 그래도 못 채웠으면 나머지는 점수순
    for (final s in scored) {
      if (picks.length >= count) break;
      if (!picks.contains(s)) picks.add(s);
    }
    return picks;
  }

  // ─────────────────────────────────────────────────────────
  //  문장 만들기 (틀을 여러 개 두고 돌려 써요)
  // ─────────────────────────────────────────────────────────
  static String _compose(List<_Scored> picks, _Context c, AppState app) {
    final rng = c.rng;
    final meal = _mealName(c.hour);
    final tot = app.todayTotals;

    // 첫 줄
    final opener = <String>[
      if (c.soup) '따끈한 국물 땡기는 날이네. ',
      if (c.spicy) '매운 게 필요한 날이구나 🔥 ',
      if (c.cold) '시원한 걸로 골라봤어. ',
      if (c.quick) '빨리 먹어야 하니까 바로 살 수 있는 걸로. ',
      if (c.stressed) '오늘 힘들었지? 기분 풀리면서도 몸엔 괜찮은 걸로. ',
      if (c.exam) '시험 전엔 배부르면 졸려 — 적당히 채우는 걸로 골랐어. ',
      if (c.budget) '가성비로 골랐어. ',
      if (c.light) '가볍지만 영양은 있는 걸로. ',
      if (c.heavy) '든든하게 가자. ',
      if (c.healthy) '건강하게 가자 🥗 덜 짜고 기름 적은 걸로 골랐어. ',
      if (c.veggie) '채소 듬뿍으로 골랐어 🥬 ',
      if (c.proteinWeight > 1 && !c.healthy) '단백질 위주로 골랐어 💪 ',
      if (c.meat) '고기로 골랐어 🥩 ',
      if (c.seafood) '해산물로 골랐어 🐟 ',
    ].join();

    final situation = tot.kcal == 0
        ? [
            '아직 오늘 기록이 없어서 하루 목표 기준으로 골랐어.',
            '오늘 첫 끼구나. 하루 목표에 맞춰서 시작해보자.',
            '기록이 비어 있어서 몸 상태 기준으로 골랐어.',
          ][rng.nextInt(3)]
        : c.sodiumHigh
            ? '오늘 짠 걸 많이 먹었더라 — 이번엔 덜 짠 걸로 골랐어.'
            : c.eatenCategoriesToday.isNotEmpty
                ? '오늘 ${c.eatenCategoriesToday.join('·')} 먹었으니까 다른 종류로 골랐어. 남은 건 ${c.remainKcal.round()}kcal, 단백질 ${c.remainProtein.round()}g.'
                : '오늘 에너지 ${c.remainKcal.round()}kcal, 단백질 ${c.remainProtein.round()}g 더 채우면 딱 좋아.';

    final buf = StringBuffer();
    // 인바디 한 줄 + 오늘 방향 (왜 이렇게 골랐는지 먼저)
    final plan = c.plan;
    buf.writeln('📊 ${app.profile!.nickname} 인바디: ${plan.bodyLine}');
    buf.writeln('→ ${plan.reasons.take(2).join(' / ')}\n');
    buf.writeln('$opener${opener.isEmpty ? '$meal 추천이야. ' : ''}$situation\n');

    final labels = c.category != null || c.wantSnack ? ['①', '②', '③'] : ['🥇 오늘의 픽', '🥈 다른 느낌으로', '🥉 이것도 괜찮아'];
    for (var i = 0; i < picks.length; i++) {
      final s = picks[i];
      final f = s.food;
      buf.writeln('${labels[i]}  ${f.name}  (${f.kcal.round()}kcal · 단백질 ${f.proteinG.round()}g)');
      final why = s.reasons.isEmpty ? _fallbackWhy(f, c, rng) : s.reasons.take(2).join(', ');
      buf.writeln('   → $why');
      final tip = _tipsFor(f);
      if (tip.isNotEmpty && rng.nextBool()) buf.writeln('   💡 ${tip.first}');
      final stores = _nearbyStoresFor(f, app.nearbyPlaces, c);
      if (stores.isNotEmpty) buf.writeln('   📍 ${stores.join(', ')}');
    }

    // 마무리 한 줄 (몸 상태에 맞춰 돌려가며)
    final a = c.analysis;
    final closer = <String>[
      if (c.light) '성장기엔 끼니를 빼는 것보다 "튀김·단 음료를 바꾸는" 게 훨씬 좋아. 그래서 굶는 추천은 안 했어.',
      if (a.shape == BodyShape.c) '지금 몸은 단백질을 챙길수록 근육이 붙고 지방은 빠지는 시기야. 매 끼 단백질 반찬 하나!',
      if (a.shape == BodyShape.d) '운동 많이 하는 몸이라 탄수화물(밥)을 줄이면 오히려 근육이 빠져. 밥은 꼭.',
      if (a.fatJudge == '낮음') '체지방이 낮은 편이라 끼니 거르면 바로 힘 빠져. 간식도 챙겨.',
      '다른 느낌 원하면 "다른 거", "매운 거", "국물", "편의점"처럼 말해줘.',
      '먹은 걸 "끼니 기록"에 적으면 다음 추천이 더 정확해져.',
      '"○○ 먹어도 돼?"라고 물어보면 판정해줄게.',
    ];
    buf.write('\n${closer[rng.nextInt(closer.length)]}');
    if (app.nearbyPlaces.isNotEmpty && rng.nextBool()) buf.write('\n가게 이름을 식당 탭 검색창에 넣으면 바로 예약돼.');
    return buf.toString();
  }

  static String _fallbackWhy(FoodItem f, _Context c, Random rng) {
    final opts = <String>[
      if (f.proteinG >= 15) '단백질 ${f.proteinG.round()}g이 들어 있어',
      if (f.kcal <= 450) '가볍게 먹기 좋아',
      if (f.kcal >= 650 && c.remainKcal >= 700) '남은 에너지를 든든하게 채워줘',
      if (f.category == '샐러드') '채소도 같이 챙겨져',
      if (f.category == '편의점') '편의점에서 바로 살 수 있어',
      '오늘 남은 영양을 골고루 채워줘',
    ];
    return opts[rng.nextInt(opts.length)];
  }

  // ─────────────────────────────────────────────────────────
  //  근처 가게 매칭 (v3: 가게 회전)
  //  예전엔 "제일 가까운 2곳"을 고정으로 붙여서 늘 같은 가게가 나왔어요.
  //  이제는 어울리는 가게 전체 중에서 거리 가중 무작위로 뽑고,
  //  최근 추천한 가게는 빼요. 제휴 가게(★)는 살짝 가산점.
  // ─────────────────────────────────────────────────────────
  static List<String> _nearbyStoresFor(FoodItem f, List<Place> places, _Context c) {
    final keys = _placeKeywords(f);
    if (keys.isEmpty || places.isEmpty) return const [];
    final hits = places.where((p) {
      final text = '${p.name} ${p.category}'.toLowerCase();
      return keys.any((k) => text.contains(k));
    }).toList();
    final picked = RecommendationMemory.rotatePlaces(
      hits,
      avoid: [...c.recentPlaces, ...c.usedPlaces],
      count: 2,
      rng: c.rng,
    );
    c.usedPlaces.addAll(picked.map((p) => p.name)); // 같은 답 안에서 가게 안 겹치게
    return picked.map((p) => '${MenuCatalog.isPartner(p) ? '★' : ''}${p.name} (${p.distanceText})').toList();
  }

  static List<String> _placeKeywords(FoodItem f) {
    final n = f.name;
    if (n.contains('덮밥') || n.contains('규동')) return ['덮밥', '규동', '일식', '한식'];
    if (n.contains('찌개') || n.contains('백반') || n.contains('국밥') || n.contains('정식')) return ['찌개', '백반', '국밥', '한식', '정식'];
    if (n.contains('비빔밥') || n.contains('곤드레')) return ['비빔밥', '한식'];
    if (n.contains('돈까스')) return ['돈까스', '돈가스', '일식'];
    if (n.contains('김밥') || n.contains('삼각김밥')) return ['김밥', '분식'];
    if (n.contains('카레')) return ['카레', '인도', '일식'];
    if (n.contains('볶음밥') || n.contains('짜장') || n.contains('짬뽕')) return ['중식', '중국', '짜장', '짬뽕'];
    if (n.contains('마라')) return ['마라', '중식'];
    if (n.contains('쌀국수')) return ['쌀국수', '베트남'];
    if (n.contains('국수') || n.contains('칼국수')) return ['국수', '칼국수', '한식'];
    if (n.contains('냉면')) return ['냉면'];
    if (n.contains('소바') || n.contains('우동')) return ['소바', '우동', '일식'];
    if (n.contains('라면') || n.contains('라볶이') || n.contains('떡볶이') || n.contains('순대') || n.contains('튀김') || n.contains('어묵') || n.contains('만두') || n.contains('토스트')) {
      return ['분식', '떡볶이', '만두', '토스트'];
    }
    if (n.contains('파스타') || n.contains('오므라이스')) return ['파스타', '양식', '이탈리', '경양식'];
    if (n.contains('버거') || n.contains('감자튀김') || n.contains('랩') || n.contains('서브웨이')) return ['햄버거', '버거', '패스트푸드', '서브웨이', '샌드위치'];
    if (n.contains('치킨') || n.contains('닭갈비')) return ['치킨', '닭갈비'];
    if (n.contains('피자')) return ['피자'];
    if (n.contains('핫도그')) return ['핫도그', '패스트푸드'];
    if (n.contains('샐러드') || n.contains('포케') || n.contains('요거트')) return ['샐러드', '포케', '샌드위치'];
    if (n.contains('샌드위치')) return ['샌드위치', '카페', '베이커리'];
    if (n.contains('오리')) return ['오리', '한식'];
    if (n.contains('생선')) return ['생선', '한식'];
    return const [];
  }
}

// ═══════════════════════════════════════════════════════════
//  도우미 클래스들
// ═══════════════════════════════════════════════════════════
class _Scored {
  final FoodItem food;
  final double score;
  final List<String> reasons;
  _Scored(this.food, this.score, this.reasons);
}

/// 질문 + 시간 + 오늘 먹은 것 + 몸 상태를 한 묶음으로
class _Context {
  final NutritionTargets t;
  final BodyAnalysis analysis;
  final int hour;
  final Random rng;
  final double remainKcal, remainProtein, remainCarb, remainFat, remainSodium;
  final bool sodiumHigh;
  final Set<String> eatenCategoriesToday;
  final Set<String> eatenNamesToday;
  final Map<String, int> weekCounts;
  final Set<String> recentlyRecommended;
  final Set<String> excludeNames;
  final Map<String, int> foodRecency; // 메뉴 이름 → 얼마나 최근에 추천했는지 (0 = 직전)
  final List<String> recentPlaces; // 최근 추천한 가게 (가장 최근 것부터)
  final MealPlan plan; // 인바디 기반 이번 끼니 방향
  final List<String> usedPlaces = []; // 이번 답변에서 이미 붙인 가게

  // 질문 힌트
  final String? category;
  final double proteinWeight, carbWeight;
  final bool light, heavy, wantSnack, wantDrink, budget, soup, spicy, cold, greasyNo, quick, stressed, exam, seafood, meat, noMeat;
  final bool healthy, veggie;

  /// 학생이 말한 조건들을 "거름망"으로 (음식이 조건을 만족하는지 보는 함수들)
  List<bool Function(FoodItem)> get intentFilters => [
        if (spicy) LocalCoach._isSpicy,
        if (soup) LocalCoach._isSoup,
        if (cold) LocalCoach._isCold,
        if (healthy) LocalCoach._isHealthy,
        if (veggie) LocalCoach._isVeggie,
        if (proteinWeight > 1) (f) => f.proteinG >= 22,
        if (meat) (f) => LocalCoach._hasMeat(f) && !LocalCoach._isSeafood(f),
        if (seafood) LocalCoach._isSeafood,
        if (quick) LocalCoach._isQuick,
        if (light) (f) => f.kcal <= 500,
        if (heavy) (f) => f.kcal >= 600,
        if (greasyNo) (f) => f.fatG <= 18 && !LocalCoach._isFried(f),
      ];

  /// 학생이 말한 조건들을 짧은 말로
  List<String> get intentLabels => [
        if (spicy) '매운 거',
        if (soup) '국물 있는 거',
        if (cold) '시원한 거',
        if (healthy) '건강한 거(덜 짜고 기름 적게)',
        if (veggie) '채소 많은 거',
        if (proteinWeight > 1) '단백질 많은 거',
        if (meat) '고기',
        if (seafood) '해산물',
        if (quick) '빨리 먹을 수 있는 거',
        if (light) '가벼운 거',
        if (heavy) '든든한 거',
        if (greasyNo) '안 느끼한 거',
        if (budget) '5천 원 안팎',
        if (exam) '시험 전',
        if (wantSnack) '간식',
        if (category != null) '$category 종류',
      ];

  _Context({
    required this.t,
    required this.analysis,
    required this.hour,
    required this.rng,
    required this.remainKcal,
    required this.remainProtein,
    required this.remainCarb,
    required this.remainFat,
    required this.remainSodium,
    required this.sodiumHigh,
    required this.eatenCategoriesToday,
    required this.eatenNamesToday,
    required this.weekCounts,
    required this.recentlyRecommended,
    required this.excludeNames,
    required this.foodRecency,
    required this.recentPlaces,
    required this.plan,
    required this.category,
    required this.proteinWeight,
    required this.carbWeight,
    required this.light,
    required this.heavy,
    required this.wantSnack,
    required this.wantDrink,
    required this.budget,
    required this.soup,
    required this.spicy,
    required this.cold,
    required this.greasyNo,
    required this.quick,
    required this.stressed,
    required this.exam,
    required this.seafood,
    required this.meat,
    required this.noMeat,
    this.healthy = false,
    this.veggie = false,
  });

  static _Context from(String q, AppState app) {
    final t = app.targets!;
    final tot = app.todayTotals;
    final now = DateTime.now();
    // "저녁 추천해줘"처럼 끼니를 직접 말했으면 시계 대신 그 끼니의 시각으로 계산해요
    final askedMeal = app.mealAskedFor(q);
    final effectiveHour = askedMeal == null ? now.hour : MealHint.hourFor(askedMeal);
    final plan = MealPlan.from(p: app.profile!, t: t, today: tot, meal: askedMeal ?? MealHint.fromClock(now.hour));

    // 오늘 먹은 것
    final today = app.todayEntries;
    final eatenCats = today.map((e) => e.food.category).toSet();
    final eatenNames = today.map((e) => e.food.name).toSet();

    // 이번 주 먹은 횟수 (앱이 최근 7일 기록을 갖고 있어요)
    final weekCounts = <String, int>{};
    for (final e in app.weekEntries) {
      weekCounts[e.food.name] = (weekCounts[e.food.name] ?? 0) + 1;
    }

    // 직전 AI 답변에 나왔던 음식 이름 (최근 답 2개) + 추천 기억 상자(3일치)
    final recent = <String>{};
    final assistantMsgs = app.chat.where((m) => !m.isUser).toList();
    for (final m in assistantMsgs.reversed.take(2)) {
      for (final f in FoodDatabase.all) {
        if (m.text.contains(f.name)) recent.add(f.name);
      }
    }
    final foodRecency = app.recMemory.recencyRank('food');
    for (final e in foodRecency.entries) {
      if (e.value == 0) recent.add(e.key); // 직전 답변 것
    }
    // "다른 거", "말고", "또" → 직전 추천은 아예 제외
    final wantsOther = q.contains('다른') || q.contains('말고') || q.contains('또') || q.contains('새로');
    final exclude = wantsOther ? Set<String>.from(recent) : <String>{};

    // 진짜 무작위: 같은 질문을 바로 또 해도 다른 조합이 나와요
    // (예전엔 "분 단위 + 질문" 시드라 같은 분에 같은 질문이면 답이 똑같았어요)
    final rng = Random();

    String? cat;
    if (q.contains('편의점') || q.contains('편도') || q.contains('cu') || q.contains('gs')) cat = '편의점';
    if (q.contains('샐러드') || q.contains('포케')) cat = '샐러드';
    if (q.contains('분식') || q.contains('떡볶이')) cat = '분식';
    if (q.contains('면') || q.contains('국수') || q.contains('라면') || q.contains('파스타')) cat = '면';
    if (q.contains('밥') || q.contains('덮밥') || q.contains('한식') || q.contains('백반')) cat = '밥';
    if (q.contains('햄버거') || q.contains('버거') || q.contains('피자') || q.contains('치킨') || q.contains('패스트')) cat = '패스트푸드';

    final sodiumHigh = tot.sodiumMg > t.sodiumMg * 0.8;

    return _Context(
      t: t,
      analysis: app.profile!.analysis,
      hour: effectiveHour,
      rng: rng,
      remainKcal: (t.kcal - tot.kcal).clamp(0, t.kcal).toDouble(),
      remainProtein: (t.proteinG - tot.proteinG).clamp(0, t.proteinG).toDouble(),
      remainCarb: (t.carbG - tot.carbG).clamp(0, t.carbG).toDouble(),
      remainFat: (t.fatG - tot.fatG).clamp(0, t.fatG).toDouble(),
      remainSodium: (t.sodiumMg - tot.sodiumMg).clamp(0, t.sodiumMg).toDouble(),
      sodiumHigh: sodiumHigh,
      eatenCategoriesToday: eatenCats,
      eatenNamesToday: eatenNames,
      weekCounts: weekCounts,
      recentlyRecommended: recent,
      excludeNames: exclude,
      foodRecency: foodRecency,
      recentPlaces: app.recMemory.recentPlaces(limit: 8),
      plan: plan,
      category: cat,
      proteinWeight: (q.contains('단백질') || q.contains('근육') || q.contains('운동') || q.contains('헬스')) ? 3.0 : 1.0,
      carbWeight: (q.contains('힘') || q.contains('체력') || q.contains('축구') || q.contains('농구')) ? 1.5 : 1.0,
      light: q.contains('가볍') || q.contains('간단') || q.contains('다이어트') || q.contains('살빼') || q.contains('덜먹') || q.contains('배안고'),
      heavy: q.contains('든든') || q.contains('배고') || q.contains('많이') || q.contains('푸짐') || q.contains('굶'),
      wantSnack: q.contains('간식') || q.contains('디저트') || q.contains('달달') || q.contains('군것질'),
      wantDrink: q.contains('음료') || q.contains('마실') || q.contains('마시'),
      budget: q.contains('천원') || q.contains('싸') || q.contains('저렴') || q.contains('돈없') || q.contains('가성비') || RegExp(r'[3-5]000').hasMatch(q),
      soup: q.contains('국물') || q.contains('따뜻') || q.contains('따끈') || q.contains('추워') || q.contains('추운') || q.contains('뜨끈') || q.contains('해장'),
      spicy: q.contains('매운') || q.contains('매콤') || q.contains('맵') || q.contains('얼큰') || q.contains('스트레스풀'),
      cold: q.contains('시원') || q.contains('더워') || q.contains('더운') || q.contains('차가운') || q.contains('상큼'),
      greasyNo: q.contains('느끼') || q.contains('안느끼') || q.contains('담백') || q.contains('속안좋') || q.contains('체했'),
      quick: q.contains('빨리') || q.contains('시간없') || q.contains('급해') || q.contains('바로') || q.contains('간편') || q.contains('학원가기전'),
      stressed: q.contains('힘들') || q.contains('우울') || q.contains('짜증') || q.contains('기분') || q.contains('위로') || q.contains('스트레스'),
      exam: q.contains('시험') || q.contains('공부') || q.contains('졸리') || q.contains('집중'),
      seafood: q.contains('해산물') || q.contains('생선') || q.contains('회') || q.contains('연어'),
      meat: (q.contains('고기') || q.contains('육식')) && !q.contains('고기말고') && !q.contains('고기빼고'),
      noMeat: q.contains('채식') || q.contains('고기말고') || q.contains('고기빼고') || q.contains('비건'),
      healthy: q.contains('건강') || q.contains('영양') || q.contains('균형') || q.contains('클린'),
      veggie: q.contains('채소') || q.contains('야채'),
    );
  }
}
