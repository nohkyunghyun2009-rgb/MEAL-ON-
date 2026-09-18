# MEAL:ON — 백마 학원가 학생 식당 예약 앱

제휴 식당 11곳 · 메뉴 353개가 들어있고, 메뉴를 골라서 **예약(날짜·시간·인원 + 예약금 모의 결제)** 까지 되는 Flutter 앱이에요.

## 실행 방법 (VS Code)

1. 이 폴더를 VS Code로 열어요 (`File → Open Folder`).
2. 처음 한 번만: VS Code 아래 터미널에서 `flutter pub get`
3. **F5** 누르기 (또는 `Run → Start Debugging`).
   → Chrome이 열리고 `http://localhost:8080` 에서 앱이 켜져요.

터미널로 켜려면:

```bash
flutter pub get
flutter run -d chrome --web-port 8080
```

## 화면 흐름

```
홈 ─┬─ [식당 예약] → 식당 목록 → 메뉴 고르기(+/−) → 날짜·시간·인원·이름 → 결제(모의) → 완료
    └─ [내 예약]   → 지금까지 한 예약 목록
```

## 폴더 구조

```
lib/
 ├─ main.dart                            ← 앱 시작 (F5 누르면 이게 실행돼요)
 ├─ main_reservation_demo.dart           ← 예약 화면만 따로 켜볼 때
 ├─ data/
 │   └─ restaurant_menu_data.dart        ← 식당·메뉴 데이터 (여기서 가격/메뉴 고쳐요)
 └─ screens/
     ├─ home_screen.dart                 ← 홈 (서비스 타일)
     └─ reservation/
         ├─ reservation_models.dart      ← 장바구니·예약 데이터 + 색상·예약금 설정
         ├─ restaurant_list_screen.dart  ← 식당 목록
         ├─ menu_order_screen.dart       ← 메뉴 고르기
         ├─ reservation_form_screen.dart ← 예약 정보 입력 + 결제
         └─ reservation_done_screen.dart ← 완료 / 내 예약
docs/
 ├─ README_설치방법.md                   ← 메뉴 데이터 검토 사항, 색 바꾸기 등 상세 설명
 └─ 메뉴목록_검토용.csv                  ← 메뉴 전체 목록 (엑셀로 열어서 대조)
```

## 자주 고치는 것

- **색 바꾸기** → `lib/screens/reservation/reservation_models.dart` 맨 위 `kBrandGreen`
- **예약금 바꾸기** → 같은 파일 `kDepositPerPerson`
- **메뉴/가격 고치기** → `lib/data/restaurant_menu_data.dart`

## 테스트

```bash
flutter test
```

## 안드로이드 / iOS 로도 켜고 싶으면

```bash
flutter create . --platforms android,ios
```

한 번 실행하면 `android/`, `ios/` 폴더가 생겨요.
