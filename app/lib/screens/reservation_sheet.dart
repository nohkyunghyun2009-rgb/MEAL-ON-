import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/partner_menus.dart';
import '../models/coupon.dart';
import '../models/reservation.dart';
import '../services/coupon_service.dart';
import '../services/kakao_local_service.dart';
import '../services/payment_service.dart';
import '../services/reservation_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'coupon_screen.dart';
import 'payment_sheet.dart';

/// 식당을 누르면 아래에서 올라오는 예약 창
Future<void> showReservationSheet(BuildContext context, Place place) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ReservationSheet(place: place),
  );
}

class _ReservationSheet extends StatefulWidget {
  final Place place;
  const _ReservationSheet({required this.place});

  @override
  State<_ReservationSheet> createState() => _ReservationSheetState();
}

class _ReservationSheetState extends State<_ReservationSheet> {
  late DateTime _visitAt;
  int _people = 2;
  final Map<String, int> _qty = {}; // 메뉴 이름 → 개수 (선주문)
  late final List<MenuItem> _menu = MenuCatalog.forPlace(widget.place);

  int get _orderTotal => _qty.entries.fold(0, (s, e) => s + (_menu.firstWhere((m) => m.name == e.key).price * e.value));
  List<OrderLine> get _orderLines => _qty.entries
      .where((e) => e.value > 0)
      .map((e) => OrderLine(name: e.key, price: _menu.firstWhere((m) => m.name == e.key).price, qty: e.value))
      .toList();

  /// 낼 돈(쿠폰 전): 메뉴를 골랐으면 메뉴값(예약금 없음), 안 골랐으면 예약금
  int get _baseAmount => _orderTotal > 0 ? _orderTotal : PaymentService.depositFor(_people);

  Coupon? _coupon; // 고른 쿠폰 (없으면 null)
  int get _discount => _coupon?.discountFor(_baseAmount) ?? 0;

  /// 실제로 낼 돈 (쿠폰 할인 뺀 뒤)
  int get _payAmount => (_baseAmount - _discount).clamp(0, _baseAmount);

  Future<void> _pickCoupon() async {
    final c = await showCouponPicker(context, amount: _baseAmount);
    if (!mounted) return;
    setState(() => _coupon = c);
  }

