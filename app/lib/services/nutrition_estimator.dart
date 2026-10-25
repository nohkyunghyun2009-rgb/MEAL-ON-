import 'dart:convert';

import '../data/food_database.dart';
import '../data/partner_menus.dart';
import '../models/nutrition.dart';
import 'claude_service.dart' show ChatMessage;
import 'gemini_service.dart';

/// ═══════════════════════════════════════════════════════════
///  "먹은 거 적으면 칼로리를 알아서 계산" 하는 추정기
///
///  순서: ① 앱 음식 목록(200개)에서 찾기 → ② 제휴 식당 메뉴판에서 찾기
///        → ③ Gemini에게 물어보기(키 있으면) → ④ 키워드로 대략 추정
///  "치킨 3조각", "참치김밥 한 줄", "피자 2조각 반" 처럼 양도 같이 읽어요.
/// ═══════════════════════════════════════════════════════════
class Estimate {
  final FoodItem food; // 1회 분량 기준 영양 (양은 servings로)
  final double servings; // 글에서 읽은 양 (없으면 1)
  final String source; // 어디서 나온 숫자인지
  final String note; // 한 줄 설명
  const Estimate({required this.food, required this.servings, required this.source, required this.note});

  double get kcalTotal => food.kcal * servings;
}

class NutritionEstimator {
  /// 전체 흐름 (인터넷이 필요한 건 Gemini뿐이에요)
  static Future<Estimate> estimate(String text) async {
    final local = fromLocal(text);
    if (local != null) return local;

    if (GeminiService.ready) {
      try {
        final ai = await _fromGemini(text);
        if (ai != null) return ai;
      } catch (_) {
        // 인터넷·키 문제면 조용히 대략 추정으로
      }
    }
    return fromHeuristic(text);
  }

  // ─────────────────────────────────────────────
  //  양 읽기: "3조각", "한 줄", "반 그릇", "2개"
  // ─────────────────────────────────────────────
  static const _units = ['인분', '그릇', '줄', '컵', '잔', '봉지', '판', '마리', '조각', '개', '장', '병', '캔', '공기', '접시'];
  static const _koreanNums = {'한': 1.0, '두': 2.0, '세': 3.0, '네': 4.0, '다섯': 5.0, '반': 0.5, '하나': 1.0, '둘': 2.0, '셋': 3.0};

