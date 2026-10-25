import 'package:flutter_test/flutter_test.dart';
import 'package:hankki/models/body_profile.dart';
import 'package:hankki/services/claude_service.dart';
import 'package:hankki/services/local_coach.dart';
import 'package:hankki/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "계속 똑같은 메뉴만 나온다" + "인바디를 반영하지 않는다" 를 직접 재현해서 확인하는 테스트
void main() {
  late AppState app;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    app = AppState();
    await app.load();
    await app.setProfile(BodyProfile(
      nickname: '민준',
      sex: Sex.male,
      age: 16,
      heightCm: 172,
      weightKg: 78,
      bodyFatPercent: 29, // 체지방 높음, 근육 적음 → C형
      skeletalMuscleKg: 25,
      activity: ActivityLevel.normal,
      measuredAt: DateTime(2026, 10, 1),
    ));
  });

  String topPick(String reply) => reply.split('\n').firstWhere((l) => l.contains('🥇'), orElse: () => '');

  test('같은 질문을 8번 해도 1등 메뉴가 계속 바뀌어요', () async {
    final tops = <String>{};
    for (var i = 0; i < 8; i++) {
      final reply = await LocalCoach.reply('지금 뭐 먹지?', app);
      await app.rememberRecommendation(reply); // 화면이 하는 것과 똑같이
      tops.add(topPick(reply));
    }
    expect(tops.length, greaterThanOrEqualTo(4), reason: '1등 메뉴가 거의 안 바뀌어요: $tops');
  });

  test('답 첫 줄에 인바디 요약이 붙고, C형이면 튀김류가 1등으로 안 나와요', () async {
    for (var i = 0; i < 6; i++) {
      final reply = await LocalCoach.reply('저녁 추천해줘', app);
      await app.rememberRecommendation(reply);
      expect(reply, contains('인바디'));
      expect(reply, contains('C형'));
      final top = topPick(reply);
      expect(top.contains('튀김') || top.contains('돈까스') || top.contains('치킨'), isFalse, reason: 'C형에 튀김류 1등: $top');
    }
  });

  test('"저녁 추천해줘" 다음에 "다른 거"라고 해도 저녁을 이어가요', () async {
    app.addChat(const ChatMessage('user', '저녁 추천해줘'));
    app.addChat(const ChatMessage('assistant', '(답)'));
    expect(LocalCoach.planFor('다른 거 추천해줘', app).meal, '저녁');
    final reply = await LocalCoach.reply('다른 거 추천해줘', app);
    expect(reply, contains('저녁 추천이야'));
    expect(app.buildSystemPrompt(question: '다른 거 추천해줘'), contains('추천할 끼니: "저녁"'));
  });

  test('이유 문장이 중복되지 않아요 (단백질 이유 두 번 금지)', () {
    for (final c in LocalCoach.candidates('저녁 추천해줘', app, count: 8)) {
      final proteinReasons = c.reasons.where((r) => r.contains('단백질')).length;
      expect(proteinReasons, lessThanOrEqualTo(1), reason: '${c.food.name}: ${c.reasons}');
    }
  });

  test('AI용 후보 8개는 종류가 섞여 있고, 인바디 방향 글이 만들어져요', () {
    final cands = LocalCoach.candidates('지금 뭐 먹지?', app, count: 8);
    expect(cands.length, 8);
    expect(cands.map((c) => c.food.category).toSet().length, greaterThanOrEqualTo(4));
    final plan = LocalCoach.planFor('저녁 추천해줘', app);
    expect(plan.meal, '저녁');
    expect(plan.needProtein, isTrue);
    final prompt = app.buildSystemPrompt(question: '저녁 추천해줘');
    expect(prompt, contains('[인바디 기반 이번 끼니 방향]'));
    expect(prompt, contains('[이번 끼니 후보 메뉴]'));
    expect(prompt, contains('1. '));
    expect(prompt, contains('추천할 끼니: "저녁"'));
  });
}
