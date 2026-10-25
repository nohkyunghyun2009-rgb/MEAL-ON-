/// 인바디 체중계에서 나온 숫자들을 담는 "몸 정보 카드"예요.
enum Sex { male, female }

enum ActivityLevel { low, normal, high }

extension ActivityLabel on ActivityLevel {
  String get label => switch (this) {
        ActivityLevel.low => '거의 앉아서',
        ActivityLevel.normal => '보통',
        ActivityLevel.high => '운동 많이',
      };
}

class BodyProfile {
  final String nickname;
  final Sex sex;
  final int age;
  final double heightCm;
  final double weightKg;
  final double bodyFatPercent; // 체지방률 (%)
  final double skeletalMuscleKg; // 골격근량 (kg)
  final double? basalMetabolicRate; // 기초대사량 (kcal) - 인바디가 알려주면 적기 (선택)
  final double? bodyWaterPercent; // 체수분량 (%) - 체중계에 있으면 적기 (선택)
  final ActivityLevel activity;
  final DateTime measuredAt;

  const BodyProfile({
    required this.nickname,
    required this.sex,
    required this.age,
    required this.heightCm,
    required this.weightKg,
    required this.bodyFatPercent,
    required this.skeletalMuscleKg,
    required this.activity,
    required this.measuredAt,
    this.basalMetabolicRate,
    this.bodyWaterPercent,
  });

  // ───── 계산으로 나오는 값들 ─────
  double get bmi => weightKg / ((heightCm / 100) * (heightCm / 100));
  double get fatMassKg => weightKg * bodyFatPercent / 100; // 체지방 무게
  double get leanMassKg => weightKg - fatMassKg; // 지방 뺀 무게
  double get muscleRatioPercent => skeletalMuscleKg / weightKg * 100; // 몸무게 중 근육 비율

  bool get isMale => sex == Sex.male;

  /// 인바디 결과지처럼 자세히 분석한 결과 (체형·또래 비교·표준 범위)
  BodyAnalysis get analysis => BodyAnalysis.from(this);

  // ───── 저장/불러오기 (폰 안에 글자로 저장했다가 다시 꺼내요) ─────
  Map<String, dynamic> toJson() => {
        'nickname': nickname,
        'sex': sex.name,
        'age': age,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'bodyFatPercent': bodyFatPercent,
        'skeletalMuscleKg': skeletalMuscleKg,
        'basalMetabolicRate': basalMetabolicRate,
        'bodyWaterPercent': bodyWaterPercent,
        'activity': activity.name,
        'measuredAt': measuredAt.millisecondsSinceEpoch,
      };

  factory BodyProfile.fromJson(Map<String, dynamic> j) => BodyProfile(
        nickname: j['nickname'] as String,
        sex: Sex.values.byName(j['sex'] as String),
        age: (j['age'] as num).toInt(),
        heightCm: (j['heightCm'] as num).toDouble(),
        weightKg: (j['weightKg'] as num).toDouble(),
        bodyFatPercent: (j['bodyFatPercent'] as num).toDouble(),
        skeletalMuscleKg: (j['skeletalMuscleKg'] as num).toDouble(),
        basalMetabolicRate: (j['basalMetabolicRate'] as num?)?.toDouble(),
        bodyWaterPercent: (j['bodyWaterPercent'] as num?)?.toDouble(),
        activity: ActivityLevel.values.byName(j['activity'] as String),
        measuredAt: DateTime.fromMillisecondsSinceEpoch(j['measuredAt'] as int),
      );
}

/// 몸 상태를 "혼내지 않고" 알려주는 한 줄 메시지들.
/// 성장기 학생에게는 "살 빼라"가 아니라 "무엇을 채우면 좋은지"를 말해줘야 해요.
class BodyInsight {
  final String headline; // 큰 제목 한 줄
  final List<String> points; // 자세한 설명들
  final List<String> focusNutrients; // AI 추천에 쓸 "채우면 좋은 영양소"

  const BodyInsight(this.headline, this.points, this.focusNutrients);

