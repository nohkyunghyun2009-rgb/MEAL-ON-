import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_keys.dart';
import 'claude_service.dart' show ChatMessage;

/// ═══════════════════════════════════════════════════════════
///  제미나이(Gemini)에게 편지를 보내고 답장을 받아오는 우체부
///  - 키는 lib/config/app_keys.dart 의 geminiApiKey 에서 읽어요
///  - Claude 우체부(claude_service.dart)와 똑같은 모양(ask)이라
///    AI 화면은 둘 중 아무거나 골라 쓸 수 있어요
///  - 웹 브라우저에서도 바로 호출돼요 (Claude와 달리 특별 헤더 불필요)
/// ═══════════════════════════════════════════════════════════
class GeminiService {
  /// 써볼 모델들 (앞에서부터). 404(그 키로는 없는 모델)가 나면 다음 걸로 자동으로 넘어가요.
  /// 전부 안 되면 구글에 "쓸 수 있는 모델 목록"을 물어봐서 flash 모델을 골라요.
  static const models = ['gemini-2.5-flash', 'gemini-2.0-flash', 'gemini-2.5-flash-lite', 'gemini-1.5-flash', 'gemini-flash-latest'];

  /// 한 번 성공한 모델은 기억해뒀다가 다음부터 바로 써요
  static String? workingModel;

  static String _urlFor(String model) => 'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent';

  /// 키를 넣었는지 확인 (구글 키는 "AIza..." 또는 "AQ." 로 시작해요)
  static bool get ready {
    final k = AppKeys.geminiApiKey.trim();
    return k.isNotEmpty && !k.contains('여기에') && (k.startsWith('AIza') || k.startsWith('AQ.'));
  }

  Future<String> ask({
    required String system,
    required List<ChatMessage> history,
    double temperature = 1.0, // 추천은 1.0(다양하게), 영양 계산은 0.2(일정하게)
  }) async {
    if (!ready) {
      throw Exception('Gemini API 키가 아직 없어요. lib/config/app_keys.dart 의 geminiApiKey 를 확인하세요.');
    }

    // 1) 기억해둔 모델 → 2) 목록의 모델들 순서대로. 404("그 모델 없음")만 다음으로 넘어가고, 다른 오류는 바로 알려줘요.
    final tryList = [if (workingModel != null) workingModel!, ...models.where((m) => m != workingModel)];
    Object? lastNotFound;
    for (final m in tryList) {
      try {
        final r = await _askModel(m, system: system, history: history, temperature: temperature);
        workingModel = m;
        return r;
      } on _ModelNotFound catch (e) {
        lastNotFound = e;
      }
    }
    // 3) 전부 404면 구글에 쓸 수 있는 모델을 물어봐요
    for (final m in await _listUsableModels()) {
      if (tryList.contains(m)) continue;
      try {
        final r = await _askModel(m, system: system, history: history, temperature: temperature);
        workingModel = m;
        return r;
      } on _ModelNotFound {
        continue;
      }
    }
    throw Exception('이 키로 쓸 수 있는 Gemini 모델을 못 찾았어요. 마지막 오류: $lastNotFound');
  }

  /// 구글에 "이 키로 쓸 수 있는 모델"을 물어봐서 generateContent 되는 flash 모델부터 돌려줘요
  Future<List<String>> _listUsableModels() async {
    try {
      final res = await http.get(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?pageSize=100'),
        headers: {'x-goog-api-key': AppKeys.geminiApiKey.trim()},
      ).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return const [];
      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final names = <String>[];
      for (final m in (data['models'] as List<dynamic>? ?? const [])) {
        final map = m as Map<String, dynamic>;
        final methods = (map['supportedGenerationMethods'] as List<dynamic>? ?? const []).cast<String>();
        if (!methods.contains('generateContent')) continue;
        final name = (map['name'] as String).replaceFirst('models/', '');
        if (name.contains('gemini')) names.add(name);
      }
      names.sort((a, b) {
        int rank(String n) => n.contains('flash') ? 0 : (n.contains('pro') ? 1 : 2);
        return rank(a).compareTo(rank(b));
      });
      return names;
    } catch (_) {
      return const [];
    }
  }

