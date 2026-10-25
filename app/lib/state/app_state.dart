import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_keys.dart';
import '../data/food_database.dart';
import '../data/partner_menus.dart';
import '../models/body_profile.dart';
import '../models/character.dart';
import '../models/nutrition.dart';
import '../services/claude_service.dart';
import '../services/kakao_local_service.dart';
import '../services/local_coach.dart';
import '../services/recommendation_memory.dart';

/// 앱의 "기억 상자".
/// 여러 화면이 같은 데이터를 보고, 바뀌면 자동으로 화면이 새로 그려져요.
class AppState extends ChangeNotifier {
  static const _kProfile = 'profile';
  static const _kEntries = 'entries';
  static const _kHistory = 'measurements'; // 측정 기록 (한 줄씩 쌓여요)

  BodyProfile? _profile;
  List<MealEntry> _entries = [];
  List<BodyProfile> _history = []; // 지금까지 잰 인바디 전부 (오래된 것부터)
  final List<ChatMessage> chat = []; // AI 대화 (앱을 끄면 사라져요)

  /// 추천 기억 상자: 최근에 어떤 가게·메뉴를 추천했는지 (폰에 저장, 3일 보관)
  /// → 같은 가게만 계속 나오는 걸 막아줘요
  final RecommendationMemory recMemory = RecommendationMemory();

  // 식당 찾기 탭이 받아온 "내 주변 1km 식당" (추천할 때 가게 이름을 붙이려고 기억해둬요)
  List<Place> nearbyPlaces = [];
  double? lastLat;
  double? lastLng;

  void setNearbyPlaces(List<Place> places, double lat, double lng) {
    nearbyPlaces = places;
    lastLat = lat;
    lastLng = lng;
    notifyListeners();
  }

  static const _zoneLat = 37.6562; // 백마 학원가 중심
  static const _zoneLng = 126.7893;

  /// 근처 식당 목록이 비어 있으면(식당 탭을 아직 안 열었으면) 백마 학원가 기준으로 받아와요.
  /// AI 추천 탭이 식당 탭보다 앞에 있어서, 이걸 안 하면 AI가 가게 이름 없이 뻔한 메뉴만 말했어요.
  Future<void> ensureNearbyPlaces() async {
    if (nearbyPlaces.isNotEmpty || !AppKeys.kakaoReady) return;
    try {
      final lat = lastLat ?? _zoneLat;
      final lng = lastLng ?? _zoneLng;
      final places = await KakaoLocalService().searchNearby(lat: lat, lng: lng, radiusM: 420);
      setNearbyPlaces(places, lat, lng);
    } catch (e) {
      debugPrint('근처 식당 불러오기 실패: $e');
    }
  }

  BodyProfile? get profile => _profile;
  bool get hasProfile => _profile != null;
  List<BodyProfile> get history => List.unmodifiable(_history);

  NutritionTargets? get targets =>
      _profile == null ? null : NutritionTargets.forProfile(_profile!);

  BodyInsight? get insight => _profile == null ? null : BodyInsight.from(_profile!);

  // ───── 폰에서 불러오기 (앱 켤 때 한 번) ─────
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    await recMemory.load();

    final p = prefs.getString(_kProfile);
    if (p != null) {
      _profile = BodyProfile.fromJson(jsonDecode(p) as Map<String, dynamic>);
    }

    final h = prefs.getString(_kHistory);
    if (h != null) {
      _history = (jsonDecode(h) as List<dynamic>)
          .map((x) => BodyProfile.fromJson(x as Map<String, dynamic>))
          .toList();
    } else if (_profile != null) {
      _history = [_profile!]; // 옛날 버전에서 저장한 게 있으면 첫 줄로
    }

