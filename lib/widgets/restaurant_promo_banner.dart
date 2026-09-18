// ============================================================
// restaurant_promo_banner.dart
// 홈 화면용 "제휴 식당 간판 홍보 배너" (자동 슬라이드)
//
// 쓰는 법 — 홈 화면 파일에 2줄만 추가하면 돼요:
//
//   import '../widgets/restaurant_promo_banner.dart';   // 파일 맨 위
//   const RestaurantPromoBanner(),                      // 배너가 나올 자리
//
// - 배너 내용은 data/promo_banner_data.dart 에서 고쳐요.
// - 4초마다 자동으로 다음 배너로 넘어가고, 손가락으로 넘겨도 돼요.
// - 누르면 그 식당의 메뉴·예약 화면으로 이동해요.
// - 간판 사진이 있으면 사진 위에 글자가, 없으면 색 배경 위에 글자가 나와요.
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import '../data/promo_banner_data.dart';
import '../data/restaurant_menu_data.dart';
import '../screens/reservation/menu_order_screen.dart';

class RestaurantPromoBanner extends StatefulWidget {
  /// 보여줄 배너들 (기본: promo_banner_data.dart 의 promoBanners)
  final List<PromoBanner> banners;

  /// 배너 높이
  final double height;

  /// 자동으로 넘어가는 간격
  final Duration interval;

  const RestaurantPromoBanner({
    super.key,
    this.banners = promoBanners,
    this.height = 150,
    this.interval = const Duration(seconds: 4),
  });

  @override
  State<RestaurantPromoBanner> createState() => _RestaurantPromoBannerState();
}

class _RestaurantPromoBannerState extends State<RestaurantPromoBanner> {
  final _controller = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _startAutoSlide();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startAutoSlide() {
    _timer?.cancel();
    if (widget.banners.length < 2) return; // 1장이면 넘길 필요 없음
    _timer = Timer.periodic(widget.interval, (_) {
      if (!_controller.hasClients) return;
      final next = (_page + 1) % widget.banners.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Restaurant? _findRestaurant(String id) {
    for (final r in partnerRestaurants) {
      if (r.id == id) return r;
    }
    return null;
  }

  void _open(PromoBanner b) {
    final r = _findRestaurant(b.restaurantId);
    if (r == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('식당 정보를 찾을 수 없어요 (${b.restaurantId})')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MenuOrderScreen(restaurant: r)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.banners.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) {
              final b = widget.banners[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _BannerCard(
                  banner: b,
                  restaurant: _findRestaurant(b.restaurantId),
                  onTap: () => _open(b),
                ),
              );
            },
          ),
        ),
        if (widget.banners.length > 1) ...[
          const SizedBox(height: 8),
          // ---------- 아래 점(●○○) 표시 ----------
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < widget.banners.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _page
                        ? const Color(0xFF00B14F)
                        : Colors.black.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// 배너 카드 1장
class _BannerCard extends StatelessWidget {
  final PromoBanner banner;
  final Restaurant? restaurant;
  final VoidCallback onTap;

  const _BannerCard({
    required this.banner,
    required this.restaurant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = banner.title.isNotEmpty
        ? banner.title
        : (restaurant?.name ?? banner.restaurantId);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Material(
        color: banner.color,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ---------- 배경: 간판 사진 or 색 ----------
              if (banner.hasImage)
                _BannerImage(banner: banner)
              else
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        banner.color,
                        Color.lerp(banner.color, Colors.black, 0.25)!,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),

              // 사진 위 글자가 잘 보이도록 왼쪽을 어둡게
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: banner.hasImage ? 0.62 : 0.10),
                      Colors.black.withValues(alpha: banner.hasImage ? 0.25 : 0.0),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),

              // 사진이 없을 때 오른쪽에 큰 첫 글자 장식
              if (!banner.hasImage)
                Positioned(
                  right: -6,
                  bottom: -22,
                  child: Text(
                    title.substring(0, 1),
                    style: TextStyle(
                      fontSize: 140,
                      fontWeight: FontWeight.w900,
                      color: Colors.white.withValues(alpha: 0.14),
                      height: 1,
                    ),
                  ),
                ),

              // ---------- 글자 + 버튼 ----------
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              _Chip(text: banner.badge, filled: true),
                              const SizedBox(width: 6),
                              const _Chip(text: 'AD'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            banner.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 예약하기 버튼 (모양만 — 카드 전체가 눌려요)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '예약하기 →',
                        style: TextStyle(
                          color: Color.lerp(banner.color, Colors.black, 0.2),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 간판 사진 (인터넷 주소면 Network, 아니면 앱 안의 assets 파일)
/// 사진을 못 불러오면 색 배경으로 대신 보여줘요.
class _BannerImage extends StatelessWidget {
  final PromoBanner banner;
  const _BannerImage({required this.banner});

  @override
  Widget build(BuildContext context) {
    Widget fallback(BuildContext _, Object __, StackTrace? ___) =>
        ColoredBox(color: banner.color);

    return banner.isNetworkImage
        ? Image.network(banner.image, fit: BoxFit.cover, errorBuilder: fallback)
        : Image.asset(banner.image, fit: BoxFit.cover, errorBuilder: fallback);
  }
}

/// 작은 라벨 (제휴 식당 / AD)
class _Chip extends StatelessWidget {
  final String text;
  final bool filled;
  const _Chip({required this.text, this.filled = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: filled ? Colors.white : Colors.transparent,
        border: filled ? null : Border.all(color: Colors.white70, width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: filled ? Colors.black87 : Colors.white,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
