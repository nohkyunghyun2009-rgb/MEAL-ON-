/// ─────────────────────────────────────────────────────────────
///  열쇠(키) 보관함
///  이 파일에 있는 값은 "비밀번호"와 같아요.
///  친구에게 보내거나, 깃허브에 올리거나, 발표 화면에 띄우면 안 돼요!
/// ─────────────────────────────────────────────────────────────
class AppKeys {
  /// 1) Claude API 키 → https://console.anthropic.com 에서 발급
  ///    "sk-ant-" 로 시작해요.
  static const String claudeApiKey = 'sk-ant-여기에-붙여넣기';
  static const String geminiApiKey = '여기에-제미나이-키';

  /// 2) 카카오 JavaScript 키 → https://developers.kakao.com
  ///    (내 애플리케이션 → 앱 키 → JavaScript 키)  지도 그릴 때 써요.
  static const String kakaoJavascriptKey = '여기에-카카오-JavaScript-키';

  /// 3) 카카오 REST API 키 → 같은 화면에서 "REST API 키"
  ///    식당 검색할 때 써요.
  static const String kakaoRestApiKey = '여기에-카카오-REST-API-키';

  /// 4) 사장님 모드 비밀번호 (박람회 때 아무나 못 들어가게)
  static const String ownerPin = '1234';

  /// 5) 우리 앱이 받는 수수료 (5% = 0.05)
  static const double commissionRate = 0.05;

  // 아래는 "키를 넣었는지" 확인하는 도우미예요. 건드리지 않아도 돼요.
  static bool get claudeReady =>
      claudeApiKey.startsWith('sk-ant-') && !claudeApiKey.contains('여기에');
  static bool get kakaoReady =>
      !kakaoJavascriptKey.contains('여기에') && !kakaoRestApiKey.contains('여기에');
}
