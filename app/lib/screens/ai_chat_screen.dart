import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_keys.dart';
import '../services/claude_service.dart';
import '../services/gemini_service.dart';
import '../services/local_coach.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icon.dart';

/// "AI 추천" 탭: AI에게 직접 물어보는 채팅 화면
/// 순서: ① Gemini 키 있으면 Gemini → ② 없으면 Claude → ③ 둘 다 없거나 실패하면 앱 자체 추천
class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _claude = ClaudeService();
  final _gemini = GeminiService();

  /// 지금 어떤 AI가 켜져 있는지
  static bool get _aiReady => GeminiService.ready || AppKeys.claudeReady;
  static String get _aiName => GeminiService.ready ? 'Gemini' : (AppKeys.claudeReady ? 'Claude' : '자체 추천');
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _loading = false;

  // 학생이 자주 묻는 질문을 버튼으로 미리 준비해요
  static const _quickQuestions = [
    '지금 뭐 먹으면 좋아?',
    '다른 거 추천해줘',
    '건강한 걸로',
    '가볍게 먹을 수 있는 걸로',
    '든든하게 먹고 싶어',
    '단백질 많은 걸로',
    '채소 많은 걸로',
    '국물 있는 걸로',
    '매운 거 먹고 싶어',
    '시원한 걸로',
    '고기 먹고 싶어',
    '안 느끼한 걸로',
    '빨리 먹을 수 있는 걸로',
    '5천 원으로 뭐 먹지?',
    '편의점에서 살 수 있는 걸로!',
    '안 가본 가게로 추천해줘',
    '시험 전에 먹을 걸로',
    '라면 먹어도 돼?',
    '내 몸 상태 어때?',
  ];

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final t = text.trim();
    if (t.isEmpty || _loading) return;

    final app = context.read<AppState>();
    app.addChat(ChatMessage('user', t)); // 1) 내 말풍선 먼저 보여주기
    _input.clear();
    setState(() => _loading = true);
    _scrollToEnd();

    try {
      // 0) 근처 식당 목록이 비어 있으면 먼저 받아와요 (AI 탭이 식당 탭보다 앞에 있어서 자주 비어 있어요)
      await app.ensureNearbyPlaces();

      if (!_aiReady) {
        // 2-a) AI 키가 하나도 없으면 앱 자체 추천 엔진이 답해요 (돈·인터넷 필요 없음)
        await Future.delayed(const Duration(milliseconds: 500)); // 잠깐 생각하는 느낌
        final reply = await LocalCoach.reply(t, app);
        app.addChat(ChatMessage('assistant', reply, note: '자체 추천'));
        await app.rememberRecommendation(reply); // 다음엔 다른 가게·메뉴가 나오게 기억
      } else {
        // 2-b) AI에게 "오늘 상황 설명서(인바디 방향 + 후보 메뉴) + 최근 대화" 보내기 (Gemini 우선, 없으면 Claude)
        final system = app.buildSystemPrompt(question: t);
        final history = _recentHistory(app.chat);
        final reply = GeminiService.ready
            ? await _gemini.ask(system: system, history: history)
            : await _claude.ask(system: system, history: history);
        app.addChat(ChatMessage('assistant', reply, note: GeminiService.ready ? 'Gemini · ${GeminiService.workingModel ?? ''}' : 'Claude'));
        await app.rememberRecommendation(reply); // 다음엔 다른 가게·메뉴가 나오게 기억
      }
    } catch (e) {
      // AI가 실패하면(키 오류, 할당량 초과, 인터넷 끊김 등) 자체 추천으로 대신 답해요
      debugPrint('$_aiName 실패, 자체 추천으로 대체: $e');
      final reply = await LocalCoach.reply(t, app);
      app.addChat(ChatMessage('assistant', reply, note: '자체 추천 · $_aiName 연결 실패: ${_shortError(e)}'));
      await app.rememberRecommendation(reply);
    } finally {
      if (mounted) setState(() => _loading = false);
      _scrollToEnd();
    }
  }

  /// AI에게는 최근 대화 10줄만 보내요. 전부 보내면 AI가 "아까 한 말"을 그대로 따라 해서 답이 비슷해져요.
  /// (Gemini는 첫 줄이 학생 말이어야 해서 앞쪽을 잘라요)
  static List<ChatMessage> _recentHistory(List<ChatMessage> chat) {
    var h = chat.length > 10 ? chat.sublist(chat.length - 10) : List.of(chat);
    while (h.isNotEmpty && !h.first.isUser) {
      h = h.sublist(1);
    }
    return h;
  }

  /// 오류 글이 너무 길면 앞부분만 (화면 아래 작은 글씨용)
  static String _shortError(Object e) {
    final s = e.toString().replaceFirst('Exception: ', '').replaceAll('\n', ' ');
    return s.length > 90 ? '${s.substring(0, 90)}…' : s;
  }

  void _scrollToEnd() {
    // 화면이 다시 그려진 "다음" 순간에 맨 아래로 내려요
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final messages = app.chat;

    return Scaffold(
      appBar: AppBar(title: const Text('AI 메뉴 코치')),
      body: Column(
        children: [
          if (!_aiReady)
            Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.mint, borderRadius: BorderRadius.circular(14)),
              child: const Row(
                children: [
                  Icon(Icons.psychology_rounded, size: 18, color: AppColors.primaryDark),
                  SizedBox(width: 8),
                  Expanded(child: Text('앱 자체 추천 모드 · Gemini나 Claude 키를 넣으면 대화형으로 바뀌어요', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                ],
              ),
            ),
          Expanded(
            child: messages.isEmpty
                ? _EmptyState(onTap: _send)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    itemCount: messages.length + (_loading ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == messages.length) return const _TypingBubble();
                      return _Bubble(message: messages[i]);
                    },
                  ),
          ),
          // 빠른 질문 버튼
          if (messages.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _quickQuestions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ActionChip(
                  label: Text(_quickQuestions[i]),
                  onPressed: () => _send(_quickQuestions[i]),
                ),
              ),
            ),
          // 입력창
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: AppColors.cardShadow),
                      child: TextField(
                        controller: _input,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: _send,
                        decoration: const InputDecoration(hintText: '메뉴 코치에게 물어보기'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _loading ? null : () => _send(_input.text),
                    icon: const Icon(Icons.arrow_upward_rounded),
                    style: IconButton.styleFrom(backgroundColor: AppColors.primary, minimumSize: const Size(52, 52)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 아직 대화가 없을 때 보이는 안내 + 시작 버튼
class _EmptyState extends StatelessWidget {
  final void Function(String) onTap;
  const _EmptyState({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final focus = app.insight?.focusNutrients.join(', ') ?? '골고루';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.teal, AppColors.primary], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const IconBadge(icon: Icons.auto_awesome_rounded, colors: [Colors.white24, Colors.white38], size: 52, shadow: false),
              const SizedBox(height: 14),
              const Text('오늘 몸 상태와 먹은 걸 보고\n근처 가게까지 골라줄게', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900, height: 1.3, letterSpacing: -0.5)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.22), borderRadius: BorderRadius.circular(999)),
                child: Text('오늘 챙기면 좋은 것: $focus', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ..._AiChatScreenState._quickQuestions.take(9).map((q) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OutlinedButton(onPressed: () => onTap(q), child: Text(q)),
            )),
      ],
    );
  }
}

