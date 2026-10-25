import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/partner_menus.dart';
import 'kakao_local_service.dart';

/// ═══════════════════════════════════════════════════════════
///  추천 기억 상자 — "방금 뭐 추천했더라?"
///
///  왜 필요해요?
///   AI한테 매번 똑같은 "가까운 순 식당 40곳"을 보여주면, AI도 사람처럼
///   맨 앞에 있는 가게만 자꾸 고르게 돼요. 자체 추천 엔진도 "제일 가까운
///   가게"를 고정으로 붙였고요. 그래서 늘 같은 가게가 나왔어요.
///
///  이 상자가 하는 일
///   ① 답변 글에서 가게 이름·메뉴 이름을 찾아내서 기록 (폰에 저장, 3일 보관)
///   ② "최근에 추천한 가게/메뉴" 목록을 돌려줘서 이번엔 피하게 해요
///   ③ AI에게 보여줄 식당 목록을 "종류별로 골고루 + 매번 섞어서" 뽑아줘요
/// ═══════════════════════════════════════════════════════════

/// ═══ 끼니 힌트 ═══
/// "저녁 추천해줘"를 밤 11시에 물어봐도 야식이 아니라 "저녁"으로 추천하게,
/// 질문에 적힌 끼니를 시계보다 우선해요.
class MealHint {
  /// 질문에서 끼니를 찾아요. 없으면 null (그땐 시계를 써요)
  static String? fromQuestion(String question) {
    final q = question.replaceAll(' ', '');
    if (q.contains('아침') || q.contains('조식') || q.contains('모닝')) return '아침';
    if (q.contains('점심') || q.contains('중식') || q.contains('런치')) return '점심';
    if (q.contains('저녁') || q.contains('석식') || q.contains('디너')) return '저녁';
    if (q.contains('야식') || q.contains('밤에') || q.contains('새벽')) return '야식';
    if (q.contains('간식') || q.contains('디저트') || q.contains('군것질')) return '간식';
    return null;
  }

  /// 최근 질문들(가장 최근 것부터)에서 끼니를 찾아요.
  /// "저녁 추천해줘" 다음에 "다른 거"라고 하면 저녁을 이어가게.
  static String? fromRecent(Iterable<String> questionsNewestFirst) {
    for (final q in questionsNewestFirst) {
      final m = fromQuestion(q);
      if (m != null) return m;
    }
    return null;
  }

  /// 끼니 이름 → 그 끼니다운 "대표 시각" (점수 계산이 시간을 쓰기 때문에)
  static int hourFor(String meal) => switch (meal) {
        '아침' => 8,
        '점심' => 12,
        '저녁' => 18,
        '간식' => 16,
        _ => 22, // 야식
      };

  /// 시계로 끼니 정하기
  static String fromClock(int hour) => hour < 10 ? '아침' : (hour < 15 ? '점심' : (hour < 21 ? '저녁' : '야식'));
}

/// 추천 기록 한 줄
class RecEntry {
  final String name;
  final String kind; // 'place'(가게) 또는 'food'(메뉴)
  final DateTime at;

  const RecEntry(this.name, this.kind, this.at);

  bool get isPlace => kind == 'place';

  Map<String, dynamic> toJson() => {'n': name, 'k': kind, 't': at.millisecondsSinceEpoch};

  factory RecEntry.fromJson(Map<String, dynamic> j) => RecEntry(
        j['n'] as String,
        j['k'] as String,
        DateTime.fromMillisecondsSinceEpoch(j['t'] as int),
      );
}

class RecommendationMemory {
  static const _key = 'rec_history_v1';

  /// 며칠 동안 기억할지
  static const keepDays = 3;

  /// 최대 몇 줄 기억할지 (가게+메뉴 합쳐서)
  static const maxEntries = 80;

  /// AI에게 보여줄 가게 수 (너무 많으면 프롬프트가 길어져요)
  static const promptPlaceCount = 45;

  List<RecEntry> _entries = [];

  List<RecEntry> get entries => List.unmodifiable(_entries);

