/// 폰(iOS/Android)에서는 파일 다운로드 대신 "공유"로 처리해요. (아직은 안내만)
Future<void> downloadTextFile(String filename, String content) async {
  throw UnsupportedError('폰에서는 곧 지원돼요. 지금은 웹 브라우저에서 다운로드해 주세요.');
}
