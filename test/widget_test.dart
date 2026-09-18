// 예약 흐름이 깨지지 않았는지 확인하는 자동 테스트
// 실행: flutter test
import 'package:flutter_test/flutter_test.dart';

import 'package:meal_on/main.dart';
import 'package:meal_on/data/restaurant_menu_data.dart';
import 'package:meal_on/screens/reservation/reservation_models.dart';

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
}
