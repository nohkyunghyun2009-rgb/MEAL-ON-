// ============================================================
// restaurant_list_screen.dart
// 화면 1: 제휴 식당 목록
//
// 흐름: [식당 목록] → (탭) → [메뉴 고르기] → [예약 정보 입력] → [예약 완료]
//
// 다른 화면에서 이 화면을 여는 방법:
//   Navigator.push(
//     context,
//     MaterialPageRoute(builder: (_) => const RestaurantListScreen()),
//   );
// ============================================================

import 'package:flutter/material.dart';
import '../../data/restaurant_menu_data.dart';
import 'reservation_models.dart';
import 'menu_order_screen.dart';

class RestaurantListScreen extends StatefulWidget {
  const RestaurantListScreen({super.key});

  @override
  State<RestaurantListScreen> createState() => _RestaurantListScreenState();
}

class _RestaurantListScreenState extends State<RestaurantListScreen> {
  String _keyword = ''; // 검색창에 적은 글자

  @override
  Widget build(BuildContext context) {
    // 검색어가 있으면 식당 이름/종류/메뉴 이름에 그 글자가 들어간 식당만 보여줌
    final list = partnerRestaurants.where((r) {
      if (_keyword.isEmpty) return true;
      final k = _keyword.toLowerCase();
      if (r.name.toLowerCase().contains(k)) return true;
      if (r.category.toLowerCase().contains(k)) return true;
      for (final c in r.categories) {
        for (final m in c.items) {
          if (m.name.toLowerCase().contains(k)) return true;
        }
      }
      return false;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: const Text('제휴 식당 예약'),
        backgroundColor: kBrandGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ---------- 초록 헤더 + 검색창 ----------
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [kBrandGreen, kBrandGreenDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '백마 학원가 반경 1km',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  '제휴 식당 ${partnerRestaurants.length}곳',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (v) => setState(() => _keyword = v.trim()),
                  decoration: InputDecoration(
                    hintText: '식당 이름이나 메뉴로 찾기 (예: 우동, 치킨)',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ---------- 식당 카드 목록 ----------
          Expanded(
            child: list.isEmpty
                ? const Center(child: Text('검색 결과가 없어요'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    itemBuilder: (context, i) => _RestaurantCard(
                      restaurant: list[i],
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                MenuOrderScreen(restaurant: list[i]),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// 식당 카드 1장
class _RestaurantCard extends StatelessWidget {
  final Restaurant restaurant;
  final VoidCallback onTap;

  const _RestaurantCard({required this.restaurant, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 왼쪽 동그란 아이콘 (식당 이름 첫 글자)
              CircleAvatar(
                radius: 26,
                backgroundColor: kBrandGreenLight,
                child: Text(
                  r.name.substring(0, 1),
                  style: const TextStyle(
                    color: kBrandGreenDark,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // 가운데 글자들
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            r.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: kBrandGreenLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            r.category,
                            style: const TextStyle(
                              fontSize: 11,
                              color: kBrandGreenDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      r.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      r.hasMenu ? '메뉴 ${r.menuCount}개' : '메뉴 준비중',
                      style: TextStyle(
                        fontSize: 12,
                        color: r.hasMenu ? kBrandGreenDark : Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.black26),
            ],
          ),
        ),
      ),
    );
  }
}
