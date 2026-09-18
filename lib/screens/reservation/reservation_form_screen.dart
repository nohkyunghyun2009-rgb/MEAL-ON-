// ============================================================
// reservation_form_screen.dart
// 화면 3: 예약 정보 입력 (날짜·시간·인원·이름·연락처) + 예약금 결제(모의)
//
// - 예약금 = 인원 × 1,000원 (선결제, 진짜 결제는 안 되고 흉내만 냄)
// - "결제하기"를 누르면 ReservationStore 에 저장하고 완료 화면으로 넘어가요.
// ============================================================

import 'package:flutter/material.dart';
import '../../data/restaurant_menu_data.dart';
import 'reservation_models.dart';
import 'reservation_done_screen.dart';

class ReservationFormScreen extends StatefulWidget {
  final Restaurant restaurant;
  final List<CartItem> cart; // 메뉴 화면에서 담아온 메뉴들 (비어있을 수도 있음)

  const ReservationFormScreen({
    super.key,
    required this.restaurant,
    required this.cart,
  });

  @override
  State<ReservationFormScreen> createState() => _ReservationFormScreenState();
}

class _ReservationFormScreenState extends State<ReservationFormScreen> {
  // 입력값들
  DateTime _date = DateTime.now().add(const Duration(days: 1)); // 기본: 내일
  TimeOfDay _time = const TimeOfDay(hour: 18, minute: 0);       // 기본: 오후 6시
  int _people = 2;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _memoCtrl = TextEditingController();
  bool _paying = false; // 결제 중이면 버튼 잠그기

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  // ---------- 계산 ----------
  int get _menuTotal => widget.cart.fold(0, (s, c) => s + c.subtotal);
  int get _deposit => _people * kDepositPerPerson;

  DateTime get _visitAt =>
      DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  // ---------- 날짜 / 시간 고르기 ----------
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
      helpText: '방문 날짜 선택',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: '방문 시간 선택',
    );
    if (picked != null) setState(() => _time = picked);
  }

  // ---------- 결제 + 예약 저장 ----------
  Future<void> _submit() async {
    // 1) 빈칸 검사
    if (_nameCtrl.text.trim().isEmpty) {
      _toast('예약자 이름을 적어주세요');
      return;
    }
    if (_phoneCtrl.text.trim().length < 9) {
      _toast('연락처를 정확히 적어주세요');
      return;
    }

    // 2) 결제 확인창
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('예약금 결제'),
        content: Text(
          '예약금 ${formatWon(_deposit)}원을 결제할까요?\n'
          '(인원 $_people명 × 1,000원)\n\n'
          '※ 시연용 모의 결제예요. 실제로 돈이 빠져나가지 않아요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: kBrandGreen, foregroundColor: Colors.white),
            child: const Text('결제하기'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    // 3) 결제 흉내 (1.2초 기다리기)
    setState(() => _paying = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    // 4) 예약 저장
    final reservation = ReservationStore.instance.add(
      restaurant: widget.restaurant,
      visitAt: _visitAt,
      people: _people,
      customerName: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      memo: _memoCtrl.text.trim(),
      items: widget.cart,
    );

    setState(() => _paying = false);

    // 5) 완료 화면으로 (뒤로가기 눌러도 입력 화면으로 안 돌아오게 pushReplacement)
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ReservationDoneScreen(reservation: reservation),
      ),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: const Text('예약 정보 입력'),
        backgroundColor: kBrandGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          // ---------- 식당 이름 ----------
          _SectionCard(
            title: '식당',
            child: Row(
              children: [
                const Icon(Icons.storefront, color: kBrandGreenDark),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.restaurant.name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // ---------- 날짜 / 시간 ----------
          _SectionCard(
            title: '방문 일시',
            child: Row(
              children: [
                Expanded(
                  child: _PickButton(
                    icon: Icons.calendar_today,
                    label: '${_date.month}월 ${_date.day}일',
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PickButton(
                    icon: Icons.access_time,
                    label: _time.format(context),
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),
          ),

          // ---------- 인원 ----------
          _SectionCard(
            title: '인원',
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$_people명',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                _RoundIconButton(
                  icon: Icons.remove,
                  onTap: _people > 1
                      ? () => setState(() => _people--)
                      : null,
                ),
                const SizedBox(width: 10),
                _RoundIconButton(
                  icon: Icons.add,
                  onTap: _people < 20
                      ? () => setState(() => _people++)
                      : null,
                ),
              ],
            ),
          ),

          // ---------- 예약자 정보 ----------
          _SectionCard(
            title: '예약자 정보',
            child: Column(
              children: [
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '이름',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: '연락처',
                    hintText: '010-0000-0000',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _memoCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: '요청사항 (선택)',
                    hintText: '예: 창가 자리로 부탁드려요',
                    prefixIcon: Icon(Icons.edit_note),
                  ),
                ),
              ],
            ),
          ),

          // ---------- 주문 메뉴 요약 ----------
          _SectionCard(
            title: '미리 주문한 메뉴',
            child: widget.cart.isEmpty
                ? const Text('담은 메뉴가 없어요 (방문해서 주문할게요)',
                    style: TextStyle(color: Colors.black54))
                : Column(
                    children: [
                      for (final c in widget.cart)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${c.menu.name}  × ${c.quantity}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                              Text('${formatWon(c.subtotal)}원',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      const Divider(height: 20),
                      Row(
                        children: [
                          const Expanded(
                              child: Text('메뉴 예상 금액',
                                  style: TextStyle(color: Colors.black54))),
                          Text('${formatWon(_menuTotal)}원',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '※ 메뉴 금액은 방문해서 식당에 결제해요',
                          style: TextStyle(fontSize: 11, color: Colors.black45),
                        ),
                      ),
                    ],
                  ),
          ),

          // ---------- 예약금 ----------
          _SectionCard(
            title: '예약금 (지금 결제)',
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                        child: Text('$_people명 × ${formatWon(kDepositPerPerson)}원',
                            style: const TextStyle(color: Colors.black54))),
                    Text(
                      '${formatWon(_deposit)}원',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: kBrandGreenDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '예약금은 방문하면 음식값에서 빼드려요. 노쇼 방지용이에요.',
                    style: TextStyle(fontSize: 11, color: Colors.black45),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      // ---------- 아래 결제 버튼 ----------
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _paying ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: kBrandGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _paying
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : Text(
                      '예약금 ${formatWon(_deposit)}원 결제하고 예약하기',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------- 작은 부품(위젯)들 ----------------

/// 흰 카드 + 제목
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
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
          Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// 날짜/시간 고르는 버튼
class _PickButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PickButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: kBrandGreenDark),
      label: Text(label,
          style: const TextStyle(
              color: Colors.black87, fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: const BorderSide(color: kBrandGreen),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// 동그란 + / - 버튼
class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _RoundIconButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: enabled ? kBrandGreenLight : const Color(0xFFF0F1F3),
          shape: BoxShape.circle,
        ),
        child: Icon(icon,
            color: enabled ? kBrandGreenDark : Colors.black26, size: 20),
      ),
    );
  }
}
