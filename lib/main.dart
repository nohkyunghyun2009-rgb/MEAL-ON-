// ============================================================
// main.dart
// MEAL:ON 앱 시작 파일
//
// VS Code에서 F5 (또는 실행 ▶ 버튼) 누르면 이 파일이 실행돼요.
// 터미널에서는:  flutter run -d chrome --web-port 8080
//
// 홈 화면에 "식당 예약" / "내 예약" 타일 2개가 있고,
// 누르면 screens/reservation/ 폴더의 예약 화면들로 이동해요.
// ============================================================

import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/reservation/reservation_models.dart';

void main() {
  runApp(const MealOnApp());
}

class MealOnApp extends StatelessWidget {
  const MealOnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MEAL:ON',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: kBrandGreen,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F6F8),
      ),
      home: const HomeScreen(),
    );
  }
}