  Future<String> _askModel(String model, {required String system, required List<ChatMessage> history, bool thinkingOff = true, int maxTokens = 2048, double temperature = 1.0}) async {

    // 제미나이는 role 이름이 달라요: 학생 = 'user', AI = 'model'
    final contents = history
        .map((m) => {
              'role': m.isUser ? 'user' : 'model',
              'parts': [
                {'text': m.text}
              ],
            })
        .toList();

    final response = await http
        .post(
          Uri.parse(_urlFor(model)),
          headers: {
            'content-type': 'application/json',
            'x-goog-api-key': AppKeys.geminiApiKey.trim(),
          },
          body: jsonEncode({
            'system_instruction': {
              'parts': [
                {'text': system}
              ]
            },
            'contents': contents,
            'generationConfig': {
              // 2.5 모델은 답하기 전에 속으로 "생각"하는 토큰을 쓰는데, 그게 이 한도에 같이 계산돼요.
              // 800이면 생각만 하다가 답이 첫 줄에서 잘려요 → 한도를 올리고(아래) 생각은 꺼요(thinkingBudget 0).
              'maxOutputTokens': maxTokens,
              // 1.0 = 제미나이 기본값. 낮을수록 매번 비슷한 답(같은 가게)이 나와요.
              'temperature': temperature,
              // 모델 이름에 상관없이 항상 생각 끄기 (gemini-flash-latest 같은 별명도 2.5일 수 있어서).
              // 이 설정을 모르는 모델은 400을 내는데, 그땐 아래에서 설정만 빼고 다시 보내요.
              if (thinkingOff) 'thinkingConfig': {'thinkingBudget': 0},
            },
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode == 404) {
      throw _ModelNotFound(model, utf8.decode(response.bodyBytes));
    }
    // 이 모델이 thinkingConfig를 모르면(400) 그 설정만 빼고 한 번 더
    if (response.statusCode == 400 && thinkingOff && utf8.decode(response.bodyBytes).toLowerCase().contains('thinking')) {
      return _askModel(model, system: system, history: history, thinkingOff: false, maxTokens: maxTokens, temperature: temperature);
    }
    if (response.statusCode != 200) {
      throw Exception('Gemini 응답 오류 (${response.statusCode}): ${utf8.decode(response.bodyBytes)}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final candidates = (data['candidates'] as List<dynamic>?) ?? const [];
    if (candidates.isEmpty) {
      throw Exception('Gemini가 답을 비워서 보냈어요 (안전 필터에 걸렸을 수 있어요)');
    }
    final first = candidates.first as Map<String, dynamic>;
    final parts = (first['content']?['parts'] as List<dynamic>?) ?? const [];

    // 답장 중에서 "글자" 부분만 모아서 돌려줘요 (생각 부분은 빼고)
    final text = parts
        .map((p) => p as Map<String, dynamic>)
        .where((p) => p['thought'] != true)
        .map((p) => p['text'] as String? ?? '')
        .where((t) => t.isNotEmpty)
        .join('\n')
        .trim();
    if (text.isEmpty) {
      throw Exception('Gemini가 글자 없이 답했어요 (finishReason: ${first['finishReason']})');
    }
    // 한도에 걸려 잘렸으면: 한도를 4배로 키워서 한 번 더 (생각 토큰이 많은 모델 대비). 그래도 잘리면 표시.
    if (first['finishReason'] == 'MAX_TOKENS') {
      if (maxTokens < 8192) {
        return _askModel(model, system: system, history: history, thinkingOff: thinkingOff, maxTokens: 8192, temperature: temperature);
      }
      return '$text\n…(답이 길어서 잘렸어. 다시 물어봐줘)';
    }
    return text;
  }
}

/// "그 모델은 이 키로 못 써요"(404) — 다음 모델로 넘어가라는 신호
class _ModelNotFound implements Exception {
  final String model;
  final String body;
  _ModelNotFound(this.model, this.body);
  @override
  String toString() => '모델 $model 없음 (404): ${body.length > 120 ? '${body.substring(0, 120)}…' : body}';
}
