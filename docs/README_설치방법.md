# MEAL:ON 제휴 식당 메뉴 + 예약 기능 — 설치 방법

메뉴판 사진 11장에서 읽은 **식당 11곳 · 메뉴 353개**가 들어있고,
그 메뉴를 골라서 **예약(날짜·시간·인원 + 예약금 1인 2,000원 토스페이먼츠 결제)** 까지 되는 화면 5개가 들어있어요.

---

## 1. 파일 넣기 (복사 붙여넣기만 하면 돼요)

압축을 풀면 이런 모양이에요:

```
lib/
 ├─ data/
 │   └─ restaurant_menu_data.dart      ← 식당·메뉴 데이터 (353개)
 ├─ screens/
 │   └─ reservation/
 │       ├─ reservation_models.dart        ← 장바구니·예약 데이터 모양 + 저장소
 │       ├─ restaurant_list_screen.dart    ← 화면 1: 식당 목록
 │       ├─ menu_order_screen.dart         ← 화면 2: 메뉴 고르기 (+ / -)
 │       ├─ reservation_form_screen.dart   ← 화면 3: 날짜·시간·인원 + 결제
 │       └─ reservation_done_screen.dart   ← 화면 4: 완료 / 화면 5: 내 예약
 └─ main_reservation_demo.dart         ← 예약 기능만 따로 실행해보는 시험용 파일
```

**하는 일:**
1. 맥에서 `hankki` 프로젝트 폴더를 Finder로 열어요.
2. 그 안의 `lib` 폴더에, 압축 푼 `lib` 안의 `data` 폴더와 `screens` 폴더를 **그대로 끌어다 놓아요.**
   - 이미 `lib/screens` 폴더가 있으면 → 그 안에 `reservation` 폴더만 넣으면 돼요.
   - 이미 `lib/data` 폴더가 있으면 → 그 안에 `restaurant_menu_data.dart` 파일만 넣으면 돼요.
3. `main_reservation_demo.dart` 도 `lib` 바로 아래에 넣어요 (시험용이라 나중에 지워도 돼요).

> 폴더 위치가 다르면 파일 맨 위의 `import '../../data/restaurant_menu_data.dart';` 줄의 `../../` 개수를 맞춰줘야 해요.
> 위 구조 그대로 넣으면 손댈 필요 없어요.

---

## 2. 먼저 예약 기능만 켜보기 (제일 쉬운 확인 방법)

터미널(VS Code 아래 터미널)에서 hankki 폴더 안에서:

```bash
flutter run -t lib/main_reservation_demo.dart
```

→ 식당 목록 → 식당 탭 → 메뉴 + / − → 예약하기 → 날짜/시간/인원/이름/연락처 → 결제하기 → 완료 화면
이 순서로 돌아가면 성공이에요.

---

## 3. 진짜 앱(main.dart)에 연결하기

홈 화면(Grab 스타일 서비스 타일)에서 "식당 예약" 타일을 누르면 열리게 하려면,
그 타일의 `onTap` 안에 이 3줄만 넣으면 돼요:

```dart
// 파일 맨 위 import 줄에 추가
import 'screens/reservation/restaurant_list_screen.dart';

// 버튼/타일의 onTap 안에
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const RestaurantListScreen()),
);
```

"내 예약" 화면을 열고 싶으면:

```dart
import 'screens/reservation/reservation_done_screen.dart';

Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const MyReservationsScreen()),
);
```

---

## 4. 색 바꾸기

`reservation_models.dart` 맨 위에 색 3개가 있어요. 앱에 이미 쓰는 초록색이 있으면 여기만 바꾸면 화면 5개 색이 한꺼번에 바뀌어요.

```dart
const Color kBrandGreen = Color(0xFF00B14F);      // 메인 초록
const Color kBrandGreenDark = Color(0xFF008F3F);  // 진한 초록 (글자용)
const Color kBrandGreenLight = Color(0xFFE6F7EC); // 연한 초록 (배경용)
```

예약금도 같은 파일에서 바꿔요:

```dart
const int kDepositPerPerson = 1000; // 1명당 예약금
```

---

## 5. 메뉴 고치기 / 추가하기

`lib/data/restaurant_menu_data.dart` 를 열면 식당마다 이렇게 생겼어요:

```dart
MenuCategory(name: '오리지널', items: [
  MenuItem(name: '크리스피치킨', price: 15900, note: '담백하고 바삭한 치킨'),
  MenuItem(name: '간장치킨',    price: 16900),          // note 는 없어도 돼요
]),
```

- **가격 고치기** → `price:` 뒤 숫자만 바꿔요 (쉼표 없이! 15900)
- **메뉴 추가** → `MenuItem(...)` 한 줄을 복사해서 붙이고 이름·가격만 바꿔요
- **식당 추가** → 맨 아래 `Restaurant(...)` 덩어리를 통째로 복사해서 붙이고 내용을 바꿔요
- 가격을 모르면 `price: 0` → 앱에 "가격 문의"로 나오고 주문은 안 담겨요

---

## 6. 꼭 확인할 것 (제가 읽으면서 애매했던 부분)

| 식당 | 확인할 내용 |
|---|---|
| **교촌치킨 백마강촌점** | PDF 6쪽에 제목만 있고 **메뉴판 사진이 없어요.** 사진 주시면 바로 추가할게요. 지금은 "메뉴 준비중"으로 나오고 예약만 돼요. |
| **깐부치킨 일산마두점** | 사진이 **판교산운마을점** 메뉴판이에요 (사진 아래 주소가 그래요). 마두점 가격이 같은지 확인 필요. |
| **도로시앤샌드위치** | 캡처에 클럽·에그 샌드위치 2개만 있어요. 메뉴가 더 있으면 알려주세요. |
| **포장마차깜보 — 오징어숙회** | 노란 종이에 가격이 안 적혀 있어서 `price: 0` (가격 문의)로 넣었어요. |
| **정글우동포차 — 우동** | 메뉴판이 `0.35`처럼 만원 단위라 3,500원으로 계산했어요. 다른 메뉴도 같은 방식(1.9 → 19,000원). |
| **정직유부 · 동경규동** | 메뉴판이 `4.7`, `9.9`처럼 천원 단위라 4,700원 / 9,900원으로 계산했어요. |
| **한잔의술 · 브라운치킨 · 정글우동 · 윤가네 · 깜보** | 소주·맥주·하이볼 등 **주류는 전부 뺐어요** (고등학생 대상 앱). 콜라·사이다·카스0.0(논알콜)은 남겼어요. |

메뉴 전체를 한눈에 대조하고 싶으면 같이 드린 **`메뉴목록_검토용.csv`** 를 엑셀/숫자로 열어보세요.

---

## 7. 다음 단계 (원하시면 이어서 해드릴 수 있는 것)

- Firebase Firestore에 예약 저장 → 식당 사장님이 "확인" 누르는 화면
- 식당 목록에 카카오맵 좌표 넣어서 지도에서 바로 예약으로 연결
- 메뉴마다 칼로리 넣어서 밀온이 표정 연동 (Claude API로 추정)
- 학생 쿠폰 / 5% 수수료 정산 리포트 화면 (박람회 부스용)
