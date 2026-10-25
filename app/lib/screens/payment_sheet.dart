import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/payment_service.dart';
import '../theme/app_theme.dart';

/// ═══════════════════════════════════════════════════════════
///  결제 창 (토스 느낌) — 카드번호 안 적고, 버튼 한 번에 결제
///   ① 금액·결제수단 보여주기 → ② "결제 중" → ③ 체크 애니메이션 + 폭죽 "결제 완료"
///  성공하면 PayResult를 돌려주고, 취소하면 null을 돌려줘요.
/// ═══════════════════════════════════════════════════════════
Future<PayResult?> showPaymentSheet(
  BuildContext context, {
  required int amount,
  required String title, // 예: "백마곱창 예약금"
}) {
  return showModalBottomSheet<PayResult>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PaymentSheet(amount: amount, title: title),
  );
}

/// 결제 수단 (연습 모드라 그림만 있어요)
class _PayMethod {
  final String emoji, name, sub, last4;
  const _PayMethod(this.emoji, this.name, this.sub, this.last4);
}

const _methods = [
  _PayMethod('💳', 'MEAL:ON 페이', '국민카드 **** 4242', '4242'),
  _PayMethod('🟡', '카카오페이', '카카오머니', '0000'),
  _PayMethod('🔵', '토스페이', '토스머니', '0000'),
  _PayMethod('🍎', 'Apple Pay', '현대카드 **** 7788', '7788'),
];

enum _Step { ready, paying, done }

class _PaymentSheet extends StatefulWidget {
  final int amount;
  final String title;
  const _PaymentSheet({required this.amount, required this.title});

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  _Step _step = _Step.ready;
  int _method = 0;
  PayResult? _result;

  String _won(int n) => '${n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}원';

  Future<void> _pay() async {
    setState(() => _step = _Step.paying);
    HapticFeedback.lightImpact();
    final r = await PaymentService.payQuick(amount: widget.amount, cardLast4: _methods[_method].last4);
    if (!mounted) return;
    setState(() {
      _result = r;
      _step = _Step.done;
    });
    HapticFeedback.mediumImpact();
    // 완료 화면을 2.2초 보여준 뒤 자동으로 닫혀요 (버튼으로도 닫을 수 있어요)
    await Future<void>.delayed(const Duration(milliseconds: 2200));
    if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop(_result);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // 결제 중·완료 중엔 밖을 눌러도 안 닫히게 (완료되면 결과를 꼭 돌려줘야 하니까)
      canPop: _step == _Step.ready,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOut,
          child: switch (_step) {
            _Step.ready => _ready(context),
            _Step.paying => _paying(context),
            _Step.done => _done(context),
          },
        ),
      ),
    );
  }

  // ───────── ① 결제 전 ─────────
  Widget _ready(BuildContext context) {
    final m = _methods[_method];
    return Column(
      key: const ValueKey('ready'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 18),
        Row(
          children: [
            Text('결제하기', style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppColors.sun.withOpacity(0.3), borderRadius: BorderRadius.circular(999)),
              child: const Text('연습 모드', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // 금액 카드
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.paper, borderRadius: BorderRadius.circular(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.muted)),
              const SizedBox(height: 6),
              Text(_won(widget.amount), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: AppColors.ink, letterSpacing: -1)),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // 결제 수단
        const Text('결제 수단', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.muted, fontSize: 13)),
        const SizedBox(height: 8),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _methods.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final mm = _methods[i];
              final sel = i == _method;
              return InkWell(
                onTap: () => setState(() => _method = i),
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 150,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.mint : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: sel ? AppColors.primary : AppColors.line, width: sel ? 2 : 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(mm.emoji, style: const TextStyle(fontSize: 18)),
                          const Spacer(),
                          if (sel) const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 18),
                        ],
                      ),
                      const Spacer(),
                      Text(mm.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                      Text(mm.sub, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),

        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          onPressed: _pay,
          child: Text('${_won(widget.amount)} 결제하기', style: const TextStyle(fontSize: 17)),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            '${m.name}로 결제돼요 · 실제 돈은 나가지 않아요 · 취소 시 전액 환불',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  // ───────── ② 결제 중 ─────────
  Widget _paying(BuildContext context) => SizedBox(
        key: const ValueKey('paying'),
        height: 300,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 56, height: 56, child: CircularProgressIndicator(strokeWidth: 5, color: AppColors.primary)),
            const SizedBox(height: 22),
            const Text('결제 중이에요', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('${_methods[_method].name} · ${_won(widget.amount)}', style: const TextStyle(color: AppColors.muted)),
          ],
        ),
      );

  // ───────── ③ 결제 완료 (토스 느낌) ─────────
  Widget _done(BuildContext context) => SizedBox(
        key: const ValueKey('done'),
        height: 360,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Positioned.fill(child: _Confetti()),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _CheckBadge(),
                const SizedBox(height: 22),
                const Text('결제 완료', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(_won(widget.amount), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: AppColors.primaryDark)),
                const SizedBox(height: 4),
                Text('${_methods[_method].name} · 승인번호 ${_result?.approvalNo ?? ''}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                const SizedBox(height: 22),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(_result),
                  child: const Text('확인'),
                ),
              ],
            ),
          ],
        ),
      );
}

