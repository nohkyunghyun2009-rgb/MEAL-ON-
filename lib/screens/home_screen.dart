// ============================================================
// home_screen.dart
// 홈 화면 (Grab 스타일 서비스 타일)
//
// - "식당 예약" 타일 → 제휴 식당 목록 → 메뉴 고르기 → 예약 → 완료
// - "내 예약"  타일 → 지금까지 한 예약 목록
//
// 나중에 다른 기능(칼로리, 지도, 쿠폰 등)을 추가하려면
// 아래 _tiles 리스트에 _ServiceTile 을 하나 더 넣으면 돼요.
// ============================================================

import 'package:flutter/material.dart';
import '../data/restaurant_menu_data.dart';
import 'reservation/reservation_models.dart';
import 'reservation/restaurant_list_screen.dart';
import 'reservation/reservation_done_screen.dart';
import '../widgets/restaurant_promo_banner.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // ---------- 초록 헤더 ----------
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [kBrandGreen, kBrandGreenDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'MEAL:ON',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '백마 학원가 학생 식당 예약 서비스',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.storefront, color: Colors.white),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '제휴 식당 ${partnerRestaurants.length}곳 · '
                            '메뉴 ${_totalMenuCount()}개',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ---------- 서비스 타일 ----------
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text(
                '서비스',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                // 화면이 넓어져도(웹 브라우저) 타일 높이는 150으로 고정
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: 150,
                ),
                children: [
                  _ServiceTile(
                    icon: Icons.restaurant,
                    title: '식당 예약',
                    subtitle: '메뉴 고르고 예약금 결제',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RestaurantListScreen()),
                      );
                    },
                  ),
                  _ServiceTile(
                    icon: Icons.receipt_long,
                    title: '내 예약',
                    subtitle: '예약 내역 확인',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const MyReservationsScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),

            // ---------- 제휴 식당 간판 홍보 배너 ----------
            // 위치를 옮기고 싶으면 이 3줄을 원하는 자리로 옮기면 돼요.
            const SizedBox(height: 20),
            const RestaurantPromoBanner(),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  int _totalMenuCount() =>
      partnerRestaurants.fold(0, (sum, r) => sum + r.menuCount);
}

/// 홈 화면의 서비스 타일 1개
class _ServiceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ServiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: kBrandGreenLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: kBrandGreenDark),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
