// ============================================================
// promo_banner_data.dart
// 홈 화면 "제휴 식당 간판 홍보 배너"에 들어갈 내용
//
// ▶ 배너를 추가하려면 맨 아래 promoBanners 리스트에 PromoBanner(...) 를 하나 더 붙이면 돼요.
// ▶ restaurantId 는 restaurant_menu_data.dart 에 있는 식당의 id 와 똑같이 적어요.
//   (누르면 그 식당의 메뉴·예약 화면으로 이동해요)
// ▶ 간판 사진을 넣는 방법 2가지:
//     1) 인터넷 주소:  image: 'https://....jpg'
//     2) 앱 안의 파일: assets/banners/ 폴더에 사진을 넣고  image: 'assets/banners/hochicken.jpg'
//   사진이 없으면 image: '' 로 두면 색 배경으로 나와요.
// ============================================================

import 'package:flutter/material.dart';

/// 홍보 배너 1장
class PromoBanner {
  final String restaurantId; // 어느 식당인지 (restaurant_menu_data.dart 의 id)
  final String title;        // 큰 글자 (비우면 식당 이름이 나와요)
  final String subtitle;     // 작은 글자 (홍보 문구)
  final String badge;        // 왼쪽 위 작은 표시 (예: 신규 제휴, 학생 할인)
  final String image;        // 간판 사진 (없으면 '')
  final Color color;         // 사진이 없을 때 배경색

  const PromoBanner({
    required this.restaurantId,
    this.title = '',
    required this.subtitle,
    this.badge = '제휴 식당',
    this.image = '',
    this.color = const Color(0xFF00B14F),
  });

  bool get hasImage => image.isNotEmpty;
  bool get isNetworkImage => image.startsWith('http');
}

/// ★ 홈 화면에 돌아가는 배너 목록 ★
/// 순서대로 4초마다 자동으로 넘어가요. (문구는 예시예요 — 식당과 정한 내용으로 바꿔주세요)
const List<PromoBanner> promoBanners = [
  PromoBanner(
    restaurantId: 'hochicken',
    subtitle: '오리지널·스페셜·로스트 3종 라인업\n미리 주문하면 기다림 없이 바로!',
    badge: '치킨',
    color: Color(0xFFE8562A),
  ),
  PromoBanner(
    restaurantId: 'hanjan',
    subtitle: '탕·요리·꼬치·피자파스타·디저트까지\n친구들과 모임은 여기서',
    badge: '한식·포차',
    color: Color(0xFF2E7D32),
  ),
  PromoBanner(
    restaurantId: 'dorothy',
    subtitle: '가성비 수제 샌드위치\n학원 가기 전 든든하게',
    badge: '샌드위치',
    color: Color(0xFFF2A900),
  ),
];
