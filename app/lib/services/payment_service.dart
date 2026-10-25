import 'dart:math';

/// ═══════════════════════════════════════════════════════════
///  결제 담당 (연습 모드)
///  - 실제 돈은 절대 안 나가요. 화면과 흐름만 진짜 결제와 똑같아요.
///  - 나중에 사업자등록을 하면 이 파일만 토스페이먼츠/카카오페이로
///    갈아끼우면 돼요. (다른 화면은 안 고쳐도 되게 만들었어요)
/// ═══════════════════════════════════════════════════════════

/// 결제가 끝나면 돌려주는 결과 쪽지
class PayResult {
  final String approvalNo; // 승인번호 (영수증에 찍히는 번호)
  final String cardLast4; // 카드번호 끝 4자리 (전체 번호는 절대 저장 금지!)
  final int amount; // 결제 금액
  final DateTime paidAt; // 결제 시각

  const PayResult({
    required this.approvalNo,
    required this.cardLast4,
    required this.amount,
    required this.paidAt,
  });
}

/// 결제 실패 이유를 담는 에러
class PayError implements Exception {
  final String message;
  const PayError(this.message);
  @override
  String toString() => message;
}

class PaymentService {
  /// 예약금: 한 명당 1,000원 (노쇼 방지용, 방문하면 음식값에서 빼줘요)
  static const int depositPerPerson = 1000;

  static int depositFor(int people) => depositPerPerson * people;

  /// ── 룬(Luhn) 알고리즘 ──
  /// 전 세계 카드사가 진짜로 쓰는 "카드번호 오타 검사법"이에요.
  /// 1) 오른쪽에서부터 두 번째 숫자마다 2를 곱하고
  /// 2) 곱해서 10이 넘으면 각 자리를 더하고 (예: 14 → 1+4=5)
  /// 3) 전부 더한 값이 10으로 나눠떨어지면 올바른 번호!
  /// 테스트 카드번호: 4242 4242 4242 4242 (통과됨)
  static bool luhnCheck(String digits) {
    if (digits.length < 13) return false;
    int sum = 0;
    bool doubleIt = false; // 오른쪽 끝은 그대로, 그 다음부터 하나 걸러 2배
    for (int i = digits.length - 1; i >= 0; i--) {
      int d = int.tryParse(digits[i]) ?? -1;
      if (d < 0) return false;
      if (doubleIt) {
        d *= 2;
        if (d > 9) d -= 9; // 14 → 1+4 는 14-9 와 같아요
      }
      sum += d;
      doubleIt = !doubleIt;
    }
    return sum % 10 == 0;
  }

  /// 유효기간(MM/YY)이 아직 안 지났는지 검사
  static bool expiryOk(String mmyy) {
    final parts = mmyy.split('/');
    if (parts.length != 2) return false;
    final mm = int.tryParse(parts[0]) ?? 0;
    final yy = int.tryParse(parts[1]) ?? -1;
    if (mm < 1 || mm > 12 || yy < 0) return false;
    final now = DateTime.now();
    final expiry = DateTime(2000 + yy, mm + 1); // 그 달의 마지막 날까지 유효
    return expiry.isAfter(now);
  }

  /// ── 간편 결제 (카드번호 입력 없음) ──
  /// 결제 수단을 고르고 버튼 한 번이면 끝. 1.2초 기다렸다가 승인번호를 돌려줘요.
  static Future<PayResult> payQuick({required int amount, required String cardLast4}) async {
    if (amount < 0) throw const PayError('금액이 이상해요');
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    final rnd = Random();
    return PayResult(
      approvalNo: List.generate(8, (_) => rnd.nextInt(10)).join(),
      cardLast4: cardLast4,
      amount: amount,
      paidAt: DateTime.now(),
    );
  }

  /// ── 모의 결제 (카드번호 직접 입력 버전 — 지금은 안 쓰지만 남겨둬요) ──
  /// 진짜 결제처럼 1.5초 기다렸다가 승인번호를 만들어 돌려줘요.
  static Future<PayResult> pay({
    required int amount,
    required String cardNumber, // 숫자만 (띄어쓰기 제거된 상태)
    required String expiry, // "MM/YY"
    required String cvc,
  }) async {
    // 1) 검사 먼저
    if (cardNumber.length != 16) {
      throw const PayError('카드번호 16자리를 다 적어주세요');
    }
    if (!luhnCheck(cardNumber)) {
      throw const PayError('카드번호가 올바르지 않아요 (테스트: 4242 4242 4242 4242)');
    }
    if (!expiryOk(expiry)) {
      throw const PayError('유효기간을 확인해주세요 (예: 12/28)');
    }
    if (cvc.length != 3) {
      throw const PayError('카드 뒷면의 CVC 3자리를 적어주세요');
    }

    // 2) 카드사에 물어보는 척 잠깐 기다리기
    await Future<void>.delayed(const Duration(milliseconds: 1500));

    // 3) 승인번호 만들기 (숫자 8자리)
    final rnd = Random();
    final approvalNo = List.generate(8, (_) => rnd.nextInt(10)).join();

    return PayResult(
      approvalNo: approvalNo,
      cardLast4: cardNumber.substring(12),
      amount: amount,
      paidAt: DateTime.now(),
    );
  }
}
