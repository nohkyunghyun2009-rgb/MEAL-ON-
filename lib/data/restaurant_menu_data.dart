// ============================================================
// restaurant_menu_data.dart
// 백마 학원가 제휴 식당 메뉴 데이터 (메뉴판 사진에서 읽어서 정리)
//
// ▶ 이 파일은 "데이터만" 들어있는 파일이에요.
//   화면(UI) 코드는 screens/reservation/ 폴더에 따로 있어요.
// ▶ 가격 단위는 '원' (예: 15900 = 15,900원)
// ▶ price 가 0 이면 앱에서 "가격 문의"로 보여줘요.
// ▶ 주류(소주·맥주·하이볼 등)는 고등학생 대상 앱이라 뺐어요.
// ============================================================

/// 메뉴 한 개 (예: 크리스피치킨 15,900원)
class MenuItem {
  final String name;        // 메뉴 이름
  final int price;          // 가격 (원). 0이면 가격 문의
  final String note;        // 설명·옵션 안내 (없으면 빈 문자열)

  const MenuItem({required this.name, required this.price, this.note = ''});

  /// 가격을 "15,900원" 처럼 예쁘게 바꿔주는 함수
  String get priceText => price == 0 ? '가격 문의' : '${formatWon(price)}원';
}

/// 메뉴 묶음 (예: "오리지널" 안에 크리스피치킨, 간장치킨...)
class MenuCategory {
  final String name;              // 묶음 이름 (예: 오리지널, 세트)
  final List<MenuItem> items;     // 그 묶음에 들어있는 메뉴들

  const MenuCategory({required this.name, required this.items});
}

/// 식당 한 곳
class Restaurant {
  final String id;                      // 컴퓨터가 구분하는 짧은 영어 이름
  final String name;                    // 사람이 보는 식당 이름
  final String category;                // 종류 (치킨, 일식 ...)
  final String description;             // 한 줄 소개
  final List<MenuCategory> categories;  // 메뉴 묶음들

  const Restaurant({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.categories,
  });

  /// 이 식당의 전체 메뉴 개수
  int get menuCount =>
      categories.fold(0, (sum, c) => sum + c.items.length);

  /// 메뉴판이 아직 없는 식당인지
  bool get hasMenu => menuCount > 0;
}

