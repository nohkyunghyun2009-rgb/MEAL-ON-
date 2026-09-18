// ============================================================
// reservation_done_screen.dart
// 화면 4: 예약 완료 (예약 번호 + 요약)   /   화면 5: 내 예약 목록
//
// - 완료 화면에서 "내 예약 보기"를 누르면 지금까지 한 예약을 볼 수 있어요.
// - 식당 사장님 확인 기능은 나중에 Firebase 붙일 때 추가하면 돼요.
// ============================================================

import 'package:flutter/material.dart';
import '../../data/restaurant_menu_data.dart';
import 'reservation_models.dart';

class ReservationDoneScreen extends StatelessWidget {
  final Reservation reservation;

  const ReservationDoneScreen({super.key, required this.reservation});

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: const Text('예약 완료'),
        backgroundColor: kBrandGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false, // 뒤로가기 화살표 숨기기
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---------- 체크 아이콘 ----------
          const SizedBox(height: 12),
          const Icon(Icons.check_circle, size: 80, color: kBrandGreen),
          const SizedBox(height: 12),
          const Text(
            '예약이 접수됐어요!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '예약번호 ${r.id}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 20),

          // ---------- 요약 카드 ----------
          _card(
            children: [
              _row('식당', r.restaurant.name, bold: true),
              _row('방문', formatVisitTime(r.visitAt)),
              _row('인원', '${r.people}명'),
              _row('예약자', '${r.customerName} (${r.phone})'),
              if (r.memo.isNotEmpty) _row('요청', r.memo),
            ],
          ),

          if (r.items.isNotEmpty)
            _card(
              children: [
                const Text('미리 주문한 메뉴',
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                for (final c in r.items)
                  _row('${c.menu.name} × ${c.quantity}',
                      '${formatWon(c.subtotal)}원'),
                const Divider(height: 20),
                _row('메뉴 예상 금액', '${formatWon(r.menuTotal)}원', bold: true),
              ],
            ),

          _card(
            children: [
              _row('결제한 예약금', '${formatWon(r.deposit)}원',
                  bold: true, color: kBrandGreenDark),
              const SizedBox(height: 4),
              const Text(
                '식당에서 예약을 확인하면 알림을 보내드려요.',
                style: TextStyle(fontSize: 12, color: Colors.black45),
              ),
            ],
          ),

          const SizedBox(height: 12),
          // ---------- 버튼 2개 ----------
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const MyReservationsScreen()),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: kBrandGreen),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('내 예약 보기',
                      style: TextStyle(color: kBrandGreenDark)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // 예약 흐름의 맨 처음(식당 목록 이전 화면)까지 돌아가기
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kBrandGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('홈으로'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _row(String left, String right,
      {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
              child: Text(left,
                  style: const TextStyle(color: Colors.black54, fontSize: 13))),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              right,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                color: color ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 화면 5: 내 예약 목록
class MyReservationsScreen extends StatelessWidget {
  const MyReservationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final list = ReservationStore.instance.all;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: const Text('내 예약'),
        backgroundColor: kBrandGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: list.isEmpty
          ? const Center(child: Text('아직 예약이 없어요'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final r = list[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(r.restaurant.name,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: kBrandGreenLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('확인 대기',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: kBrandGreenDark,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('${formatVisitTime(r.visitAt)} · ${r.people}명',
                          style: const TextStyle(color: Colors.black54)),
                      if (r.items.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          r.items
                              .map((c) => '${c.menu.name}×${c.quantity}')
                              .join(', '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black45),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text('예약금 ${formatWon(r.deposit)}원 · 예약번호 ${r.id}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black45)),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
