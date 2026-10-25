import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/nutrition.dart';
import '../services/auth_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icon.dart';
import '../widgets/body_summary_card.dart';
import '../widgets/milon_card.dart';
import '../widgets/nutrient_gauge.dart';
import 'body_input_screen.dart';
import 'coupon_screen.dart';
import 'food_picker_sheet.dart';

/// "홈" 탭 (Grab 스타일)
/// 위에서부터: 초록 그라데이션 헤더(검색) → 서비스 타일 격자 → 환영 배너 → 혜택 쿠폰 → 오늘의 균형 → 끼니 기록
class MealLogScreen extends StatelessWidget {
  final void Function(int tabIndex)? onGoToTab;
  const MealLogScreen({super.key, this.onGoToTab});

  void _openBody(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BodyInputScreen()));

  /// 타일에서 바로 끼니 기록: 지금 시간에 맞는 끼니(아침/점심/저녁)에 넣어줘요
  Future<void> _quickLog(BuildContext context) async {
    final h = DateTime.now().hour;
    final meal = h < 11 ? MealType.breakfast : (h < 16 ? MealType.lunch : MealType.dinner);
    final picked = await showFoodPicker(context);
    if (picked != null && context.mounted) {
      await context.read<AppState>().addEntry(meal, picked.food, picked.servings);
    }
  }

  /// 프로필 동그라미를 누르면 나오는 "내 계정" 창
  void _openAccount(BuildContext context) {
    final auth = context.read<AuthService>();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheet) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('내 계정', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(auth.email ?? '', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.monitor_weight_outlined, color: AppColors.primary),
              title: const Text('인바디 다시 재기', style: TextStyle(fontWeight: FontWeight.w800)),
              onTap: () {
                Navigator.pop(sheet);
                _openBody(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.muted),
              title: const Text('로그아웃', style: TextStyle(fontWeight: FontWeight.w800)),
              onTap: () async {
                Navigator.pop(sheet);
                await auth.signOut();
                if (context.mounted) RootGate.restart(context); // 로그인 화면으로 싹 돌아가요
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openCoupons(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CouponScreen()));

  void _soon(BuildContext context, String what) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$what은(는) 곧 열려요! 🚧')));

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = app.profile;
    final t = app.targets;
    final total = app.todayTotals;
    final topPad = MediaQuery.of(context).padding.top; // 폰 상단 노치 높이

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero, // 헤더가 맨 위까지 꽉 차게
        children: [
          // ═══════ 1) 초록 그라데이션 헤더 + 검색창 ═══════
          Container(
            padding: EdgeInsets.fromLTRB(16, topPad + 18, 16, 22),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.teal, AppColors.primary],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
            ),
            child: Row(
              children: [
                // 예약번호 스캔 아이콘 (내 예약으로 이동)
                _RoundIcon(icon: Icons.qr_code_scanner_rounded, onTap: () => onGoToTab?.call(3)),
                const SizedBox(width: 10),
                // 검색창 (누르면 식당 찾기 탭으로)
                Expanded(
                  child: InkWell(
                    onTap: () => onGoToTab?.call(2),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
                      child: const Row(
                        children: [
                          Icon(Icons.search_rounded, color: AppColors.muted, size: 26),
                          SizedBox(width: 10),
                          Text('메뉴, 식당 검색', style: TextStyle(color: AppColors.muted, fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // 프로필 동그라미 (내 계정: 이메일 · 인바디 다시 재기 · 로그아웃)
                InkWell(
                  onTap: () => _openAccount(context),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.85), shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: p == null
                        ? const Icon(Icons.person_rounded, color: AppColors.primary, size: 28)
                        : Text(p.nickname.characters.first,
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 18)),
                  ),
                ),
              ],
            ),
          ),

          // ═══════ 2) 서비스 타일 격자 (3개 + 4개) ═══════
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _ServiceTile(icon: Icons.auto_awesome_rounded, colors: Grad.green, label: 'AI 추천', big: true, onTap: () => onGoToTab?.call(1))),
                    const SizedBox(width: 10),
                    Expanded(child: _ServiceTile(icon: Icons.storefront_rounded, colors: Grad.orange, label: '식당 찾기', big: true, onTap: () => onGoToTab?.call(2))),
                    const SizedBox(width: 10),
                    Expanded(child: _ServiceTile(icon: Icons.monitor_weight_rounded, colors: Grad.sky, label: '인바디', big: true, onTap: () => _openBody(context))),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _ServiceTile(icon: Icons.edit_note_rounded, colors: Grad.sun, label: '끼니 기록', onTap: () => _quickLog(context))),
                    const SizedBox(width: 10),
                    Expanded(child: _ServiceTile(icon: Icons.confirmation_number_rounded, colors: Grad.teal, label: '내 예약', onTap: () => onGoToTab?.call(3))),
                    const SizedBox(width: 10),
                    Expanded(child: _ServiceTile(icon: Icons.card_giftcard_rounded, colors: Grad.plum, label: '쿠폰함', onTap: () => _openCoupons(context))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ═══════ 3) 밀온이 (다마고치) ═══════
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: MilonCard(),
          ),
          const SizedBox(height: 18),

          // ═══════ 4) 환영 배너 ═══════
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _WelcomeBanner(nickname: p?.nickname, onTap: () => onGoToTab?.call(1)),
          ),
          const SizedBox(height: 18),

          // ═══════ 4) 혜택 쿠폰 띠 ═══════
          Container(
            padding: const EdgeInsets.fromLTRB(16, 20, 0, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.mint, AppColors.paper]),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('웰컴 혜택 받기', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 22)),
                const SizedBox(height: 2),
                Text('백마 학원가 제휴 식당 전용', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
                const SizedBox(height: 14),
                SizedBox(
                  height: 96,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _CouponCard(big: '퀴즈', small: '풀고 쿠폰 받기', icon: Icons.psychology_rounded, onTap: () => _openCoupons(context)),
                      _CouponCard(big: '1,000원', small: '웰컴 쿠폰', onTap: () => _openCoupons(context)),
                      _CouponCard(big: '최대 15%', small: '퀴즈 만점 보상', onTap: () => _openCoupons(context)),
                      _CouponCard(big: '곱빼기', small: '퀴즈 합격 보상', onTap: () => _openCoupons(context)),
                      const SizedBox(width: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ═══════ 5) 아래는 원래 있던 몸 리포트 + 균형 + 끼니 기록 ═══════
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (p != null) BodySummaryCard(profile: p, compact: true),
                if (p != null) const SizedBox(height: 18),

                _SectionCard(
                  title: '오늘의 균형',
                  trailing: t == null
                      ? null
                      : _Pill(text: '${total.kcal.round()} / ${t.kcal.round()} kcal', color: AppColors.mint, textColor: AppColors.primaryDark),
                  child: t == null
                      ? Text('인바디를 먼저 적으면 목표가 생겨요', style: Theme.of(context).textTheme.bodySmall)
                      : Column(
                          children: [
                            NutrientGauge(label: '에너지', value: total.kcal, target: t.kcal, unit: 'kcal', color: AppColors.primary),
                            NutrientGauge(label: '탄수화물', value: total.carbG, target: t.carbG, unit: 'g', color: AppColors.sun),
                            NutrientGauge(label: '단백질', value: total.proteinG, target: t.proteinG, unit: 'g', color: AppColors.sky),
                            NutrientGauge(label: '지방', value: total.fatG, target: t.fatG, unit: 'g', color: AppColors.green),
                            NutrientGauge(label: '나트륨', value: total.sodiumMg, target: t.sodiumMg, unit: 'mg', color: AppColors.plum, lessIsBetter: true),
                          ],
                        ),
                ),
                const SizedBox(height: 18),

                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 10),
                  child: Text('오늘 뭐 먹었어?', style: Theme.of(context).textTheme.titleLarge),
                ),
                ...MealType.values.map((m) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _MealCard(meal: m),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 헤더 양옆 동그란 반투명 아이콘 버튼
class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.28), shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      );
}

