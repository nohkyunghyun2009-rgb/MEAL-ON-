// 웹이 아닌 곳(flutter test 등)에서 쓰는 결제 통로 — 항상 모의 결제
import 'payment_gateway.dart';

PaymentGateway createGateway() => MockPaymentGateway();
