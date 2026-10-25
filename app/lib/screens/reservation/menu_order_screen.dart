// ============================================================
// menu_order_screen.dart
// 화면 2: 메뉴 고르기 (수량 + / -)  →  아래 "예약하기" 버튼
//
// - 메뉴는 묶음(카테고리)별로 제목이 붙어서 나와요.
// - 검색창에 글자를 치면 그 글자가 들어간 메뉴만 보여요.
// - 메뉴를 안 골라도 예약은 할 수 있어요 ("메뉴 없이 예약하기").
// ============================================================

import 'package:flutter/material.dart';
import '../../data/restaurant_menu_data.dart';
import 'reservation_models.dart';
import 'reservation_form_screen.dart';

class MenuOrderScreen extends StatefulWidget {
  final Restaurant restaurant;

  const MenuOrderScreen({super.key, required this.restaurant});

  @override
  State<MenuOrderScreen> createState() => _MenuOrderScreenState();
}

class _MenuOrderScreenState extends State<MenuOrderScreen> {
  /// 장바구니: 메뉴 이름 → 담은 줄
  /// (메뉴 이름이 식당 안에서는 겹치지 않으니까 이름을 열쇠로 써요)
  final Map<String, CartItem> _cart = {};
  String _keyword = '';

  // ---------- 장바구니 계산 ----------
  int get _totalCount =>
      _cart.values.fold(0, (sum, c) => sum + c.quantity);
  int get _totalPrice =>
      _cart.values.fold(0, (sum, c) => sum + c.subtotal);

  int _qtyOf(MenuItem m) => _cart[m.name]?.quantity ?? 0;

  void _plus(MenuItem m) {
    setState(() {
      final line = _cart[m.name];
      if (line == null) {
        _cart[m.name] = CartItem(menu: m, quantity: 1);
      } else {
        line.quantity++;
      }
    });
  }

  void _minus(MenuItem m) {
    setState(() {
      final line = _cart[m.name];
      if (line == null) return;
      line.quantity--;
      if (line.quantity <= 0) _cart.remove(m.name);
    });
  }

  // ---------- 다음 화면으로 ----------
  void _goReservation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReservationFormScreen(
          restaurant: widget.restaurant,
          cart: _cart.values.toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.restaurant;

    // 검색어로 걸러낸 카테고리 목록 만들기
    final k = _keyword.toLowerCase();
    final visibleCategories = r.categories
        .map((c) => MenuCategory(
              name: c.name,
              items: c.items
                  .where((m) =>
                      k.isEmpty || m.name.toLowerCase().contains(k))
                  .toList(),
            ))
        .where((c) => c.items.isNotEmpty)
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: Text(r.name),
        backgroundColor: kBrandGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ---------- 식당 소개 + 검색 ----------
          Container(
            color: kBrandGreen,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.description,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                const SizedBox(height: 10),
                if (r.hasMenu)
                  TextField(
                    onChanged: (v) => setState(() => _keyword = v.trim()),
                    decoration: InputDecoration(
                      hintText: '메뉴 검색',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ---------- 메뉴 목록 ----------
          Expanded(
            child: !r.hasMenu
                ? _EmptyMenu()
                : visibleCategories.isEmpty
                    ? const Center(child: Text('검색 결과가 없어요'))
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                        children: [
                          for (final c in visibleCategories) ...[
                            // 카테고리 제목
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(4, 14, 4, 8),
                              child: Text(
                                c.name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: kBrandGreenDark,
                                ),
                              ),
                            ),
                            // 그 카테고리의 메뉴들
                            for (final m in c.items)
                              _MenuRow(
                                menu: m,
                                quantity: _qtyOf(m),
                                onPlus: () => _plus(m),
                                onMinus: () => _minus(m),
                              ),
                          ],
                        ],
                      ),
          ),
        ],
      ),

      // ---------- 아래 고정 바: 담은 개수 / 총액 / 예약 버튼 ----------
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2)),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _totalCount == 0 ? '담은 메뉴 없음' : '$_totalCount개 담음',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    Text(
                      '${formatWon(_totalPrice)}원',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _goReservation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kBrandGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                  ),
                  child: Text(
                    _totalCount == 0 ? '메뉴 없이 예약하기' : '예약하기',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 메뉴판이 아직 없는 식당일 때 보여주는 안내
class _EmptyMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.restaurant_menu, size: 48, color: Colors.black26),
            SizedBox(height: 12),
            Text(
              '메뉴판을 준비 중이에요.\n메뉴 없이 방문 예약만 할 수 있어요.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

/// 메뉴 한 줄: 이름 / 설명 / 가격 / [-] 수량 [+]
class _MenuRow extends StatelessWidget {
  final MenuItem menu;
  final int quantity;
  final VoidCallback onPlus;
  final VoidCallback onMinus;

  const _MenuRow({
    required this.menu,
    required this.quantity,
    required this.onPlus,
    required this.onMinus,
  });

  @override
  Widget build(BuildContext context) {
    final picked = quantity > 0;
    final canOrder = menu.price > 0; // 가격 문의 메뉴는 주문 담기 불가

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: picked ? kBrandGreen : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  menu.name,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
                if (menu.note.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    menu.note,
                    style: const TextStyle(fontSize: 11, color: Colors.black45),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  menu.priceText,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: canOrder ? Colors.black87 : Colors.orange,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (canOrder)
            // 수량 조절 버튼
            Container(
              decoration: BoxDecoration(
                color: picked ? kBrandGreenLight : const Color(0xFFF0F1F3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: picked ? onMinus : null,
                    icon: const Icon(Icons.remove),
                    iconSize: 18,
                    color: kBrandGreenDark,
                    constraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: EdgeInsets.zero,
                  ),
                  SizedBox(
                    width: 22,
                    child: Text(
                      '$quantity',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  IconButton(
                    onPressed: onPlus,
                    icon: const Icon(Icons.add),
                    iconSize: 18,
                    color: kBrandGreenDark,
                    constraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