/// 흰 카드 + 그라데이션 아이콘 배지 + 글자 타일 (이모지 대신 아이콘이라 어디서나 똑같이 보여요)
class _ServiceTile extends StatelessWidget {
  final IconData icon;
  final List<Color> colors;
  final String label;
  final bool big; // 윗줄 3개는 크게, 아랫줄 3개는 작게
  final VoidCallback onTap;
  const _ServiceTile({required this.icon, required this.colors, required this.label, required this.onTap, this.big = false});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            height: big ? 118 : 104,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.line, width: 1),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconBadge(icon: icon, colors: colors, size: big ? 52 : 44),
                SizedBox(height: big ? 12 : 10),
                Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: big ? 14 : 13, color: AppColors.ink, letterSpacing: -0.2)),
              ],
            ),
          ),
        ),
      );
}

/// 초록 배경 환영 배너: 노란 팻말 + 인사말 + 음식 이모지 일러스트
class _WelcomeBanner extends StatelessWidget {
  final String? nickname;
  final VoidCallback onTap;
  const _WelcomeBanner({required this.nickname, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          height: 170,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFD7F5E3), Color(0xFF9EDFB8)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Stack(
            children: [
              // 뒤쪽 큰 원 (도시 실루엣 느낌)
              Positioned(right: -30, bottom: -50, child: _Blob(size: 190, color: AppColors.primary.withOpacity(0.18))),
              Positioned(right: 90, top: -40, child: _Blob(size: 120, color: AppColors.primary.withOpacity(0.12))),
              // 오른쪽 아이콘 일러스트 (겹쳐 놓은 배지 3개 + 하트)
              const Positioned(right: 22, top: 24, child: IconBadge(icon: Icons.eco_rounded, colors: Grad.green, size: 64, radius: 22)),
              const Positioned(right: 88, bottom: 18, child: IconBadge(icon: Icons.rice_bowl_rounded, colors: Grad.sun, size: 46, radius: 16)),
              const Positioned(right: 18, bottom: 16, child: IconBadge(icon: Icons.local_drink_rounded, colors: Grad.teal, size: 40, radius: 14)),
              Positioned(right: 112, top: 22, child: Icon(Icons.favorite_rounded, size: 18, color: AppColors.primary.withOpacity(0.55))),
              Positioned(right: 100, top: 48, child: Icon(Icons.favorite_rounded, size: 11, color: AppColors.primary.withOpacity(0.4))),
              // 왼쪽 노란 팻말 + 글
              Positioned(
                left: 18,
                top: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3A6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE6D25A), width: 2),
                      ),
                      child: Text(
                        nickname == null ? '환영해요!' : '$nickname, 환영해요!',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AppColors.primaryDark),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('나에게 맞는 한 끼를 켜다', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.ink)),
                    const SizedBox(height: 4),
                    const Text('AI 추천 받으러 가기 →', style: TextStyle(fontSize: 13, color: AppColors.primaryDark, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _Blob extends StatelessWidget {
  final double size;
  final Color color;
  const _Blob({required this.size, required this.color});
  @override
  Widget build(BuildContext context) =>
      Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

/// 노란 쿠폰 카드 (가로로 넘겨보는 것)
class _CouponCard extends StatelessWidget {
  final String big, small;
  final IconData? icon;
  final VoidCallback onTap;
  const _CouponCard({required this.big, required this.small, required this.onTap, this.icon});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: 150,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFFFF0A3), borderRadius: BorderRadius.circular(18)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 24, color: AppColors.ink),
                      const SizedBox(width: 6),
                    ],
                    Text(big, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: AppColors.ink)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(small, style: const TextStyle(fontSize: 13, color: AppColors.ink, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      );
}
/// 흰색 둥근 카드 + 제목
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Widget child;
  const _SectionCard({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), boxShadow: AppColors.cardShadow),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 6),
            child,
          ],
        ),
      );
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color, textColor;
  const _Pill({required this.text, required this.color, required this.textColor});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: TextStyle(color: textColor, fontWeight: FontWeight.w800, fontSize: 12)),
      );
}

