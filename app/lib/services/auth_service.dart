import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ═══════════════════════════════════════════════════════════
///  로그인 담당 (예약 장부처럼 2가지 버전)
///  - FirebaseAuthService : 구글 Firebase 로그인 서버 → 진짜 이메일 로그인 (진짜 모드)
///  - LocalAuthService    : 내 폰에만 저장 → Firebase 연결 전 연습용 (연습 모드)
/// ═══════════════════════════════════════════════════════════

/// 로그인 실패 이유 (한국어로)
class AuthError implements Exception {
  final String message;
  const AuthError(this.message);
  @override
  String toString() => message;
}

abstract class AuthService extends ChangeNotifier {
  AuthService();

  factory AuthService.create({required bool useFirebase}) =>
      useFirebase ? FirebaseAuthService() : LocalAuthService();

  /// 지금 로그인된 이메일 (없으면 null)
  String? get email;
  bool get isSignedIn => email != null;
  bool get isOnline;

  Future<void> init();
  Future<void> signUp(String email, String password);
  Future<void> signIn(String email, String password);
  Future<void> signOut();
  Future<void> sendPasswordReset(String email);

  /// 이메일 모양이 맞는지 간단 검사 (골뱅이 + 점)
  static bool looksLikeEmail(String s) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s.trim());
}

// ═══════════════════════════════════════════════════════════
//  진짜 모드: Firebase Authentication
// ═══════════════════════════════════════════════════════════
class FirebaseAuthService extends AuthService {
  final _auth = fb.FirebaseAuth.instance;

  @override
  String? get email => _auth.currentUser?.email;

  @override
  bool get isOnline => true;

  @override
  Future<void> init() async {
    // 로그인 상태가 바뀔 때마다(로그인/로그아웃) 화면에 알려줘요
    _auth.authStateChanges().listen((_) => notifyListeners());
  }

  /// Firebase가 영어로 주는 오류 코드를 한국어로 바꿔줘요
  AuthError _translate(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return const AuthError('이미 가입된 이메일이에요. 로그인해 주세요.');
      case 'invalid-email':
        return const AuthError('이메일 모양이 이상해요. 다시 확인해 주세요.');
      case 'weak-password':
        return const AuthError('비밀번호는 6자 이상으로 해주세요.');
      case 'user-not-found':
        return const AuthError('가입되지 않은 이메일이에요.');
      case 'wrong-password':
      case 'invalid-credential':
        return const AuthError('이메일 또는 비밀번호가 틀렸어요.');
      case 'too-many-requests':
        return const AuthError('너무 많이 시도했어요. 잠시 후 다시 해주세요.');
      case 'network-request-failed':
        return const AuthError('인터넷 연결을 확인해 주세요.');
      default:
        return AuthError('로그인에 문제가 생겼어요 (${e.code})');
    }
  }

  @override
  Future<void> signUp(String email, String password) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
      await cred.user?.sendEmailVerification(); // 진짜 이메일로 인증 메일이 날아가요
    } on fb.FirebaseAuthException catch (e) {
      throw _translate(e);
    }
  }

  @override
  Future<void> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
    } on fb.FirebaseAuthException catch (e) {
      throw _translate(e);
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on fb.FirebaseAuthException catch (e) {
      throw _translate(e);
    }
  }
}

// ═══════════════════════════════════════════════════════════
//  연습 모드: 내 폰에만 저장 (Firebase 연결 전)
// ═══════════════════════════════════════════════════════════
class LocalAuthService extends AuthService {
  static const _kUsers = 'local_users'; // {이메일: 비밀번호} 장부
  static const _kCurrent = 'local_current_email'; // 지금 로그인된 사람

  Map<String, String> _users = {};
  String? _current;

  @override
  String? get email => _current;

  @override
  bool get isOnline => false;

  @override
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kUsers);
    if (raw != null) {
      _users = (jsonDecode(raw) as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String));
    }
    _current = prefs.getString(_kCurrent);
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUsers, jsonEncode(_users));
    if (_current == null) {
      await prefs.remove(_kCurrent);
    } else {
      await prefs.setString(_kCurrent, _current!);
    }
  }

  @override
  Future<void> signUp(String email, String password) async {
    final e = email.trim().toLowerCase();
    if (!AuthService.looksLikeEmail(e)) throw const AuthError('이메일 모양이 이상해요. 다시 확인해 주세요.');
    if (password.length < 6) throw const AuthError('비밀번호는 6자 이상으로 해주세요.');
    if (_users.containsKey(e)) throw const AuthError('이미 가입된 이메일이에요. 로그인해 주세요.');
    await Future<void>.delayed(const Duration(milliseconds: 600)); // 서버에 묻는 척
    _users[e] = password;
    _current = e;
    notifyListeners();
    await _save();
  }

  @override
  Future<void> signIn(String email, String password) async {
    final e = email.trim().toLowerCase();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!_users.containsKey(e)) throw const AuthError('가입되지 않은 이메일이에요.');
    if (_users[e] != password) throw const AuthError('이메일 또는 비밀번호가 틀렸어요.');
    _current = e;
    notifyListeners();
    await _save();
  }

  @override
  Future<void> signOut() async {
    _current = null;
    notifyListeners();
    await _save();
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    final e = email.trim().toLowerCase();
    if (!_users.containsKey(e)) throw const AuthError('가입되지 않은 이메일이에요.');
    // 연습 모드는 메일을 못 보내니 비밀번호를 123456으로 바꿔줘요
    _users[e] = '123456';
    await _save();
  }
}
