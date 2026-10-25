import 'package:flutter/material.dart';

import '../data/food_database.dart';
import '../models/nutrition.dart';
import '../services/gemini_service.dart';
import '../services/nutrition_estimator.dart';
import '../theme/app_theme.dart';

/// 음식 고르기 창이 돌려주는 답: "이 음식을, 이만큼"
class PickedFood {
  final FoodItem food;
  final double servings;
  const PickedFood(this.food, this.servings);
}

/// 아래에서 올라오는 음식 고르기 창을 열어요.
Future<PickedFood?> showFoodPicker(BuildContext context) {
  return showModalBottomSheet<PickedFood>(
    context: context,
    isScrollControlled: true, // 화면 높이만큼 크게
    backgroundColor: Colors.transparent,
    builder: (_) => const _FoodPickerSheet(),
  );
}

class _FoodPickerSheet extends StatefulWidget {
  const _FoodPickerSheet();

  @override
  State<_FoodPickerSheet> createState() => _FoodPickerSheetState();
}

class _FoodPickerSheetState extends State<_FoodPickerSheet> {
  final _query = TextEditingController();
  String _category = '전체';

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _choose(FoodItem food) async {
    // 몇 인분인지 묻기
    final servings = await showDialog<double>(
      context: context,
      builder: (_) => _ServingsDialog(food: food),
    );
    if (servings != null && mounted) {
      Navigator.of(context).pop(PickedFood(food, servings));
    }
  }

  /// "직접 입력": 먹은 걸 글로 적으면 앱이 칼로리를 계산해줘요
  Future<void> _addCustom({String? initial}) async {
    final picked = await showDialog<PickedFood>(
      context: context,
      builder: (_) => _SmartFoodDialog(initial: initial ?? _query.text),
    );
    if (picked != null && mounted) Navigator.of(context).pop(picked);
  }

