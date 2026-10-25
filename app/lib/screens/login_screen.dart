import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icon.dart';

/// ═══════════════════════════════════════════════════════════
///  로그인 / 회원가입 화면 (앱 켜면 제일 먼저 나와요)
///  로그인에 성공하면 onDone()을 불러줘요 → main.dart가 다음 화면을 정해요
/// ═══════════════════════════════════════════════════════════
class LoginScreen extends StatefulWidget {
  final VoidCallback onDone;
  const LoginScreen({super.key, required this.onDone});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  bool _isSignUp = false; // false = 로그인 화면, true = 회원가입 화면
  bool _busy = false;
  bool _hidePw = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final auth = context.read<AuthService>();
    final email = _email.text.trim();
    final pw = _pw.text;

    if (!AuthService.looksLikeEmail(email)) {
      setState(() => _error = '이메일을 정확히 적어주세요 (예: name@gmail.com)');
      return;
    }
    if (pw.length < 6) {
      setState(() => _error = '비밀번호는 6자 이상이에요');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_isSignUp) {
        await auth.signUp(email, pw);
        if (!mounted) return;
        if (auth.isOnline) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$email 로 인증 메일을 보냈어요. 메일함을 확인해 주세요!')),
          );
        }
      } else {
        await auth.signIn(email, pw);
      }
      if (!mounted) return;
      widget.onDone();
    } on AuthError catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  Future<void> _forgot() async {
    final auth = context.read<AuthService>();
    final email = _email.text.trim();
    if (!AuthService.looksLikeEmail(email)) {
      setState(() => _error = '먼저 위에 이메일을 적어주세요');
      return;
    }
    try {
      await auth.sendPasswordReset(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.isOnline
              ? '$email 로 비밀번호 재설정 메일을 보냈어요'
              : '연습 모드: 비밀번호가 123456 으로 바뀌었어요'),
        ),
      );
    } on AuthError catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final online = context.watch<AuthService>().isOnline;

    return Scaffold(
      body: Column(
        children: [
          // ── 위쪽: 초록 그라데이션 + 로고 ──
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.teal, AppColors.primary],
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                      decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(999)),
                      child: const Text('MEAL:ON',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 26, letterSpacing: 1)),
                    ),
                    const SizedBox(height: 14),
                    const Text('나에게 맞는 한 끼를 켜다',
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconBadge(icon: Icons.eco_rounded, colors: [Colors.white24, Colors.white38], size: 40, shadow: false),
                        SizedBox(width: 10),
                        IconBadge(icon: Icons.rice_bowl_rounded, colors: [Colors.white24, Colors.white38], size: 40, shadow: false),
                        SizedBox(width: 10),
                        IconBadge(icon: Icons.local_drink_rounded, colors: [Colors.white24, Colors.white38], size: 40, shadow: false),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── 아래쪽: 흰 카드 (입력) ──
          Expanded(
            flex: 6,
            child: Container(
              width: double.infinity,
              transform: Matrix4.translationValues(0, -24, 0), // 초록 위로 살짝 겹치게
              decoration: const BoxDecoration(
                color: AppColors.paper,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_isSignUp ? '회원가입' : '로그인', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 4),
                    Text(
                      _isSignUp ? '이메일로 가입하면 예약·기록이 내 계정에 저장돼요' : '가입한 이메일로 들어와요',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (!online) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.sun.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                        child: const Text('연습 모드: 계정이 이 기기에만 저장돼요. Firebase를 연결하면 진짜 이메일 로그인이 돼요.',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ],
                    const SizedBox(height: 18),

                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: const InputDecoration(labelText: '이메일', prefixIcon: Icon(Icons.mail_outline_rounded)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pw,
                      obscureText: _hidePw,
                      onSubmitted: (_) => _busy ? null : _go(),
                      decoration: InputDecoration(
                        labelText: '비밀번호 (6자 이상)',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(_hidePw ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setState(() => _hidePw = !_hidePw),
                        ),
                      ),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(_error!, style: const TextStyle(color: Color(0xFFD93025), fontWeight: FontWeight.w700, fontSize: 13)),
                    ],
                    const SizedBox(height: 18),

                    FilledButton(
                      onPressed: _busy ? null : _go,
                      child: _busy
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(_isSignUp ? '가입하고 시작하기' : '로그인'),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                    _isSignUp = !_isSignUp;
                                    _error = null;
                                  }),
                          child: Text(_isSignUp ? '이미 계정이 있어요 → 로그인' : '처음이에요 → 회원가입',
                              style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
                        ),
                        if (!_isSignUp)
                          TextButton(
                            onPressed: _busy ? null : _forgot,
                            child: const Text('비밀번호를 잊었어요', style: TextStyle(color: AppColors.muted)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
