import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_keys.dart';
import '../models/reservation.dart';
import '../services/reservation_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'owner_screen.dart';

/// "내 예약" 탭
class MyReservationsScreen extends StatelessWidget {
  const MyReservationsScreen({super.key});

  Future<void> _openOwnerMode(BuildContext context) async {
    final pin = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('사장님 모드'),
        content: TextField(
          controller: pin,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '비밀번호'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(80, 44)),
            onPressed: () => Navigator.pop(context, pin.text == AppKeys.ownerPin),
            child: const Text('들어가기'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OwnerScreen()));
    } else if (ok == false && context.mounted && pin.text.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('비밀번호가 달라요')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final nickname = context.watch<AppState>().profile?.nickname ?? '손님';
    final service = context.watch<ReservationService>();
    final list = service.forUser(nickname);

    return Scaffold(
      appBar: AppBar(
        title: const Text('내 예약'),
        actions: [
          IconButton(
            tooltip: '사장님 모드',
            icon: const Icon(Icons.storefront_outlined),
            onPressed: () => _openOwnerMode(context),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!service.isOnline)
            Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.sun.withOpacity(0.2), borderRadius: BorderRadius.circular(14)),
              child: const Text('연습 모드: 예약이 내 폰에만 저장돼요. Firebase를 연결하면 사장님과 공유돼요.', style: TextStyle(fontSize: 13)),
            ),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.confirmation_number_outlined, size: 40, color: AppColors.muted),
                        const SizedBox(height: 10),
                        Text('아직 예약이 없어요', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text('"식당 찾기"에서 가게를 눌러봐요', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _ReservationCard(reservation: list[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ReservationCard extends StatelessWidget {
  final Reservation reservation;
  const _ReservationCard({required this.reservation});

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(r.restaurantName, style: Theme.of(context).textTheme.titleMedium)),
                StatusChip(status: r.status),
              ],
            ),
            const SizedBox(height: 6),
            Text('${formatVisitTime(r.visitAt)} · ${r.people}명', style: Theme.of(context).textTheme.bodyMedium),
            if (r.note.isNotEmpty) Text('요청: ${r.note}', style: Theme.of(context).textTheme.bodySmall),
            if (r.order.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('🍽 선주문: ${r.orderSummary}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink)),
              ),
            if (r.deposit > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  r.payStatus == PayStatus.refunded
                      ? '💳 ${formatWon(r.deposit)} 환불됨'
                      : r.order.isNotEmpty
                          ? '💳 메뉴값 ${formatWon(r.deposit)} 결제 완료 · 앉으면 바로 나와요'
                          : '💳 예약금 ${formatWon(r.deposit)} 결제됨 · 방문 시 음식값에서 차감',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: r.payStatus == PayStatus.refunded ? AppColors.muted : AppColors.green,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: AppColors.mint, borderRadius: BorderRadius.circular(12)),
                  child: Text('예약번호 ${r.code}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.green, letterSpacing: 2)),
                ),
                const Spacer(),
                if (r.status == ReservationStatus.pending)
                  TextButton(
                    onPressed: () async {
                      // 실수로 누르는 걸 막으려고 한 번 물어봐요
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('예약을 취소할까요?'),
                          content: Text(r.deposit > 0
                              ? '예약금 ${formatWon(r.deposit)}은 카드로 바로 환불돼요.'
                              : '취소하면 되돌릴 수 없어요.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('아니요')),
                            FilledButton(
                              style: FilledButton.styleFrom(minimumSize: const Size(80, 44)),
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('네, 취소할게요'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true && context.mounted) {
                        await context.read<ReservationService>().updateStatus(r.id, ReservationStatus.cancelled);
                        if (context.mounted && r.deposit > 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('예약이 취소됐어요. 예약금 ${formatWon(r.deposit)}이 환불됐어요.')),
                          );
                        }
                      }
                    },
                    child: const Text('취소', style: TextStyle(color: AppColors.muted)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 상태(대기/확정/방문완료/취소)를 색깔 알약으로
class StatusChip extends StatelessWidget {
  final ReservationStatus status;
  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ReservationStatus.pending => AppColors.sun,
      ReservationStatus.confirmed => AppColors.sky,
      ReservationStatus.visited => AppColors.green,
      ReservationStatus.cancelled => AppColors.muted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(999)),
      child: Text(status.label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }
}
