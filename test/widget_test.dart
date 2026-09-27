// 예약 흐름이 깨지지 않았는지 확인하는 자동 테스트
// 실행: flutter test
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meal_on/main.dart';
import 'package:meal_on/data/restaurant_menu_data.dart';
import 'package:meal_on/screens/reservation/reservation_models.dart';
import 'package:meal_on/data/promo_banner_data.dart';
import 'package:meal_on/widgets/restaurant_promo_banner.dart';
import 'package:meal_on/payment/payment_gateway.dart';
import 'package:meal_on/payment/pending_reservation.dart';

void main() {
  testWidgets('홈 → 식당 예약 → 식당 목록이 보인다', (tester) async {
    await tester.pumpWidget(const MealOnApp());

    expect(find.text('MEAL:ON'), findsOneWidget);
    expect(find.text('식당 예약'), findsOneWidget);

    await tester.tap(find.text('식당 예약'));
    await tester.pumpAndSettle();

    expect(find.text('제휴 식당 예약'), findsOneWidget);
    expect(find.text(partnerRestaurants.first.name), findsOneWidget);
  });

  testWidgets('홈 → 내 예약 → 비어있다는 안내가 보인다', (tester) async {
    await tester.pumpWidget(const MealOnApp());

    await tester.tap(find.text('내 예약'));
    await tester.pumpAndSettle();

    expect(find.text('아직 예약이 없어요'), findsOneWidget);
  });

  test('메뉴 데이터: 식당 11곳, 가격은 0 이상', () {
    expect(partnerRestaurants.length, 11);
    for (final r in partnerRestaurants) {
      expect(r.id, isNotEmpty);
      expect(r.name, isNotEmpty);
      for (final c in r.categories) {
        for (final m in c.items) {
          expect(m.price, greaterThanOrEqualTo(0), reason: '${r.name} / ${m.name}');
        }
      }
    }
  });

  test('ReservationStore: 예약금과 수수료 계산', () {
    final r = partnerRestaurants.firstWhere((r) => r.hasMenu);
    final menu = r.categories.first.items.firstWhere((m) => m.price > 0);

    final saved = ReservationStore.instance.add(
      restaurant: r,
      visitAt: DateTime(2026, 9, 20, 18, 30),
      people: 3,
      customerName: '테스트',
      phone: '010-0000-0000',
      memo: '',
      items: [CartItem(menu: menu, quantity: 2)],
    );

    expect(kDepositPerPerson, 2000);
    expect(saved.deposit, 3 * kDepositPerPerson);
    expect(saved.isPaidForReal, isFalse);
    expect(saved.menuTotal, menu.price * 2);
    expect(saved.commission, (menu.price * 2 * 0.05).round());
    expect(ReservationStore.instance.all.first.id, saved.id);
  });

  testWidgets('홈 배너가 보이고, 누르면 그 식당 메뉴 화면으로 간다', (tester) async {
    await tester.pumpWidget(const MealOnApp());

    expect(find.byType(RestaurantPromoBanner), findsOneWidget);

    final first = promoBanners.first;
    final restaurant =
        partnerRestaurants.firstWhere((r) => r.id == first.restaurantId);
    // 배너 제목 = 식당 이름 (title 비웠을 때)
    expect(find.text(restaurant.name), findsOneWidget);
    expect(find.text('예약하기 →'), findsWidgets);

    // 배너가 화면 아래쪽에 있으니 보이는 위치까지 스크롤한 뒤 탭
    await tester.ensureVisible(find.byType(RestaurantPromoBanner));
    await tester.pumpAndSettle();
    await tester.tap(find.text(restaurant.name));
    await tester.pumpAndSettle();

    // 메뉴 화면: 앱바에 식당 이름, 메뉴 검색창
    expect(find.text('메뉴 검색'), findsOneWidget);
    expect(find.text(restaurant.name), findsOneWidget);
  });

  testWidgets('배너 restaurantId 는 전부 실제 식당 id 여야 한다', (tester) async {
    final ids = partnerRestaurants.map((r) => r.id).toSet();
    for (final b in promoBanners) {
      expect(ids.contains(b.restaurantId), isTrue,
          reason: '배너의 restaurantId "${b.restaurantId}" 가 식당 목록에 없어요');
    }
  });

  testWidgets('배너가 4초마다 자동으로 넘어간다', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: RestaurantPromoBanner()),
    ));
    final r0 = partnerRestaurants
        .firstWhere((r) => r.id == promoBanners[0].restaurantId);
    final r1 = partnerRestaurants
        .firstWhere((r) => r.id == promoBanners[1].restaurantId);
    expect(find.text(r0.name), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(find.text(r1.name), findsOneWidget);
  });

  test('예약번호(orderId)는 토스 규칙(6~64자, 영문·숫자·-·_)에 맞고 겹치지 않는다', () {
    final store = ReservationStore.instance;
    final ids = {for (var i = 0; i < 50; i++) store.newOrderId()};
    expect(ids.length, 50);
    for (final id in ids) {
      expect(id.length, inInclusiveRange(6, 64));
      expect(RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id), isTrue, reason: id);
    }
  });

  test('PendingReservation: JSON 으로 저장했다가 다시 꺼내면 같은 내용', () {
    final r = partnerRestaurants.firstWhere((r) => r.hasMenu);
    final menu = r.categories.first.items.first;
    final p = PendingReservation(
      orderId: 'MO20260927-TEST01',
      restaurantId: r.id,
      visitAt: DateTime(2026, 10, 1, 12, 30),
      people: 4,
      customerName: '홍길동',
      phone: '010-1234-5678',
      memo: '창가',
      items: [CartItem(menu: menu, quantity: 3)],
      amount: 4 * kDepositPerPerson,
    );

    final back = PendingReservation.decode(p.encode())!;
    expect(back.orderId, p.orderId);
    expect(back.restaurantId, r.id);
    expect(back.visitAt, p.visitAt);
    expect(back.people, 4);
    expect(back.customerName, '홍길동');
    expect(back.memo, '창가');
    expect(back.amount, 8000);
    expect(back.items.single.menu.name, menu.name);
    expect(back.items.single.quantity, 3);
    expect(back.orderNameFor(r), '${r.name} 예약금 (4명)');

    expect(PendingReservation.decode('{"restaurantId":"없는식당"}'), isNull);
    expect(PendingReservation.decode('이건 JSON 아님'), isNull);
  });

  test('PaymentReturn: 토스가 돌려보낸 주소에서 결과를 읽는다', () {
    final ok = PaymentReturn.fromUri(Uri.parse(
        'http://localhost:8080/?payment=success&paymentKey=pk_1&orderId=MO1-AB&amount=4000'))!;
    expect(ok.success, isTrue);
    expect(ok.paymentKey, 'pk_1');
    expect(ok.orderId, 'MO1-AB');
    expect(ok.amount, 4000);

    final fail = PaymentReturn.fromUri(Uri.parse(
        'http://localhost:8080/?payment=fail&code=PAY_PROCESS_CANCELED&message=%EC%B7%A8%EC%86%8C&orderId=MO1-AB'))!;
    expect(fail.success, isFalse);
    expect(fail.isUserCancel, isTrue);
    expect(fail.message, '취소');

    expect(PaymentReturn.fromUri(Uri.parse('http://localhost:8080/#/')), isNull);
  });

  test('테스트(웹 아님)에서는 모의 결제 통로가 쓰인다', () {
    expect(PaymentGateway.instance.isReal, isFalse);
    expect(PaymentGateway.instance.readReturn(), isNull);
  });

  testWidgets('예약 폼 → 결제하기 → (모의 결제) 완료 화면', (tester) async {
    await tester.pumpWidget(const MealOnApp());
    await tester.tap(find.text('식당 예약'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(partnerRestaurants.first.name));
    await tester.pumpAndSettle();

    // 메뉴 화면 → 예약하기 버튼 (메뉴는 안 담아도 예약 가능)
    await tester.tap(find.textContaining('예약하기').last);
    await tester.pumpAndSettle();
    expect(find.text('예약 정보 입력'), findsOneWidget);
    expect(find.text('예약금 ${formatWon(2 * kDepositPerPerson)}원 결제하고 예약하기'),
        findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '이름'), '테스트');
    await tester.enterText(find.widgetWithText(TextField, '연락처'), '010-1111-2222');
    await tester.tap(find.textContaining('결제하고 예약하기'));
    await tester.pumpAndSettle();

    // 확인창
    expect(find.text('예약금 결제'), findsOneWidget);
    await tester.tap(find.text('결제하기'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('예약이 접수됐어요!'), findsOneWidget);
    expect(find.text('모의 결제'), findsOneWidget);
  });
}
