// ============================================================
// pending_reservation.dart
// "결제 중인 예약" — 결제창으로 넘어가기 전에 입력한 내용을 잠깐 보관해요.
//
// 토스 결제창은 브라우저 페이지를 통째로 바꿔버려서(리다이렉트),
// 결제가 끝나고 앱으로 돌아오면 입력했던 내용이 다 사라져요.
// 그래서 결제창으로 가기 전에 여기 모양으로 만들어서 브라우저 저장소에
// 글자(JSON)로 넣어두고, 돌아온 뒤에 다시 꺼내서 예약으로 저장해요.
// ============================================================

import 'dart:convert';

import '../data/restaurant_menu_data.dart';
import '../screens/reservation/reservation_models.dart';

class PendingReservation {
  final String orderId;      // 토스 주문번호 = 예약번호
  final String restaurantId; // 어느 식당 (id)
  final DateTime visitAt;
  final int people;
  final String customerName;
  final String phone;
  final String memo;
  final List<CartItem> items;
  final int amount;          // 결제할 예약금 (원)

  PendingReservation({
    required this.orderId,
    required this.restaurantId,
    required this.visitAt,
    required this.people,
    required this.customerName,
    required this.phone,
    required this.memo,
    required this.items,
    required this.amount,
  });

  /// 결제창에 보여줄 주문 이름: "홍대돈까스 예약금 (2명)"
  String orderNameFor(Restaurant r) => '${r.name} 예약금 ($people명)';

  Map<String, dynamic> toJson() => {
        'orderId': orderId,
        'restaurantId': restaurantId,
        'visitAt': visitAt.toIso8601String(),
        'people': people,
        'customerName': customerName,
        'phone': phone,
        'memo': memo,
        'amount': amount,
        'items': [
          for (final c in items) {'name': c.menu.name, 'quantity': c.quantity}
        ],
      };

  String encode() => jsonEncode(toJson());

  /// JSON 글자에서 다시 만들기. 식당·메뉴는 이름으로 찾아요.
  /// 식당을 못 찾으면 null 을 돌려줘요.
  static PendingReservation? decode(String source) {
    final Map<String, dynamic> j;
    try {
      j = jsonDecode(source) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
    final restaurant = findRestaurant(j['restaurantId'] as String? ?? '');
    if (restaurant == null) return null;

    final menusByName = {
      for (final c in restaurant.categories)
        for (final m in c.items) m.name: m,
    };
    final items = <CartItem>[];
    for (final it in (j['items'] as List? ?? const [])) {
      final m = menusByName[it['name']];
      if (m != null) items.add(CartItem(menu: m, quantity: it['quantity'] as int));
    }

    return PendingReservation(
      orderId: j['orderId'] as String,
      restaurantId: restaurant.id,
      visitAt: DateTime.parse(j['visitAt'] as String),
      people: j['people'] as int,
      customerName: j['customerName'] as String? ?? '',
      phone: j['phone'] as String? ?? '',
      memo: j['memo'] as String? ?? '',
      items: items,
      amount: j['amount'] as int,
    );
  }
}

/// id 로 식당 찾기 (없으면 null)
Restaurant? findRestaurant(String id) {
  for (final r in partnerRestaurants) {
    if (r.id == id) return r;
  }
  return null;
}
