import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_keys.dart';

/// 대화 한 줄. role은 'user'(학생) 또는 'assistant'(Claude)
class ChatMessage {
  final String role;
  final String text;

  /// 어떤 엔진이 답했는지 (예: 'Gemini', '자체 추천 · Gemini 연결 실패: ...'). 학생 말풍선은 비어 있어요.
  final String note;
  const ChatMessage(this.role, this.text, {this.note = ''});

  bool get isUser => role == 'user';
}

/// Claude에게 편지를 보내고 답장을 받아오는 우체부
class ClaudeService {
  static const _url = 'https://api.anthropic.com/v1/messages';

  /// 어떤 Claude 모델을 쓸지. 바꾸고 싶으면 여기만 고치면 돼요.
  /// 더 싸고 빠른 걸 원하면 'claude-haiku-4-5' 로 바꿔도 돼요.
  static const model = 'claude-sonnet-5';

  Future<String> ask({
    required String system,
    required List<ChatMessage> history,
  }) async {
    if (!AppKeys.claudeReady) {
      throw Exception('Claude API 키가 아직 없어요. lib/config/app_keys.dart 에 키를 넣어주세요.');    }

    final response = await http
        .post(
          Uri.parse(_url),
          headers: {
            'content-type': 'application/json',
            'x-api-key': AppKeys.claudeApiKey,
            'anthropic-version': '2023-06-01',
                        'anthropic-dangerous-direct-browser-access': 'true',
          },
          body: jsonEncode({
            'model': model,
            'max_tokens': 800,
            'system': system,
            'messages': history
                .map((m) => {'role': m.role, 'content': m.text})
                .toList(),
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw Exception('Claude 응답 오류 (${response.statusCode}): ${utf8.decode(response.bodyBytes)}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final content = data['content'] as List<dynamic>;

    // 답장 중에서 "글자" 부분만 모아서 돌려줘요
    return content
        .where((c) => c['type'] == 'text')
        .map((c) => c['text'] as String)
        .join('\n')
        .trim();
  }
}
