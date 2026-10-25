import 'package:flutter_test/flutter_test.dart';
import 'package:hankki/data/food_database.dart';
import 'package:hankki/models/body_profile.dart';
import 'package:hankki/models/nutrition.dart';
import 'package:hankki/services/local_coach.dart';
import 'package:hankki/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 스크린샷 상황 재현: D형 + 체수분 부족 + 오늘 짠 걸 많이 먹은 학생이 "매운 거"를 물었더니
/// 흰밥 한 공기·오트밀 컵이 나왔던 문제
void main() {
  late AppState app;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    app = AppState();
    await app.load();
    await app.setProfile(BodyProfile(
      nickname: '경현',
      sex: Sex.male,
      age: 17,
      heightCm: 178,
      weightKg: 66,
      bodyFatPercent: 13,
      skeletalMuscleKg: 34,
      bodyWaterPercent: 47,
      activity: ActivityLevel.high,
      measuredAt: DateTime(2026, 10, 1),
    ));
    // 오늘 이미 많이, 짜게 먹음
    final ramen = FoodDatabase.all.firstWhere((f) => f.name == '큰 컵라면+삼각김밥');
    final gukbap = FoodDatabase.all.firstWhere((f) => f.name == '순대국+밥');
    await app.addEntry(MealType.breakfast, ramen, 1);
    await app.addEntry(MealType.lunch, gukbap, 1);
  });

  const spicyWords = ['김치', '떡볶이', '라볶이', '짬뽕', '마라', '제육', '닭갈비', '비빔', '육개장', '순두부', '닭볶음탕', '부대찌개', '쫄면', '양념치킨', '닭강정', '마파두부', '라면', '라멘', '뼈해장국', '감자탕'];
  List<String> pickNames(String reply) =>
      reply.split('\n').where((l) => l.contains('🥇') || l.contains('🥈') || l.contains('🥉')).toList();

  test('"매운 거"라고 하면 세 개 전부 매운 메뉴예요 (흰밥·오트밀 금지)', () async {
    for (var i = 0; i < 5; i++) {
      final reply = await LocalCoach.reply('매운 거 먹고 싶어', app);
      await app.rememberRecommendation(reply);
      final picks = pickNames(reply);
      expect(picks.length, 3);
      for (final p in picks) {
        expect(spicyWords.any(p.contains), isTrue, reason: '안 매운 게 나왔어요: $p');
        expect(p.contains('흰밥') || p.contains('오트밀'), isFalse, reason: p);
      }
    }
  });

  test('"건강한 걸로"는 튀김·세트·패스트푸드 없이 덜 짠 메뉴만', () async {
    final cands = LocalCoach.candidates('건강한 걸로', app, count: 6);
    expect(cands.length, 6);
    for (final c in cands) {
      final n = c.food.name;
      expect(n.contains('튀김') || n.contains('돈까스') || n.contains('치킨') || n.contains('세트') || n.contains('피자'), isFalse, reason: n);
      expect(c.food.sodiumMg, lessThanOrEqualTo(1300), reason: n);
      expect(c.food.kcal, greaterThanOrEqualTo(250), reason: n);
    }
    expect(LocalCoach.intentsFor('건강한 걸로', app).join(), contains('건강'));
  });

  test('"가볍게"는 500kcal 이하, "든든하게"는 600kcal 이상, "단백질"은 22g 이상', () async {
    for (final c in LocalCoach.candidates('가볍게 먹을 수 있는 걸로', app, count: 5)) {
      expect(c.food.kcal, lessThanOrEqualTo(500), reason: c.food.name);
    }
    for (final c in LocalCoach.candidates('든든하게 먹고 싶어', app, count: 5)) {
      expect(c.food.kcal, greaterThanOrEqualTo(600), reason: c.food.name);
    }
    for (final c in LocalCoach.candidates('단백질 많은 걸로', app, count: 5)) {
      expect(c.food.proteinG, greaterThanOrEqualTo(22), reason: c.food.name);
    }
  });

  test('"채소 많은 걸로", "고기", "시원한 걸로"도 조건대로', () async {
    for (final c in LocalCoach.candidates('채소 많은 걸로', app, count: 4)) {
      final n = c.food.name;
      expect(c.food.category == '샐러드' || n.contains('샐러드') || n.contains('비빔밥') || n.contains('곤드레') || n.contains('포케') || n.contains('두부') || n.contains('토마토'), isTrue, reason: n);
    }
    for (final c in LocalCoach.candidates('고기 먹고 싶어', app, count: 4)) {
      final n = c.food.name;
      // 해산물·채소만 있는 건 "고기"가 아니에요
      expect(n.contains('연어') || n.contains('새우') || n.contains('참치') || n.contains('생선') || n.contains('두부 샐러드') || n.contains('요거트'), isFalse, reason: n);
    }
    for (final c in LocalCoach.candidates('시원한 걸로', app, count: 3)) {
      final n = c.food.name;
      expect(n.contains('냉면') || n.contains('소바') || n.contains('비빔국수') || n.contains('막국수') || c.food.category == '샐러드' || n.contains('포케') || n.contains('요거트') || n.contains('스무디') || n.contains('콩국수'), isTrue, reason: n);
    }
  });

  test('그냥 "뭐 먹지"라고 해도 반찬급(흰밥 한 공기, 닭가슴살 100g)은 메인으로 안 나와요', () async {
    for (var i = 0; i < 6; i++) {
      final reply = await LocalCoach.reply('지금 뭐 먹지?', app);
      await app.rememberRecommendation(reply);
      for (final p in pickNames(reply)) {
        expect(p.contains('한 공기') || p.contains('100g') || p.contains('어묵 2개') || p.contains('바나나'), isFalse, reason: p);
      }
    }
  });

  test('프롬프트에 요청 조건 줄이 들어가요', () {
    final prompt = app.buildSystemPrompt(question: '매운 거 먹고 싶어');
    expect(prompt, contains('[학생의 이번 요청 조건]'));
    expect(prompt, contains('매운 거'));
  });
}
