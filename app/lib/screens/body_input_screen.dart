import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/body_profile.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'health_report_screen.dart';
import 'home_shell.dart';

/// 앱을 켜면 제일 먼저 나오는 화면.
/// 인바디 체중계에 나온 숫자를 그대로 옮겨 적어요.
class BodyInputScreen extends StatefulWidget {
  const BodyInputScreen({super.key});

  @override
  State<BodyInputScreen> createState() => _BodyInputScreenState();
}

class _BodyInputScreenState extends State<BodyInputScreen> {
  final _formKey = GlobalKey<FormState>();

  // 글자를 입력받는 "칸"들. 칸마다 컨트롤러 하나씩이에요.
  final _nickname = TextEditingController();
  final _age = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();
  final _bodyFat = TextEditingController();
  final _muscle = TextEditingController();
  final _bmr = TextEditingController();
  final _water = TextEditingController();

  Sex _sex = Sex.male;
  ActivityLevel _activity = ActivityLevel.normal;

  @override
  void initState() {
    super.initState();
    // 전에 저장한 값이 있으면 미리 채워두기
    final p = context.read<AppState>().profile;
    if (p != null) {
      _nickname.text = p.nickname;
      _age.text = p.age.toString();
      _height.text = _trim(p.heightCm);
      _weight.text = _trim(p.weightKg);
      _bodyFat.text = _trim(p.bodyFatPercent);
      _muscle.text = _trim(p.skeletalMuscleKg);
      _bmr.text = p.basalMetabolicRate == null ? '' : _trim(p.basalMetabolicRate!);
      _water.text = p.bodyWaterPercent == null ? '' : _trim(p.bodyWaterPercent!);
      _sex = p.sex;
      _activity = p.activity;
    }
  }

  String _trim(double v) => v == v.roundToDouble() ? v.round().toString() : v.toString();

  @override
  void dispose() {
    for (final c in [_nickname, _age, _height, _weight, _bodyFat, _muscle, _bmr, _water]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    // 빈 칸이나 이상한 값이 있으면 여기서 멈춰요
    if (!_formKey.currentState!.validate()) return;

    final profile = BodyProfile(
      nickname: _nickname.text.trim(),
      sex: _sex,
      age: int.parse(_age.text),
      heightCm: double.parse(_height.text),
      weightKg: double.parse(_weight.text),
      bodyFatPercent: double.parse(_bodyFat.text),
      skeletalMuscleKg: double.parse(_muscle.text),
      basalMetabolicRate: _bmr.text.trim().isEmpty ? null : double.parse(_bmr.text),
      bodyWaterPercent: _water.text.trim().isEmpty ? null : double.parse(_water.text),
      activity: _activity,
      measuredAt: DateTime.now(),
    );

    await context.read<AppState>().setProfile(profile);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HealthReportScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSaved = context.watch<AppState>().hasProfile;

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            children: [
              // ───── 제목 ─────
              // ───── 브랜드 ─────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(999)),
                    child: const Text('MEAL:ON', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  ),
                  const SizedBox(width: 10),
                  Text('나에게 맞는 한 끼를 켜다', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 14),
              Text('인바디 결과를\n그대로 적어주세요', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                '체중계 화면에 나온 숫자를 옮겨 적으면 오늘 몸 상태와 딱 맞는 메뉴를 찾아줘요.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 24),

              // ───── 기본 정보 ─────
              _Label('닉네임'),
              TextFormField(
                controller: _nickname,
                decoration: const InputDecoration(hintText: '예: 경현'),
                textInputAction: TextInputAction.next,
                validator: (v) => (v == null || v.trim().isEmpty) ? '닉네임을 적어주세요' : null,
              ),
              const SizedBox(height: 16),

              _Label('성별'),
              SegmentedButton<Sex>(
                segments: const [
                  ButtonSegment(value: Sex.male, label: Text('남'), icon: Icon(Icons.male)),
                  ButtonSegment(value: Sex.female, label: Text('여'), icon: Icon(Icons.female)),
                ],
                selected: {_sex},
                onSelectionChanged: (s) => setState(() => _sex = s.first),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(child: _numberField(_age, '나이', '세', min: 8, max: 25, integer: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _numberField(_height, '키', 'cm', min: 100, max: 220)),
                ],
              ),
              const SizedBox(height: 24),

              // ───── 인바디 숫자 ─────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.monitor_weight_outlined, color: AppColors.green),
                        const SizedBox(width: 8),
                        Text('인바디 화면에서 찾기', style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _numberField(_weight, '몸무게', 'kg', min: 20, max: 200)),
                        const SizedBox(width: 12),
                        Expanded(child: _numberField(_muscle, '골격근량', 'kg', min: 5, max: 80)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _numberField(_bodyFat, '체지방률', '%', min: 2, max: 60)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _numberField(_bmr, '기초대사량', 'kcal', min: 800, max: 3000, required: false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _numberField(_water, '체수분량', '%', min: 30, max: 80, required: false)),
                        const SizedBox(width: 12),
                        const Expanded(child: SizedBox()),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('기초대사량·체수분량은 없으면 비워도 돼요. BMI는 키로 자동 계산해요.', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ───── 활동량 ─────
              _Label('평소 활동량'),
              SegmentedButton<ActivityLevel>(
                segments: ActivityLevel.values
                    .map((a) => ButtonSegment(value: a, label: Text(a.label)))
                    .toList(),
                selected: {_activity},
                onSelectionChanged: (s) => setState(() => _activity = s.first),
              ),
              const SizedBox(height: 32),

              FilledButton(onPressed: _submit, child: const Text('내 몸 상태 확인하기')),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  'O · Observe  나의 식습관을 관찰하고\nN · Navigate  더 나은 선택으로 나아간다',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.6),
                ),
              ),
              if (hasSaved) ...[
                const SizedBox(height: 10),
                OutlinedButton(
                  // 홈에서 넘어왔으면 그냥 뒤로, 앱 첫 화면이면 홈으로 바꿔치기
                  onPressed: () => Navigator.of(context).canPop()
                      ? Navigator.of(context).pop()
                      : Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const HomeShell()),
                        ),
                  child: const Text('지난 측정값으로 바로 시작'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 숫자 입력 칸을 만드는 도우미. 같은 모양을 여러 번 쓰니까 함수로 뺐어요.
  Widget _numberField(
    TextEditingController c,
    String label,
    String unit, {
    required double min,
    required double max,
    bool integer = false,
    bool required = true,
  }) {
    return TextFormField(
      controller: c,
      keyboardType: TextInputType.numberWithOptions(decimal: !integer),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(integer ? r'[0-9]' : r'[0-9.]')),
      ],
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(labelText: label, suffixText: unit),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return required ? '적어주세요' : null;
        final n = double.tryParse(v);
        if (n == null) return '숫자만';
        if (n < min || n > max) return '$min~$max 사이';
        return null;
      },
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}
