// ============================================================
// payment_config.dart
// 결제 설정 — 토스페이먼츠 키와 결제 승인 서버 주소를 여기서 바꿔요.
//
// ▶ 테스트 키(test_ck_…)로는 결제창이 진짜처럼 뜨지만 돈은 안 빠져나가요.
//   (테스트 카드번호: 아무 숫자 16자리, 유효기간/CVC도 아무거나)
// ▶ 실제 결제로 바꾸려면:
//   1. 토스페이먼츠 가입 → 사업자 심사 → 운영 키(live_ck_…) 발급
//   2. kTossClientKey 를 운영 클라이언트 키로 바꾸기
//   3. server/ 의 시크릿 키(TOSS_SECRET_KEY)를 운영 시크릿 키로 바꾸기
//   → 코드는 그대로예요.
// ============================================================

/// 토스페이먼츠 클라이언트 키 (앱에 넣어도 되는 공개 키)
/// 아래는 토스 개발자센터가 공개한 "문서용 테스트 키"예요.
/// 내 계정으로 가입하면 developers.tosspayments.com → 내 개발정보 에서
/// 내 테스트 키를 받아서 바꿔 넣으면 돼요.
const String kTossClientKey = 'test_ck_D5GePWvyJnrK0W0k6q8gLzN97Eoq';

/// 결제 승인 서버 주소 (server/confirm_server.js 를 켜면 이 주소예요)
/// 시크릿 키가 필요한 "결제 승인"은 앱이 아니라 이 서버가 해요.
/// Firebase Functions 등에 올리면 그 주소로 바꿔요. (끝에 / 없이)
const String kPaymentServerUrl = 'http://localhost:3000';

/// true 로 바꾸면 토스 결제창을 안 띄우고 예전처럼 "흉내만" 내요.
/// (승인 서버를 켜기 귀찮을 때, 화면만 시연할 때)
const bool kUseMockPayment = false;

/// 결제창에 보이는 가게 이름
const String kStoreName = 'MEAL:ON';
