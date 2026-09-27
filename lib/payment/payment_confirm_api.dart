// ============================================================
// payment_confirm_api.dart
// 결제 승인 서버(server/confirm_server.js)에 "이 결제 승인해줘" 하고 묻는 부분
//
// 왜 앱이 직접 토스에 승인 요청을 안 하나요?
//   승인에는 시크릿 키가 필요한데, 앱(브라우저)에 넣으면 누구나 볼 수 있어요.
//   그래서 시크릿 키는 서버에만 두고, 앱은 서버에게 부탁만 해요.
// ============================================================

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/payment_config.dart';

/// 승인 결과
class ConfirmedPayment {
  final String paymentKey;
  final String orderId;
  final int totalAmount;
  final String method;     // 예: 카드, 간편결제
  final String approvedAt; // 승인 시각 (ISO 글자)

  const ConfirmedPayment({
    required this.paymentKey,
    required this.orderId,
    required this.totalAmount,
    required this.method,
    required this.approvedAt,
  });
}

class PaymentConfirmException implements Exception {
  final String message;
  const PaymentConfirmException(this.message);
  @override
  String toString() => message;
}

/// 승인 서버에 POST /confirm 요청. 실패하면 PaymentConfirmException
Future<ConfirmedPayment> confirmPayment({
  required String paymentKey,
  required String orderId,
  required int amount,
  http.Client? client,
}) async {
  final c = client ?? http.Client();
  final http.Response res;
  try {
    res = await c
        .post(
          Uri.parse('$kPaymentServerUrl/confirm'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'paymentKey': paymentKey,
            'orderId': orderId,
            'amount': amount,
          }),
        )
        .timeout(const Duration(seconds: 20));
  } catch (e) {
    throw const PaymentConfirmException(
      '결제 승인 서버에 연결할 수 없어요.\n'
      'server 폴더에서 `npm start` 로 서버를 켰는지 확인해주세요.',
    );
  } finally {
    if (client == null) c.close();
  }

  final Map<String, dynamic> body;
  try {
    body = jsonDecode(res.body) as Map<String, dynamic>;
  } catch (_) {
    throw PaymentConfirmException('서버 응답을 읽을 수 없어요 (${res.statusCode})');
  }

  if (res.statusCode != 200 || body['ok'] != true) {
    throw PaymentConfirmException(
        body['message']?.toString() ?? '결제 승인에 실패했어요 (${res.statusCode})');
  }

  final p = body['payment'] as Map<String, dynamic>;
  return ConfirmedPayment(
    paymentKey: p['paymentKey'] as String,
    orderId: p['orderId'] as String,
    totalAmount: (p['totalAmount'] as num).toInt(),
    method: p['method']?.toString() ?? '',
    approvedAt: p['approvedAt']?.toString() ?? '',
  );
}
