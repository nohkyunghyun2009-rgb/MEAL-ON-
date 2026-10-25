/// 배포할 때 GitHub Actions가 넣어주는 "이 앱이 언제 빌드됐는지" 표시
/// (홈 → 오른쪽 위 프로필 → 내 계정 에서 보여요. 새 버전이 떴는지 확인할 때 써요)
class BuildInfo {
  static const stamp = String.fromEnvironment('BUILD_STAMP', defaultValue: '개발용 빌드');
}