  static BodyInsight from(BodyProfile p) {
    final points = <String>[];
    final focus = <String>[];

    // 1) 체지방률 - 청소년 참고 범위 (대략적인 값이에요)
    final fat = p.bodyFatPercent;
    final (fatLow, fatHigh) = p.isMale ? (10.0, 20.0) : (17.0, 27.0);
    String fatWord;
    if (fat < fatLow) {
      fatWord = '체지방이 적은 편';
      points.add('체지방률 ${fat.toStringAsFixed(1)}% — 참고 범위보다 낮아요. 성장기엔 에너지가 충분해야 하니 끼니를 거르지 않는 게 중요해요.');
      focus.add('에너지(탄수화물)');
    } else if (fat <= fatHigh) {
      fatWord = '체지방 균형이 좋아요';
      points.add('체지방률 ${fat.toStringAsFixed(1)}% — 참고 범위 안이에요. 지금처럼 골고루 먹으면 돼요.');
    } else if (fat <= fatHigh + 5) {
      fatWord = '체지방이 조금 있는 편';
      points.add('체지방률 ${fat.toStringAsFixed(1)}% — 참고 범위보다 살짝 높아요. 튀김·단 음료를 줄이고 채소를 곁들이면 좋아요.');
      focus.add('채소·식이섬유');
    } else {
      fatWord = '체지방이 많은 편';
      points.add('체지방률 ${fat.toStringAsFixed(1)}% — 참고 범위보다 높아요. 굶는 건 금물! 밥은 그대로, 튀김·단 음료를 다른 걸로 바꿔봐요.');
      focus.add('채소·식이섬유');
    }

    // 2) 근육 비율 (골격근량 ÷ 몸무게)
    final mr = p.muscleRatioPercent;
    final (mGood, mOk) = p.isMale ? (40.0, 35.0) : (34.0, 30.0);
    if (mr >= mGood) {
      points.add('골격근 비율 ${mr.toStringAsFixed(0)}% — 근육이 탄탄해요. 단백질을 꾸준히 먹으면 성장에 도움이 돼요.');
    } else if (mr >= mOk) {
      points.add('골격근 비율 ${mr.toStringAsFixed(0)}% — 보통이에요. 단백질(계란·두부·생선·고기)을 매 끼니 조금씩 넣어봐요.');
      focus.add('단백질');
    } else {
      points.add('골격근 비율 ${mr.toStringAsFixed(0)}% — 근육을 더 키우면 좋아요. 단백질 반찬을 한 가지 더 챙기고, 가볍게 몸을 움직여봐요.');
      focus.add('단백질');
    }

    // 3) BMI는 숫자만 부드럽게 (청소년은 나이별 기준이 달라서 진단하지 않아요)
    points.add('BMI ${p.bmi.toStringAsFixed(1)} — 성장기에는 나이마다 기준이 달라요. 이 숫자보다 위의 근육·체지방 균형이 더 중요해요.');

    if (focus.isEmpty) focus.add('골고루');

    final headline = '$fatWord${mr >= mGood ? ', 근육도 든든해요' : ''}';
    return BodyInsight(headline, points, focus);
  }
}


// ═══════════════════════════════════════════════════════════
//  인바디 결과지 수준의 분석 엔진
//  체중계가 주는 숫자(몸무게·체지방률·골격근량·체수분)로
//  ① 또래 BMI 백분위  ② 체형(C/I/D)  ③ 항목별 표준 범위 를 계산해요.
// ═══════════════════════════════════════════════════════════

