// ============================================================
// main_reservation_demo.dart
// 예약 기능만 따로 실행해보고 싶을 때 쓰는 "시험용 시작 파일"
//
// 실행 방법 (터미널에서, hankki 폴더 안에서):
//   flutter run -t lib/main_reservation_demo.dart
//
// 진짜 앱(main.dart)에 붙일 때는 이 파일은 필요 없고,
// 홈 화면의 버튼에서 RestaurantListScreen 으로 이동만 시키면 돼요:
//
//   Navigator.push(
//     context,
//     MaterialPageRoute(builder: (_) => const RestaurantListScreen()),
//   );
// ============================================================

import 'package:flutter/material.dart';
import 'screens/reservation/reservation_models.dart';
import 'screens/reservation/restaurant_list_screen.dart';

void main() {
  runApp(const ReservationDemoApp());
}

class ReservationDemoApp extends StatelessWidget {
  const ReservationDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MEAL:ON 예약 데모',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: kBrandGreen,
        useMaterial3: true,
        fontFamily: null, // 앱에 폰트가 있으면 여기에 이름 적기
      ),
      home: const RestaurantListScreen(),
    );
  }
}
