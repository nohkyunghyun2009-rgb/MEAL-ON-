import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/character.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// 홈에 올라가는 밀온이 카드 (다마고치)
///  캐릭터 그림 + 말풍선 + 레벨/경험치 게이지
class MilonCard extends StatelessWidget {
  const MilonCard({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final m = app.milon;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEAF7EC), Color(0xFFD7F0DD)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 캐릭터 (통통 튀는 애니메이션)
              _BouncyMilon(face: m.face, scale: m.stage.scale),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    // 말풍선
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: AppColors.cardShadow),
                      child: Text(m.message, style: const TextStyle(fontSize: 13.5, height: 1.35, color: AppColors.ink, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 12),
                    // 레벨 + 호칭
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(999)),
                          child: Text('Lv.${m.level}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text('${m.stage.emoji} ${m.stage.title}',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.primaryDark), overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 경험치 게이지
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: m.progress,
                        minHeight: 10,
                        backgroundColor: Colors.white,
                        valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      m.expForNext == 0 ? '최고 레벨! 총 경험치 ${m.exp}' : '다음 레벨까지 ${m.expForNext - m.expInLevel} EXP',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 캐릭터가 살짝 위아래로 통통 뜨는 애니메이션
class _BouncyMilon extends StatefulWidget {
  final MilonFace face;
  final double scale;
  const _BouncyMilon({required this.face, required this.scale});

  @override
  State<_BouncyMilon> createState() => _BouncyMilonState();
}

class _BouncyMilonState extends State<_BouncyMilon> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const box = 96.0;
    return SizedBox(
      width: box,
      height: box,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Transform.translate(offset: Offset(0, -6 * _c.value), child: child),
        child: Center(
          child: Image.asset(
            widget.face.asset,
            width: box * widget.scale,
            height: box * widget.scale,
            fit: BoxFit.contain,
            // 그림을 아직 안 넣었을 때도 앱이 안 죽게 대비
            errorBuilder: (_, __, ___) => Text(
              switch (widget.face) {
                MilonFace.happy => '😄',
                MilonFace.cheer => '🥰',
                MilonFace.think => '🤔',
                MilonFace.hello => '👋',
              },
              style: const TextStyle(fontSize: 48),
            ),
          ),
        ),
      ),
    );
  }
}
