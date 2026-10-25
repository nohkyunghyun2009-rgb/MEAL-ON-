// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;

/// 웹 브라우저에서 글자를 파일로 만들어 "다운로드" 폴더로 내려보내요
Future<void> downloadTextFile(String filename, String content) async {
  // 엑셀이 한글을 안 깨뜨리게 맨 앞에 BOM(\uFEFF)을 붙여요
  final bytes = utf8.encode('\uFEFF$content');
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}

/// 폰의 "공유" 창(카톡·메모·메일·에어드롭…)을 띄워요. 지원 안 되는 브라우저(PC 등)면 false.
Future<bool> shareText(String title, String text) async {
  try {
    await html.window.navigator.share({'title': title, 'text': text});
    return true;
  } catch (_) {
    return false;
  }
}
