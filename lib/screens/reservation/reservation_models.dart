// ============================================================
// reservation_models.dart
// 예약 기능에서 쓰는 "데이터 모양"과 "예약 저장소"
//
// ▶ CartItem      : 장바구니에 담긴 메뉴 1줄 (메뉴 + 수량)
// ▶ Reservation   : 예약 1건 (누가, 언제, 몇 명, 무슨 메뉴)
// ▶ ReservationStore : 예약을 앱 안에 저장해두는 곳 (지금은 메모리에만 저장)
//                      → 나중에 Firebase로 바꾸면 진짜 서버에 저장돼요.
// ============================================================

import 'package:flutter/material.dart';
import '../../data/restaurant_menu_data.dart';

/// MEAL:ON 브랜드 초록색 (Grab 스타일)
/// 이미 앱에 브랜드 색이 있으면 이 값을 그 색으로 바꿔주세요.
const Color kBrandGreen = Color(0xFF00B14F);
const Color kBrandGreenDark = Color(0xFF008F3F);
const Color kBrandGreenLight = Color(0xFFE6F7EC);

/// 예약금: 1명당 1,000원 (선결제 모의 결제)
const int kDepositPerPerson = 1000;

/// 장바구니 한 줄: "크리스피치킨 × 2"
class CartItem {
  final MenuItem menu;
  int quantity;

  CartItem({required this.menu, this.quantity = 1});

  /// 이 줄의 금액 = 가격 × 수량
  int get subtotal => menu.price * quantity;
}

/// 예약 1건
class Reservation {
  final String id;                 // 예약 번호 (자동 생성)
  final Restaurant restaurant;     // 어느 식당
  final DateTime visitAt;          // 방문 날짜 + 시간
  final int people;                // 인원
  final String customerName;       // 예약자 이름
  final String phone;              // 연락처
  final String memo;               // 요청사항
  final List<CartItem> items;      // 미리 주문한 메뉴
  final DateTime createdAt;        // 예약한 시각

  Reservation({
    required this.id,
    required this.restaurant,
    required this.visitAt,
    required this.people,
    required this.customerName,
    required this.phone,
    required this.memo,
    required this.items,
    required this.createdAt,
  });

  /// 메뉴 예상 금액 (식당에서 낼 돈)
  int get menuTotal => items.fold(0, (sum, it) => sum + it.subtotal);

  /// 예약금 = 인원 × 1,000원
  int get deposit => people * kDepositPerPerson;

  /// 우리 회사 수수료 (음식값의 5%) — 사업 계획서용 계산
  int get commission => (menuTotal * 0.05).round();
}

/// 예약 저장소 (앱을 껐다 켜면 사라져요 — 시연용)
/// 나중에 Firebase Firestore로 바꾸면 여기만 고치면 돼요.
class ReservationStore {
  ReservationStore._();                       // 밖에서 new 못 하게 막기
  static final ReservationStore instance = ReservationStore._();

  final List<Reservation> _list = [];
  int _counter = 0;

  /// 저장된 예약 전부 (최신순)
  List<Reservation> get all => List.unmodifiable(_list.reversed.toList());

  /// 예약 추가하고, 만들어진 예약을 돌려줌
  Reservation add({
    required Restaurant restaurant,
    required DateTime visitAt,
    required int people,
    required String customerName,
    required String phone,
    required String memo,
    required List<CartItem> items,
  }) {
    _counter++;
    final now = DateTime.now();
    final id =
        'MO${now.year}${_two(now.month)}${_two(now.day)}-${_counter.toString().padLeft(3, '0')}';
    final r = Reservation(
      id: id,
      restaurant: restaurant,
      visitAt: visitAt,
      people: people,
      customerName: customerName,
      phone: phone,
      memo: memo,
      items: items.map((c) => CartItem(menu: c.menu, quantity: c.quantity)).toList(),
      createdAt: now,
    );
    _list.add(r);
    return r;
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}

/// 날짜/시간을 "9월 20일 (토) 오후 6:30" 처럼 보여주는 도우미
String formatVisitTime(DateTime t) {
  const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
  final wd = weekdays[t.weekday - 1];
  final isPm = t.hour >= 12;
  int h = t.hour % 12;
  if (h == 0) h = 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '${t.month}월 ${t.day}일 ($wd) ${isPm ? '오후' : '오전'} $h:$m';
}
