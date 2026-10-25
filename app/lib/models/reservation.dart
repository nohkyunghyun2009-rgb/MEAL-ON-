/// 예약 한 건
/// 흐름: 학생이 예약(대기) → 사장님이 확인(확정) → 가게 방문 후 사장님이 "방문완료" 클릭
enum ReservationStatus { pending, confirmed, visited, cancelled }

extension ReservationStatusInfo on ReservationStatus {
  String get label => switch (this) {
        ReservationStatus.pending => '대기',
        ReservationStatus.confirmed => '확정',
        ReservationStatus.visited => '방문완료',
        ReservationStatus.cancelled => '취소',
      };
}

/// 예약금 결제 상태: 안 냄 / 냈음 / 환불됨
enum PayStatus { none, paid, refunded }

extension PayStatusInfo on PayStatus {
  String get label => switch (this) {
        PayStatus.none => '결제 없음',
        PayStatus.paid => '결제 완료',
        PayStatus.refunded => '환불됨',
      };
}

/// 미리 주문한 메뉴 한 줄 (이름 · 가격 · 개수)
class OrderLine {
  final String name;
  final int price;
  final int qty;
  const OrderLine({required this.name, required this.price, required this.qty});

  int get total => price * qty;

  Map<String, dynamic> toMap() => {'name': name, 'price': price, 'qty': qty};
  factory OrderLine.fromMap(Map<String, dynamic> m) =>
      OrderLine(name: m['name'] as String, price: (m['price'] as num).toInt(), qty: (m['qty'] as num).toInt());
}

class Reservation {
  final String id;
  final String code; // 가게에서 보여줄 4자리 예약번호 (예: A7K2)
  final String restaurantId;
  final String restaurantName;
  final String restaurantAddress;
  final String userNickname;
  final DateTime visitAt; // 방문 시간
  final int people; // 인원
  final String note; // 요청사항
  final ReservationStatus status;
  final DateTime createdAt;
  final int? paidAmount; // 방문 후 사장님이 적는 결제 금액 (수수료 계산용)
  final int deposit; // 예약할 때 카드로 낸 예약금 (인원 × 1,000원)
  final String cardLast4; // 결제한 카드 끝 4자리 (전체 번호는 저장 안 해요!)
  final PayStatus payStatus; // 예약금이 지금 어떤 상태인지
  final List<OrderLine> order; // 미리 주문한 메뉴 (없으면 빈 목록)

  const Reservation({
    required this.id,
    required this.code,
    required this.restaurantId,
    required this.restaurantName,
    required this.restaurantAddress,
    required this.userNickname,
    required this.visitAt,
    required this.people,
    required this.note,
    required this.status,
    required this.createdAt,
    this.paidAmount,
    this.deposit = 0,
    this.cardLast4 = '',
    this.payStatus = PayStatus.none,
    this.order = const [],
  });

  /// 선주문 합계 (0이면 예약금만 낸 예약)
  int get orderTotal => order.fold(0, (s, o) => s + o.total);
  String get orderSummary => order.map((o) => '${o.name}×${o.qty}').join(', ');

  Reservation copyWith({String? id, ReservationStatus? status, int? paidAmount, PayStatus? payStatus}) => Reservation(
        id: id ?? this.id,
        code: code,
        restaurantId: restaurantId,
        restaurantName: restaurantName,
        restaurantAddress: restaurantAddress,
        userNickname: userNickname,
        visitAt: visitAt,
        people: people,
        note: note,
        status: status ?? this.status,
        createdAt: createdAt,
        paidAmount: paidAmount ?? this.paidAmount,
        deposit: deposit,
        cardLast4: cardLast4,
        payStatus: payStatus ?? this.payStatus,
        order: order,
      );

  /// Firebase와 폰 저장 둘 다 같은 모양으로 저장해요 (날짜는 숫자로)
  Map<String, dynamic> toMap() => {
        'code': code,
        'restaurantId': restaurantId,
        'restaurantName': restaurantName,
        'restaurantAddress': restaurantAddress,
        'userNickname': userNickname,
        'visitAt': visitAt.millisecondsSinceEpoch,
        'people': people,
        'note': note,
        'status': status.name,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'paidAmount': paidAmount,
        'deposit': deposit,
        'cardLast4': cardLast4,
        'payStatus': payStatus.name,
        'order': order.map((o) => o.toMap()).toList(),
      };

  factory Reservation.fromMap(String id, Map<String, dynamic> m) => Reservation(
        id: id,
        code: m['code'] as String,
        restaurantId: m['restaurantId'] as String,
        restaurantName: m['restaurantName'] as String,
        restaurantAddress: (m['restaurantAddress'] ?? '') as String,
        userNickname: m['userNickname'] as String,
        visitAt: DateTime.fromMillisecondsSinceEpoch((m['visitAt'] as num).toInt()),
        people: (m['people'] as num).toInt(),
        note: (m['note'] ?? '') as String,
        status: ReservationStatus.values.byName(m['status'] as String),
        createdAt: DateTime.fromMillisecondsSinceEpoch((m['createdAt'] as num).toInt()),
        paidAmount: (m['paidAmount'] as num?)?.toInt(),
        // 옛날에 저장된 예약(결제 칸이 없던 시절)도 안 터지게 기본값을 줘요
        deposit: (m['deposit'] as num?)?.toInt() ?? 0,
        cardLast4: (m['cardLast4'] ?? '') as String,
        payStatus: PayStatus.values.byName((m['payStatus'] ?? 'none') as String),
        order: ((m['order'] as List<dynamic>?) ?? const [])
            .map((x) => OrderLine.fromMap(Map<String, dynamic>.from(x as Map)))
            .toList(),
      );
}

/// 날짜를 "9월 3일 (수) 18:30" 처럼 예쁘게 바꿔주는 도우미
String formatVisitTime(DateTime d) {
  const days = ['월', '화', '수', '목', '금', '토', '일'];
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${d.month}월 ${d.day}일 (${days[d.weekday - 1]}) $hh:$mm';
}

/// 숫자에 쉼표 넣기: 12800 → 12,800
String formatWon(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    buf.write(s[i]);
    final remaining = s.length - i - 1;
    if (remaining > 0 && remaining % 3 == 0) buf.write(',');
  }
  return '${buf.toString()}원';
}