/// 초록 동그라미가 "통" 하고 커지면서 체크가 그려지는 배지
class _CheckBadge extends StatefulWidget {
  const _CheckBadge();

  @override
  State<_CheckBadge> createState() => _CheckBadgeState();
}

class _CheckBadgeState extends State<_CheckBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = CurvedAnimation(parent: _c, curve: const Interval(0, 0.6, curve: Curves.elasticOut));
    final draw = CurvedAnimation(parent: _c, curve: const Interval(0.45, 1, curve: Curves.easeOutCubic));
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Transform.scale(
        scale: scale.value,
        child: Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary,
            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.35), blurRadius: 24, spreadRadius: 2)],
          ),
          child: CustomPaint(painter: _CheckPainter(draw.value)),
        ),
      ),
    );
  }
}

/// 체크 표시를 0→1 만큼 그려요
class _CheckPainter extends CustomPainter {
  final double t;
  _CheckPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;
    final p = Path()
      ..moveTo(size.width * 0.28, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.68)
      ..lineTo(size.width * 0.73, size.height * 0.36);
    final metric = p.computeMetrics().first;
    final part = metric.extractPath(0, metric.length * t);
    canvas.drawPath(
      part,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.t != t;
}

/// 색종이 폭죽 — 가운데 위에서 터져서 아래로 떨어져요
class _Confetti extends StatefulWidget {
  const _Confetti();

  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..forward();
  late final List<_Piece> _pieces = List.generate(46, (i) => _Piece(Random(i * 7 + 3)));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => CustomPaint(painter: _ConfettiPainter(_pieces, _c.value)),
        ),
      );
}

class _Piece {
  final double angle, speed, size, spin, delay;
  final Color color;
  final bool round;
  _Piece(Random r)
      : angle = -pi / 2 + (r.nextDouble() - 0.5) * pi * 1.3, // 위쪽으로 부채꼴
        speed = 260 + r.nextDouble() * 260,
        size = 6 + r.nextDouble() * 6,
        spin = (r.nextDouble() - 0.5) * 12,
        delay = r.nextDouble() * 0.15,
        round = r.nextBool(),
        color = [AppColors.primary, AppColors.teal, AppColors.sun, AppColors.coral, AppColors.sky, AppColors.plum][r.nextInt(6)];
}

class _ConfettiPainter extends CustomPainter {
  final List<_Piece> pieces;
  final double t;
  _ConfettiPainter(this.pieces, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.32);
    const g = 900.0; // 중력
    for (final p in pieces) {
      final tt = (t - p.delay).clamp(0.0, 1.0);
      if (tt <= 0) continue;
      final time = tt * 1.6; // 초
      final dx = cos(p.angle) * p.speed * time;
      final dy = sin(p.angle) * p.speed * time + 0.5 * g * time * time;
      final pos = origin + Offset(dx, dy);
      final alpha = (1 - tt).clamp(0.0, 1.0);
      final paint = Paint()..color = p.color.withOpacity(alpha);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.spin * tt);
      if (p.round) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6), const Radius.circular(1.5)), paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
