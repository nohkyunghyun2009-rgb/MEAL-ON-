import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/quiz_bank.dart';
import '../models/coupon.dart';
import '../services/coupon_service.dart';
import '../theme/app_theme.dart';

/// 식습관 퀴즈 — 5문제 중 4개 이상 맞히면 쿠폰!
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late final List<QuizQuestion> _qs = QuizBank.pick(CouponService.questionsPerRound, seed: Random().nextInt(1 << 30));
  int _index = 0; // 지금 몇 번째 문제
  int? _picked; // 이번 문제에서 고른 번호 (null = 아직)
  int _correct = 0;
  bool _done = false;
  Coupon? _won;

  QuizQuestion get _q => _qs[_index];
  bool get _answered => _picked != null;

  void _choose(int i) {
    if (_answered) return;
    setState(() {
      _picked = i;
      if (i == _q.answer) _correct++;
    });
  }

  Future<void> _next() async {
    if (_index + 1 < _qs.length) {
      setState(() {
        _index++;
        _picked = null;
      });
      return;
    }
    // 마지막 문제 → 결과
    final won = await context.read<CouponService>().finishQuiz(correct: _correct, total: _qs.length);
    if (!mounted) return;
    setState(() {
      _done = true;
      _won = won;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('식습관 퀴즈')),
      body: _done ? _result(context) : _question(context),
    );
  }

  // ───────── 문제 화면 ─────────
  Widget _question(BuildContext context) {
    final q = _q;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        // 진행 막대
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: (_index + (_answered ? 1 : 0)) / _qs.length,
                  minHeight: 10,
                  backgroundColor: AppColors.line,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text('${_index + 1} / ${_qs.length}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primaryDark)),
          ],
        ),
        const SizedBox(height: 6),
        Text('맞힌 문제 $_correct개 · ${CouponService.passScore}개 이상이면 쿠폰, 다 맞히면 더 좋은 쿠폰', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 18),

        // 문제 카드
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.teal, AppColors.primary], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (q.tag.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(99)),
                  child: Text('#${q.tag}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                ),
              const SizedBox(height: 10),
              Text(q.q, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900, height: 1.4)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 보기 4개
        for (var i = 0; i < q.options.length; i++) ...[
          _OptionTile(
            label: '①②③④'[i],
            text: q.options[i],
            state: !_answered
                ? _OptState.idle
                : i == q.answer
                    ? _OptState.correct
                    : i == _picked
                        ? _OptState.wrong
                        : _OptState.dim,
            onTap: () => _choose(i),
          ),
          const SizedBox(height: 10),
        ],

        // 해설 (답을 고른 뒤에만)
        if (_answered) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _picked == q.answer ? AppColors.mint : AppColors.sun.withOpacity(0.18),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _picked == q.answer ? '🎯 정답!' : '😅 아쉽다! 정답은 ${'①②③④'[q.answer]}',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                const SizedBox(height: 6),
                Text(q.why, style: const TextStyle(height: 1.5)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _next,
            child: Text(_index + 1 < _qs.length ? '다음 문제' : '결과 보기'),
          ),
        ],
      ],
    );
  }

  // ───────── 결과 화면 ─────────
  Widget _result(BuildContext context) {
    final total = _qs.length;
    final perfect = _correct >= total;
    final passed = _won != null;
    final svc = context.watch<CouponService>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        Center(
          child: Text(perfect ? '🏆' : passed ? '🎉' : '💪', style: const TextStyle(fontSize: 72)),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            perfect
                ? '만점! 식습관 박사네'
                : passed
                    ? '합격! 쿠폰 받았어'
                    : '아깝다, ${CouponService.passScore}개 이상이면 쿠폰이야',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 6),
        Center(child: Text('$total문제 중 $_correct개 정답', style: Theme.of(context).textTheme.bodyMedium)),
        const SizedBox(height: 24),

        if (_won != null) _CouponReveal(coupon: _won!),

        if (_won == null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.mint, borderRadius: BorderRadius.circular(18)),
            child: Text(
              svc.canQuizToday
                  ? '오늘 ${svc.quizLeftToday}번 더 도전할 수 있어. 해설을 떠올리면서 다시!'
                  : '오늘 도전 횟수를 다 썼어. 내일 다시 와!',
              style: const TextStyle(fontWeight: FontWeight.w700, height: 1.5),
            ),
          ),
        const SizedBox(height: 24),

        if (_won == null && svc.canQuizToday)
          FilledButton(
            onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const QuizScreen())),
            child: const Text('다시 도전'),
          ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(_won),
          child: Text(_won != null ? '쿠폰함으로' : '닫기'),
        ),
      ],
    );
  }
}

enum _OptState { idle, correct, wrong, dim }

class _OptionTile extends StatelessWidget {
  final String label, text;
  final _OptState state;
  final VoidCallback onTap;
  const _OptionTile({required this.label, required this.text, required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (bg, border, fg) = switch (state) {
      _OptState.idle => (Colors.white, AppColors.line, AppColors.ink),
      _OptState.correct => (AppColors.mint, AppColors.primary, AppColors.primaryDark),
      _OptState.wrong => (AppColors.coral.withOpacity(0.12), AppColors.coral, AppColors.coral),
      _OptState.dim => (Colors.white, AppColors.line, AppColors.muted),
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: state == _OptState.idle || state == _OptState.dim ? 1 : 2),
        ),
        child: Row(
          children: [
            Text(label, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: fg)),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: TextStyle(fontWeight: FontWeight.w700, color: fg, height: 1.35))),
            if (state == _OptState.correct) const Icon(Icons.check_circle_rounded, color: AppColors.primary),
            if (state == _OptState.wrong) const Icon(Icons.cancel_rounded, color: AppColors.coral),
          ],
        ),
      ),
    );
  }
}

/// 쿠폰이 "짠" 하고 나타나는 카드
class _CouponReveal extends StatefulWidget {
  final Coupon coupon;
  const _CouponReveal({required this.coupon});

  @override
  State<_CouponReveal> createState() => _CouponRevealState();
}

class _CouponRevealState extends State<_CouponReveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.coupon;
    return ScaleTransition(
      scale: CurvedAnimation(parent: _c, curve: Curves.elasticOut),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.sun,
          borderRadius: BorderRadius.circular(22),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          children: [
            Text(c.emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.big, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                  Text(c.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('${c.small} · ${c.daysLeft}일 남음', style: const TextStyle(fontSize: 12, color: AppColors.ink)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