  // ───── 저장/불러오기 ─────
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      _entries = (jsonDecode(raw) as List<dynamic>)
          .map((x) => RecEntry.fromJson(x as Map<String, dynamic>))
          .toList();
      _trim();
    } catch (_) {
      _entries = [];
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(_entries.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

  void _trim() {
    final cutoff = DateTime.now().subtract(const Duration(days: keepDays));
    _entries = _entries.where((e) => e.at.isAfter(cutoff)).toList();
    if (_entries.length > maxEntries) {
      _entries = _entries.sublist(_entries.length - maxEntries);
    }
  }

  Future<void> clear() async {
    _entries = [];
    await _save();
  }

  // ───── 기록하기 ─────

  /// 답변 글 속에서 가게 이름·메뉴 이름을 찾아 기록해요.
  /// 돌려주는 값: 이번에 새로 기록된 이름들
  Future<List<String>> remember(
    String reply, {
    required Iterable<String> placeNames,
    required Iterable<String> foodNames,
  }) async {
    final now = DateTime.now();
    final found = <String>[];
    final text = _norm(reply);
    final foodText = foodKey(reply); // 메뉴 이름과 같은 방식으로 숫자·단위·괄호를 떼요

    for (final name in placeNames) {
      if (mentionsPlace(text, name)) {
        _entries.add(RecEntry(name, 'place', now));
        found.add(name);
      }
    }
    for (final name in foodNames) {
      final key = foodKey(name);
      final core = foodCore(name);
      // "김치찌개 백반"을 AI가 "김치찌개"라고만 써도 잡히게, 앞 단어(3글자 이상)로도 확인해요
      if ((key.length >= 2 && foodText.contains(key)) || (core.length >= 3 && text.contains(core))) {
        _entries.add(RecEntry(name, 'food', now));
        found.add(name);
      }
    }

    if (found.isNotEmpty) {
      _trim();
      await _save();
    }
    return found;
  }

  // ───── 꺼내 보기 ─────

  /// 최근에 추천한 가게 이름 (가장 최근 것부터, 중복 없이)
  List<String> recentPlaces({int limit = 12}) => _recent('place', limit);

  /// 최근에 추천한 메뉴 이름 (가장 최근 것부터, 중복 없이)
  List<String> recentFoods({int limit = 10}) => _recent('food', limit);

  /// 이름 → "얼마나 최근인지" 순위 (0 = 가장 최근 답변에 나온 것)
  /// 같은 답변에서 나온 것들은 같은 순위를 받아요.
  Map<String, int> recencyRank(String kind) {
    final out = <String, int>{};
    var rank = -1;
    DateTime? lastAt;
    for (final e in _entries.reversed) {
      if (e.kind != kind) continue;
      // 1초 안에 기록된 건 "같은 답변"으로 쳐요
      if (lastAt == null || lastAt.difference(e.at).inSeconds > 1) rank++;
      lastAt = e.at;
      out.putIfAbsent(e.name, () => rank);
    }
    return out;
  }

  List<String> _recent(String kind, int limit) {
    final out = <String>[];
    for (final e in _entries.reversed) {
      if (e.kind != kind || out.contains(e.name)) continue;
      out.add(e.name);
      if (out.length >= limit) break;
    }
    return out;
  }

  // ───── 이름 맞추기 도우미 ─────

  static String _norm(String s) => s.replaceAll(RegExp(r'\s+'), '').toLowerCase();

  /// "잭슨블러바드 백마점" → "잭슨블러바드" 처럼 지점 이름을 떼요
  static String coreName(String placeName) {
    var n = placeName.replaceAll(RegExp(r'\([^)]*\)'), ' ').trim();
    final tokens = n.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.length >= 2 && tokens.last.endsWith('점')) tokens.removeLast();
    n = tokens.join();
    return n.length >= 2 ? n : placeName.replaceAll(' ', '');
  }

  /// 글 속에 이 가게가 나오는지 (띄어쓰기 무시, 지점명 떼고도 확인)
  static bool mentionsPlace(String normalizedText, String placeName) {
    final full = _norm(placeName);
    if (full.length >= 2 && normalizedText.contains(full)) return true;
    final core = _norm(coreName(placeName));
    return core.length >= 2 && normalizedText.contains(core);
  }

  /// "김치찌개 백반" → "김치찌개", "규동(소고기덮밥)" → "규동"  (앞 단어만)
  static String foodCore(String foodName) {
    final first = foodName.split(RegExp(r'[\s(]')).firstWhere((t) => t.trim().isNotEmpty, orElse: () => '');
    return first.replaceAll(RegExp(r'\d.*$'), '').trim().toLowerCase();
  }

  /// "김밥 1줄" → "김밥", "삶은 계란 2개" → "삶은계란"
  static String foodKey(String foodName) =>
      foodName.replaceAll(RegExp(r'[\s\d()+개줄조각봉지컵팩줌mlgL]+'), '').toLowerCase();

  // ───── AI에게 보여줄 가게 목록 뽑기 ─────

  /// 종류별로 골고루, 매번 순서를 섞어서, 최근 추천한 가게는 빼고 뽑아요.
  ///  - [avoid]: 최근 추천한 가게 (가장 최근 것부터). 이 가게들은 뒤로 밀려요.
  ///  - 종류별 가게가 적어서 [max]를 못 채우면 avoid 중 오래된 것부터 다시 넣어요.
  static List<Place> pickForPrompt(
    List<Place> all, {
    required List<String> avoid,
    int max = promptPlaceCount,
    Random? rng,
  }) {
    if (all.isEmpty) return const [];
    final r = rng ?? Random();
    final avoidSet = avoid.toSet();

    // 1) 최근 추천한 가게 / 아닌 가게로 나누기
    final fresh = <Place>[];
    final stale = <Place>[];
    for (final p in all) {
      (avoidSet.contains(p.name) ? stale : fresh).add(p);
    }

    // 2) 종류별로 묶고, 묶음 안에서 섞기 (제휴 가게는 앞쪽에 — 진짜 메뉴가 있으니까)
    final groups = <String, List<Place>>{};
    for (final p in fresh) {
      groups.putIfAbsent(p.shortCategory.isEmpty ? '기타' : p.shortCategory, () => []).add(p);
    }
    final groupList = groups.values.toList()..shuffle(r);
    for (final g in groupList) {
      g.shuffle(r);
      g.sort((a, b) {
        final pa = MenuCatalog.isPartner(a) ? 0 : 1;
        final pb = MenuCatalog.isPartner(b) ? 0 : 1;
        return pa.compareTo(pb); // 안정 정렬이라 섞은 순서는 유지돼요
      });
    }

    // 3) 종류를 돌아가며 하나씩 뽑기 (한 종류가 목록을 독차지하지 않게)
    final picked = <Place>[];
    var idx = 0;
    while (picked.length < max) {
      var added = false;
      for (final g in groupList) {
        if (idx < g.length) {
          picked.add(g[idx]);
          added = true;
          if (picked.length >= max) break;
        }
      }
      if (!added) break;
      idx++;
    }

    // 4) 너무 적으면 최근 추천한 가게 중 "가장 오래전에 추천한 것"부터 다시 채우기
    if (picked.length < max) {
      final order = {for (var i = 0; i < avoid.length; i++) avoid[i]: i};
      stale.sort((a, b) => (order[b.name] ?? 0).compareTo(order[a.name] ?? 0));
      for (final p in stale) {
        if (picked.length >= max) break;
        picked.add(p);
      }
    }
    return picked;
  }

  /// 메뉴 하나에 어울리는 근처 가게를 골라요.
  ///  - 가까운 가게가 뽑힐 확률이 높지만, 항상 1등만 뽑히진 않아요 (무작위 가중치)
  ///  - 최근에 추천한 가게는 빼요 (그 가게밖에 없으면 그때만 허용)
  ///  - 제휴 가게는 살짝 가산점
  static List<Place> rotatePlaces(
    List<Place> candidates, {
    required List<String> avoid,
    int count = 2,
    Random? rng,
  }) {
    if (candidates.isEmpty) return const [];
    final r = rng ?? Random();
    final avoidSet = avoid.toSet();

    var pool = candidates.where((p) => !avoidSet.contains(p.name)).toList();
    if (pool.isEmpty) pool = List.of(candidates);

    final out = <Place>[];
    while (out.length < count && pool.isNotEmpty) {
      // 가중치: 300m마다 반으로 줄어듦 + 제휴 1.5배
      final weights = pool.map((p) {
        final w = 1.0 / (1.0 + p.distanceM / 300.0);
        return MenuCatalog.isPartner(p) ? w * 1.5 : w;
      }).toList();
      final total = weights.fold(0.0, (a, b) => a + b);
      var roll = r.nextDouble() * total;
      var chosen = pool.length - 1;
      for (var i = 0; i < pool.length; i++) {
        roll -= weights[i];
        if (roll <= 0) {
          chosen = i;
          break;
        }
      }
      out.add(pool.removeAt(chosen));
    }
    return out;
  }
}