  @override
  Widget build(BuildContext context) {
    final results = FoodDatabase.search(_query.text, category: _category);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scroll) => Container(
        decoration: const BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  Text('뭐 먹었어?', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _addCustom,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('직접 입력'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _query,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: '음식 이름 검색 (예: 덮밥)',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _query.clear()),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // 카테고리 칩 (옆으로 스크롤)
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: FoodDatabase.categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final c = FoodDatabase.categories[i];
                  return ChoiceChip(
                    label: Text(c),
                    selected: _category == c,
                    onSelected: (_) => setState(() => _category = c),
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('목록에 없어요', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 6),
                          Text('그래도 괜찮아요. 적은 그대로 칼로리를 계산해줄게요', style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(minimumSize: const Size(220, 48)),
                            onPressed: () => _addCustom(initial: _query.text),
                            icon: const Icon(Icons.calculate_rounded),
                            label: Text('"${_query.text.trim()}" 칼로리 계산'),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
                      itemCount: results.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final f = results[i];
                        return Card(
                          child: ListTile(
                            onTap: () => _choose(f),
                            title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(
                              '${f.kcal.round()}kcal · 탄 ${f.carbG.round()}g · 단 ${f.proteinG.round()}g · 지 ${f.fatG.round()}g',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: AppColors.mint, borderRadius: BorderRadius.circular(999)),
                              child: Text(f.category, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.green)),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "몇 인분 먹었어?" 묻는 작은 창
class _ServingsDialog extends StatefulWidget {
  final FoodItem food;
  const _ServingsDialog({required this.food});

  @override
  State<_ServingsDialog> createState() => _ServingsDialogState();
}

class _ServingsDialogState extends State<_ServingsDialog> {
  double _servings = 1;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.food.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('얼마나 먹었어?'),
          const SizedBox(height: 12),
          SegmentedButton<double>(
            segments: const [
              ButtonSegment(value: 0.5, label: Text('반')),
              ButtonSegment(value: 1, label: Text('1')),
              ButtonSegment(value: 1.5, label: Text('1.5')),
              ButtonSegment(value: 2, label: Text('2')),
            ],
            selected: {_servings},
            onSelectionChanged: (s) => setState(() => _servings = s.first),
          ),
          const SizedBox(height: 10),
          Text('${(widget.food.kcal * _servings).round()} kcal', style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(80, 44)),
          onPressed: () => Navigator.pop(context, _servings),
          child: const Text('추가'),
        ),
      ],
    );
  }
}

/// 먹은 걸 글로 적으면 앱이 칼로리·영양을 계산해주는 창
/// (앱 음식 목록 → 제휴 메뉴판 → Gemini → 키워드 추정 순서로 찾아요)
class _SmartFoodDialog extends StatefulWidget {
  final String initial;
  const _SmartFoodDialog({this.initial = ''});

  @override
  State<_SmartFoodDialog> createState() => _SmartFoodDialogState();
}

class _SmartFoodDialogState extends State<_SmartFoodDialog> {
  late final _text = TextEditingController(text: widget.initial);
  final _kcalEdit = TextEditingController();
  Estimate? _est;
  double _servings = 1;
  bool _loading = false;
  bool _editing = false; // 칼로리 숫자 직접 고치기

  @override
  void initState() {
    super.initState();
    if (widget.initial.trim().isNotEmpty) _calc();
  }

  @override
  void dispose() {
    _text.dispose();
    _kcalEdit.dispose();
    super.dispose();
  }

  Future<void> _calc() async {
    final t = _text.text.trim();
    if (t.isEmpty || _loading) return;
    setState(() {
      _loading = true;
      _editing = false;
    });
    final est = await NutritionEstimator.estimate(t);
    if (!mounted) return;
    setState(() {
      _est = est;
      _servings = est.servings;
      _kcalEdit.text = est.food.kcal.round().toString();
      _loading = false;
    });
  }

  /// 칼로리를 손으로 고치면 탄단지도 같은 비율로 따라가요
  FoodItem _finalFood() {
    final f = _est!.food;
    final edited = double.tryParse(_kcalEdit.text);
    if (!_editing || edited == null || edited <= 0 || f.kcal <= 0) return f;
    final r = edited / f.kcal;
    return FoodItem(name: f.name, category: f.category, kcal: edited, carbG: f.carbG * r, proteinG: f.proteinG * r, fatG: f.fatG * r, sodiumMg: f.sodiumMg * r);
  }

  @override
  Widget build(BuildContext context) {
    final est = _est;
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('먹은 거 적기'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _text,
              autofocus: widget.initial.trim().isEmpty,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _calc(),
              decoration: const InputDecoration(hintText: '예: 치킨 3조각, 참치김밥 한 줄, 엄마가 싸준 도시락'),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
              onPressed: _loading ? null : _calc,
              icon: _loading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.calculate_rounded),
              label: Text(_loading ? '계산 중...' : (est == null ? '칼로리 계산' : '다시 계산')),
            ),
            if (est != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.mint, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(est.food.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (_editing)
                          SizedBox(
                            width: 90,
                            child: TextField(
                              controller: _kcalEdit,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                            ),
                          )
                        else
                          Text('${(_finalFood().kcal * _servings).round()}', style: theme.textTheme.headlineMedium?.copyWith(color: AppColors.primaryDark)),
                        const SizedBox(width: 4),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(_editing ? 'kcal (1회 기준)' : 'kcal', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => setState(() => _editing = !_editing),
                          child: Text(_editing ? '완료' : '숫자 고치기', style: const TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    Text(
                      '탄 ${(_finalFood().carbG * _servings).round()}g · 단 ${(_finalFood().proteinG * _servings).round()}g · 지 ${(_finalFood().fatG * _servings).round()}g · 나트륨 ${(_finalFood().sodiumMg * _servings).round()}mg',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.muted),
                        const SizedBox(width: 4),
                        Expanded(child: Text('${est.source} · ${est.note}', style: theme.textTheme.bodySmall)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text('얼마나 먹었어?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              SegmentedButton<double>(
                segments: const [
                  ButtonSegment(value: 0.5, label: Text('반')),
                  ButtonSegment(value: 1, label: Text('1')),
                  ButtonSegment(value: 1.5, label: Text('1.5')),
                  ButtonSegment(value: 2, label: Text('2')),
                  ButtonSegment(value: 3, label: Text('3')),
                ],
                selected: {const [0.5, 1.0, 1.5, 2.0, 3.0].contains(_servings) ? _servings : 1.0},
                onSelectionChanged: (s) => setState(() => _servings = s.first),
                showSelectedIcon: false,
              ),
              if (!const [0.5, 1.0, 1.5, 2.0, 3.0].contains(_servings))
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('글에서 읽은 양: ${_servings % 1 == 0 ? _servings.toInt() : _servings}회분으로 계산 중', style: theme.textTheme.bodySmall),
                ),
            ] else if (!GeminiService.ready) ...[
              const SizedBox(height: 8),
              Text('목록·메뉴판에 없는 음식은 키워드로 대략 계산해요. Gemini 키가 있으면 더 정확해져요.', style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
          onPressed: est == null ? null : () => Navigator.pop(context, PickedFood(_finalFood(), _servings)),
          child: const Text('기록하기'),
        ),
      ],
    );
  }
}
