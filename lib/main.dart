// ============================================================
// main.dart
// MEAL:ON 앱 시작 파일
//
// VS Code에서 F5 (또는 실행 ▶ 버튼) 누르면 이 파일이 실행돼요.
// 터미널에서는:  flutter run -d chrome --web-port 8080
//
// 홈 화면에 "식당 예약" / "내 예약" 타일 2개가 있고,
// 누르면 screens/reservation/ 폴더의 예약 화면들로 이동해요.
//
// 결제: 토스 결제창에서 앱으로 돌아오면 주소에 ?payment=success&paymentKey=…
// 가 붙어있어요. 앱이 켜질 때 그걸 발견하면 PaymentResultScreen 을 띄워서
// 승인 → 예약 저장 → 완료 화면까지 이어가요.
// ============================================================

import 'package:flutter/material.dart';
import 'payment/payment_gateway.dart';
import 'screens/home_screen.dart';
import 'screens/payment/payment_result_screen.dart';
import 'screens/reservation/reservation_models.dart';

void main() {
  runApp(const MealOnApp());
}

class MealOnApp extends StatefulWidget {
  const MealOnApp({super.key});

  @override
  State<MealOnApp> createState() => _MealOnAppState();
}

class _MealOnAppState extends State<MealOnApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // 결제창에서 돌아온 거면, 홈 위에 결제 결과 화면을 올려요
    final ret = PaymentGateway.instance.readReturn();
    if (ret != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => PaymentResultScreen(result: ret)),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MEAL:ON',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: ThemeData(
        colorSchemeSeed: kBrandGreen,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F6F8),
      ),
      home: const HomeScreen(),
    );
  }
}