    final e = prefs.getString(_kEntries);
    if (e != null) {
      final list = jsonDecode(e) as List<dynamic>;
      _entries = list
          .map((x) => MealEntry.fromJson(x as Map<String, dynamic>))
          .toList();
    }
    notifyListeners();
  }

  Future<void> _saveEntries() async {
    final prefs = await SharedPreferences.getInstance();
    // 최근 7일치만 남겨서 저장 공간 아끼기
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    _entries = _entries.where((e) => e.date.isAfter(cutoff)).toList();
    await prefs.setString(_kEntries, jsonEncode(_entries.map((e) => e.toJson()).toList()));
  }

  // ───── 인바디 정보 ─────
  Future<void> setProfile(BodyProfile p) async {
    _profile = p;
    _history = [..._history, p]; // 기록에 한 줄 추가
    if (_history.length > 60) _history = _history.sublist(_history.length - 60); // 최근 60번만
    chat.clear(); // 몸 정보가 바뀌면 AI 대화도 새로 시작
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kProfile, jsonEncode(p.toJson()));
    await prefs.setString(_kHistory, jsonEncode(_history.map((x) => x.toJson()).toList()));
  }

  // ───── 식사 기록 ─────
  List<MealEntry> get todayEntries {
    final now = DateTime.now();
    return _entries.where((e) => e.isSameDay(now)).toList();
  }

  /// 최근 7일 기록 전부 (추천 엔진이 "이번 주에 자주 먹은 것"을 볼 때 써요)
  List<MealEntry> get weekEntries => List.unmodifiable(_entries);

  List<MealEntry> entriesFor(MealType meal) =>
      todayEntries.where((e) => e.meal == meal).toList();

  NutritionTotals get todayTotals => NutritionTotals.sum(todayEntries);

  // ───── 밀온이 (다마고치) ─────
  bool _justAte = false; // 방금 먹었을 때 잠깐 기뻐하는 표정
  MilonState get milon => MilonState.build(
        allEntries: _entries,
        todayEntries: todayEntries,
        targets: targets,
        todayTotals: todayTotals,
        profile: _profile,
        justAte: _justAte,
      );

  /// 방금 먹은 기쁨 표정을 잠깐 켰다가 끄기 (홈에서 애니메이션용)
  void _flashJustAte() {
    _justAte = true;
    notifyListeners();
    Future.delayed(const Duration(seconds: 4), () {
      _justAte = false;
      notifyListeners();
    });
  }

  Future<void> addEntry(MealType meal, FoodItem food, double servings) async {
    _entries.add(MealEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      meal: meal,
      food: food,
      servings: servings,
      date: DateTime.now(),
    ));
    _flashJustAte(); // 밀온이가 방금 먹은 걸 기뻐해요
    notifyListeners();
    await _saveEntries();
  }

  Future<void> removeEntry(String id) async {
    _entries.removeWhere((e) => e.id == id);
    notifyListeners();
    await _saveEntries();
  }

  // ───── AI 대화 ─────
  void addChat(ChatMessage m) {
    chat.add(m);
    notifyListeners();
  }

  /// AI(또는 자체 추천)가 답한 글에서 가게·메뉴 이름을 찾아 기억해둬요.
  /// 다음 추천 때 "이건 방금 했으니 빼자"에 쓰여요.
  Future<void> rememberRecommendation(String reply) async {
    final found = await recMemory.remember(
      reply,
      placeNames: nearbyPlaces.map((p) => p.name),
      foodNames: FoodDatabase.all.map((f) => f.name),
    );
    if (found.isNotEmpty) notifyListeners();
  }

  /// 학생이 말한 끼니. 이번 질문에 없으면 최근 질문 4개까지 거슬러 봐요.
  /// ("저녁 추천해줘" → "다른 거" 를 저녁으로 이어가려고)
  String? mealAskedFor(String question) {
    final recent = [question, ...chat.reversed.where((m) => m.isUser).map((m) => m.text).take(4)];
    return MealHint.fromRecent(recent);
  }

  /// 최근에 추천한 가게 이름 (가장 최근 것부터)
  List<String> get recentPlaceNames => recMemory.recentPlaces();

  /// 최근에 추천한 메뉴 이름 (가장 최근 것부터)
  List<String> get recentFoodNames => recMemory.recentFoods();

  /// AI(Gemini/Claude)에게 보낼 "오늘의 상황 설명서"
  /// 몸 정보 + 오늘 먹은 것 + 남은 양 + ★인바디 기반 방향 + ★앱이 미리 고른 후보 메뉴를 글로 정리해요.
  /// 가게 이름이 붙으려면 먼저 ensureNearbyPlaces()를 기다려야 해요.
  String buildSystemPrompt({String? question}) {
    final p = _profile;
    final t = targets;
    final total = todayTotals;
    final hour = DateTime.now().hour;
    // 학생이 "저녁 추천해줘"처럼 끼니를 직접 말했으면 시계보다 그걸 우선해요
    final lastQuestion = question ?? (chat.isNotEmpty && chat.last.isUser ? chat.last.text : '');
    final askedMeal = mealAskedFor(lastQuestion);
    final nextMeal = askedMeal ?? MealHint.fromClock(hour);
    final mealNote = askedMeal != null
        ? '(학생이 이 대화에서 "$askedMeal"이라고 했어. 지금 시간이 늦어도 야식이 아니라 $askedMeal 메뉴로 추천해.)'
        : '';

    final eaten = todayEntries.isEmpty
        ? '아직 아무것도 기록하지 않음'
        : todayEntries
            .map((e) => '${e.meal.label}: ${e.food.name} ${e.servings}인분 (${e.kcal.round()}kcal)')
            .join(', ');

    String remain(double target, double eatenVal, String unit) {
      final r = target - eatenVal;
      return r > 0 ? '${r.round()}$unit 더 채우면 좋음' : '충분히 채움';
    }

    final body = p == null
        ? '몸 정보 없음'
        : '''
- 닉네임: ${p.nickname}, ${p.isMale ? '남' : '여'}, ${p.age}세
- 키 ${p.heightCm}cm, 몸무게 ${p.weightKg}kg, 체지방률 ${p.bodyFatPercent}%, 골격근량 ${p.skeletalMuscleKg}kg
- 활동량: ${p.activity.label}
- 몸 상태 요약: ${insight!.headline}
- 인바디 분석: ${p.analysis.summaryForAi}
- 특히 챙기면 좋은 것: ${insight!.focusNutrients.join(', ')}''';

    final budget = t == null
        ? ''
        : '''
[오늘 남은 양]
- 에너지: ${remain(t.kcal, total.kcal, 'kcal')} (목표 ${t.kcal.round()} / 지금 ${total.kcal.round()})
- 탄수화물: ${remain(t.carbG, total.carbG, 'g')}
- 단백질: ${remain(t.proteinG, total.proteinG, 'g')}
- 지방: ${remain(t.fatG, total.fatG, 'g')}
- 나트륨: 지금 ${total.sodiumMg.round()}mg / 목표 ${t.sodiumMg.round()}mg 이하''';

    // ── 근처 식당: 매번 "종류별로 골고루 + 순서 섞어서 + 최근 추천한 곳은 빼고" 보여줘요.
    //    예전엔 늘 "가까운 순 40곳"을 똑같이 보내서 AI가 앞쪽 가게만 골랐어요.
    final recentPlaces = recentPlaceNames;
    final recentFoods = recentFoodNames;
    final nearby = _nearbyForPrompt(recentPlaces);

    final avoidPlaces = recentPlaces.isEmpty ? '(없음)' : recentPlaces.join(', ');
    final avoidFoods = recentFoods.isEmpty ? '(없음)' : recentFoods.join(', ');

    // ── 인바디 기반 방향 + 앱이 미리 고른 후보 (AI는 이 안에서 고르기만) ──
    String planText = '(인바디 정보 없음 — 인바디를 먼저 적어달라고 말해)';
    String candidateText = '(인바디 정보가 없어서 후보를 못 만들었어)';
    String intentText = '(특별한 조건 없음)';
    if (p != null && t != null) {
      final intents = LocalCoach.intentsFor(lastQuestion, this);
      if (intents.isNotEmpty) intentText = '${intents.join(', ')} ← 후보 메뉴는 이미 이 조건으로 걸러져 있어. 조건에 안 맞는 메뉴는 절대 고르지 마.';
      planText = LocalCoach.planFor(lastQuestion, this).toPromptText();
      final cands = LocalCoach.candidates(lastQuestion, this, count: 8);
      if (cands.isNotEmpty) {
        candidateText = [
          for (var i = 0; i < cands.length; i++)
            '${i + 1}. ${cands[i].food.name} (${cands[i].food.kcal.round()}kcal · 단백질 ${cands[i].food.proteinG.round()}g · 나트륨 ${cands[i].food.sodiumMg.round()}mg)'
                '${cands[i].reasons.isEmpty ? '' : ' — ${cands[i].reasons.take(2).join(', ')}'}'
                '${cands[i].stores.isEmpty ? '' : ' — 📍 ${cands[i].stores.join(', ')}'}',
        ].join('\n');
      }
    }

    return '''
너는 "MEAL:ON(밀온)"이라는 청소년 건강 식단 앱의 친절한 메뉴 코치야. 고등학생과 대화해.

[인바디 기반 이번 끼니 방향] ← 제일 중요. 모든 추천 이유를 여기에 연결해.
$planText

[학생의 이번 요청 조건]
$intentText

[이번 끼니 후보 메뉴] ← 앱이 인바디·오늘 먹은 것·최근 추천·요청 조건을 반영해 고른 순서야. 메뉴 추천은 반드시 이 안에서 3개 골라.
$candidateText

[근처 1km 안 실제 식당 목록 — 종류별] (★ = 제휴 가게, 앱에서 바로 예약돼) — 후보에 📍가 없을 때만 여기서 가게를 골라
$nearby

[최근에 이미 추천한 가게 — 학생이 콕 집어 묻지 않는 한 이번엔 추천하지 마]
$avoidPlaces

[최근에 이미 추천한 메뉴 — 이번엔 다른 메뉴로]
$avoidFoods

[학생 정보]
$body

[오늘 먹은 것]
$eaten

$budget

[지금 시간] $hour시 · 추천할 끼니: "$nextMeal" $mealNote

[규칙]
1. 절대 "살 빼라", "굶어라", "칼로리 줄여라" 같은 말을 하지 마. 성장기니까 "무엇을 더 채우면 좋은지"로 말해.
2. 학원가 근처에서 실제로 살 수 있는 메뉴로 추천해 (덮밥, 국수, 분식, 샌드위치, 샐러드, 포케, 편의점 조합 등).
3. 메뉴 추천 형식 (꼭 지켜):
   첫 줄: "📊 네 인바디: ..." — [인바디 기반 방향]을 학생 말로 한 줄 (예: "골격근이 표준보다 적고 체지방은 살짝 높아서 오늘은 단백질 25g 이상, 튀김은 빼자").
   그 다음 3가지를 번호로. 각각: 메뉴 이름([후보 메뉴]에 적힌 이름 그대로) (kcal·단백질) → 이유 한 줄 → "📍 가게이름 (거리)".
   이유에는 인바디 수치(골격근·체지방·체형·체수분)와 오늘 남은 양 중 하나를 구체적으로 연결해. "맛있어서", "인기 있어서"는 이유가 아니야.
   3가지는 [후보 메뉴]에서만 고르고, 종류(밥·면·샐러드…)와 가게가 서로 다르게. 후보에 📍가 있으면 그 가게를 써. 목록에 없는 가게 이름을 지어내지 마.
4. 같은 가게를 연달아 추천하지 마. [최근에 이미 추천한 가게]에 있는 곳과, 이 대화에서 네가 이미 말한 가게·메뉴는
   학생이 콕 집어 다시 묻지 않는 한 또 추천하지 마. 연속으로 물어보면 매번 완전히 새로운 3곳을 골라.
   가까운 순서가 아니라 "오늘 몸에 맞는 메뉴가 있는 가게"를 골라 — 1km 안이면 조금 멀어도 괜찮아.
   목록은 매번 새로 섞여서 오니까, 이번 목록 안에서 골라. ★제휴 가게는 메뉴 예시가 적혀 있으니 그 메뉴 이름을 그대로 써.
5. 학생이 "다른 거", "말고"라고 하면 직전 답과 가게·메뉴 종류를 모두 다르게.
   학생이 끼니(아침/점심/저녁/야식)를 말하면 그 끼니에 맞는 메뉴로. 시간은 참고만 해.
6. 짧고 친근하게, 존댓말 대신 편한 반말 말투로. 200자 안팎.
7. 의학적 진단은 하지 마. 몸이 아프다고 하면 보건 선생님이나 병원을 권해.
''';
  }

  /// AI에게 보여줄 식당 목록 글 만들기 (종류별로 묶어서)
  String _nearbyForPrompt(List<String> recentPlaces) {
    if (nearbyPlaces.isEmpty) return '(아직 검색 전)';

    final picked = RecommendationMemory.pickForPrompt(
      nearbyPlaces,
      avoid: recentPlaces,
      rng: Random(),
    );

    // 종류별로 묶기 (같은 종류끼리 한 줄에)
    final groups = <String, List<Place>>{};
    for (final p in picked) {
      groups.putIfAbsent(p.shortCategory.isEmpty ? '기타' : p.shortCategory, () => []).add(p);
    }
    final lines = <String>[];
    for (final e in groups.entries) {
      final names = e.value.map((p) {
        if (!MenuCatalog.isPartner(p)) return '${p.name} (${p.distanceText})';
        // 제휴 가게는 진짜 메뉴판이 있으니 식사 메뉴 3개를 예시로 붙여요 (음료·사이드 제외)
        final menus = MenuCatalog.forPlace(p)
            .where((m) => m.kcal >= 250 && m.section != '음료' && m.section != '사이드')
            .take(3)
            .map((m) => '${m.name} ${m.price}원')
            .join('·');
        return '★${p.name} (${p.distanceText}${menus.isEmpty ? '' : ', 메뉴 예: $menus'})';
      }).join(', ');
      lines.add('- ${e.key}: $names');
    }
    return lines.join('\n');
  }
}
