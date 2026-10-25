import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/reservation.dart';

/// 예약을 저장하고 불러오는 "예약 장부"
///
/// 두 가지 버전이 있어요.
///  - FirestoreReservationService : 인터넷(Firebase)에 저장 → 사장님 폰에서도 보여요 (진짜 모드)
///  - LocalReservationService     : 내 폰에만 저장 → Firebase 설정 전에 연습용 (연습 모드)
/// 화면 코드는 둘 중 뭐가 켜졌는지 몰라도 똑같이 동작해요.
abstract class ReservationService extends ChangeNotifier {
  ReservationService();

  factory ReservationService.create({required bool useFirebase}) =>
      useFirebase ? FirestoreReservationService() : LocalReservationService();

  List<Reservation> get all;
  bool get isOnline;

  Future<void> init();

  Future<Reservation> create({
    required String restaurantId,
    required String restaurantName,
    required String restaurantAddress,
    required String userNickname,
    required DateTime visitAt,
    required int people,
    required String note,
    int deposit = 0, // 카드로 낸 예약금
    String cardLast4 = '', // 결제한 카드 끝 4자리
    List<OrderLine> order = const [], // 미리 주문한 메뉴
  });

  Future<void> updateStatus(String id, ReservationStatus status, {int? paidAmount});

  // ───── 공통 도우미 ─────
  List<Reservation> forUser(String nickname) =>
      all.where((r) => r.userNickname == nickname).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<Reservation> forRestaurant(String name) =>
      all.where((r) => r.restaurantName.trim() == name.trim()).toList()
        ..sort((a, b) => a.visitAt.compareTo(b.visitAt));

  /// 취소하면 예약금을 돌려줘야 하는지 알려주는 도우미
  /// (돈을 냈던 예약이면 → 환불됨으로 바꿔요)
  PayStatus refundOnCancel(Reservation r, ReservationStatus newStatus) {
    if (newStatus == ReservationStatus.cancelled && r.payStatus == PayStatus.paid) {
      return PayStatus.refunded;
    }
    return r.payStatus;
  }

  /// 헷갈리는 글자(0, O, 1, I)를 뺀 4자리 예약번호 만들기
  static String makeCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random();
    return List.generate(4, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  Reservation buildNew({
    required String restaurantId,
    required String restaurantName,
    required String restaurantAddress,
    required String userNickname,
    required DateTime visitAt,
    required int people,
    required String note,
    int deposit = 0,
    String cardLast4 = '',
    List<OrderLine> order = const [],
  }) =>
      Reservation(
        id: '',
        code: makeCode(),
        restaurantId: restaurantId,
        restaurantName: restaurantName,
        restaurantAddress: restaurantAddress,
        userNickname: userNickname,
        visitAt: visitAt,
        people: people,
        note: note,
        status: ReservationStatus.pending,
        createdAt: DateTime.now(),
        deposit: deposit,
        cardLast4: cardLast4,
        payStatus: deposit > 0 ? PayStatus.paid : PayStatus.none,
        order: order,
      );
}

// ═══════════════════════════════════════════════════════════
//  진짜 모드: Firebase Firestore
// ═══════════════════════════════════════════════════════════
class FirestoreReservationService extends ReservationService {
  final _col = FirebaseFirestore.instance.collection('reservations');
  List<Reservation> _all = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  @override
  List<Reservation> get all => _all;

  @override
  bool get isOnline => true;

  @override
  Future<void> init() async {
    // 장부가 바뀔 때마다(누가 예약하거나 사장님이 확인하면) 자동으로 새로 받아와요
    _sub = _col.orderBy('createdAt', descending: true).snapshots().listen((snap) {
      _all = snap.docs.map((d) => Reservation.fromMap(d.id, d.data())).toList();
      notifyListeners();
    });
  }

  @override
  Future<Reservation> create({
    required String restaurantId,
    required String restaurantName,
    required String restaurantAddress,
    required String userNickname,
    required DateTime visitAt,
    required int people,
    required String note,
    int deposit = 0,
    String cardLast4 = '',
    List<OrderLine> order = const [],
  }) async {
    final r = buildNew(
      restaurantId: restaurantId,
      restaurantName: restaurantName,
      restaurantAddress: restaurantAddress,
      userNickname: userNickname,
      visitAt: visitAt,
      people: people,
      note: note,
      deposit: deposit,
      cardLast4: cardLast4,
      order: order,
    );
    final doc = await _col.add(r.toMap());
    return r.copyWith(id: doc.id);
  }

  @override
  Future<void> updateStatus(String id, ReservationStatus status, {int? paidAmount}) async {
    // 취소인데 예약금을 냈던 예약이면 → 환불됨으로 같이 바꿔요
    final current = _all.where((r) => r.id == id).firstOrNull;
    final newPay = current == null ? null : refundOnCancel(current, status);
    await _col.doc(id).update({
      'status': status.name,
      if (paidAmount != null) 'paidAmount': paidAmount,
      if (newPay != null) 'payStatus': newPay.name,
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

// ═══════════════════════════════════════════════════════════
//  연습 모드: 내 폰에만 저장
// ═══════════════════════════════════════════════════════════
class LocalReservationService extends ReservationService {
  static const _key = 'local_reservations';
  List<Reservation> _all = [];

  @override
  List<Reservation> get all => _all;

  @override
  bool get isOnline => false;

  @override
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      final list = jsonDecode(raw) as List<dynamic>;
      _all = list.map((x) {
        final m = x as Map<String, dynamic>;
        return Reservation.fromMap(m['id'] as String, m);
      }).toList();
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _all.map((r) => {'id': r.id, ...r.toMap()}).toList();
    await prefs.setString(_key, jsonEncode(list));
  }

  @override
  Future<Reservation> create({
    required String restaurantId,
    required String restaurantName,
    required String restaurantAddress,
    required String userNickname,
    required DateTime visitAt,
    required int people,
    required String note,
    int deposit = 0,
    String cardLast4 = '',
    List<OrderLine> order = const [],
  }) async {
    final r = buildNew(
      restaurantId: restaurantId,
      restaurantName: restaurantName,
      restaurantAddress: restaurantAddress,
      userNickname: userNickname,
      visitAt: visitAt,
      people: people,
      note: note,
      deposit: deposit,
      cardLast4: cardLast4,
      order: order,
    ).copyWith(id: DateTime.now().microsecondsSinceEpoch.toString());
    _all.insert(0, r);
    notifyListeners();
    await _save();
    return r;
  }

  @override
  Future<void> updateStatus(String id, ReservationStatus status, {int? paidAmount}) async {
    _all = _all.map((r) {
      if (r.id != id) return r;
      return r.copyWith(status: status, paidAmount: paidAmount, payStatus: refundOnCancel(r, status));
    }).toList();
    notifyListeners();
    await _save();
  }
}
