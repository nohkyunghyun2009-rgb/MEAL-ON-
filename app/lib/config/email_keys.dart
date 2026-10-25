/// ─────────────────────────────────────────────────────────────
///  이메일 발송 키 (EmailJS) — 리포트를 진짜 메일로 보내려면 여기 채워요
///  https://www.emailjs.com 가입 → Email Services → Email Templates → Account
///  비워두면 앱은 "메일 앱 열기" 방식으로 자동 전환돼요 (연습 모드)
/// ─────────────────────────────────────────────────────────────
class EmailKeys {
  /// Email Services 탭에서 만든 서비스의 Service ID (예: service_abc123)
  static const String serviceId = '여기에-service-id';

  /// Email Templates 탭에서 만든 템플릿의 Template ID (예: template_xyz789)
  static const String templateId = '여기에-template-id';

  /// Account 탭 → General → Public Key
  static const String publicKey = '여기에-public-key';

  static bool get ready =>
      !serviceId.contains('여기에') && !templateId.contains('여기에') && !publicKey.contains('여기에');
}