/// 말풍선 하나
class _Bubble extends StatelessWidget {
  final ChatMessage message;
  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
      decoration: BoxDecoration(
        color: isUser ? AppColors.primary : Colors.white,
        boxShadow: isUser ? null : AppColors.cardShadow,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(isUser ? 20 : 6),
          bottomRight: Radius.circular(isUser ? 6 : 20),
        ),
      ),
      child: SelectableText(
        message.text,
        style: TextStyle(color: isUser ? Colors.white : AppColors.ink, fontSize: 15, height: 1.55, fontWeight: isUser ? FontWeight.w700 : FontWeight.w500),
      ),
    );

    if (isUser) return Align(alignment: Alignment.centerRight, child: bubble);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Padding(
          padding: EdgeInsets.only(right: 8, bottom: 8),
          child: IconBadge(icon: Icons.auto_awesome_rounded, colors: Grad.green, size: 30, radius: 999, shadow: false),
        ),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bubble,
              // 어떤 엔진이 답했는지 (문제 생기면 여기 보고 알 수 있어요)
              if (message.note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 6, bottom: 4),
                  child: Text(message.note, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "생각 중..." 표시
class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: AppColors.cardShadow,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 10),
              Text('메뉴 고르는 중...', style: TextStyle(color: AppColors.muted)),
            ],
          ),
        ),
      );
}
