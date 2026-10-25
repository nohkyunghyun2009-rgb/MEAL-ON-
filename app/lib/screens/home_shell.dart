import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'ai_chat_screen.dart';
import 'meal_log_screen.dart';
import 'my_reservations_screen.dart';
import 'restaurant_map_screen.dart';

/// 아래 탭 4개를 가진 "집" 화면.
/// IndexedStack을 쓰면 탭을 옮겨도 각 화면이 기억을 잃지 않아요.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _go(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final pages = [
      MealLogScreen(onGoToTab: _go), // 홈에서 "AI 추천/근처 식당" 타일을 누르면 탭이 바뀌어요
      const AiChatScreen(),
      const RestaurantMapScreen(),
      const MyReservationsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, -4))],
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _go,
          backgroundColor: Colors.white,
          indicatorColor: AppColors.peach,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: '홈'),
            NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'AI 추천'),
            NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront_rounded), label: '식당'),
            NavigationDestination(icon: Icon(Icons.confirmation_number_outlined), selectedIcon: Icon(Icons.confirmation_number_rounded), label: '내 예약'),
          ],
        ),
      ),
    );
  }
}
