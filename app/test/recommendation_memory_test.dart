import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hankki/services/kakao_local_service.dart';
import 'package:hankki/services/recommendation_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';

Place p(String name, String cat, int d) => Place(
      id: name,
      name: name,
      category: '음식점 > $cat',
      address: '',
      phone: '',
      lat: 0,
      lng: 0,
      distanceM: d,
      url: '',
    );

void main() {
  mealHintTests();
  final places = <Place>[
    p('현대옥 백마점', '한식', 80),
    p('꽉찬식당', '한식', 150),
    p('윤가네 김치찌개', '한식', 400),
    p('백마분식', '분식', 60),
    p('김밥천국 일산점', '분식', 300),
    p('잭슨블러바드 백마점', '피자', 120),
    p('피자스쿨 백마점', '피자', 500),
    p('동경규동', '일식', 200),
    p('정글우동', '일식', 700),
    p('샐러디 백마점', '샐러드', 900),
  ];

  group('이름 맞추기', () {
    test('지점명을 떼고도 가게를 알아봐요', () {
      expect(RecommendationMemory.coreName('잭슨블러바드 백마점'), '잭슨블러바드');
      expect(RecommendationMemory.coreName('모퉁이 테이블 일산마두점'), '모퉁이테이블');
      expect(RecommendationMemory.coreName('본죽'), '본죽');
      final text = '→ 근처: 잭슨 블러바드 (120m)'.replaceAll(' ', '');
      expect(RecommendationMemory.mentionsPlace(text, '잭슨블러바드 백마점'), isTrue);
      expect(RecommendationMemory.mentionsPlace(text, '현대옥 백마점'), isFalse);
    });

    test('메뉴 이름에서 숫자·단위를 떼요', () {
      expect(RecommendationMemory.foodKey('김밥 1줄'), '김밥');
      expect(RecommendationMemory.foodKey('삶은 계란 2개'), '삶은계란');
    });
  });

  group('AI용 가게 목록', () {
    test('최근 추천한 가게는 뒤로 빠지고, 종류별로 골고루 들어가요', () {
      final picked = RecommendationMemory.pickForPrompt(
        places,
        avoid: ['현대옥 백마점', '백마분식'],
        max: 6,
        rng: Random(1),
      );
      expect(picked.length, 6);
      expect(picked.map((x) => x.name), isNot(contains('현대옥 백마점')));
      expect(picked.map((x) => x.name), isNot(contains('백마분식')));
      // 5개 종류가 모두 한 번씩은 들어가요
      expect(picked.map((x) => x.shortCategory).toSet().length, 5);
    });

    test('호출할 때마다 순서가 달라져요', () {
      final a = RecommendationMemory.pickForPrompt(places, avoid: const [], rng: Random(1)).map((x) => x.name).toList();
      final b = RecommendationMemory.pickForPrompt(places, avoid: const [], rng: Random(2)).map((x) => x.name).toList();
      expect(a.toSet(), b.toSet()); // 같은 가게들이지만
      expect(a, isNot(equals(b))); // 순서는 다르게
    });

    test('가게가 모자라면 오래전에 추천한 가게부터 다시 넣어요', () {
      final picked = RecommendationMemory.pickForPrompt(
        places.take(3).toList(),
        avoid: ['현대옥 백마점', '꽉찬식당', '윤가네 김치찌개'],
        max: 3,
        rng: Random(1),
      );
      expect(picked.length, 3);
      expect(picked.first.name, '윤가네 김치찌개'); // 가장 오래전 것
    });
  });

  group('메뉴별 가게 회전', () {
    test('가까운 1등만 뽑히지 않고 돌아가며 나와요', () {
      final korean = places.where((x) => x.shortCategory == '한식').toList();
      final seen = <String>{};
      for (var i = 0; i < 40; i++) {
        final r = RecommendationMemory.rotatePlaces(korean, avoid: const [], count: 1, rng: Random(i));
        seen.add(r.single.name);
      }
      expect(seen.length, 3);
    });

    test('최근 추천한 가게는 피하고, 그 가게뿐이면 그때만 허용해요', () {
      final korean = places.where((x) => x.shortCategory == '한식').toList();
      for (var i = 0; i < 20; i++) {
        final r = RecommendationMemory.rotatePlaces(korean, avoid: ['현대옥 백마점'], count: 2, rng: Random(i));
        expect(r.map((x) => x.name), isNot(contains('현대옥 백마점')));
        expect(r.length, 2);
      }
      final only = RecommendationMemory.rotatePlaces([korean.first], avoid: ['현대옥 백마점'], count: 1);
      expect(only.single.name, '현대옥 백마점');
    });
  });

  group('기억하기', () {
    test('답변 글에서 가게·메뉴를 찾아 기록하고 최근 순으로 꺼내요', () async {
      SharedPreferences.setMockInitialValues({});
      final m = RecommendationMemory();
      await m.load();
      final found = await m.remember(
        '🥇 김밥 1줄 → 📍 백마분식 (60m)\n🥈 규동(소고기덮밥) → 📍 동경규동 (200m)',
        placeNames: places.map((x) => x.name),
        foodNames: const ['김밥 1줄', '규동(소고기덮밥)', '라면'],
      );
      expect(found, containsAll(['백마분식', '동경규동', '김밥 1줄', '규동(소고기덮밥)']));
      expect(found, isNot(contains('라면')));
      expect(m.recentPlaces(), containsAll(['백마분식', '동경규동']));
      expect(m.recencyRank('food')['김밥 1줄'], 0);

      // 앱을 껐다 켜도 남아 있어요
      final m2 = RecommendationMemory();
      await m2.load();
      expect(m2.recentPlaces(), containsAll(['백마분식', '동경규동']));
    });
  });
}

void mealHintTests() {
  group('끼니 힌트', () {
    test('질문에 적힌 끼니가 시계보다 우선해요', () {
      expect(MealHint.fromQuestion('저녁 추천해줘'), '저녁');
      expect(MealHint.fromQuestion('내일 아침 뭐 먹지'), '아침');
      expect(MealHint.fromQuestion('야식 땡겨'), '야식');
      expect(MealHint.fromQuestion('지금 뭐 먹으면 좋아?'), isNull);
      expect(MealHint.hourFor('저녁'), 18);
      expect(MealHint.fromClock(23), '야식');
    });
    test('AI가 "김치찌개"라고만 써도 "김치찌개 백반"으로 기억해요', () {
      expect(RecommendationMemory.foodCore('김치찌개 백반'), '김치찌개');
      expect(RecommendationMemory.foodCore('규동(소고기덮밥)'), '규동');
      expect(RecommendationMemory.foodCore('김밥 1줄'), '김밥');
    });
  });
}
