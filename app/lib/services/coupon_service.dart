import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/coupon.dart';

/// ═══════════════════════════════════════════════════════════
///  쿠폰함 — 퀴즈로 쿠폰을 받고, 예약할 때 써요 (이 기기에 저장)
///
///  규칙
///   - 퀴즈는 하루 2번까지 (자정에 초기화)
///   - 5문제 중 4개 이상 맞히면 쿠폰 1장, 5개 다 맞히면 더 좋은 쿠폰
///   - 쿠폰은 받은 날부터 14일 동안 쓸 수 있어요
///   - 처음 쿠폰함을 열면 웰컴 쿠폰(1,000원) 1장을 그냥 줘요
/// ═══════════════════════════════════════════════════════════
class CouponService extends ChangeNotifier {
  static const _kCoupons = 'coupons_v1';
  static const _kQuizLog = 'quiz_log_v1'; // {날짜: 푼 횟수}
  static const _kWelcome = 'coupon_welcome_given';
  static const _kStats = 'quiz_stats_v1'; // {total, correct}

  static const int quizPerDay = 2;
  static const int questionsPerRound = 5;
  static const int passScore = 4;
  static const int validDays = 14;

  List<Coupon> _coupons = [];
  Map<String, int> _quizLog = {};
  int totalAnswered = 0;
  int totalCorrect = 0;

  List<Coupon> get all => List.unmodifiable(_coupons);
  List<Coupon> get available => _coupons.where((c) => c.isAvailable).toList()..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
  List<Coupon> get usedOrExpired => _coupons.where((c) => !c.isAvailable).toList()..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));

  static String _today() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  /// 오늘 남은 퀴즈 횟수
  int get quizLeftToday => (quizPerDay - (_quizLog[_today()] ?? 0)).clamp(0, quizPerDay);
  bool get canQuizToday => quizLeftToday > 0;

  // ───── 불러오기 / 저장 ─────
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kCoupons);
    if (raw != null) {
      _coupons = (jsonDecode(raw) as List<dynamic>).map((m) => Coupon.fromMap(m as Map<String, dynamic>)).toList();
    }
    final log = prefs.getString(_kQuizLog);
    if (log != null) {
      _quizLog = (jsonDecode(log) as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as num).toInt()));
    }
    final st = prefs.getString(_kStats);
    if (st != null) {
      final m = jsonDecode(st) as Map<String, dynamic>;
      totalAnswered = (m['total'] as num?)?.toInt() ?? 0;
      totalCorrect = (m['correct'] as num?)?.toInt() ?? 0;
    }
    // 처음이면 웰컴 쿠폰
    if (!(prefs.getBool(_kWelcome) ?? false)) {
      _coupons.add(_make(kind: CouponKind.won, value: 1000, title: '웰컴 1,000원 할인', source: '웰컴'));
      await prefs.setBool(_kWelcome, true);
      await _save();
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCoupons, jsonEncode(_coupons.map((c) => c.toMap()).toList()));
    await prefs.setString(_kQuizLog, jsonEncode(_quizLog));
    await prefs.setString(_kStats, jsonEncode({'total': totalAnswered, 'correct': totalCorrect}));
  }

  Coupon _make({required CouponKind kind, required int value, required String title, required String source}) {
    final now = DateTime.now();
    final id = '${now.millisecondsSinceEpoch}${Random().nextInt(1000)}';
    return Coupon(
      id: id,
      title: title,
      kind: kind,
      value: value,
      source: source,
      issuedAt: now,
      expiresAt: DateTime(now.year, now.month, now.day + validDays, 23, 59),
    );
  }

  // ───── 퀴즈 결과 → 쿠폰 ─────
  /// 퀴즈 한 판이 끝났을 때 불러요. 쿠폰을 받았으면 그 쿠폰, 못 받았으면 null
  Future<Coupon?> finishQuiz({required int correct, required int total}) async {
    _quizLog[_today()] = (_quizLog[_today()] ?? 0) + 1;
    totalAnswered += total;
    totalCorrect += correct;

    Coupon? won;
    if (correct >= total) {
      // 만점: 셋 중 하나를 랜덤으로 (더 좋은 쿠폰)
      final r = Random().nextInt(3);
      won = switch (r) {
        0 => _make(kind: CouponKind.won, value: 2000, title: '만점 2,000원 할인', source: '퀴즈 만점'),
        1 => _make(kind: CouponKind.percent, value: 15, title: '만점 15% 할인', source: '퀴즈 만점'),
        _ => _make(kind: CouponKind.drink, value: 0, title: '만점 음료 1잔', source: '퀴즈 만점'),
      };
    } else if (correct >= passScore) {
      final r = Random().nextInt(3);
      won = switch (r) {
        0 => _make(kind: CouponKind.won, value: 1000, title: '퀴즈 1,000원 할인', source: '퀴즈'),
        1 => _make(kind: CouponKind.percent, value: 10, title: '퀴즈 10% 할인', source: '퀴즈'),
        _ => _make(kind: CouponKind.bigPortion, value: 0, title: '퀴즈 곱빼기 무료', source: '퀴즈'),
      };
    }
    if (won != null) _coupons.add(won);
    await _save();
    notifyListeners();
    return won;
  }

  // ───── 예약할 때 쓰기 ─────
  Future<void> use(Coupon c, String storeName) async {
    final i = _coupons.indexWhere((x) => x.id == c.id);
    if (i < 0) return;
    _coupons[i] = _coupons[i].markUsed(storeName);
    await _save();
    notifyListeners();
  }

  /// 전부 지우기 (테스트용)
  Future<void> clearAll() async {
    _coupons = [];
    _quizLog = {};
    totalAnswered = 0;
    totalCorrect = 0;
    await _save();
    notifyListeners();
  }
}
