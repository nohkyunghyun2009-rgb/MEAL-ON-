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
 │   ├─ restaurant_menu_data.dart        ← 식당·메뉴 데이터 (여기서 가격/메뉴 고쳐요)
 │   └─ promo_banner_data.dart           ← 홈 배너 내용 (문구·사진·색)
 ├─ widgets/
 │   └─ restaurant_promo_banner.dart     ← 홈 배너 (자동 슬라이드 광고)
 └─ screens/
     ├─ home_screen.dart                 ← 홈 (서비스 타일 + 배너)
     └─ reservation/
         ├─ reservation_models.dart      ← 장바구니·예약 데이터 + 색상·예약금 설정
         ├─ restaurant_list_screen.dart  ← 식당 목록
         ├─ menu_order_screen.dart       ← 메뉴 고르기
         ├─ reservation_form_screen.dart ← 예약 정보 입력 + 결제
         └─ reservation_done_screen.dart ← 완료 / 내 예약
assets/
 └─ banners/                             ← 식당 간판 사진 넣는 곳
docs/
 ├─ README_설치방법.md                   ← 메뉴 데이터 검토 사항, 색 바꾸기 등 상세 설명
 └─ 메뉴목록_검토용.csv                  ← 메뉴 전체 목록 (엑셀로 열어서 대조)
```

## 홈 화면 "제휴 식당 간판 홍보 배너"

홈 화면 서비스 타일 아래에 식당 광고 배너가 4초마다 자동으로 넘어가요. 누르면 그 식당의 메뉴·예약 화면으로 가요.

- **배너 문구·순서 바꾸기** → `lib/data/promo_banner_data.dart` 의 `promoBanners` 리스트
- **간판 사진 넣기** → 사진 파일을 `assets/banners/` 폴더에 넣고, 배너의 `image: 'assets/banners/파일이름.jpg'` 로 적어요
  (인터넷 주소도 돼요: `image: 'https://...'`). 사진이 없으면 `color:` 색 배경으로 나와요.
- **배너 추가** → `PromoBanner(...)` 덩어리를 복사해서 붙이고 `restaurantId` 를 식당 id로 바꿔요
  (식당 id는 `lib/data/restaurant_menu_data.dart` 에서 `id: '...'` 를 찾으면 돼요)

### 원래 만들어둔 앱(다른 홈 화면)에 이 배너를 붙이려면

1. 이 저장소의 파일 2개를 그 앱의 같은 위치로 복사해요:
   - `lib/widgets/restaurant_promo_banner.dart` → 그 앱의 `lib/widgets/` (폴더 없으면 만들기)
   - `lib/data/promo_banner_data.dart` → 그 앱의 `lib/data/`
2. 그 앱의 `pubspec.yaml` 에서 `flutter:` 아래에 추가하고, `assets/banners/` 폴더를 만들어요:
   ```yaml
   flutter:
     uses-material-design: true
     assets:
       - assets/banners/
   ```
3. 홈 화면 파일에 2줄 추가:
   ```dart
   import '../widgets/restaurant_promo_banner.dart';   // 파일 맨 위 import 들 옆에

   const RestaurantPromoBanner(),                      // 배너가 나올 자리 (예: 서비스 타일 바로 아래)
   ```
4. 터미널에서 `flutter pub get` 한 번 실행 → 다시 켜면 배너가 나와요.

> 배너 파일은 `data/restaurant_menu_data.dart` 와 `screens/reservation/menu_order_screen.dart` 를 사용해요.
> 그 앱에 예약 기능(zip으로 받은 `screens/reservation` 폴더)이 이미 들어있어야 해요.

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