/// 숫자에 쉼표 넣기: 15900 -> "15,900"
String formatWon(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// ★ 제휴 식당 전체 목록 ★
/// 새 식당을 추가하려면 이 리스트 맨 아래에 Restaurant(...) 를 하나 더 붙이면 돼요.
const List<Restaurant> partnerRestaurants = [

  // ---------- 호치킨 일산백마점 ----------
  Restaurant(
    id: 'hochicken',
    name: '호치킨 일산백마점',
    category: '치킨',
    description: '오리지널·스페셜·로스트 3종 라인업. 순살 변경 +2,000원',
    categories: [
      MenuCategory(name: '오리지널', items: [
        MenuItem(name: '크리스피치킨', price: 15900, note: '남녀노소 누구나 입맛에 맞는 담백하고 바삭바삭한 치킨'),
        MenuItem(name: '간장치킨', price: 16900, note: '바삭한 크리스피와 간장소스의 달콤 짭조름한 조합'),
        MenuItem(name: '양념치킨', price: 16900, note: '호치킨만의 소스로 맛을 낸 매콤달콤한 양념의 치킨'),
        MenuItem(name: '반반치킨', price: 16900, note: '크리스피+양념 or 크리스피+간장 (양념+간장/크리스피+치즈찐 +1,000, 양념+치즈찐/크리스피+맛나게맵닭 +2,000)'),
      ]),
      MenuCategory(name: '스페셜', items: [
        MenuItem(name: '왕호라이드', price: 17900, note: '바삭바삭 크리스피가 더욱 커져 돌아왔다! (순살 불가)'),
        MenuItem(name: '치즈찐', price: 17900, note: '단짠 체다치즈와 고소한 크림치즈에 파마산치즈로 풍미 UP'),
        MenuItem(name: '호차오', price: 18900, note: '바삭한 치킨을 강한 불에 볶아 불맛을 더한 중화풍 깐풍치킨'),
        MenuItem(name: '크런치새우치킨', price: 18900, note: '리얼 새우스낵과 치킨의 고소 바삭한 조합 (새우스낵토핑 +2,500)'),
        MenuItem(name: '어니언치킨', price: 18900, note: '아삭한 양파링과 호치킨 특제소스를 듬뿍 올린 상큼한 치킨'),
        MenuItem(name: '오리지널윙봉', price: 18900, note: '바삭하게 즐기는 가성비 최강 호치킨 윙봉 (순살 불가)'),
        MenuItem(name: '핫쏘이치킨', price: 17900, note: '달콤 짭조름한 간장 소스에 매콤 알싸한 청양고추와 월남고추의 만남'),
        MenuItem(name: '치타치킨', price: 17900, note: '매콤 고소한 스리라차마요소스와 타코시즈닝을 더한 멕시칸 스타일 치킨'),
        MenuItem(name: '치슐랭', price: 18900, note: '오븐에 한번 더 구워 바삭함과 소이립 풍미를 살린 프리미엄 치킨'),
        MenuItem(name: '파닭', price: 18900, note: '알싸한 파와 톡 쏘는 겨자소스가 입맛을 자극하는 크리스피 치킨'),
        MenuItem(name: '맛나게맵닭', price: 18900, note: '화끈한 소스와 과육의 달콤함이 만난 매콤달콤한 치킨'),
      ]),
      MenuCategory(name: '로스트', items: [
        MenuItem(name: '직화소금구이', price: 17900, note: '대파, 양파, 청양고추의 깊은 풍미를 담은 오븐구이'),
        MenuItem(name: '직화양념구이', price: 18900, note: '매콤달콤한 양념과 직화의 깊은 풍미가 어우러진 오븐구이'),
        MenuItem(name: '로스트', price: 15900, note: '육즙이 살아있는 오븐구이 웰빙 치킨'),
        MenuItem(name: '바베큐 로스트', price: 17900, note: '매콤한 바베큐소스와 담백한 로스트 치킨의 만남 (보통맛/매운맛 선택)'),
        MenuItem(name: '후끈이', price: 18900, note: '기름을 쏙 뺀 오븐 로스트에 매콤함의 환상 조합'),
      ]),
      MenuCategory(name: '세트', items: [
        MenuItem(name: '반반반 치킨세트 (크리스피+양념+간장)', price: 25900, note: '한마리 반으로 푸짐한 3가지 맛'),
        MenuItem(name: '반반반 치킨세트 (크리스피+양념+치즈찐)', price: 26900),
        MenuItem(name: '반반반 치킨세트 (크리스피+간장+치즈찐)', price: 26900),
        MenuItem(name: '반반반 치킨세트 (크리스피+간장+맛나게맵닭)', price: 26900),
        MenuItem(name: '치면세트 (크리스피+비빔우동)', price: 19900, note: '치킨 한마리와 면의 꿀조합'),
        MenuItem(name: '치면세트 (양념/간장/크리스피+양념/크리스피+간장)', price: 20900, note: '치킨 종류 선택'),
        MenuItem(name: '치면세트 (크리스피+치즈찐/양념+간장)', price: 21900),
        MenuItem(name: '치면세트 (양념+치즈찐/크리스피+맛나게맵닭)', price: 22900),
      ]),
      MenuCategory(name: '추가·소스·토핑', items: [
        MenuItem(name: '반마리 추가 (크리스피)', price: 9000, note: '치킨 주문 시 추가 가능'),
        MenuItem(name: '반마리 추가 (양념 or 간장)', price: 10000, note: '치킨 주문 시 추가 가능'),
        MenuItem(name: '소스 (간장/양념/겨자/청고추/갈릭퐁듀/머스타드/맵닭)', price: 500),
        MenuItem(name: '소스 (찐치즈/어니언/스리라차마요)', price: 1000),
        MenuItem(name: '토핑 왕비홍고추', price: 1000),
        MenuItem(name: '토핑 (쫀떡튀김/개운파채/아삭양파채)', price: 3500),
      ]),
    ],
  ),
  // ---------- 한잔의술 백마점 ----------
  Restaurant(
    id: 'hanjan',
    name: '한잔의술 백마점',
    category: '한식·포차',
    description: 'High-end 퓨전포차. 탕·요리·꼬치·피자파스타·디저트 (주류 제외)',
    categories: [
      MenuCategory(name: '대표메뉴', items: [
        MenuItem(name: '순살닭볶음탕 + 셀프볶음밥', price: 24900),
        MenuItem(name: '묵은지순살닭볶음탕 + 셀프칼국수', price: 26900),
        MenuItem(name: '로제순살닭볶음탕 + 셀프파스타', price: 26900),
        MenuItem(name: '누룽지닭볶음탕 + 셀프계란죽', price: 26900),
      ]),
      MenuCategory(name: '탕', items: [
        MenuItem(name: '김치어묵우동', price: 16900),
        MenuItem(name: '나가사끼짬뽕탕', price: 15900),
        MenuItem(name: '매콤차돌순두부김치찌개', price: 18900),
        MenuItem(name: '고기&김치만두계란탕', price: 16900),
        MenuItem(name: '순두부해물짬뽕탕', price: 16900),
        MenuItem(name: '꼬지빨간오뎅탕', price: 17900),
        MenuItem(name: '꼬지오뎅탕', price: 17900),
        MenuItem(name: '한술알탕', price: 18900),
        MenuItem(name: '한술해물누룽지탕', price: 17900),
        MenuItem(name: '바지락칼국수', price: 17900),
        MenuItem(name: '차돌스키야끼', price: 19900),
        MenuItem(name: '묵은지돼지고기김치찌개', price: 18900, note: 'NEW'),
        MenuItem(name: '산더미꽃게탕', price: 19900, note: 'NEW'),
        MenuItem(name: '우삼겹된장술밥', price: 17900, note: 'NEW'),
      ]),
      MenuCategory(name: '요리·메인·샐러드', items: [
        MenuItem(name: '쟁반찜닭볶음우동', price: 15900),
        MenuItem(name: '훈제삼겹두부김치', price: 17900),
        MenuItem(name: '후라이드순살치킨&감튀', price: 15900),
        MenuItem(name: '지파이유린기', price: 16900),
        MenuItem(name: '매콤돼지껍떡볶음&셀프주먹밥', price: 16900),
        MenuItem(name: '매콤눈꽃치즈닭떡볶이', price: 17900),
        MenuItem(name: '차돌숙주볶음', price: 15900),
        MenuItem(name: '매콤육회&치즈', price: 16900),
        MenuItem(name: '매콤무뼈닭발&셀프주먹밥', price: 17900),
        MenuItem(name: '골뱅이소면', price: 17900),
        MenuItem(name: '모듬소세지&감튀', price: 14900),
        MenuItem(name: '어묵꼬지국물떡볶이', price: 12900),
        MenuItem(name: '데리마요닭강정', price: 12900),
        MenuItem(name: '한술돈까스&감튀', price: 13900),
        MenuItem(name: '먹태+땅콩', price: 15900),
        MenuItem(name: '반건조오징어+땅콩', price: 13900),
        MenuItem(name: '케이준치킨샐러드', price: 12900),
      ]),
      MenuCategory(name: '꼬치·간단안주', items: [
        MenuItem(name: '염통꼬치 (5pcs)', price: 7900),
        MenuItem(name: '닭껍질꼬치 (5pcs)', price: 7900),
        MenuItem(name: '데리야끼닭다리살꼬치 (6pcs)', price: 10900),
        MenuItem(name: '은행꼬치 (10pcs)', price: 9900),
        MenuItem(name: '아이스크림 꿀호떡', price: 9900),
        MenuItem(name: '츄러스&바닐라아이스크림', price: 9900),
        MenuItem(name: '연유페스츄리&바닐라아이스크림', price: 7900),
        MenuItem(name: '우삼겹계란게티', price: 7900),
        MenuItem(name: '해장라면', price: 5900),
        MenuItem(name: '바삭롱치즈스틱&감튀', price: 9900),
        MenuItem(name: 'L사 양념 감튀 (크림버터/매콤칠리)', price: 9900),
        MenuItem(name: '계란찜', price: 6900),
        MenuItem(name: '파인메론 반반', price: 12900),
        MenuItem(name: '연유큐브수박', price: 8900),
        MenuItem(name: '연유토마토', price: 5900),
        MenuItem(name: '콘치즈', price: 6900),
        MenuItem(name: '쥐포튀김', price: 5900),
        MenuItem(name: '셀프주먹밥', price: 3500),
      ]),
      MenuCategory(name: '시원한안주·디저트', items: [
        MenuItem(name: '파인애플샤베트', price: 6900),
        MenuItem(name: '아이스망고큐브치즈', price: 6900),
        MenuItem(name: '용과샤베트', price: 8900),
        MenuItem(name: '요구르트샤베트', price: 9900),
        MenuItem(name: '딸기우유냉동과일', price: 11900),
        MenuItem(name: '콜드황도', price: 5900),
      ]),
      MenuCategory(name: '피자·파스타', items: [
        MenuItem(name: '빠네크림베이컨파스타', price: 18900),
        MenuItem(name: '감바스파스타', price: 17900),
        MenuItem(name: '매콤로제떡볶이파스타', price: 14900),
        MenuItem(name: '페스츄리페페로니피자', price: 15900),
      ]),
    ],
  ),
  // ---------- 도로시앤샌드위치 ----------
  Restaurant(
    id: 'dorothy',
    name: '도로시앤샌드위치',
    category: '샌드위치',
    description: '가성비 수제 샌드위치',
    categories: [
      MenuCategory(name: '추천 메뉴', items: [
        MenuItem(name: '클럽 샌드위치', price: 2500, note: '닭가슴살 베이스 수제소스로 어우러진 담백한맛 (대표)'),
        MenuItem(name: '에그 샌드위치', price: 2500, note: '으깬달걀을 마요네즈에 버무려 시중에 파는 에그마요와 다른 고소한 맛'),
      ]),
    ],
  ),
  // ---------- 브라운치킨 일산백마점 ----------
  Restaurant(
    id: 'brownchicken',
    name: '브라운치킨 일산백마점',
    category: '치킨',
    description: '국내산 영계닭만 사용. 반반 선택 가능',
    categories: [
      MenuCategory(name: '치킨류', items: [
        MenuItem(name: '마늘치킨', price: 18000),
        MenuItem(name: '후라이드치킨', price: 17000),
        MenuItem(name: '양념치킨', price: 18000),
        MenuItem(name: '간장치킨', price: 18000),
        MenuItem(name: '파치킨', price: 18000),
        MenuItem(name: '반반치킨 (마늘/후라이드/양념/간장 중 선택)', price: 18000),
        MenuItem(name: '반마리 추가', price: 9000),
      ]),
      MenuCategory(name: '치킨세트', items: [
        MenuItem(name: '치킨뱅이', price: 39000),
        MenuItem(name: '마늘뱅이', price: 40000),
        MenuItem(name: '세트 (후+간+마 반마리)', price: 28000),
        MenuItem(name: '감자튀김 추가', price: 5000),
      ]),
      MenuCategory(name: '안주·식사', items: [
        MenuItem(name: '을지로골뱅이', price: 23000),
        MenuItem(name: '감자튀김', price: 10000),
        MenuItem(name: '번데기', price: 12000),
        MenuItem(name: '황도', price: 10000),
        MenuItem(name: '갑오징어숙회', price: 25000),
        MenuItem(name: '오뎅탕', price: 20000),
        MenuItem(name: '두부김치', price: 20000),
        MenuItem(name: '무뼈닭발볶음', price: 20000),
        MenuItem(name: '부대찌개', price: 25000),
        MenuItem(name: '두부짜박이', price: 20000),
        MenuItem(name: '모듬소세지+떡튀김', price: 15000),
        MenuItem(name: '김치찌개', price: 25000, note: '김치·고기 국내산'),
        MenuItem(name: '제육볶음', price: 25000),
      ]),
      MenuCategory(name: '마른안주', items: [
        MenuItem(name: '노가리', price: 17000),
        MenuItem(name: '한치', price: 18000),
        MenuItem(name: '먹태', price: 20000),
        MenuItem(name: '반건조오징어', price: 17000),
        MenuItem(name: '마른오징어', price: 15000),
      ]),
      MenuCategory(name: '음료·기타', items: [
        MenuItem(name: '콜라/사이다', price: 2000),
        MenuItem(name: '햇반', price: 2000),
      ]),
    ],
  ),
  // ---------- 정직유부 일산백마점 ----------
  Restaurant(
    id: 'jeongjik',
    name: '정직유부 일산백마점',
    category: '유부초밥·우동',
    description: '주문 즉시 조리하는 유부초밥. 전 메뉴 반반 가능(정직유부 제외)',
    categories: [
      MenuCategory(name: '유부메뉴 (4p)', items: [
        MenuItem(name: '정직유부', price: 4700, note: '갖은 야채와 국내산 돼지고기가 들어간 정직유부의 기본 메뉴'),
        MenuItem(name: '참치마요유부', price: 5900, note: '고소한 참치와 크리미한 특제 마요소스로 맛이 일품 (BEST)'),
        MenuItem(name: '볶음김치유부', price: 5900, note: '정성스럽게 볶은 국내산 김치가 들어간 유부'),
        MenuItem(name: '불고기유부', price: 5900, note: '100% 국내산 돼지고기에 특제 소스로 만든 인기만점 유부 (BEST)'),
        MenuItem(name: '크래미와사마요유부', price: 5900, note: '알싸한 와사비마요소스에 쫄깃한 크래미가 더해진 유부'),
        MenuItem(name: '에그유부', price: 5900, note: '올리브유 베이스의 에그소스로 만든 부드러운 유부'),
        MenuItem(name: '닭갈비유부', price: 5900, note: '촉촉한 닭다리살에 매콤달콤 양념이 배어든 유부'),
        MenuItem(name: '매콤참치유부', price: 5900, note: '화끈한 청양고추와 참치가 어우러진 빨간맛 유부'),
        MenuItem(name: '청양마요유부', price: 5900, note: '강렬한 맛의 특제 청양마요 소스와 양파 후레이크의 고소한 맛 유부'),
        MenuItem(name: '제육유부', price: 6400, note: '매콤달콤한 비법양념으로 볶은 제육이 들어간 유부 (체다치즈 추가 +1,000) (BEST)'),
        MenuItem(name: '마라유부', price: 6400, note: '특제 마라소스와 100% 국내산 돼지고기로 만든 매콤얼얼한 유부 (NEW)'),
      ]),
      MenuCategory(name: '세트메뉴', items: [
        MenuItem(name: '시그니처 8종 모둠세트 (8pcs)', price: 12900, note: '정직·참치마요·볶음김치·불고기·크래미와사마요·에그·닭갈비·매콤참치 (BEST)'),
        MenuItem(name: '1인세트 (면메뉴+유부 3pcs)', price: 9000, note: '유부초밥과 면메뉴를 원하는대로 가성비 있게 즐기는 1인 세트 (9,000~)'),
      ]),
      MenuCategory(name: '면 메뉴', items: [
        MenuItem(name: '마라마제우동', price: 7500, note: '부드러운 순두부와 마라소스가 어우러진 꾸덕한 마라마제우동 (NEW)'),
        MenuItem(name: '정직냉모밀', price: 7500, note: '가쓰오 풍미 가득 시원한 육수와 고소한 메밀면의 조화 (BEST)'),
        MenuItem(name: '참깨초계면', price: 7000, note: '참깨소스와 닭가슴살 동치미육수가 어우러진 파스타'),
        MenuItem(name: '비빔막국수', price: 7000, note: '춘천막국수 스타일의 깊은 단맛과 매콤한 맛 (4~10월 시즌메뉴)'),
        MenuItem(name: '물비빔막국수', price: 7500, note: '시원한 동치미육수로 물/비빔 모두 즐길 수 있는 메뉴 (4~10월 시즌메뉴)'),
        MenuItem(name: '순두부우동', price: 6700, note: '얼큰 칼칼한 육수와 부드러운 순두부의 만남 (BEST)'),
        MenuItem(name: '어묵우동', price: 6700, note: '포장마차 스타일의 진한 어묵우동 (매콤 +200, 김치 +900)'),
        MenuItem(name: '정직우동', price: 5500, note: '담백하고 깊은맛의 우동 (얼큰 +200, THE얼큰 +500) (BEST)'),
        MenuItem(name: '닭곰탕우동', price: 6700, note: '맑고 진한 닭곰탕육수에 부드러운 닭가슴살이 듬뿍'),
        MenuItem(name: '쫄면', price: 6500, note: '쫄깃한 면발과 매콤달콤새콤 소스가 어우러져 중독성 있는 메뉴'),
        MenuItem(name: '삼겹비빔면', price: 6000, note: '유부초밥과 잘 어울리는 삼겹살과 비빔면'),
        MenuItem(name: '정직라면', price: 4500, note: '파송송 맛있는 라면 (치즈라면 +500)'),
      ]),
      MenuCategory(name: '사이드 메뉴', items: [
        MenuItem(name: '국물떡볶이', price: 5500, note: '진하고 칼칼한 국물에 쫄깃한 떡과 부산 어묵이 들어간 떡볶이'),
        MenuItem(name: '정직우볶이', price: 4500, note: '고추장 베이스 매콤 우볶이 유부찍먹 면메뉴'),
        MenuItem(name: '어묵탕', price: 4500, note: '담백하고 깊은맛의 어묵탕 (매콤 +200)'),
      ]),
    ],
  ),
  // ---------- 교촌치킨 백마강촌점 ----------
  Restaurant(
    id: 'kyochon',
    name: '교촌치킨 백마강촌점',
    category: '치킨',
    description: '메뉴판 사진이 PDF에 없어 메뉴를 아직 넣지 못했어요. 사진을 받으면 추가!',
    categories: [],
  ),
  // ---------- 정글우동포차 ----------
  Restaurant(
    id: 'jungle',
    name: '정글우동포차',
    category: '포차·분식',
    description: '우동 3,500원부터 — 학생 가성비 식사 + 안주·탕 (주류 제외)',
    categories: [
      MenuCategory(name: '식사류', items: [
        MenuItem(name: '우동', price: 3500, note: '어묵추가 +1,000'),
        MenuItem(name: '즉석떡볶이 (2인분)', price: 9000),
        MenuItem(name: '돈까스', price: 4500),
        MenuItem(name: '해물짬뽕라면', price: 4000),
        MenuItem(name: '냉면', price: 4500),
        MenuItem(name: '홍합토마토스파게티', price: 8000),
        MenuItem(name: '김치찌개', price: 5500),
        MenuItem(name: '부대찌개', price: 5500),
        MenuItem(name: '제육덮밥', price: 5500),
        MenuItem(name: '김치볶음밥', price: 5500),
        MenuItem(name: '오므라이스', price: 5500),
        MenuItem(name: '뚝배기불고기', price: 6000),
      ]),
      MenuCategory(name: '추가메뉴', items: [
        MenuItem(name: '볶음밥', price: 3000),
        MenuItem(name: '김가루밥', price: 2000),
        MenuItem(name: '공기밥', price: 1000),
        MenuItem(name: '우동사리', price: 2000),
        MenuItem(name: '라면사리', price: 1000),
        MenuItem(name: '팝콘', price: 3000),
        MenuItem(name: '각종음료', price: 2000),
      ]),
      MenuCategory(name: '튀김류', items: [
        MenuItem(name: '훈제통오리', price: 19000),
        MenuItem(name: '훈제통닭', price: 13000),
        MenuItem(name: '칠면조다리튀김&감자튀김', price: 14000),
        MenuItem(name: '가라아게튀김&감자튀김', price: 14000),
        MenuItem(name: '치즈스틱&감자튀김', price: 13000),
        MenuItem(name: '살로만치킨&감자튀김', price: 15000),
        MenuItem(name: '똥집튀김', price: 14000),
        MenuItem(name: '탕수육', price: 15000),
        MenuItem(name: '감자튀김', price: 5000),
        MenuItem(name: '물만두튀김', price: 5000),
      ]),
      MenuCategory(name: '기타', items: [
        MenuItem(name: '부추전', price: 11000),
        MenuItem(name: '해물부추전', price: 14000),
        MenuItem(name: '김치전', price: 11000),
        MenuItem(name: '먹태', price: 14000),
        MenuItem(name: '콘치즈', price: 8000),
        MenuItem(name: '스팸계란후라이', price: 6000),
        MenuItem(name: '너비아니계란후라이', price: 6000),
        MenuItem(name: '마약소세지', price: 12000),
        MenuItem(name: '계란말이', price: 12000),
        MenuItem(name: '피자', price: 10000),
        MenuItem(name: '짜파게티', price: 8000),
        MenuItem(name: '황도', price: 8000),
        MenuItem(name: '번데기탕', price: 5000),
        MenuItem(name: '계란찜', price: 4000),
        MenuItem(name: '촉촉한노가리', price: 13000),
        MenuItem(name: '반건조오징어', price: 13000),
      ]),
      MenuCategory(name: '안주류', items: [
        MenuItem(name: '낙지볶음소면', price: 23000),
        MenuItem(name: '찜닭', price: 23000),
        MenuItem(name: '갑오징어숙회', price: 21000),
        MenuItem(name: '골뱅이무침', price: 18000),
        MenuItem(name: '훈제오리부추무침', price: 19000),
        MenuItem(name: '김치두루치기', price: 16000),
        MenuItem(name: '돼지두루치기', price: 23000),
        MenuItem(name: '돼지고기두부김치', price: 15000),
        MenuItem(name: '콩나물쭈꾸미볶음', price: 16000),
        MenuItem(name: '고추장삼겹살볶음', price: 16000),
        MenuItem(name: '삼겹숙주볶음', price: 16000),
        MenuItem(name: '매운오돌뼈볶음', price: 14000),
        MenuItem(name: '닭똥집마늘볶음', price: 14000),
        MenuItem(name: '야채곱창볶음', price: 16000),
        MenuItem(name: '무뼈국물닭발', price: 16000),
        MenuItem(name: '돼지껍데기볶음', price: 13000),
      ]),
      MenuCategory(name: '탕류', items: [
        MenuItem(name: '묵은지닭도리탕', price: 25000),
        MenuItem(name: '신매콤닭도리탕', price: 23000),
        MenuItem(name: '양푼김치찌개', price: 14000),
        MenuItem(name: '양푼부대찌개', price: 14000),
        MenuItem(name: '얼큰짬뽕탕', price: 15000),
        MenuItem(name: '나가사끼짬뽕탕', price: 15000),
        MenuItem(name: '오뎅탕', price: 11000),
        MenuItem(name: '홍합탕', price: 11000),
        MenuItem(name: '얼큰알탕', price: 14000),
        MenuItem(name: '물만두계란탕', price: 10000),
        MenuItem(name: '물만두김치우동', price: 12000),
      ]),
    ],
  ),
  // ---------- 포장마차깜보 ----------
  Restaurant(
    id: 'kkambo',
    name: '포장마차깜보',
    category: '포차·한식',
    description: '제주돼지 생오겹살·풍천민물장어·부대찌개. 모든 메뉴 포장 가능',
    categories: [
      MenuCategory(name: '구이·탕', items: [
        MenuItem(name: '생오겹살 (1인분 180g)', price: 14000, note: '100g 7,000원'),
        MenuItem(name: '민물장어 大 2마리', price: 59000),
        MenuItem(name: '부대찌개 (2인 이상, 1인분)', price: 8000),
        MenuItem(name: '햄·쏘세지사리', price: 7000),
        MenuItem(name: '라면사리', price: 2000),
        MenuItem(name: '닭볶음탕', price: 27000),
        MenuItem(name: '오뎅탕', price: 15000),
        MenuItem(name: '알탕', price: 19000),
        MenuItem(name: '동태탕', price: 27000),
      ]),
      MenuCategory(name: '볶음·안주', items: [
        MenuItem(name: '무뼈닭발', price: 16000),
        MenuItem(name: '닭똥집', price: 16000),
        MenuItem(name: '꼼장어볶음', price: 16000),
        MenuItem(name: '오징어볶음', price: 16000),
        MenuItem(name: '쭈꾸미볶음', price: 16000),
        MenuItem(name: '제육볶음', price: 17000),
        MenuItem(name: '코다리구이', price: 17000),
        MenuItem(name: '가오리찜', price: 17000),
        MenuItem(name: '한우육회', price: 17000),
        MenuItem(name: '해물파전', price: 15000),
        MenuItem(name: '두부김치', price: 15000),
        MenuItem(name: '골뱅이무침', price: 23000),
        MenuItem(name: '계란찜', price: 7000),
        MenuItem(name: '계란말이', price: 12000),
        MenuItem(name: '사누끼 우동', price: 5000),
        MenuItem(name: '구룡포 과메기', price: 23000, note: '겨울철 별미'),
        MenuItem(name: '용대리 먹태', price: 17000),
        MenuItem(name: '대구노가리', price: 15000),
        MenuItem(name: '기장 멸치무침', price: 23000),
        MenuItem(name: '홍어회', price: 25000),
        MenuItem(name: '오징어숙회', price: 0, note: '가격 미표기 — 매장 문의'),
      ]),
    ],
  ),
  // ---------- 윤가네바베큐 마두점 ----------
  Restaurant(
    id: 'yoongane',
    name: '윤가네바베큐 마두점',
    category: '바베큐·한식',
    description: '치즈 통닭 바베큐·양념삼겹 바베큐 등 (주류 제외)',
    categories: [
      MenuCategory(name: '메인메뉴', items: [
        MenuItem(name: '치즈 통닭 바베큐', price: 22000),
        MenuItem(name: '양념삼겹 바베큐', price: 32000),
        MenuItem(name: '고추장양념삼겹 바베큐', price: 34000),
        MenuItem(name: '오리훈제 바베큐', price: 32000),
        MenuItem(name: '닭도리탕', price: 32000),
        MenuItem(name: '오삼 불고기', price: 32000),
        MenuItem(name: '알탕', price: 32000),
        MenuItem(name: '피꼬막', price: 32000, note: '개시'),
      ]),
      MenuCategory(name: '사이드메뉴', items: [
        MenuItem(name: '수제소시지', price: 22000),
        MenuItem(name: '오징어 볶음', price: 26000),
        MenuItem(name: '돼지고기 볶음', price: 26000),
        MenuItem(name: '꼼장어 볶음', price: 26000),
        MenuItem(name: '골뱅이', price: 22000),
        MenuItem(name: '두부김치', price: 26000),
        MenuItem(name: '김치찌개', price: 26000),
        MenuItem(name: '새우튀김', price: 22000),
        MenuItem(name: '돈까스 안주', price: 28000),
        MenuItem(name: '먹태', price: 26000),
        MenuItem(name: '매운닭발', price: 24000),
        MenuItem(name: '고급오뎅전골', price: 22000),
        MenuItem(name: '한치', price: 22000),
        MenuItem(name: '부추전', price: 22000),
        MenuItem(name: '계란말이', price: 16000),
        MenuItem(name: '번데기탕', price: 12000),
      ]),
      MenuCategory(name: '음료', items: [
        MenuItem(name: '카스 0.0 (논알콜)', price: 4000),
      ]),
    ],
  ),
  // ---------- 깐부치킨 일산마두점 ----------
  Restaurant(
    id: 'kkanbu',
    name: '깐부치킨 일산마두점',
    category: '치킨',
    description: '전기구이·크리스피·순살 등 (사진은 판교점 메뉴판 — 마두점 가격 확인 필요)',
    categories: [
      MenuCategory(name: '치킨', items: [
        MenuItem(name: '깐부 바삭한식스팩 (Kkanbu Crispy 6 Pack)', price: 18000, note: 'NEW'),
        MenuItem(name: '전기구이치킨', price: 14000),
        MenuItem(name: '고추간장치킨', price: 18000, note: 'NEW'),
        MenuItem(name: '크리스피치킨', price: 17000),
        MenuItem(name: '마늘전기구이', price: 16000),
        MenuItem(name: '깐부불사조 (순살)', price: 17000),
        MenuItem(name: '후라이드치킨', price: 16000),
        MenuItem(name: '순살파닭', price: 18000),
        MenuItem(name: '순살크리스피', price: 17000),
        MenuItem(name: '순살스윗치킨', price: 17000),
        MenuItem(name: '깐부로스트 윙&봉', price: 15000),
      ]),
      MenuCategory(name: '사이드', items: [
        MenuItem(name: '깐부골뱅이', price: 19000),
        MenuItem(name: '케이준치킨샐러드', price: 13000),
        MenuItem(name: '깐부소시지', price: 16000),
        MenuItem(name: '반건조오징어세트', price: 13000),
        MenuItem(name: '어니언포테이토', price: 11000),
        MenuItem(name: '웨지포테이토', price: 11000),
        MenuItem(name: '스파이시포테이토', price: 11000),
      ]),
    ],
  ),
  // ---------- 동경규동 일산백마점 ----------
  Restaurant(
    id: 'tokyogyudong',
    name: '동경규동 일산백마점',
    category: '일식·덮밥',
    description: '규동·가츠동·우동·카레·정식세트',
    categories: [
      MenuCategory(name: '정식/세트', items: [
        MenuItem(name: '규동정식세트', price: 13500),
        MenuItem(name: '매운야끼규동 정식세트', price: 13700),
        MenuItem(name: '김치가츠나베 정식세트', price: 13700),
        MenuItem(name: '수제등심 돈가츠 정식세트', price: 13000),
        MenuItem(name: '불닭치즈 나베 정식세트', price: 12000),
        MenuItem(name: '규동(소)+대파유린치킨세트', price: 10400),
        MenuItem(name: '냉모밀 돈가츠 정식세트', price: 13700),
        MenuItem(name: '야끼규 냉모밀 정식세트', price: 13700),
      ]),
      MenuCategory(name: '규동', items: [
        MenuItem(name: '규동메가콤보', price: 9900),
        MenuItem(name: '김치규동', price: 8500),
        MenuItem(name: '규동', price: 7900),
        MenuItem(name: '야끼규동', price: 8100),
        MenuItem(name: '매운 야끼규동', price: 8400),
        MenuItem(name: '불판 김치볶음규동', price: 9100),
        MenuItem(name: '오코노미 규타마동', price: 9100),
        MenuItem(name: '부타동', price: 8000),
        MenuItem(name: '불판 김치부타동', price: 9100),
        MenuItem(name: '치즈 매운야끼규동', price: 9100),
      ]),
      MenuCategory(name: '돈가츠/치킨/새우', items: [
        MenuItem(name: '수제등심 가츠동', price: 8400),
        MenuItem(name: '수제등심 김치가츠동', price: 8900),
        MenuItem(name: '수제등심 치즈가츠동', price: 9400),
        MenuItem(name: '수제등심 치즈김치가츠동', price: 9700),
        MenuItem(name: '다리살 치킨가라아게동', price: 8200),
        MenuItem(name: '다리살 치킨마요동', price: 8200),
        MenuItem(name: '타마고 에비텐동', price: 9900),
      ]),
      MenuCategory(name: '우동·모밀', items: [
        MenuItem(name: '가쓰오 동경우동', price: 6200),
        MenuItem(name: '유부듬뿍 김치우동', price: 6800),
        MenuItem(name: '에비텐 가쓰오우동', price: 7600),
        MenuItem(name: '니꾸우동', price: 8700),
        MenuItem(name: '얼큰 니꾸우동', price: 9000),
        MenuItem(name: '타마고 우동나베', price: 9500),
        MenuItem(name: '얼큰우동나베', price: 9800),
        MenuItem(name: '냉모밀', price: 7900),
        MenuItem(name: '에비텐 냉모밀', price: 9300),
      ]),
      MenuCategory(name: '카레', items: [
        MenuItem(name: '에비텐 카레', price: 9500),
        MenuItem(name: '수제등심 가츠가레', price: 9300),
        MenuItem(name: '다리살 치킨카레', price: 8900),
        MenuItem(name: '야끼규 카레', price: 9300),
        MenuItem(name: '고로케 카레', price: 8900),
        MenuItem(name: '에비텐 카레우동', price: 7900),
      ]),
      MenuCategory(name: '사이드메뉴', items: [
        MenuItem(name: '샐러드 고로케', price: 5000),
        MenuItem(name: '샐러드 치킨가라아게', price: 5000),
        MenuItem(name: '대파유린돈가츠', price: 5900),
        MenuItem(name: '대파유린치킨', price: 5900),
        MenuItem(name: '미니돈가츠', price: 5000),
        MenuItem(name: '후리가케 공기밥', price: 1200),
        MenuItem(name: '온센타마고', price: 1200),
        MenuItem(name: '콜라', price: 2000),
        MenuItem(name: '제로콜라', price: 2000),
        MenuItem(name: '사이다', price: 2000),
      ]),
    ],
  ),
];