  /// (양 뺀 이름, 숫자, 단위) — "치킨 3조각" → ("치킨", 3, "조각")
  static (String, double?, String?) parseQuantity(String text) {
    var t = text.trim();
    final unitAlt = _units.join('|');
    // 숫자 + 단위  (예: 3조각, 1.5인분, 2 개)
    final m1 = RegExp(r'(\d+(?:\.\d+)?)\s*(' + unitAlt + r')(?:\s*반)?').firstMatch(t);
    if (m1 != null) {
      var n = double.parse(m1.group(1)!);
      if (m1.group(0)!.endsWith('반')) n += 0.5;
      t = t.replaceFirst(m1.group(0)!, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
      return (t, n, m1.group(2));
    }
    // 한글 수 + 단위 (예: 한 줄, 두 개, 반 그릇)
    final m2 = RegExp(r'(한|두|세|네|다섯|반|하나|둘|셋)\s*(' + unitAlt + r')').firstMatch(t);
    if (m2 != null) {
      final n = _koreanNums[m2.group(1)!]!;
      t = t.replaceFirst(m2.group(0)!, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
      return (t, n, m2.group(2));
    }
    // 숫자만 (예: 김밥 2)
    final m3 = RegExp(r'\s(\d+(?:\.\d+)?)$').firstMatch(t);
    if (m3 != null) {
      final n = double.parse(m3.group(1)!);
      t = t.substring(0, m3.start).trim();
      return (t, n, null);
    }
    if (t.endsWith(' 반') || t.endsWith('반개') || t.endsWith('반그릇')) return (t.replaceAll(RegExp(r'\s*반(개|그릇)?$'), '').trim(), 0.5, null);
    return (t, null, null);
  }

  static String _norm(String s) => s.replaceAll(RegExp(r'[\s()+·,.\-_/]'), '').toLowerCase();

  /// 두 이름이 얼마나 비슷한지 (0~1)
  static double similarity(String a, String b) {
    final x = _norm(a), y = _norm(b);
    if (x.isEmpty || y.isEmpty) return 0;
    if (x == y) return 1;
    if (y.contains(x) || x.contains(y)) {
      final shorter = x.length < y.length ? x.length : y.length;
      final longer = x.length < y.length ? y.length : x.length;
      return 0.6 + 0.4 * shorter / longer; // 포함되면 최소 0.6
    }
    // 2글자 조각(bigram) 겹침
    Set<String> grams(String s) => {for (var i = 0; i + 1 < s.length; i++) s.substring(i, i + 2)};
    final ga = grams(x), gb = grams(y);
    if (ga.isEmpty || gb.isEmpty) return 0;
    final inter = ga.intersection(gb).length;
    return inter / (ga.length + gb.length - inter);
  }

  /// 이름 속 숫자+단위 ("후라이드치킨 3조각" → (3, 조각))
  static (double, String)? _unitInName(String name) {
    final m = RegExp(r'(\d+(?:\.\d+)?)\s*(' + _units.join('|') + r')').firstMatch(name);
    if (m == null) return null;
    return (double.parse(m.group(1)!), m.group(2)!);
  }

  /// 개수로 세는 음식인지 (계란, 빵, 과일…)
  static bool _isSingleThing(String n) =>
      n.contains('계란') || n.contains('빵') || n.contains('바나나') || n.contains('사과') || n.contains('고구마') || n.contains('김밥') || n.contains('만두') || n.contains('튀김');

  /// 목록 음식과 글의 양을 맞춰 "몇 인분"으로 바꿔요
  static double _servingsFor(FoodItem f, double? n, String? unit) {
    if (n == null) return 1;
    final inName = _unitInName(f.name);
    if (inName != null && unit != null && inName.$2 == unit) return n / inName.$1; // 피자 3조각 vs 피자 2조각 → 1.5
    if (inName != null && unit == null) return n / inName.$1;
    if (unit == '개' || unit == '조각' || unit == '장') {
      // 목록 음식이 1개짜리가 아니면(김밥 1줄 같은) 개수는 그대로 곱해요
      return n;
    }
    return n;
  }

  // ─────────────────────────────────────────────
  //  ① 앱 음식 목록  ② 제휴 메뉴판
  // ─────────────────────────────────────────────
  static Estimate? fromLocal(String text) {
    final (name, n, unit) = parseQuantity(text);
    if (_norm(name).length < 2) return null;

    // ① 앱 음식 목록 — 이름이 비슷한 정도 + 양 단위가 같으면 가산점
    //    ("치킨 3조각" → '치킨마요덮밥'이 아니라 '후라이드치킨 3조각'을 고르게)
    FoodItem? best;
    var bestScore = 0.0;
    for (final f in FoodDatabase.all) {
      var s = similarity(name, f.name);
      final inName = _unitInName(f.name);
      if (unit != null && inName != null) {
        s += inName.$2 == unit ? 0.2 : -0.1;
      } else if (unit != null && (unit == '조각' || unit == '개' || unit == '장') && inName == null && !_isSingleThing(f.name)) {
        s -= 0.05; // "3조각"이라고 했는데 조각으로 안 파는 음식(덮밥 등)은 살짝 뒤로
      }
      if (s > bestScore) {
        bestScore = s;
        best = f;
      }
    }
    if (best != null && bestScore >= 0.5) {
      return Estimate(
        food: best,
        servings: _servingsFor(best, n, unit),
        source: '앱 음식 목록',
        note: bestScore >= 0.99 ? '목록에 있는 음식이에요' : '"${best.name}"(으)로 계산했어요',
      );
    }

    // ② 제휴 식당 메뉴판 (kcal·단백질만 있어서 탄수화물·지방은 비율로 추정)
    MenuItem? bestMenu;
    var bestMenuScore = 0.0;
    String? storeKey;
    for (final e in MenuCatalog.partnerMenus.entries) {
      for (final m in e.value) {
        if (m.kcal < 50) continue; // 음료·사이드 제외
        final s = similarity(name, m.name.split('·').first);
        if (s > bestMenuScore) {
          bestMenuScore = s;
          bestMenu = m;
          storeKey = e.key;
        }
      }
    }
    if (bestMenu != null && bestMenuScore >= 0.55) {
      final food = _fromKcalProtein(bestMenu.name, bestMenu.kcal, bestMenu.proteinG);
      return Estimate(food: food, servings: n ?? 1, source: '제휴 식당 메뉴판 ($storeKey)', note: '메뉴판 칼로리 기준, 탄수화물·지방은 비율로 추정');
    }
    return null;
  }

  /// kcal·단백질만 알 때 나머지 채우기
  static FoodItem _fromKcalProtein(String name, double kcal, double protein, {String? category}) {
    final fried = name.contains('튀김') || name.contains('치킨') || name.contains('돈까스') || name.contains('피자') || name.contains('크림');
    final soup = name.contains('국') || name.contains('탕') || name.contains('찌개') || name.contains('라면') || name.contains('짬뽕');
    final fat = kcal * (fried ? 0.38 : 0.26) / 9;
    final carb = ((kcal - protein * 4 - fat * 9) / 4).clamp(0.0, 999.0);
    final sodium = soup ? 1600.0 : (fried ? 1200.0 : 900.0);
    return FoodItem(name: name, category: category ?? _guessCategory(name), kcal: kcal, carbG: carb, proteinG: protein, fatG: fat, sodiumMg: sodium);
  }

  static String _guessCategory(String n) {
    if (n.contains('샐러드') || n.contains('포케')) return '샐러드';
    if (n.contains('면') || n.contains('국수') || n.contains('라면') || n.contains('파스타') || n.contains('우동') || n.contains('짜장') || n.contains('짬뽕')) return '면';
    if (n.contains('떡볶이') || n.contains('순대') || n.contains('튀김') || n.contains('김밥')) return '분식';
    if (n.contains('버거') || n.contains('피자') || n.contains('치킨')) return '패스트푸드';
    if (n.contains('커피') || n.contains('라떼') || n.contains('음료') || n.contains('주스') || n.contains('우유') || n.contains('차')) return '음료';
    if (n.contains('빵') || n.contains('과자') || n.contains('케이크') || n.contains('아이스') || n.contains('초코') || n.contains('과일') || n.contains('귤') || n.contains('사과') || n.contains('바나나')) return '간식';
    return '밥';
  }

  // ─────────────────────────────────────────────
  //  ③ Gemini 에게 물어보기 (JSON으로만 답하게)
  // ─────────────────────────────────────────────
  static Future<Estimate?> _fromGemini(String text) async {
    const system = '''
너는 한국 음식 영양 추정기야. 학생이 먹은 음식을 글로 적으면, 그 글에 적힌 양 전체 기준으로 영양을 추정해.
반드시 아래 JSON 한 개만 출력해. 설명·마크다운·코드펜스 금지.
{"name":"음식 이름(짧게)","kcal":숫자,"carb_g":숫자,"protein_g":숫자,"fat_g":숫자,"sodium_mg":숫자,"category":"밥|면|분식|패스트푸드|편의점|샐러드|음료|간식 중 하나","confidence":"높음|보통|낮음"}
한국 식약처 영양성분 DB와 프랜차이즈 공개값을 참고한 평균값으로. 양이 안 적혀 있으면 보통 1인분으로.
''';
    final raw = await GeminiService().ask(system: system, history: [ChatMessage('user', text)], temperature: 0.2);
    final m = RegExp(r'\{[\s\S]*\}').firstMatch(raw);
    if (m == null) return null;
    final j = jsonDecode(m.group(0)!) as Map<String, dynamic>;
    double numOf(String k) => ((j[k] as num?) ?? 0).toDouble();
    final kcal = numOf('kcal');
    if (kcal <= 0) return null;
    final food = FoodItem(
      name: (j['name'] as String?)?.trim().isNotEmpty == true ? (j['name'] as String).trim() : text.trim(),
      category: FoodDatabase.categories.contains(j['category']) ? j['category'] as String : _guessCategory(text),
      kcal: kcal,
      carbG: numOf('carb_g'),
      proteinG: numOf('protein_g'),
      fatG: numOf('fat_g'),
      sodiumMg: numOf('sodium_mg'),
    );
    return Estimate(food: food, servings: 1, source: 'AI 추정 (Gemini)', note: '확신도 ${j['confidence'] ?? '보통'} · 적은 양 전체 기준');
  }

  // ─────────────────────────────────────────────
  //  ④ 키워드로 대략 추정 (인터넷 없을 때)
  // ─────────────────────────────────────────────
  /// (키워드들, kcal, 탄, 단, 지, 나트륨, 종류, 개수 단위인지)
  static const _table = <(List<String>, double, double, double, double, double, String, bool)>[
    (['치킨', '닭강정', '닭튀김'], 260, 10, 18, 16, 400, '패스트푸드', true), // 조각당
    (['피자'], 280, 30, 12, 12, 600, '패스트푸드', true), // 조각당
    (['햄버거', '버거'], 500, 45, 22, 24, 900, '패스트푸드', true),
    (['감자튀김', '감튀'], 330, 42, 4, 16, 250, '패스트푸드', false),
    (['라면', '라멘'], 500, 78, 10, 16, 1800, '면', false),
    (['국수', '우동', '냉면', '소바', '파스타', '짜장', '짬뽕', '쌀국수'], 600, 90, 20, 15, 1500, '면', false),
    (['김밥'], 480, 75, 14, 13, 1000, '밥', true), // 줄당
    (['떡볶이', '라볶이'], 500, 95, 9, 8, 1300, '분식', false),
    (['순대'], 380, 50, 14, 13, 800, '분식', false),
    (['튀김'], 120, 13, 2, 7, 150, '분식', true), // 개당
    (['만두', '교자'], 70, 8, 3, 3, 150, '분식', true), // 개당
    (['덮밥', '볶음밥', '비빔밥', '카레', '오므라이스', '규동', '돈부리'], 700, 95, 24, 20, 1300, '밥', false),
    (['찌개', '국밥', '탕', '전골', '백반', '정식', '한식', '떡국', '죽'], 600, 80, 26, 16, 1700, '밥', false),
    (['돈까스', '돈가스', '까스', '카츠'], 900, 95, 35, 38, 1400, '밥', false),
    (['삼겹살', '목살', '갈비', '소고기', '스테이크', '고기'], 850, 40, 40, 50, 1200, '밥', false),
    (['샐러드', '포케'], 380, 25, 25, 15, 600, '샐러드', false),
    (['샌드위치', '서브웨이', '토스트', '베이글'], 400, 42, 16, 16, 750, '편의점', true),
    (['삼각김밥', '주먹밥'], 180, 36, 4, 2, 400, '편의점', true),
    (['도시락', '컵밥', '밥버거'], 600, 85, 20, 20, 1300, '편의점', false),
    (['계란', '달걀'], 75, 1, 6, 5, 70, '편의점', true), // 개당
    (['닭가슴살'], 110, 1, 22, 2, 350, '편의점', true),
    (['우유', '두유'], 125, 10, 6, 7, 100, '음료', true),
    (['요거트', '요구르트'], 110, 15, 4, 3, 60, '편의점', true),
    (['아메리카노', '커피'], 10, 1, 0, 0, 5, '음료', true),
    (['라떼', '카페라떼'], 180, 16, 8, 9, 120, '음료', true),
    (['버블티', '밀크티'], 400, 70, 4, 10, 150, '음료', true),
    (['콜라', '사이다', '탄산'], 210, 54, 0, 0, 20, '음료', true),
    (['주스', '에이드', '스무디'], 150, 35, 1, 0, 20, '음료', true),
    (['물', '제로', '녹차', '보리차'], 0, 0, 0, 0, 0, '음료', true),
    (['빵', '크로와상', '도넛', '머핀', '케이크', '마카롱', '와플'], 320, 40, 6, 14, 300, '간식', true),
    (['과자', '칩', '스낵', '쿠키', '비스킷'], 350, 45, 4, 17, 350, '간식', false),
    (['초코', '초콜릿', '사탕', '젤리'], 250, 35, 3, 12, 100, '간식', false),
    (['아이스크림', '빙수'], 250, 32, 4, 11, 80, '간식', true),
    (['붕어빵', '호떡', '계란빵'], 150, 25, 3, 4, 100, '간식', true),
    (['바나나'], 100, 25, 1, 0, 1, '간식', true),
    (['사과', '배', '복숭아', '오렌지'], 95, 25, 0, 0, 2, '간식', true),
    (['귤', '키위', '자두'], 40, 10, 0, 0, 1, '간식', true),
    (['딸기', '포도', '방울토마토', '블루베리', '수박', '과일'], 60, 15, 1, 0, 2, '간식', false),
    (['견과', '아몬드', '땅콩', '호두'], 170, 6, 5, 15, 5, '간식', false),
    (['고구마', '감자', '옥수수'], 160, 36, 2, 0, 20, '간식', true),
    (['밥', '공기'], 300, 66, 5, 1, 5, '밥', true),
  ];

  static Estimate fromHeuristic(String text) {
    final (name, n, unit) = parseQuantity(text);
    final key = _norm(name);
    for (final row in _table) {
      final (keys, kcal, carb, prot, fat, sod, cat, perUnit) = row;
      if (keys.any((k) => key.contains(_norm(k)))) {
        final count = perUnit ? (n ?? 1) : (n ?? 1);
        // 세트/곱빼기/라지 같은 말은 양을 키워요
        var mult = 1.0;
        if (key.contains('세트')) mult *= 1.6;
        if (key.contains('곱빼기') || key.contains('대자') || key.contains('라지') || key.contains('큰')) mult *= 1.4;
        if (key.contains('작은') || key.contains('미니') || key.contains('소자')) mult *= 0.7;
        final food = FoodItem(name: name.trim().isEmpty ? text.trim() : name.trim(), category: cat, kcal: kcal * mult, carbG: carb * mult, proteinG: prot * mult, fatG: fat * mult, sodiumMg: sod * mult);
        return Estimate(
          food: food,
          servings: count,
          source: '대략 추정 (키워드)',
          note: perUnit && unit != null ? '${unit == '인분' ? '1인분' : '1$unit'}당 ${(kcal * mult).round()}kcal로 계산' : '비슷한 음식 평균값이에요. 숫자가 다르면 고쳐도 돼요',
        );
      }
    }
    // 아무 키워드도 없으면 "한 끼 보통" 값
    return Estimate(
      food: FoodItem(name: name.trim().isEmpty ? text.trim() : name.trim(), category: '밥', kcal: 500, carbG: 70, proteinG: 18, fatG: 15, sodiumMg: 900),
      servings: n ?? 1,
      source: '기본값',
      note: '무슨 음식인지 몰라서 한 끼 평균(500kcal)으로 넣었어요. 숫자를 고쳐주세요',
    );
  }
}
