// ─────────────────────────────────────────────────────────────
//  Firebase 연결 설정 — 진짜 회원가입·로그인·예약 저장을 켜는 파일
//
//  채우는 법 (한 번만):
//   1) https://console.firebase.google.com → 프로젝트 추가 → 이름 mealon
//   2) 왼쪽 "빌드" → Authentication → 시작하기 → "이메일/비밀번호" 사용 설정
//   3) 왼쪽 "빌드" → Firestore Database → 데이터베이스 만들기 → 테스트 모드
//   4) 톱니바퀴(프로젝트 설정) → 아래 "내 앱" → 웹(</>) 추가 → 닉네임 mealon → 앱 등록
//      → 화면에 뜨는 firebaseConfig 의 6개 값을 아래 따옴표 안에 붙여넣기
//   5) 저장 → 서버 재시작 → 로그인 화면의 "연습 모드" 띠가 사라지면 성공
//
//  6개 값이 하나라도 비어 있으면 앱은 자동으로 "연습 모드"(이 기기에만 저장)로 켜져요.
//  ※ 이 값들은 Firebase가 "공개돼도 되는 값"으로 만든 거라 GitHub에 올라가도 괜찮아요.
// ─────────────────────────────────────────────────────────────
import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  // ↓↓↓ 여기 6개만 채우면 돼요 (firebaseConfig 에서 같은 이름을 찾아서 복사) ↓↓↓
  static const String apiKey = '여기에-apiKey';
  static const String authDomain = '여기에-authDomain'; // 예: mealon-12345.firebaseapp.com
  static const String projectId = '여기에-projectId'; // 예: mealon-12345
  static const String storageBucket = '여기에-storageBucket'; // 예: mealon-12345.firebasestorage.app
  static const String messagingSenderId = '여기에-messagingSenderId'; // 숫자만
  static const String appId = '여기에-appId'; // 예: 1:1234567890:web:abc123
  // ↑↑↑ 여기까지 ↑↑↑

  static bool _ok(String v) => v.trim().isNotEmpty && !v.contains('여기에');

  /// 아직 안 채운 값 이름들 (모두 채웠으면 빈 목록)
  static List<String> get missing => [
        if (!_ok(apiKey)) 'apiKey',
        if (!_ok(authDomain)) 'authDomain',
        if (!_ok(projectId)) 'projectId',
        if (!_ok(storageBucket)) 'storageBucket',
        if (!_ok(messagingSenderId)) 'messagingSenderId',
        if (!_ok(appId)) 'appId',
      ];

  static bool get ready => missing.isEmpty;

  /// 앱이 켜질 때 main.dart 가 이걸 불러요
  static FirebaseOptions get currentPlatform {
    if (!ready) {
      throw UnsupportedError('Firebase 설정이 아직 비어 있어요: ${missing.join(', ')} → lib/firebase_options.dart');
    }
    // 웹·폰 모두 이 설정 하나로 돼요 (지금은 웹으로 쓰니까)
    return const FirebaseOptions(
      apiKey: apiKey,
      authDomain: authDomain,
      projectId: projectId,
      storageBucket: storageBucket,
      messagingSenderId: messagingSenderId,
      appId: appId,
    );
  }
}
