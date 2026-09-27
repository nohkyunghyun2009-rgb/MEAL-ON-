// ============================================================
// payment_result_screen.dart
// 토스 결제창에서 앱으로 돌아왔을 때 보이는 화면
//
// 1. 주소에 실려온 결과(성공/실패)를 받아요 (main.dart 가 넘겨줘요)
// 2. 성공이면 → 보관해둔 예약 내용을 꺼내고 → 승인 서버에 "승인해줘" →
//    승인되면 ReservationStore 에 저장하고 완료 화면으로 넘어가요
// 3. 실패/취소면 → 이유를 보여주고 홈으로 돌아가는 버튼
// ============================================================

import 'package:flutter/material.dart';

import '../../data/restaurant_menu_data.dart';
import '../../payment/payment_confirm_api.dart';
import '../../payment/payment_gateway.dart';
import '../../payment/pending_reservation.dart';
import '../reservation/reservation_done_screen.dart';
import '../reservation/reservation_models.dart';

class PaymentResultScreen extends StatefulWidget {
  final PaymentReturn result;
  const PaymentResultScreen({super.key, required this.result});

  @override
  State<PaymentResultScreen> createState() => _PaymentResultScreenState();
}

class _PaymentResultScreenState extends State<PaymentResultScreen> {
  bool _working = true;
  String _error = '';
  String _errorDetail = '';

  @override
  void initState() {
    super.initState();
    _process();
  }

  Future<void> _process() async {
    final gateway = PaymentGateway.instance;
    final r = widget.result;

    // 새로고침해도 다시 승인하지 않게 주소부터 정리
    gateway.clearReturn();

    if (!r.success) {
      gateway.clearPending();
      setState(() {
        _working = false;
        _error = r.isUserCancel ? '결제를 취소했어요' : '결제가 완료되지 않았어요';
        _errorDetail = r.isUserCancel ? '' : '${r.message} (${r.code})';
      });
      return;
    }

    // 결제창 가기 전에 보관해둔 예약 내용
    final pending = gateway.loadPending(r.orderId);
    if (pending == null) {
      setState(() {
        _working = false;
        _error = '예약 내용을 찾을 수 없어요';
        _errorDetail = '결제는 됐을 수 있어요. 예약번호 ${r.orderId} 를 알려주시면 확인해드릴게요.';
      });
      return;
    }
    // 금액이 바뀌었으면 승인하지 않아요 (주소창을 손댄 경우 등)
    if (pending.amount != r.amount) {
      gateway.clearPending();
      setState(() {
        _working = false;
        _error = '결제 금액이 맞지 않아요';
        _errorDetail = '예약금 ${formatWon(pending.amount)}원 / 결제 ${formatWon(r.amount)}원';
      });
      return;
    }

    // 승인 서버에 확인 요청 (시크릿 키는 서버에만 있어요)
    final ConfirmedPayment paid;
    try {
      paid = await confirmPayment(
        paymentKey: r.paymentKey,
        orderId: r.orderId,
        amount: r.amount,
      );
    } on PaymentConfirmException catch (e) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = '결제 승인에 실패했어요';
        _errorDetail = e.message;
      });
      return;
    }

    // 예약 저장
    final restaurant = findRestaurant(pending.restaurantId)!;
    final reservation = ReservationStore.instance.add(
      id: pending.orderId,
      restaurant: restaurant,
      visitAt: pending.visitAt,
      people: pending.people,
      customerName: pending.customerName,
      phone: pending.phone,
      memo: pending.memo,
      items: pending.items,
      paymentKey: paid.paymentKey,
      paymentMethod: paid.method.isEmpty ? '토스페이먼츠' : paid.method,
    );
    gateway.clearPending();

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ReservationDoneScreen(reservation: reservation),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: Text(_working ? '결제 확인 중' : '결제 결과'),
        backgroundColor: kBrandGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _working
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: kBrandGreen),
                    SizedBox(height: 20),
                    Text('결제를 확인하고 있어요…',
                        style: TextStyle(fontSize: 16, color: Colors.black54)),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 72, color: Colors.redAccent),
                    const SizedBox(height: 14),
                    Text(_error,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    if (_errorDetail.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(_errorDetail,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black54)),
                    ],
                    const SizedBox(height: 28),
                    SizedBox(
                      width: 220,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => Navigator.popUntil(
                            context, (route) => route.isFirst),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kBrandGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('홈으로',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