class _MealCard extends StatelessWidget {
  final MealType meal;
  const _MealCard({required this.meal});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final entries = app.entriesFor(meal);
    final kcal = entries.fold<double>(0, (s, e) => s + e.kcal);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), boxShadow: AppColors.cardShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(icon: MealIcon.of(meal), colors: MealIcon.colorsOf(meal), size: 44, radius: 14),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(meal.label, style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      entries.isEmpty ? '아직 기록이 없어요' : '${entries.length}개 · ${kcal.round()} kcal',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  final picked = await showFoodPicker(context);
                  if (picked != null && context.mounted) {
                    await context.read<AppState>().addEntry(meal, picked.food, picked.servings);
                  }
                },
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.peach,
                  foregroundColor: AppColors.primaryDark,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('추가'),
              ),
            ],
          ),
          if (entries.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(height: 1),
            ...entries.map((e) => Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.food.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text(
                              '${_servingText(e.servings)} · ${e.kcal.round()}kcal · 단백질 ${e.proteinG.round()}g',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18, color: AppColors.muted),
                        onPressed: () => context.read<AppState>().removeEntry(e.id),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  String _servingText(double s) {
    if (s == 0.5) return '반 인분';
    if (s == 1) return '1인분';
    if (s == 1.5) return '1.5인분';
    return '${s.round()}인분';
  }
}
