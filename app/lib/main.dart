import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'screens/body_input_screen.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/coupon_service.dart';
import 'services/reservation_service.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'widgets/app_icon.dart';

/// 앱이 켜지면 제일 먼저 실행되는 곳
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Firebase 연결 시도. 아직 설정 안 했으면 "연습 모드"로 켜요.
  bool firebaseReady = false;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    firebaseReady = true;
  } catch (e) {
    debugPrint('Firebase 없이 연습 모드로 시작해요: $e');
  }

  // 2) 폰에 저장된 것 불러오기
  final appState = AppState();
  await appState.load();

  // Firebase는 됐는데 Firestore(예약 장부)를 아직 안 만들었으면 예약만 연습 모드로
  bool firestoreReady = firebaseReady;
  if (firebaseReady) {
    try {
      await FirebaseFirestore.instance.collection('reservations').limit(1).get().timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('Firestore가 아직 없어서 예약은 연습 모드로: $e');
      firestoreReady = false;
    }
  }
  final reservations = ReservationService.create(useFirebase: firestoreReady);
  await reservations.init();

  final auth = AuthService.create(useFirebase: firebaseReady);
  await auth.init();

  final coupons = CouponService();
  await coupons.init();

  // 3) 앱 시작! (기억 상자 세 개를 모든 화면에 나눠줘요)
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: appState),
        ChangeNotifierProvider<ReservationService>.value(value: reservations),
        ChangeNotifierProvider<AuthService>.value(value: auth),
        ChangeNotifierProvider<CouponService>.value(value: coupons),
      ],
      child: const MealOnApp(),
    ),
  );
}

class MealOnApp extends StatelessWidget {
  const MealOnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MEAL:ON',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      // PC·태블릿처럼 넓은 화면에서는 가운데 폰 폭으로 모아서 보여줘요 (폰에서는 그대로)
      builder: (context, child) => PhoneFrame(child: child ?? const SizedBox.shrink()),
      home: const RootGate(),
    );
  }
}

/// "교통정리" 화면: 상황 보고 어디로 보낼지 정해요
///  - 로그인 안 했으면  → 로그인 화면
///  - 로그인했는데 인바디가 없으면 → 인바디 입력 (처음 한 번)
///  - 둘 다 있으면 → 바로 홈 (Grab처럼 켜자마자 타일 화면)
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  /// 로그인/로그아웃 뒤에 이 화면으로 싹 돌아오게 하는 도우미
  static void restart(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RootGate()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = context.watch<AuthService>().isSignedIn;
    final hasProfile = context.watch<AppState>().hasProfile;

    if (!signedIn) return LoginScreen(onDone: () => restart(context));
    if (!hasProfile) return const BodyInputScreen();
    return const HomeShell();
  }
}
