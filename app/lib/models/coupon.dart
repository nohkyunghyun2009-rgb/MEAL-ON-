/// ═══════════════════════════════════════════════════════════
///  쿠폰 — 룰렛·퀴즈·웰컴으로 받고, 예약할 때 써요
/// ═══════════════════════════════════════════════════════════

/// 쿠폰 종류
enum CouponKind {
  won, // 금액 할인 (예: 1,000원)
  percent, // % 할인 (예: 10%)
  drink, // 음료 1잔 무료 (가게에서 받는 선물)
  bigPortion, // 곱빼기 무료 (가게에서 받는 선물)
}

class Coupon {
  final String id;
  final String title; // 화면에 보이는 이름 (예: "1,000원 할인")
  final CouponKind kind;
  final int value; // won이면 원, percent면 %, 선물이면 0
  final String source; // 어디서 받았는지 (룰렛 / 퀴즈 / 웰컴)
  final DateTime issuedAt;
  final DateTime expiresAt;
  final DateTime? usedAt;
  final String usedStore; // 어느 가게에서 썼는지

  const Coupon({
    required this.id,
    required this.title,
    required this.kind,
    required this.value,
    required this.source,
    required this.issuedAt,
    required this.expiresAt,
    this.usedAt,
    this.usedStore = '',
  });

  bool get isUsed => usedAt != null;
  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isAvailable => !isUsed && !isExpired;

  /// 남은 날짜 (0이면 오늘까지)
  int get daysLeft => expiresAt.difference(DateTime.now()).inDays;

  String get emoji => switch (kind) {
        CouponKind.won => '💸',
        CouponKind.percent => '🏷️',
        CouponKind.drink => '🥤',
        CouponKind.bigPortion => '🍜',
      };

  /// 큰 글씨 (쿠폰 카드 앞면)
  String get big => switch (kind) {
        CouponKind.won => '${_comma(value)}원',
        CouponKind.percent => '$value%',
        CouponKind.drink => '음료 1잔',
        CouponKind.bigPortion => '곱빼기',
      };

  /// 작은 글씨
  String get small => switch (kind) {
        CouponKind.won => '결제 금액에서 빼줘요',
        CouponKind.percent => '결제 금액의 $value% 할인',
        CouponKind.drink => '가게에서 음료 1잔 무료',
        CouponKind.bigPortion => '면·밥 곱빼기 무료',
      };

  /// 이 쿠폰을 쓰면 얼마가 빠지는지 (선물 쿠폰은 0원 — 가게에서 받는 거라)
  int discountFor(int amount) => switch (kind) {
        CouponKind.won => value.clamp(0, amount),
        CouponKind.percent => ((amount * value / 100) / 100).round() * 100, // 100원 단위로
        _ => 0,
      };

  /// 선물 쿠폰이면 예약 요청사항에 붙일 말
  String get giftNote => switch (kind) {
        CouponKind.drink => '[쿠폰] 음료 1잔 무료',
        CouponKind.bigPortion => '[쿠폰] 곱빼기 무료',
        _ => '',
      };

  Coupon markUsed(String store) => Coupon(
        id: id,
        title: title,
        kind: kind,
        value: value,
        source: source,
        issuedAt: issuedAt,
        expiresAt: expiresAt,
        usedAt: DateTime.now(),
        usedStore: store,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'kind': kind.name,
        'value': value,
        'source': source,
        'issuedAt': issuedAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'usedAt': usedAt?.toIso8601String(),
        'usedStore': usedStore,
      };

  static Coupon fromMap(Map<String, dynamic> m) => Coupon(
        id: m['id'] as String,
        title: m['title'] as String,
        kind: CouponKind.values.firstWhere((k) => k.name == m['kind'], orElse: () => CouponKind.won),
        value: (m['value'] as num?)?.toInt() ?? 0,
        source: (m['source'] as String?) ?? '',
        issuedAt: DateTime.tryParse(m['issuedAt'] as String? ?? '') ?? DateTime.now(),
        expiresAt: DateTime.tryParse(m['expiresAt'] as String? ?? '') ?? DateTime.now().add(const Duration(days: 30)),
        usedAt: m['usedAt'] == null ? null : DateTime.tryParse(m['usedAt'] as String),
        usedStore: (m['usedStore'] as String?) ?? '',
      );

  static String _comma(int n) => n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
}
