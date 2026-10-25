import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/body_profile.dart';
import '../services/auth_service.dart';
import '../services/report_mailer.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/body_summary_card.dart';
import '../widgets/section_title.dart';
import 'home_shell.dart';

/// 인바디를 적은 직후에 보는 "내 몸 리포트" — 인바디 결과지처럼!
///  ① 숫자 요약 카드  ② 막대 3개(체중/골격근/체지방)  ③ 체형 판정  ④ 또래 비교  ⑤ 항목별 카드  ⑥ 오늘 목표
class HealthReportScreen extends StatelessWidget {
  const HealthReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = app.profile!;
    final a = p.analysis;
    final insight = app.insight!;
    final t = app.targets!;

    return Scaffold(
      appBar: AppBar(title: const Text('내 몸 리포트')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          BodySummaryCard(profile: p),
          const SizedBox(height: 24),

          // ───── ① 체성분 막대 3개 (인바디 결과지의 핵심 그래프) ─────
          const SectionTitle('체성분 분석', subtitle: '회색 띠가 표준 범위, 초록 막대가 내 값이에요'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
              child: Column(
                children: [
                  ...a.bars.map((b) => _BodyBarRow(bar: b)),
                  const SizedBox(height: 6),
                  Text('적정 체중 ${a.idealWeightKg.toStringAsFixed(1)}kg 기준 (또래 중간 BMI × 키²)',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ───── ② 체형 판정 ─────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.teal, AppColors.primary], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.22), borderRadius: BorderRadius.circular(20)),
                  alignment: Alignment.center,
                  child: Text(a.shape.label.substring(0, 1),
                      style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${a.shape.label} · ${a.shape.title}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
                      const SizedBox(height: 6),
                      Text(a.shape.advice, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ───── ③ 또래 비교 ─────
          const SectionTitle('또래와 비교하면', subtitle: '질병관리청 소아청소년 성장도표 기준'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('또래 100명 중 ', style: Theme.of(context).textTheme.bodyLarge),
                      Text('${a.bmiPercentile.round()}번째',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primaryDark)),
                      const Spacer(),
                      _Chip(a.bmiCategory, _catColor(a.bmiCategory)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // 백분위 눈금 막대: 5 / 85 / 95 에 선
                  _PercentileScale(percentile: a.bmiPercentile),
                  const SizedBox(height: 8),
                  Text(
                    'BMI ${p.bmi.toStringAsFixed(1)} · 같은 나이·성별 ${a.usedAdultRef ? '(18세 기준 참고)' : ''} 기준이에요. '
                    '85번째 이상은 과체중, 95번째 이상은 비만 구간이에요.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ───── ④ 항목별 카드 ─────
          const SectionTitle('항목별 자세히'),
          Row(
            children: [
              Expanded(child: _MiniCard('체지방률', '${p.bodyFatPercent.toStringAsFixed(1)}%', a.fatJudge, _judgeColor(a.fatJudge))),
              const SizedBox(width: 10),
              Expanded(child: _MiniCard('골격근 비율', '${a.smmRatioPercent.toStringAsFixed(0)}%', a.bars[1].judge, _judgeColor(a.bars[1].judge))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MiniCard('체수분', p.bodyWaterPercent == null ? '—' : '${p.bodyWaterPercent!.toStringAsFixed(1)}%',
                    a.waterJudge ?? '안 적음', _judgeColor(a.waterJudge ?? '')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniCard('기초대사량', p.basalMetabolicRate == null ? '—' : '${p.basalMetabolicRate!.round()} kcal',
                    '하루 가만히 있어도 쓰는 양', AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ───── ⑤ 한 줄 결론 + 설명 ─────
          Text(insight.headline, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 22)),
          const SizedBox(height: 12),
          ...insight.points.map((text) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 7, right: 10),
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    ),
                    Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyLarge)),
                  ],
                ),
              )),
          const SizedBox(height: 24),

          // ───── ⑥ 오늘 목표 ─────
          const SectionTitle('오늘 이만큼 채우면 좋아요', subtitle: '청소년 영양소 섭취기준 + 인바디 결과로 계산했어요'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _TargetRow('에너지', '${t.kcal.round()} kcal', AppColors.primary),
                  _TargetRow('탄수화물', '${t.carbG.round()} g', AppColors.sun),
                  _TargetRow('단백질', '${t.proteinG.round()} g', AppColors.sky),
                  _TargetRow('지방', '${t.fatG.round()} g', AppColors.coral),
                  _TargetRow('나트륨', '${t.sodiumMg.round()} mg 이하', AppColors.plum),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '이 리포트는 참고용이에요. 몸이 아프거나 걱정되는 게 있으면 보건 선생님이나 병원에 이야기해요.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),

          // ───── ⑦ 리포트 내보내기 (이메일 / 공유 / CSV) ─────
          const SectionTitle('리포트 저장하기', subtitle: '표로 정리해서 메일로 보내거나, 공유하거나, 엑셀 파일로 내려받아요'),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _sendEmail(context, p),
                  icon: const Icon(Icons.mail_outline_rounded),
                  label: Text(ReportMailer.realSend ? '이메일로 받기' : '메일로 보내기'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _share(context, p),
                  icon: const Icon(Icons.ios_share_rounded),
                  label: const Text('공유하기'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _downloadCsv(context, app.history),
            icon: const Icon(Icons.table_chart_outlined),
            label: const Text('CSV(엑셀) 다운로드'),
          ),
          const SizedBox(height: 6),
          Text(
            ReportMailer.realSend
                ? '로그인한 이메일로 표가 담긴 메일이 바로 발송돼요.'
                : '메일 앱이 열리고 리포트가 채워져요. 받는 사람은 바꿔도 돼요. "공유하기"는 카톡·메모로 바로 보낼 수 있어요.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),

          FilledButton(
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const HomeShell()),
            ),
            child: const Text('홈으로 가기'),
          ),
        ],
      ),
    );
  }

  /// 공유 버튼: 폰이면 공유 창(카톡·메모·메일…), PC면 글 복사
  Future<void> _share(BuildContext context, BodyProfile p) async {
    final messenger = ScaffoldMessenger.of(context);
    final shared = await ReportMailer.share(p);
    if (shared) return;
    await Clipboard.setData(ClipboardData(text: ReportMailer.asText(p)));
    messenger.showSnackBar(const SnackBar(content: Text('이 기기는 공유 창이 없어서 리포트 글을 복사했어요. 원하는 곳에 붙여넣기 하면 돼요 📋')));
  }

  /// 이메일 버튼: EmailJS 키 있으면 바로 발송, 없으면 내 메일 앱을 열어 본문을 채워줘요
  Future<void> _sendEmail(BuildContext context, BodyProfile p) async {
    final email = context.read<AuthService>().email ?? '';
    final messenger = ScaffoldMessenger.of(context);
    if (!ReportMailer.realSend) {
      try {
        await ReportMailer.openMailApp(toEmail: email, p: p);
      } catch (_) {
        await Clipboard.setData(ClipboardData(text: ReportMailer.asText(p)));
        messenger.showSnackBar(const SnackBar(content: Text('메일 앱을 못 열어서 리포트 글을 복사했어요. 메일에 붙여넣기 하면 돼요 📋')));
      }
      return;
    }
    if (email.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('로그인한 이메일이 없어요. 로그아웃 후 이메일로 다시 로그인해요.')));
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text('$email 로 보내는 중...')));
    try {
      await ReportMailer.sendWithEmailJs(toEmail: email, p: p);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        content: Text('$email 로 리포트를 보냈어요 📧 (스팸함도 확인!)'),
        duration: const Duration(seconds: 5),
      ));
    } catch (e) {
      messenger.hideCurrentSnackBar();
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('메일을 못 보냈어요'),
          content: SingleChildScrollView(child: SelectableText('$e'.replaceFirst('Exception: ', ''))),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: '$e'));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('오류 복사'),
            ),
            FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('확인')),
          ],
        ),
      );
    }
  }

  /// CSV 버튼: 측정 기록 전부를 엑셀 파일로
  Future<void> _downloadCsv(BuildContext context, List<BodyProfile> history) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ReportMailer.downloadCsv(history);
      messenger.showSnackBar(SnackBar(content: Text('측정 ${history.length}건을 CSV로 내려받았어요 📊')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  static Color _catColor(String c) => switch (c) {
        '정상' => AppColors.green,
        '저체중' => AppColors.sky,
        '과체중' => AppColors.sun,
        _ => AppColors.coral,
      };

  static Color _judgeColor(String j) {
    if (j.startsWith('표준')) return AppColors.green;
    if (j.contains('낮음') || j.contains('부족') || j.contains('이하')) return AppColors.sky;
    if (j.contains('높음') || j.contains('많음') || j.contains('이상')) return AppColors.coral;
    return AppColors.muted;
  }
}

/// 인바디 결과지의 막대 한 줄: 라벨 · 회색 표준 띠 · 초록 내 값 막대 · 숫자
class _BodyBarRow extends StatelessWidget {
  final BodyBar bar;
  const _BodyBarRow({required this.bar});

  @override
  Widget build(BuildContext context) {
    const maxPct = 200.0; // 막대 끝 = 표준의 200%
    final color = bar.judge == '표준' ? AppColors.primary : (bar.judge == '표준 이상' ? AppColors.coral : AppColors.sky);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(bar.label, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(width: 8),
              _Chip(bar.judge, color),
              const Spacer(),
              Text('${bar.valueKg.toStringAsFixed(1)} kg',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.ink)),
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (_, c) {
              final w = c.maxWidth;
              double x(double pct) => (pct / maxPct).clamp(0.0, 1.0) * w;
              return SizedBox(
                height: 18,
                child: Stack(
                  children: [
                    // 바탕
                    Container(height: 18, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(9))),
                    // 표준 범위(회색 띠)
                    Positioned(
                      left: x(bar.lowPct),
                      width: x(bar.highPct) - x(bar.lowPct),
                      top: 0,
                      bottom: 0,
                      child: Container(decoration: BoxDecoration(color: const Color(0xFFC9CED6), borderRadius: BorderRadius.circular(9))),
                    ),
                    // 내 값 막대
                    Container(
                      width: x(bar.percent).clamp(10.0, w),
                      height: 18,
                      decoration: BoxDecoration(color: color.withOpacity(0.85), borderRadius: BorderRadius.circular(9)),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          Text('표준 대비 ${bar.percent.round()}%  (표준 ${bar.lowPct.round()}~${bar.highPct.round()}%)',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// 또래 백분위 눈금: 0 ─ 5 ─ 85 ─ 95 ─ 100 에 내 위치 점
class _PercentileScale extends StatelessWidget {
  final double percentile;
  const _PercentileScale({required this.percentile});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (_, c) {
          final w = c.maxWidth;
          double x(double p) => p / 100 * w;
          return SizedBox(
            height: 34,
            child: Stack(
              children: [
                Positioned(
                  top: 8,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      gradient: const LinearGradient(
                        colors: [AppColors.sky, AppColors.green, AppColors.green, AppColors.sun, AppColors.coral],
                        stops: [0.0, 0.05, 0.85, 0.95, 1.0],
                      ),
                    ),
                  ),
                ),
                for (final mark in [5.0, 85.0, 95.0])
                  Positioned(
                    left: x(mark) - 8,
                    top: 20,
                    child: Text('${mark.round()}', style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                  ),
                Positioned(
                  left: x(percentile) - 9,
                  top: 4,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: AppColors.ink, width: 3)),
                  ),
                ),
              ],
            ),
          );
        },
      );
}

class _MiniCard extends StatelessWidget {
  final String title, value, judge;
  final Color color;
  const _MiniCard(this.title, this.value, this.judge, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: AppColors.cardShadow),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.ink)),
            const SizedBox(height: 6),
            Text(judge, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
      );
}

class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  const _Chip(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11)),
      );
}

class _TargetRow extends StatelessWidget {
  final String label, value;
  final Color color;
  const _TargetRow(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Text(label, style: Theme.of(context).textTheme.bodyLarge),
            const Spacer(),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      );
}
