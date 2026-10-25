import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../config/email_keys.dart';
import '../models/body_profile.dart';
import '../models/nutrition.dart';
import 'download/download_stub.dart' if (dart.library.html) 'download/download_web.dart';

/// ═══════════════════════════════════════════════════════════
///  리포트를 "표"로 정리해서 ① 이메일로 보내거나 ② CSV 파일로 내려받게 해요
///  - EmailKeys가 채워져 있으면 → EmailJS로 진짜 발송
///  - 비어 있으면 → 내 메일 앱을 열고 본문을 채워줘요 (연습 모드)
/// ═══════════════════════════════════════════════════════════
class ReportMailer {
  static bool _ok(String v) => v.trim().isNotEmpty && !v.contains('여기에');

  /// 아직 안 채운 EmailJS 키 이름들 (모두 채웠으면 빈 목록)
  static List<String> get missingKeys => [
        if (!_ok(EmailKeys.serviceId)) 'Service ID',
        if (!_ok(EmailKeys.templateId)) 'Template ID',
        if (!_ok(EmailKeys.publicKey)) 'Public Key',
      ];

  static bool get realSend => missingKeys.isEmpty;

  /// 표의 한 줄: (항목, 값)
  static List<(String, String)> rows(BodyProfile p) {
    final a = p.analysis;
    final t = NutritionTargets.forProfile(p);
    final d = p.measuredAt;
    return [
      ('측정일', '${d.year}-${_2(d.month)}-${_2(d.day)} ${_2(d.hour)}:${_2(d.minute)}'),
      ('닉네임', p.nickname),
      ('성별 / 나이', '${p.isMale ? '남' : '여'} / ${p.age}세'),
      ('키', '${p.heightCm} cm'),
      ('몸무게', '${p.weightKg} kg (적정 ${a.idealWeightKg.toStringAsFixed(1)} kg)'),
      ('BMI', '${p.bmi.toStringAsFixed(1)} · 또래 ${a.bmiPercentile.round()}번째 (${a.bmiCategory})'),
      ('체지방률', '${p.bodyFatPercent} % (${a.fatJudge})'),
      ('체지방량', '${p.fatMassKg.toStringAsFixed(1)} kg · 표준 대비 ${a.bars[2].percent.round()}%'),
      ('골격근량', '${p.skeletalMuscleKg} kg · 표준 대비 ${a.bars[1].percent.round()}% (${a.bars[1].judge})'),
      ('골격근 비율', '${a.smmRatioPercent.toStringAsFixed(0)} %'),
      ('체수분', p.bodyWaterPercent == null ? '-' : '${p.bodyWaterPercent} % (${a.waterJudge})'),
      ('기초대사량', p.basalMetabolicRate == null ? '-' : '${p.basalMetabolicRate!.round()} kcal'),
      ('체형 판정', '${a.shape.label} · ${a.shape.title}'),
      ('활동량', p.activity.label),
      ('하루 권장 에너지', '${t.kcal.round()} kcal'),
      ('하루 권장 탄수화물', '${t.carbG.round()} g'),
      ('하루 권장 단백질', '${t.proteinG.round()} g'),
      ('하루 권장 지방', '${t.fatG.round()} g'),
      ('나트륨 상한', '${t.sodiumMg.round()} mg'),
    ];
  }

  static String _2(int n) => n.toString().padLeft(2, '0');

  /// 글자 표 (메일 앱 본문용)
  static String asText(BodyProfile p) {
    final buf = StringBuffer('[MEAL:ON] ${p.nickname}님의 몸 리포트\n\n');
    for (final (k, v) in rows(p)) {
      buf.writeln('$k: $v');
    }
    buf.writeln('\n체형 조언: ${p.analysis.shape.advice}');
    buf.writeln('\n※ 참고용 리포트예요. 걱정되는 게 있으면 보건 선생님이나 병원에 이야기해요.');
    return buf.toString();
  }

  /// HTML 표 (EmailJS 발송용 — 메일에서 예쁜 표로 보여요)
  static String asHtml(BodyProfile p) {
    final tr = rows(p)
        .map((r) => '<tr><td style="padding:8px 12px;border:1px solid #e5e7eb;color:#6b7280">${r.$1}</td>'
            '<td style="padding:8px 12px;border:1px solid #e5e7eb;font-weight:700">${r.$2}</td></tr>')
        .join();
    return '''
<div style="font-family:-apple-system,Helvetica,Arial,sans-serif;max-width:560px">
  <div style="display:inline-block;background:#1f1f24;color:#fff;font-weight:900;padding:6px 14px;border-radius:999px;letter-spacing:1px">MEAL:ON</div>
  <h2 style="margin:14px 0 4px">${p.nickname}님의 몸 리포트</h2>
  <p style="color:#6b7280;margin:0 0 14px">나에게 맞는 한 끼를 켜다</p>
  <table style="border-collapse:collapse;width:100%">$tr</table>
  <div style="margin-top:16px;padding:14px;background:#e6f7ec;border-radius:12px">
    <b>체형 조언</b><br>${p.analysis.shape.advice}
  </div>
  <p style="color:#9ca3af;font-size:12px;margin-top:16px">참고용 리포트예요. 걱정되는 게 있으면 보건 선생님이나 병원에 이야기해요.</p>
</div>''';
  }

