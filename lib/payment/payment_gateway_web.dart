// ============================================================
// payment_gateway_web.dart
// 웹(Chrome)용 결제 통로 — 토스페이먼츠 결제창(v1 SDK)을 띄워요.
//
// web/index.html 에 넣어둔 <script src="https://js.tosspayments.com/v1/payment">
// 가 만들어주는 자바스크립트 TossPayments 객체를 Dart에서 불러 써요.
// ============================================================

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import '../config/payment_config.dart';
import 'payment_gateway.dart';
import 'pending_reservation.dart';

PaymentGateway createGateway() => TossWebPaymentGateway();

// ---------- 자바스크립트 TossPayments 객체와 연결 ----------

@JS('TossPayments')
external _JSTossPayments _tossPayments(String clientKey);

extension type _JSTossPayments._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> requestPayment(String method, JSObject options);
}

/// 브라우저 저장소(localStorage)에 "결제 중인 예약"을 넣을 때 쓰는 이름
const String _pendingKey = 'mealon.pendingReservation';

class TossWebPaymentGateway extends PaymentGateway {
  @override
  bool get isReal => true;

  @override
  Future<void> requestPayment(PendingReservation pending) async {
    final restaurant = findRestaurant(pending.restaurantId);

    // 1) 입력 내용 보관 (결제창 갔다 오면 페이지가 새로 켜지니까)
    web.window.localStorage.setItem(_pendingKey, pending.encode());

    // 2) 결제 끝나고 돌아올 주소 = 지금 앱 주소 + ?payment=success / fail
    //    토스가 뒤에 &paymentKey=…&orderId=…&amount=… 를 붙여서 보내줘요.
    final here = _appBaseUrl();

    final options = <String, Object?>{
      'amount': pending.amount,
      'orderId': pending.orderId,
      'orderName': restaurant == null
          ? '$kStoreName 예약금'
          : pending.orderNameFor(restaurant),
      'customerName': pending.customerName,
      'successUrl': '$here?payment=success',
      'failUrl': '$here?payment=fail',
    }.jsify() as JSObject;

    // 3) 결제창 열기. 성공하면 successUrl 로 페이지가 바뀌어서 여기로 안 돌아와요.
    //    사용자가 창을 닫으면 에러(USER_CANCEL)가 나서 여기로 돌아와요.
    try {
      await _tossPayments(kTossClientKey).requestPayment('카드', options).toDart;
    } catch (e) {
      clearPending();
      if (e case final JSObject err) {
        final code = err['code']?.dartify()?.toString() ?? '';
        final message = err['message']?.dartify()?.toString() ?? '$e';
        throw PaymentException(code, message);
      }
      throw PaymentException('', '$e');
    }
  }

  @override
  PaymentReturn? readReturn() => PaymentReturn.fromUri(Uri.base);

  @override
  void clearReturn() {
    // 주소창에서 ?payment=…&paymentKey=… 를 지워요 (새로고침해도 다시 처리 안 하게)
    web.window.history.replaceState(null, '', _appBaseUrl());
  }

  /// 지금 앱 주소에서 ?query 와 #fragment 를 뗀 것: "http://localhost:8080/"
  static String _appBaseUrl() => '${Uri.base.origin}${Uri.base.path}';

  @override
  PendingReservation? loadPending(String orderId) {
    final raw = web.window.localStorage.getItem(_pendingKey);
    if (raw == null) return null;
    final p = PendingReservation.decode(raw);
    if (p == null || p.orderId != orderId) return null;
    return p;
  }

  @override
  void clearPending() => web.window.localStorage.removeItem(_pendingKey);
}
