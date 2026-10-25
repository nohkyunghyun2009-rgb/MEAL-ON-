import 'package:flutter_test/flutter_test.dart';
import 'package:hankki/services/nutrition_estimator.dart';

void main() {
  group('양 읽기', () {
    test('숫자+단위, 한글 수, 반', () {
      expect(NutritionEstimator.parseQuantity('치킨 3조각'), ('치킨', 3.0, '조각'));
      expect(NutritionEstimator.parseQuantity('참치김밥 한 줄'), ('참치김밥', 1.0, '줄'));
      expect(NutritionEstimator.parseQuantity('밥 반 그릇'), ('밥', 0.5, '그릇'));
      expect(NutritionEstimator.parseQuantity('피자 2조각 반'), ('피자', 2.5, '조각'));
      expect(NutritionEstimator.parseQuantity('된장찌개'), ('된장찌개', null, null));
    });
  });

  group('앱 목록·메뉴판에서 찾기', () {
    test('목록에 있는 음식은 그대로, 양도 맞춰요', () {
      final e = NutritionEstimator.fromLocal('참치김밥 한 줄')!;
      expect(e.food.name, '참치김밥 1줄');
      expect(e.servings, 1);
      expect(e.source, '앱 음식 목록');
    });
    test('"치킨 3조각"은 덮밥이 아니라 "후라이드치킨 3조각" 1회분', () {
      final e = NutritionEstimator.fromLocal('치킨 3조각')!;
      expect(e.food.name, anyOf('후라이드치킨 3조각', '양념치킨 3조각')); // 둘 다 "치킨 3조각"이라 어느 쪽이든 OK
      expect(e.servings, 1);
      expect(e.kcalTotal, inInclusiveRange(700, 800));
    });
    test('"피자 3조각"은 목록의 "피자 2조각" × 1.5', () {
      final e = NutritionEstimator.fromLocal('피자 3조각')!;
      expect(e.food.name, '피자 2조각');
      expect(e.servings, 1.5);
      expect(e.kcalTotal, 840);
    });
    test('띄어쓰기·오타 비슷하면 찾아요', () {
      expect(NutritionEstimator.fromLocal('닭가슴살샐러드')!.food.name, '닭가슴살 샐러드');
      expect(NutritionEstimator.fromLocal('김치 찌개')!.food.name, '김치찌개 백반');
    });
    test('제휴 메뉴판 메뉴도 찾아요 (탄수화물·지방은 비율 추정)', () {
      final e = NutritionEstimator.fromLocal('까르보나라')!;
      expect(e.source, contains('제휴 식당 메뉴판'));
      expect(e.food.kcal, greaterThan(500));
      expect(e.food.carbG, greaterThan(0));
    });
    test('아예 모르는 말은 null', () {
      expect(NutritionEstimator.fromLocal('엄마가 싸준 도시락 특제'), isNull);
    });
  });

  group('키워드 대략 추정 (인터넷 없을 때)', () {
    test('개수 단위 음식은 개당 × 개수', () {
      final e = NutritionEstimator.fromHeuristic('귤 3개');
      expect(e.servings, 3);
      expect(e.food.kcal, 40);
      expect(e.kcalTotal, 120);
      expect(e.food.category, '간식');
    });
    test('세트·곱빼기는 양을 키워요', () {
      expect(NutritionEstimator.fromHeuristic('불고기버거 세트').food.kcal, 800);
      expect(NutritionEstimator.fromHeuristic('짜장면 곱빼기').food.kcal, greaterThan(700));
    });
    test('모르는 음식은 한 끼 기본값 500kcal + 안내', () {
      final e = NutritionEstimator.fromHeuristic('특제 비밀 요리');
      expect(e.food.kcal, 500);
      expect(e.source, '기본값');
    });
  });

  test('estimate()는 키 없을 때 목록 → 키워드 순으로 답해요', () async {
    expect((await NutritionEstimator.estimate('라면')).source, '앱 음식 목록');
    expect((await NutritionEstimator.estimate('할머니표 떡국')).food.category, '밥');
  });
}