  /// CSV (엑셀 시트) — 측정 기록 전부, 한 줄에 한 번 측정
  static String asCsv(List<BodyProfile> history) {
    const header = ['측정일', '닉네임', '성별', '나이', '키(cm)', '몸무게(kg)', '체지방률(%)', '체지방량(kg)', '골격근량(kg)', '골격근비율(%)', '체수분(%)', '기초대사량(kcal)', 'BMI', '또래백분위', 'BMI판정', '체형', '적정체중(kg)', '권장에너지(kcal)', '권장단백질(g)'];
    final lines = [header.join(',')];
    for (final p in history) {
      final a = p.analysis;
      final t = NutritionTargets.forProfile(p);
      final d = p.measuredAt;
      lines.add([
        '${d.year}-${_2(d.month)}-${_2(d.day)} ${_2(d.hour)}:${_2(d.minute)}',
        p.nickname,
        p.isMale ? '남' : '여',
        p.age,
        p.heightCm,
        p.weightKg,
        p.bodyFatPercent,
        p.fatMassKg.toStringAsFixed(1),
        p.skeletalMuscleKg,
        a.smmRatioPercent.toStringAsFixed(1),
        p.bodyWaterPercent ?? '',
        p.basalMetabolicRate?.round() ?? '',
        p.bmi.toStringAsFixed(1),
        a.bmiPercentile.round(),
        a.bmiCategory,
        a.shape.label,
        a.idealWeightKg.toStringAsFixed(1),
        t.kcal.round(),
        t.proteinG.round(),
      ].map((v) => '"$v"').join(','));
    }
    return lines.join('\n');
  }

  // ─────────────────────────────────────────────────────────
  //  ① 이메일 보내기
  // ─────────────────────────────────────────────────────────

  /// 진짜 발송 (EmailJS). 실패하면 이유를 사람 말로 담아 Exception을 던져요
  static Future<void> sendWithEmailJs({required String toEmail, required BodyProfile p}) async {
    final missing = missingKeys;
    if (missing.isNotEmpty) {
      throw Exception('lib/config/email_keys.dart 에 ${missing.join(', ')} 이(가) 아직 비어 있어요');
    }
    final http.Response res;
    try {
      res = await http
          .post(
            Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'service_id': EmailKeys.serviceId.trim(),
              'template_id': EmailKeys.templateId.trim(),
              'user_id': EmailKeys.publicKey.trim(),
              'template_params': {
                // ① 우리 템플릿용: "To Email" 칸에 {{to_email}} 을 넣으면 로그인한 사람에게 가요
                'to_email': toEmail,
                'to_name': p.nickname,
                'reply_to': toEmail,
                'subject': '[MEAL:ON] ${p.nickname}님의 몸 리포트',
                'message_html': asHtml(p),
                'message_text': asText(p),
                // ② EmailJS 가입 때 자동으로 생기는 기본 템플릿("Contact Us")용 — 템플릿을 안 고쳐도 돼요
                //    (단, 기본 템플릿은 가입한 지메일로 가요. 다른 사람에게 보내려면 ①처럼 To Email을 바꿔야 해요)
                'name': 'MEAL:ON · ${p.nickname}',
                'email': toEmail,
                'title': '[MEAL:ON] ${p.nickname}님의 몸 리포트',
                'message': asText(p),
                'time': DateTime.now().toString().substring(0, 16),
              },
            }),
          )
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      throw Exception('메일 서버에 연결을 못 했어요 (인터넷·광고차단 확장 확인): $e');
    }
    if (res.statusCode == 200) return;

    // EmailJS가 돌려주는 에러를 사람 말로
    final body = res.body.toLowerCase();
    String why;
    if (body.contains('service id')) {
      why = 'Service ID가 틀렸어요 (EmailJS → Email Services 에서 복사)';
    } else if (body.contains('template id')) {
      why = 'Template ID가 틀렸어요 (EmailJS → Email Templates 에서 복사)';
    } else if (body.contains('public key') || body.contains('user id') || body.contains('user_id')) {
      why = 'Public Key가 틀렸어요 (EmailJS → Account → General 에서 복사)';
    } else if (body.contains('recipients') || body.contains('to_email') || body.contains('recipient')) {
      why = '템플릿의 "To Email" 칸이 비어 있어요 → EmailJS 템플릿 Settings 에서 To Email 에 {{to_email}} 을 넣어요';
    } else if (body.contains('quota') || body.contains('limit')) {
      why = '이번 달 무료 발송 200통을 다 썼어요';
    } else if (res.statusCode == 403) {
      why = '접근이 막혔어요 (EmailJS → Account → Security 에서 "API Calls" 허용 확인)';
    } else {
      why = '메일 서비스 응답 ${res.statusCode}';
    }
    throw Exception('$why · 원문: ${res.body}');
  }

  /// 연습 모드: 내 메일 앱을 열고 받는 사람·제목·본문을 채워줘요
  static Future<void> openMailApp({required String toEmail, required BodyProfile p}) async {
    final uri = Uri(
      scheme: 'mailto',
      path: toEmail,
      query: _encodeQuery({
        'subject': '[MEAL:ON] ${p.nickname}님의 몸 리포트',
        'body': asText(p),
      }),
    );
    if (!await launchUrl(uri)) {
      throw Exception('메일 앱을 열 수 없어요');
    }
  }

  static String _encodeQuery(Map<String, String> params) =>
      params.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&');

  // ─────────────────────────────────────────────────────────
  //  ② CSV 다운로드
  // ─────────────────────────────────────────────────────────
  static Future<void> downloadCsv(List<BodyProfile> history) async {
    final d = DateTime.now();
    await downloadTextFile('mealon_report_${d.year}${_2(d.month)}${_2(d.day)}.csv', asCsv(history));
  }
}