/// 청소년 BMI 백분위표 (질병관리청 2017 소아청소년 성장도표를 참고한 근사값)
/// 나이 → [5백분위, 50백분위(중간), 85백분위, 95백분위]
/// 85 이상 = 과체중 구간, 95 이상 = 비만 구간 (소아청소년 기준)
const Map<int, List<double>> _bmiBoys = {
  10: [14.2, 17.0, 19.9, 22.1],
  11: [14.6, 17.6, 20.7, 23.0],
  12: [15.1, 18.3, 21.5, 23.9],
  13: [15.7, 19.0, 22.3, 24.7],
  14: [16.3, 19.7, 23.0, 25.4],
  15: [16.9, 20.4, 23.6, 26.0],
  16: [17.5, 21.0, 24.2, 26.5],
  17: [18.0, 21.5, 24.7, 26.9],
  18: [18.4, 21.9, 25.1, 27.3],
};
const Map<int, List<double>> _bmiGirls = {
  10: [14.1, 16.9, 19.8, 22.0],
  11: [14.6, 17.6, 20.7, 23.0],
  12: [15.1, 18.3, 21.5, 23.9],
  13: [15.7, 19.0, 22.2, 24.6],
  14: [16.2, 19.6, 22.8, 25.2],
  15: [16.7, 20.1, 23.3, 25.7],
  16: [17.1, 20.5, 23.7, 26.1],
  17: [17.4, 20.8, 24.0, 26.4],
  18: [17.6, 21.0, 24.2, 26.6],
};

/// 체형: 인바디 용지의 막대 3개(체중·골격근·체지방)가 만드는 모양
enum BodyShape { c, i, d }

extension BodyShapeInfo on BodyShape {
  String get label => switch (this) {
        BodyShape.c => 'C형',
        BodyShape.i => 'I형',
        BodyShape.d => 'D형',
      };
  String get title => switch (this) {
        BodyShape.c => '근육보다 지방이 앞서는 체형',
        BodyShape.i => '균형 잡힌 체형',
        BodyShape.d => '근육이 앞서는 운동형',
      };
  String get advice => switch (this) {
        BodyShape.c => '굶지 말고 "바꾸기": 밥은 그대로, 튀김·단 음료 대신 단백질 반찬과 채소를. 가벼운 근력 운동이 제일 효과 커요.',
        BodyShape.i => '지금 균형이 좋아요. 성장기니까 끼니 거르지 않고 단백질을 꾸준히 챙기면 그대로 자라요.',
        BodyShape.d => '근육이 든든해요. 운동량이 많다면 탄수화물(밥)을 충분히 먹어야 근육이 안 빠져요.',
      };
}

/// 막대 하나 (인바디 용지의 한 줄)
class BodyBar {
  final String label; // 체중 / 골격근량 / 체지방량
  final double valueKg; // 내 값
  final double percent; // 표준 대비 % (100 = 표준 한가운데)
  final double lowPct; // 표준 범위 시작 (%)
  final double highPct; // 표준 범위 끝 (%)
  const BodyBar(this.label, this.valueKg, this.percent, this.lowPct, this.highPct);

  String get judge => percent < lowPct ? '표준 이하' : (percent > highPct ? '표준 이상' : '표준');
}

class BodyAnalysis {
  final double idealWeightKg; // 또래 중간 BMI 기준 적정 체중
  final double bmiPercentile; // 또래 100명 중 몇 번째 (가벼운 순)
  final String bmiCategory; // 저체중 / 정상 / 과체중 / 비만 (청소년 기준)
  final List<BodyBar> bars; // 체중·골격근·체지방 막대 3개
  final BodyShape shape;
  final String? waterJudge; // 체수분 판정 (없으면 null)
  final double smmRatioPercent; // 골격근 ÷ 몸무게
  final String fatJudge; // 체지방률 판정
  final bool usedAdultRef; // 나이가 표 밖이라 18세 기준을 썼는지

  const BodyAnalysis({
    required this.idealWeightKg,
    required this.bmiPercentile,
    required this.bmiCategory,
    required this.bars,
    required this.shape,
    required this.waterJudge,
    required this.smmRatioPercent,
    required this.fatJudge,
    required this.usedAdultRef,
  });