  /// 메뉴 줄들 + 묶음 제목(section)이 바뀔 때마다 작은 제목을 끼워 넣어요
  List<Widget> _menuWithHeaders() {
    final widgets = <Widget>[];
    String lastSection = '';
    for (final m in _menu) {
      if (m.section.isNotEmpty && m.section != lastSection) {
        lastSection = m.section;
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 6, left: 2),
          child: Text(m.section, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.primaryDark)),
        ));
      }
      widgets.add(_MenuRow(
        item: m,
        qty: _qty[m.name] ?? 0,
        onChanged: (q) => setState(() => q <= 0 ? _qty.remove(m.name) : _qty[m.name] = q),
      ));
    }
    return widgets;
  }
  final _note = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // 기본값: 지금부터 1시간 뒤, 분은 0 또는 30으로 맞춤
    final now = DateTime.now().add(const Duration(hours: 1));
    _visitAt = DateTime(now.year, now.month, now.day, now.hour, now.minute < 30 ? 0 : 30);
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _visitAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (d != null) {
      setState(() => _visitAt = DateTime(d.year, d.month, d.day, _visitAt.hour, _visitAt.minute));
    }
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _visitAt.hour, minute: _visitAt.minute),
    );
    if (t != null) {
      setState(() => _visitAt = DateTime(_visitAt.year, _visitAt.month, _visitAt.day, t.hour, t.minute));
    }
  }

  Future<void> _submit() async {
    final app = context.read<AppState>();
    final service = context.read<ReservationService>();
    final nickname = app.profile?.nickname ?? '손님';

    // 1) 먼저 카드 결제 창 — 메뉴를 골랐으면 메뉴값, 아니면 예약금(인원 × 1,000원)
    //    쿠폰으로 0원이 되면 결제 창은 건너뛰어요
    final order = _orderLines;
    PayResult? pay;
    if (_payAmount > 0) {
      pay = await showPaymentSheet(
        context,
        amount: _payAmount,
        title: order.isEmpty ? '${widget.place.name} 예약금 ($_people명)' : '${widget.place.name} 선주문 ${order.length}가지',
      );
      if (pay == null) return; // 결제 창을 그냥 닫으면 예약도 안 해요
      if (!mounted) return;
    }

    // 쿠폰을 썼으면 요청사항에 적어서 가게에서도 알 수 있게
    final couponNote = _coupon == null
        ? ''
        : _coupon!.giftNote.isNotEmpty
            ? _coupon!.giftNote
            : '[쿠폰] ${_coupon!.title} (-${formatWon(_discount)})';
    final note = [if (_note.text.trim().isNotEmpty) _note.text.trim(), if (couponNote.isNotEmpty) couponNote].join(' · ');

    // 2) 결제가 성공했을 때만 예약을 만들어요
    setState(() => _sending = true);
    try {
      final r = await service.create(
        restaurantId: widget.place.id,
        restaurantName: widget.place.name,
        restaurantAddress: widget.place.address,
        userNickname: nickname,
        visitAt: _visitAt,
        people: _people,
        note: note,
        deposit: pay?.amount ?? 0,
        cardLast4: pay?.cardLast4 ?? '',
        order: order,
      );
      // 예약이 진짜로 만들어진 뒤에만 쿠폰을 "사용함"으로
      if (_coupon != null && mounted) {
        await context.read<CouponService>().use(_coupon!, widget.place.name);
      }
      if (!mounted) return;
      Navigator.of(context).pop(); // 예약 창 닫기
      await showDialog<void>(
        context: context,
        builder: (_) => _CodeDialog(reservation: r, online: service.isOnline),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('예약을 못 보냈어요: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.place;
    final bottom = MediaQuery.of(context).viewInsets.bottom; // 키보드 높이

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              Text(p.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('${p.shortCategory} · ${p.distanceText} · ${p.address}', style: Theme.of(context).textTheme.bodySmall),
              if (p.phone.isNotEmpty) Text(p.phone, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 20),

              // ───── 방문 시간 ─────
              Text('언제 갈 거야?', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _PickBox(
                      icon: Icons.calendar_today_outlined,
                      text: '${_visitAt.month}월 ${_visitAt.day}일',
                      onTap: _pickDate,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PickBox(
                      icon: Icons.schedule,
                      text: '${_visitAt.hour.toString().padLeft(2, '0')}:${_visitAt.minute.toString().padLeft(2, '0')}',
                      onTap: _pickTime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // ───── 인원 ─────
              Row(
                children: [
                  Text('몇 명이야?', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  IconButton.outlined(
                    onPressed: _people > 1 ? () => setState(() => _people--) : null,
                    icon: const Icon(Icons.remove),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text('$_people명', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
                  ),
                  IconButton.outlined(
                    onPressed: _people < 10 ? () => setState(() => _people++) : null,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ───── 메뉴 미리 주문 ─────
              Row(
                children: [
                  Text('🍽 메뉴 미리 주문', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: MenuCatalog.isPartner(widget.place) ? AppColors.primary : AppColors.line,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      MenuCatalog.isPartner(widget.place) ? '제휴 메뉴' : '샘플 메뉴',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: MenuCatalog.isPartner(widget.place) ? Colors.white : AppColors.muted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('앉자마자 바로 나와요 · 안 골라도 예약은 돼요', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              ..._menuWithHeaders(),
              const SizedBox(height: 14),

              // ───── 요청사항 ─────
              TextField(
                controller: _note,
                maxLines: 2,
                decoration: const InputDecoration(hintText: '요청사항 (예: 창가 자리, 덜 맵게)'),
              ),
              const SizedBox(height: 14),

              // ───── 예약금 안내 ─────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.peach, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(_orderTotal > 0 ? '💳 선주문 결제' : '💳 예약금', style: const TextStyle(fontWeight: FontWeight.w800)),
                        const Spacer(),
                        if (_discount > 0)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Text(formatWon(_baseAmount), style: const TextStyle(fontSize: 12, color: AppColors.muted, decoration: TextDecoration.lineThrough)),
                          ),
                        Text(
                          formatWon(_payAmount),
                          style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primaryDark, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // ── 쿠폰 줄 ──
                    InkWell(
                      onTap: _pickCoupon,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: _coupon == null ? Colors.white : AppColors.sun,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _coupon == null ? AppColors.line : AppColors.sun),
                        ),
                        child: Row(
                          children: [
                            Text(_coupon?.emoji ?? '🎁', style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _coupon == null
                                    ? '쿠폰 쓰기 (${context.watch<CouponService>().available.length}장 있음)'
                                    : '${_coupon!.title}${_discount > 0 ? ' · -${formatWon(_discount)}' : ' · 가게에서 받아요'}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                              ),
                            ),
                            if (_coupon != null)
                              GestureDetector(
                                onTap: () => setState(() => _coupon = null),
                                child: const Icon(Icons.close_rounded, size: 16),
                              )
                            else
                              const Icon(Icons.chevron_right_rounded, size: 18),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (_orderTotal > 0) ...[
                      Text(_orderLines.map((o) => '${o.name}×${o.qty}').join(', '), style: const TextStyle(fontSize: 12, color: AppColors.ink, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      const Text('메뉴값을 미리 내면 예약금은 없어요 · 취소하면 전액 환불', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                    ] else
                      const Text(
                        '1명당 1,000원 · 가게에 가면 음식값에서 빼줘요 · 취소하면 전액 환불',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              FilledButton(
                onPressed: _sending ? null : _submit,
                child: _sending
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_payAmount == 0
                        ? '쿠폰으로 무료 예약하기'
                        : _orderTotal > 0
                            ? '${formatWon(_payAmount)} 결제하고 선주문 예약'
                            : '${formatWon(_payAmount)} 결제하고 예약하기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickBox extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  const _PickBox({required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.green),
              const SizedBox(width: 8),
              Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
        ),
      );
}

/// 예약이 끝나면 크게 보여주는 "예약번호" 창
class _CodeDialog extends StatelessWidget {
  final Reservation reservation;
  final bool online;
  const _CodeDialog({required this.reservation, required this.online});

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    return AlertDialog(
      title: const Text('예약 요청 완료'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            width: double.infinity,
            decoration: BoxDecoration(color: AppColors.mint, borderRadius: BorderRadius.circular(18)),
            child: Column(
              children: [
                const Text('예약번호', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                Text(r.code, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: AppColors.green, letterSpacing: 6)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text('${r.restaurantName}\n${formatVisitTime(r.visitAt)} · ${r.people}명', textAlign: TextAlign.center),
          if (r.deposit > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: AppColors.peach, borderRadius: BorderRadius.circular(999)),
              child: Text(
                r.order.isEmpty
                    ? '💳 예약금 ${formatWon(r.deposit)} 결제 완료 (끝번호 ${r.cardLast4})'
                    : '🍽 ${r.orderSummary} · ${formatWon(r.deposit)} 결제 완료',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            online
                ? '가게에 가서 이 번호를 보여주면 돼요. 사장님이 확인하면 "내 예약"에서 상태가 바뀌어요.'
                : '지금은 연습 모드라 내 폰에만 저장돼요. Firebase를 연결하면 사장님 폰에서도 보여요.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
          onPressed: () => Navigator.pop(context),
          child: const Text('확인'),
        ),
      ],
    );
  }
}


/// 메뉴 한 줄: 이모지 · 이름 · 칼로리/단백질 · 가격 · − 개수 +
class _MenuRow extends StatelessWidget {
  final MenuItem item;
  final int qty;
  final ValueChanged<int> onChanged;
  const _MenuRow({required this.item, required this.qty, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: qty > 0 ? Border.all(color: AppColors.primary, width: 1.5) : null,
        ),
        child: Row(
          children: [
            Text(item.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text('${item.kcal.round()}kcal · 단백질 ${item.proteinG.round()}g', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Text(formatWon(item.price), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(width: 6),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: qty > 0 ? () => onChanged(qty - 1) : null,
              icon: const Icon(Icons.remove_circle_outline, size: 22),
            ),
            SizedBox(width: 18, child: Text('$qty', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900))),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: qty < 9 ? () => onChanged(qty + 1) : null,
              icon: const Icon(Icons.add_circle, size: 22, color: AppColors.primary),
            ),
          ],
        ),
      );
}
