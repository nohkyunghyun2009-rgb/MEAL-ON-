import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/coupon.dart';
import '../services/coupon_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icon.dart';
import '../widgets/section_title.dart';
import 'quiz_screen.dart';

/// 🎁 쿠폰함 — 퀴즈로 받고, 예약할 때 써요
class CouponScreen extends StatelessWidget {
  const CouponScreen({super.key});

  Future<void> _startQuiz(BuildContext context) async {
    final svc = context.read<CouponService>();
    if (!svc.canQuizToday) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오늘 퀴즈는 다 풀었어요. 내일 다시 와요!')));
      return;
    }
    await Navigator.of(context).push<Coupon?>(MaterialPageRoute(builder: (_) => const QuizScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<CouponService>();
    final avail = svc.available;
    final old = svc.usedOrExpired;
    final rate = svc.totalAnswered == 0 ? 0 : (svc.totalCorrect * 100 / svc.totalAnswered).round();

    return Scaffold(
      appBar: AppBar(title: const Text('쿠폰함')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // ───── 퀴즈 배너 ─────
          InkWell(
            onTap: () => _startQuiz(context),
            borderRadius: BorderRadius.circular(22),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.teal, AppColors.primary], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(22),
                boxShadow: AppColors.cardShadow,
              ),
              child: Row(
                children: [
                  const IconBadge(icon: Icons.psychology_rounded, colors: [Colors.white24, Colors.white38], size: 56, shadow: false),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('식습관 퀴즈 풀고 쿠폰 받기', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text(
                          '5문제 중 ${CouponService.passScore}개 이상 맞히면 쿠폰 · 만점이면 더 좋은 쿠폰\n'
                          '오늘 남은 도전 ${svc.quizLeftToday}번${svc.totalAnswered > 0 ? ' · 지금까지 정답률 $rate%' : ''}',
                          style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ───── 쓸 수 있는 쿠폰 ─────
          SectionTitle('쓸 수 있는 쿠폰 ${avail.length}장', subtitle: '식당 예약할 때 "쿠폰 쓰기"를 누르면 돼요'),
          if (avail.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
              child: const Text('아직 쿠폰이 없어요. 위에서 퀴즈를 풀어봐요!', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
            ),
          for (final c in avail) ...[
            _CouponTile(coupon: c),
            const SizedBox(height: 10),
          ],

          // ───── 지난 쿠폰 ─────
          if (old.isNotEmpty) ...[
            const SizedBox(height: 14),
            SectionTitle('지난 쿠폰 ${old.length}장'),
            for (final c in old) ...[
              _CouponTile(coupon: c, dim: true),
              const SizedBox(height: 10),
            ],
          ],

          const SizedBox(height: 10),
          Text(
            '쿠폰은 받은 날부터 ${CouponService.validDays}일 동안 쓸 수 있어요. 할인 쿠폰은 예약금·선주문 금액에서 빠지고, 음료·곱빼기 쿠폰은 가게에서 예약번호와 함께 보여주면 돼요.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// 쿠폰 한 장 (노란 티켓 모양)
class _CouponTile extends StatelessWidget {
  final Coupon coupon;
  final bool dim;
  const _CouponTile({required this.coupon, this.dim = false});

  @override
  Widget build(BuildContext context) {
    final c = coupon;
    final status = c.isUsed
        ? '사용함 · ${c.usedStore}'
        : c.isExpired
            ? '기간 지남'
            : c.daysLeft <= 2
                ? '⏰ ${c.daysLeft == 0 ? '오늘까지' : '${c.daysLeft}일 남음'}'
                : '${c.daysLeft}일 남음';
    return Opacity(
      opacity: dim ? 0.45 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.sun,
          borderRadius: BorderRadius.circular(18),
          boxShadow: dim ? null : AppColors.cardShadow,
        ),
        child: Row(
          children: [
            // 왼쪽 큰 글씨
            Container(
              width: 118,
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Column(
                children: [
                  Text(c.emoji, style: const TextStyle(fontSize: 22)),
                  Text(c.big, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
                ],
              ),
            ),
            // 점선
            Container(width: 1, height: 64, color: Colors.black.withOpacity(0.12)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(c.small, style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('${c.source} · $status', style: const TextStyle(fontSize: 11, color: AppColors.ink, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 예약 창에서 쓰는 "쿠폰 고르기" — 고른 쿠폰을 돌려줘요 (안 고르면 null)
Future<Coupon?> showCouponPicker(BuildContext context, {required int amount}) {
  final avail = context.read<CouponService>().available;
  return showModalBottomSheet<Coupon?>(
    context: context,
    backgroundColor: AppColors.paper,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('쿠폰 고르기', style: Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('결제 금액 ${_won(amount)} · 쿠폰은 한 번에 1장', style: Theme.of(ctx).textTheme.bodySmall),
          const SizedBox(height: 14),
          if (avail.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('쓸 수 있는 쿠폰이 없어요. 홈 → 🎁 쿠폰함에서 퀴즈를 풀어봐요!', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
            ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final c in avail)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () => Navigator.pop(ctx, c),
                      borderRadius: BorderRadius.circular(18),
                      child: Stack(
                        children: [
                          _CouponTile(coupon: c),
                          Positioned(
                            right: 12,
                            top: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(99)),
                              child: Text(
                                c.discountFor(amount) > 0 ? '-${_won(c.discountFor(amount))}' : '가게에서',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          OutlinedButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('쿠폰 안 쓰기')),
        ],
      ),
    ),
  );
}

String _won(int n) => '${n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}원';
