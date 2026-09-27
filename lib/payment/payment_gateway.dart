// ============================================================
// payment_gateway.dart
// 결제 통로 — 앱의 다른 부분은 이 파일만 알면 돼요.
//
// ▶ 웹(Chrome)에서 실행:  payment_gateway_web.dart  → 토스페이먼츠 결제창
// ▶ 그 외(테스트 등):     payment_gateway_stub.dart → 흉내(모의) 결제
// ▶ kUseMockPayment = true 면 웹에서도 흉내 결제
//
// 흐름:
//   1. requestPayment()  : 입력 내용을 보관하고 토스 결제창으로 이동
//      (페이지가 통째로 바뀌므로 이 함수는 보통 "돌아오지 않아요")
//   2. 결제가 끝나면 토스가 앱 주소로 다시 보내줘요 (?payment=success&paymentKey=…)
//   3. readReturn()      : 그 주소에서 결제 결과를 읽어요 (main.dart 가 앱 켜질 때 호출)
//   4. PaymentResultScreen 이 승인 서버에 확인 요청 → 예약 저장
// ============================================================

import '../config/payment_config.dart';
import 'pending_reservation.dart';
import 'payment_gateway_stub.dart'
    if (dart.library.js_interop) 'payment_gateway_web.dart' as impl;

/// 결제창에서 돌아왔을 때 주소에 실려온 결과
class PaymentReturn {
  final bool success;
  final String orderId;
  final String paymentKey; // 성공일 때만
  final int amount;        // 성공일 때만
  final String code;       // 실패일 때만 (예: PAY_PROCESS_CANCELED)
  final String message;    // 실패일 때만

  const PaymentReturn.success({
    required this.orderId,
    required this.paymentKey,
    required this.amount,
  })  : success = true,
        code = '',
        message = '';

  const PaymentReturn.failure({
    required this.orderId,
    required this.code,
    required this.message,
  })  : success = false,
        paymentKey = '',
        amount = 0;

  /// 사용자가 결제창을 직접 닫은 경우
  bool get isUserCancel =>
      code == 'PAY_PROCESS_CANCELED' || code == 'USER_CANCEL';

  /// 앱 주소(query)에서 결과 읽기. 결제에서 돌아온 게 아니면 null
  static PaymentReturn? fromUri(Uri uri) {
    final q = uri.queryParameters;
    final kind = q['payment'];
    if (kind == 'success' && q['paymentKey'] != null) {
      return PaymentReturn.success(
        orderId: q['orderId'] ?? '',
        paymentKey: q['paymentKey']!,
        amount: int.tryParse(q['amount'] ?? '') ?? 0,
      );
    }
    if (kind == 'fail') {
      return PaymentReturn.failure(
        orderId: q['orderId'] ?? '',
        code: q['code'] ?? '',
        message: q['message'] ?? '결제가 취소되었어요',
      );
    }
    return null;
  }
}

/// 결제창을 띄우다 실패했을 때 (예: 사용자가 창을 닫음)
class PaymentException implements Exception {
  final String code;
  final String message;
  const PaymentException(this.code, this.message);

  bool get isUserCancel => code == 'USER_CANCEL' || code == 'PAY_PROCESS_CANCELED';

  @override
  String toString() => message;
}

abstract class PaymentGateway {
  /// 지금 쓰는 결제 통로 (웹 + 실제 키면 토스, 아니면 모의)
  static final PaymentGateway instance =
      kUseMockPayment ? MockPaymentGateway() : impl.createGateway();

  /// 진짜 결제창(토스)을 쓰는지. 모의 결제면 false
  bool get isReal;

  /// 입력 내용을 보관하고 결제창으로 이동해요.
  /// 모의 결제면 잠깐 기다렸다가 그냥 돌아와요.
  Future<void> requestPayment(PendingReservation pending);

  /// 앱이 켜질 때 주소에 결제 결과가 실려있는지 확인 (없으면 null)
  PaymentReturn? readReturn();

  /// 결제 결과를 주소에서 지워요 (새로고침해도 다시 처리하지 않게)
  void clearReturn();

  /// 보관해둔 "결제 중인 예약" 꺼내기 (없으면 null)
  PendingReservation? loadPending(String orderId);

  /// 보관해둔 "결제 중인 예약" 지우기
  void clearPending();
}

/// 흉내(모의) 결제 — 결제창 없이 1.2초 기다리고 끝
class MockPaymentGateway extends PaymentGateway {
  @override
  bool get isReal => false;

  @override
  Future<void> requestPayment(PendingReservation pending) =>
      Future.delayed(const Duration(milliseconds: 1200));

  @override
  PaymentReturn? readReturn() => null;

  @override
  void clearReturn() {}

  @override
  PendingReservation? loadPending(String orderId) => null;

  @override
  void clearPending() {}
}
