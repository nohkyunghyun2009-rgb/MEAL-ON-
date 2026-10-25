import 'body_profile.dart';

/// 음식 한 가지 (1인분 기준 영양 정보)
class FoodItem {
  final String name;
  final String category; // 밥, 면, 분식, 패스트푸드, 편의점, 음료, 간식, 샐러드
  final double kcal;
  final double carbG;
  final double proteinG;
  final double fatG;
  final double sodiumMg;

  const FoodItem({
    required this.name,
    required this.category,
    required this.kcal,
    required this.carbG,
    required this.proteinG,
    required this.fatG,
    required this.sodiumMg,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'category': category,
        'kcal': kcal,
        'carbG': carbG,
        'proteinG': proteinG,
        'fatG': fatG,
        'sodiumMg': sodiumMg,
      };

  factory FoodItem.fromJson(Map<String, dynamic> j) => FoodItem(
        name: j['name'] as String,
        category: j['category'] as String,
        kcal: (j['kcal'] as num).toDouble(),
        carbG: (j['carbG'] as num).toDouble(),
        proteinG: (j['proteinG'] as num).toDouble(),
        fatG: (j['fatG'] as num).toDouble(),
        sodiumMg: (j['sodiumMg'] as num).toDouble(),
      );
}

/// 아침 / 점심 / 저녁 / 간식
enum MealType { breakfast, lunch, dinner, snack }

extension MealTypeInfo on MealType {
  String get label => switch (this) {
        MealType.breakfast => '아침',
        MealType.lunch => '점심',
        MealType.dinner => '저녁',
        MealType.snack => '간식',
      };

  String get emoji => switch (this) {
        MealType.breakfast => '🌅',
        MealType.lunch => '☀️',
        MealType.dinner => '🌙',
        MealType.snack => '🍪',
      };
}

/// "언제, 무엇을, 얼마나" 먹었는지 한 줄 기록
class MealEntry {
  final String id;
  final MealType meal;
  final FoodItem food;
  final double servings; // 0.5 = 반 그릇, 1 = 한 그릇, 2 = 두 그릇
  final DateTime date;

  const MealEntry({
    required this.id,
    required this.meal,
    required this.food,
    required this.servings,
    required this.date,
  });

  double get kcal => food.kcal * servings;
  double get carbG => food.carbG * servings;
  double get proteinG => food.proteinG * servings;
  double get fatG => food.fatG * servings;
  double get sodiumMg => food.sodiumMg * servings;

  bool isSameDay(DateTime other) =>
      date.year == other.year && date.month == other.month && date.day == other.day;

  Map<String, dynamic> toJson() => {
        'id': id,
        'meal': meal.name,
        'food': food.toJson(),
        'servings': servings,
        'date': date.millisecondsSinceEpoch,
      };

  factory MealEntry.fromJson(Map<String, dynamic> j) => MealEntry(
        id: j['id'] as String,
        meal: MealType.values.byName(j['meal'] as String),
        food: FoodItem.fromJson(j['food'] as Map<String, dynamic>),
        servings: (j['servings'] as num).toDouble(),
        date: DateTime.fromMillisecondsSinceEpoch(j['date'] as int),
      );
}

/// 오늘 먹은 것 전부 더한 값
class NutritionTotals {
  final double kcal, carbG, proteinG, fatG, sodiumMg;
  const NutritionTotals({
    this.kcal = 0,
    this.carbG = 0,
    this.proteinG = 0,
    this.fatG = 0,
    this.sodiumMg = 0,
  });

  static NutritionTotals sum(Iterable<MealEntry> entries) {
    double k = 0, c = 0, p = 0, f = 0, s = 0;
    for (final e in entries) {
      k += e.kcal;
      c += e.carbG;
      p += e.proteinG;
      f += e.fatG;
      s += e.sodiumMg;
    }
    return NutritionTotals(kcal: k, carbG: c, proteinG: p, fatG: f, sodiumMg: s);
  }
}

/// 청소년 하루 권장 섭취량
/// 기준: 2020 한국인 영양소 섭취기준(KDRIs) 12~14세 / 15~18세 표를 바탕으로 했어요.
/// 인바디에서 기초대사량을 적었다면 그 값도 절반 정도 반영해요.
class NutritionTargets {
  final double kcal, carbG, proteinG, fatG, sodiumMg;
  const NutritionTargets({
    required this.kcal,
    required this.carbG,
    required this.proteinG,
    required this.fatG,
    required this.sodiumMg,
  });

  static NutritionTargets forProfile(BodyProfile p) {
    // 1) 나이·성별로 기본 에너지와 단백질 정하기
    double kcal;
    double protein;
    if (p.age <= 14) {
      kcal = p.isMale ? 2500 : 2000;
      protein = p.isMale ? 60 : 55;
    } else if (p.age <= 18) {
      kcal = p.isMale ? 2700 : 2000;
      protein = p.isMale ? 65 : 55;
    } else {
      kcal = p.isMale ? 2600 : 2000;
      protein = p.isMale ? 65 : 55;
    }

    // 2) 활동량에 따라 조금 더 / 조금 덜
    final activityFactor = switch (p.activity) {
      ActivityLevel.low => 0.9,
      ActivityLevel.normal => 1.0,
      ActivityLevel.high => 1.1,
    };
    kcal *= activityFactor;

    // 3) 인바디 기초대사량이 있으면 "그 사람 몸에 맞게" 절반 섞기
    if (p.basalMetabolicRate != null && p.basalMetabolicRate! > 800) {
      final tdeeFactor = switch (p.activity) {
        ActivityLevel.low => 1.4,
        ActivityLevel.normal => 1.6,
        ActivityLevel.high => 1.8,
      };
      final fromBody = p.basalMetabolicRate! * tdeeFactor;
      kcal = (kcal + fromBody) / 2;
    }

    // 4) 성장기 단백질은 몸무게 1kg당 약 1g 이상은 되도록
    if (p.weightKg * 1.0 > protein) protein = p.weightKg * 1.0;

    // 5) 탄수화물 60%, 지방 25% (에너지 적정 비율의 중간값)
    final carb = kcal * 0.60 / 4; // 탄수화물 1g = 4kcal
    final fat = kcal * 0.25 / 9; // 지방 1g = 9kcal

    return NutritionTargets(
      kcal: kcal.roundToDouble(),
      carbG: carb.roundToDouble(),
      proteinG: protein.roundToDouble(),
      fatG: fat.roundToDouble(),
      sodiumMg: 2000, // 나트륨 목표 섭취량
    );
  }
}