  static BodyAnalysis from(BodyProfile p) {
    // ── 1) 나이·성별에 맞는 BMI 기준 줄 찾기 ──
    final table = p.isMale ? _bmiBoys : _bmiGirls;
    final age = p.age.clamp(10, 18).toInt();
    final row = table[age]!;
    final usedAdult = p.age > 18 || p.age < 10;
    final (p5, p50, p85, p95) = (row[0], row[1], row[2], row[3]);

    // ── 2) 내 BMI가 또래 몇 번째인지 (기준점 사이는 직선으로 이어서 계산) ──
    final bmi = p.bmi;
    double pct;
    if (bmi <= p5) {
      pct = 5 * (bmi / p5); // 5 아래는 대충 비례
    } else if (bmi <= p50) {
      pct = 5 + 45 * (bmi - p5) / (p50 - p5);
    } else if (bmi <= p85) {
      pct = 50 + 35 * (bmi - p50) / (p85 - p50);
    } else if (bmi <= p95) {
      pct = 85 + 10 * (bmi - p85) / (p95 - p85);
    } else {
      pct = 95 + 4 * ((bmi - p95) / 3).clamp(0.0, 1.0); // 95 위는 최대 99
    }
    pct = pct.clamp(1, 99).toDouble();

    final category = pct < 5
        ? '저체중'
        : pct < 85
            ? '정상'
            : pct < 95
                ? '과체중'
                : '비만';

    // ── 3) 적정 체중 = 또래 중간 BMI × 키² ──
    final h = p.heightCm / 100;
    final ideal = p50 * h * h;

    // ── 4) 막대 3개: 인바디 방식 (적정 체중 기준 표준 범위) ──
    // 체중: 적정 체중의 85~115%가 표준
    final wPct = p.weightKg / ideal * 100;
    // 골격근: 적정 체중 × (남 0.44 / 여 0.38)의 90~110%가 표준
    final smmStd = ideal * (p.isMale ? 0.44 : 0.38);
    final mPct = p.skeletalMuscleKg / smmStd * 100;
    // 체지방: 적정 체중 × (남 15% / 여 23%)의 80~160%가 표준
    final fatStd = ideal * (p.isMale ? 0.15 : 0.23);
    final fPct = p.fatMassKg / fatStd * 100;

    final bars = [
      BodyBar('체중', p.weightKg, wPct, 85, 115),
      BodyBar('골격근량', p.skeletalMuscleKg, mPct, 90, 110),
      BodyBar('체지방량', p.fatMassKg, fPct, 80, 160),
    ];

    // ── 5) 체형: 막대 길이 비교 (표준 한가운데 대비) ──
    // 지방 막대가 근육 막대보다 길면 C, 근육이 길면 D, 비슷하면 I
    final mScore = mPct - 100; // 근육이 표준보다 얼마나 +/-
    final fScore = (fPct - 120) / 2; // 지방 범위(80~160)는 넓어서 반으로 눌러 비교
    BodyShape shape;
    if (fScore - mScore > 8) {
      shape = BodyShape.c;
    } else if (mScore - fScore > 8) {
      shape = BodyShape.d;
    } else {
      shape = BodyShape.i;
    }

    // ── 6) 체수분 ──
    String? water;
    if (p.bodyWaterPercent != null) {
      final (wLow, wHigh) = p.isMale ? (50.0, 65.0) : (45.0, 60.0);
      final w = p.bodyWaterPercent!;
      water = w < wLow ? '부족 (물을 더 마셔요)' : (w > wHigh ? '많음' : '표준');
    }

    // ── 7) 체지방률 판정 (청소년 참고 범위) ──
    final (fatLow, fatHigh) = p.isMale ? (10.0, 20.0) : (17.0, 27.0);
    final fat = p.bodyFatPercent;
    final fatJudge = fat < fatLow ? '낮음' : (fat <= fatHigh ? '표준' : (fat <= fatHigh + 5 ? '살짝 높음' : '높음'));

    return BodyAnalysis(
      idealWeightKg: ideal,
      bmiPercentile: pct,
      bmiCategory: category,
      bars: bars,
      shape: shape,
      waterJudge: water,
      smmRatioPercent: p.muscleRatioPercent,
      fatJudge: fatJudge,
      usedAdultRef: usedAdult,
    );
  }

  /// AI 프롬프트에 넣을 한 줄 요약
  String get summaryForAi =>
      '체형 ${shape.label}(${shape.title}), 또래 BMI 백분위 ${bmiPercentile.round()}($bmiCategory), '
      '체지방률 $fatJudge, 골격근 ${bars[1].judge}${waterJudge == null ? '' : ', 체수분 $waterJudge'}';
}
