// 예약 흐름이 깨지지 않았는지 확인하는 자동 테스트
// 실행: flutter test
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meal_on/main.dart';
import 'package:meal_on/data/restaurant_menu_data.dart';
import 'package:meal_on/screens/reservation/reservation_models.dart';
import 'package:meal_on/data/promo_banner_data.dart';
import 'package:meal_on/widgets/restaurant_promo_banner.dart';

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

    expect(saved.deposit, 3 * kDepositPerPerson);
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
}
