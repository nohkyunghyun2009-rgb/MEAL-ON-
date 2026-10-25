import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_keys.dart';
import '../models/reservation.dart';
import '../services/reservation_service.dart';
import '../theme/app_theme.dart';
import '../widgets/section_title.dart';
import 'my_reservations_screen.dart';

/// 사장님이 보는 화면
/// 1) 우리 가게로 들어온 예약 확인  2) 방문완료 처리 + 결제금액 입력  3) 이번 달 수수료 자동 계산
class OwnerScreen extends StatefulWidget {
  const OwnerScreen({super.key});

  @override
  State<OwnerScreen> createState() => _OwnerScreenState();
}

class _OwnerScreenState extends State<OwnerScreen> {
  final _name = TextEditingController();
  String _restaurant = '';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _markVisited(Reservation r) async {
    final amount = TextEditingController();
    final value = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('방문 확인'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('예약번호 ${r.code} · ${r.userNickname} · ${r.people}명'),
            const SizedBox(height: 12),
            TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(labelText: '결제 금액', suffixText: '원'),
            ),
            const SizedBox(height: 6),
            const Text('월말 수수료 계산에만 쓰여요.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
            onPressed: () => Navigator.pop(context, int.tryParse(amount.text) ?? 0),
            child: const Text('방문완료'),
          ),
        ],
      ),
    );
    if (value != null && mounted) {
      await context.read<ReservationService>().updateStatus(r.id, ReservationStatus.visited, paidAmount: value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ReservationService>();
    final all = _restaurant.isEmpty ? <Reservation>[] : service.forRestaurant(_restaurant);

    final now = DateTime.now();
    final visitedThisMonth = all
        .where((r) => r.status == ReservationStatus.visited && r.visitAt.year == now.year && r.visitAt.month == now.month)
        .toList();
    final sales = visitedThisMonth.fold<int>(0, (s, r) => s + (r.paidAmount ?? 0));
    final fee = (sales * AppKeys.commissionRate).round();
    // 이번 달 카드로 받은 예약금 합계 (환불된 건 제외)
    final depositTotal = all
        .where((r) => r.payStatus == PayStatus.paid && r.visitAt.year == now.year && r.visitAt.month == now.month)
        .fold<int>(0, (s, r) => s + r.deposit);

    final active = all.where((r) => r.status == ReservationStatus.pending || r.status == ReservationStatus.confirmed).toList();
    final done = all.where((r) => r.status == ReservationStatus.visited || r.status == ReservationStatus.cancelled).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('사장님 모드')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          // ───── 가게 이름 ─────
          TextField(
            controller: _name,
            textInputAction: TextInputAction.done,
            onSubmitted: (v) => setState(() => _restaurant = v.trim()),
            decoration: InputDecoration(
              labelText: '가게 이름 (카카오맵에 나온 이름 그대로)',
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: () => setState(() => _restaurant = _name.text.trim()),
              ),
            ),
          ),
          const SizedBox(height: 20),

          if (_restaurant.isNotEmpty) ...[
            // ───── 이번 달 정산 ─────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(22)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${now.month}월 정산 미리보기 · $_restaurant', style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _Big('방문', '${visitedThisMonth.length}건'),
                      _Big('매출', formatWon(sales)),
                      _Big('수수료 ${(AppKeys.commissionRate * 100).round()}%', formatWon(fee)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text('💳 이번 달 받은 예약금 ${formatWon(depositTotal)} · 손님 방문 시 음식값에서 차감', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text('사장님이 "방문완료"를 누른 건만 계산돼요. 월말에 이 금액을 이체해 주시면 돼요.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ───── 들어온 예약 ─────
            SectionTitle('들어온 예약', subtitle: '${active.length}건 기다리는 중'),
            if (active.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text('아직 예약이 없어요.', style: Theme.of(context).textTheme.bodySmall),
              ),
            ...active.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _OwnerCard(
                    reservation: r,
                    onConfirm: r.status == ReservationStatus.pending
                        ? () => service.updateStatus(r.id, ReservationStatus.confirmed)
                        : null,
                    onVisited: () => _markVisited(r),
                  ),
                )),
            const SizedBox(height: 14),

            // ───── 지난 예약 ─────
            if (done.isNotEmpty) ...[
              const SectionTitle('지난 예약'),
              ...done.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _OwnerCard(reservation: r),
                  )),
            ],
          ] else
            Text('가게 이름을 적고 화살표를 누르면 우리 가게 예약이 보여요.', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _Big extends StatelessWidget {
  final String label, value;
  const _Big(this.label, this.value);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ),
      );
}

class _OwnerCard extends StatelessWidget {
  final Reservation reservation;
  final VoidCallback? onConfirm;
  final VoidCallback? onVisited;
  const _OwnerCard({required this.reservation, this.onConfirm, this.onVisited});

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
                Text(r.code, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.green, letterSpacing: 3)),
                const SizedBox(width: 12),
                Expanded(child: Text('${r.userNickname} · ${r.people}명', style: Theme.of(context).textTheme.titleMedium)),
                StatusChip(status: r.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(formatVisitTime(r.visitAt), style: Theme.of(context).textTheme.bodyMedium),
            if (r.note.isNotEmpty) Text('요청: ${r.note}', style: Theme.of(context).textTheme.bodySmall),
            if (r.order.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.mint, borderRadius: BorderRadius.circular(10)),
                child: Text('🍽 선주문 · ${r.orderSummary}\n손님 도착 시간에 맞춰 준비해 주세요', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
              ),
            if (r.deposit > 0)
              Text(
                r.payStatus == PayStatus.refunded
                    ? '💳 ${formatWon(r.deposit)} 환불됨 (취소)'
                    : r.order.isNotEmpty
                        ? '💳 메뉴값 ${formatWon(r.deposit)} 선결제됨 · 추가 결제 없음'
                        : '💳 예약금 ${formatWon(r.deposit)} 받음 · 방문 시 음식값에서 차감해 주세요',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: r.payStatus == PayStatus.refunded ? AppColors.muted : AppColors.primaryDark),
              ),
            if (r.paidAmount != null) Text('결제 ${formatWon(r.paidAmount!)}', style: Theme.of(context).textTheme.bodySmall),
            if (onConfirm != null || onVisited != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (onConfirm != null)
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                        onPressed: onConfirm,
                        child: const Text('예약 확정'),
                      ),
                    ),
                  if (onConfirm != null && onVisited != null) const SizedBox(width: 8),
                  if (onVisited != null)
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                        onPressed: onVisited,
                        child: const Text('방문완료'),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
