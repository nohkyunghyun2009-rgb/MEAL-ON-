import '../services/kakao_local_service.dart';
import 'baekma_menus.dart';
import 'baekma_menus2.dart';
import 'baekma_menus3.dart';
import 'baekma_menus4.dart';
import 'baekma_menus5.dart';
import 'baekma_menus6.dart';

/// ═══════════════════════════════════════════════════════════
///  메뉴판 데이터
///  - 카카오 지도는 가게 위치만 주고 메뉴는 안 줘요.
///  - 그래서 ① 제휴 가게는 이름으로 "진짜 메뉴"를 넣고
///          ② 나머지는 가게 종류(분식/한식/치킨…)에 맞는 "샘플 메뉴판"을 붙여요.
///  제휴를 맺으면 partnerMenus 에 가게 이름 + 실제 메뉴·가격을 추가하면 끝!
/// ═══════════════════════════════════════════════════════════

class MenuItem {
  final String name;
  final int price; // 원
  final double kcal;
  final double proteinG;
  final String emoji;
  final String section; // 메뉴판 묶음 제목 (예: '오리지널 피자'). 비우면 묶음 없음
  const MenuItem(this.name, this.price, this.kcal, this.proteinG, this.emoji, {this.section = ''});
}

/// 피자처럼 사이즈별 가격이 다른 메뉴를 한 줄로 쓰기 위한 도우미
/// 칼로리는 퍼스널(8인치) 기준 추정값이고, 레귤러 ×1.9 · 라지 ×3.2 로 계산해요
List<MenuItem> _pizza(String name, String emoji, double kcalPersonal, double proteinPersonal, int personal, int regular, int large, {String section = '오리지널 피자'}) => [
      MenuItem('$name · 퍼스널(8인치)', personal, kcalPersonal, proteinPersonal, emoji, section: section),
      MenuItem('$name · 레귤러(10인치)', regular, kcalPersonal * 1.9, proteinPersonal * 1.9, emoji, section: section),
      MenuItem('$name · 라지(13인치)', large, kcalPersonal * 3.2, proteinPersonal * 3.2, emoji, section: section),
    ];

class MenuCatalog {
  /// ① 제휴 가게 실제 메뉴 — 가게 이름에 이 글자가 들어가면 이 메뉴판을 써요
  ///    (제휴 맺을 때마다 여기에 추가)
  static final Map<String, List<MenuItem>> partnerMenus = {
    // 가게 이름에 '잭슨'이 들어가면 이 메뉴판 (잭슨 블러바드 백마점)
    '잭슨': jacksonBlvd,
    // 가게 이름에 '모퉁이'가 들어가면 이 메뉴판 (모퉁이 테이블 일산마두점)
    '모퉁이': motungiTable,
    // 백마 학원가 13곳 (도로시·고봉민·꽉찬·앤티앤스·프랭크·기영이·쭈꾸미마을·피자스쿨·해바라기·현대옥·대림·본죽·롯데리아)
    ...BaekmaMenus.all,
    // 백마 학원가 2탄 9곳 (호치킨·한잔의술·브라운치킨·정직유부·정글우동·깜보·윤가네·깐부·동경규동)
    ...BaekmaMenus2.all,
    // 백마 학원가 3탄 9곳 (쫄쫄맨·써브웨이·반올림피자·버거킹·소코아·후쿠로우·노랑강정·김앤밥스·긴자료코)
    ...BaekmaMenus3.all,
    // 백마 학원가 4탄 9곳 (심가네돼지갈비·백마황소곱창·달구족발·맛갈촌·창업마라탕&양꼬치·홍콩반점·짱돈까스·마라공방·한신우동)
    ...BaekmaMenus4.all,
    // 백마 학원가 5탄 14곳 (글자 메뉴판: 이삭토스트·미소야·맘스터치·교촌치킨·신전떡볶이·응달집·누루·생선도마 등)
    ...BaekmaMenus5.all,
    // 백마 학원가 6탄 21곳 (사진 메뉴판: 행복한찜닭·서오릉피자·봉구스·윤씨네·두끼·엽기떡볶이·명랑핫도그·빨간모자피자·연어만·만나고김밥 등)
    ...BaekmaMenus6.all,
  };

  /// ═══ 모퉁이 테이블 일산마두점 실제 메뉴판 ═══
  /// 가격은 메뉴판 그대로. 칼로리·단백질은 비슷한 음식 기준 추정값이에요.
  static const List<MenuItem> motungiTable = [
    // ── 파스타 ──
    MenuItem('엔초비 오일 파스타', 10500, 620, 20, '🍝', section: '파스타'),
    MenuItem('까르보나라', 9500, 780, 26, '🍝', section: '파스타'),
    MenuItem('쉬림프 알리오올리오', 11500, 640, 28, '🍤', section: '파스타'),
    MenuItem('토마토 파스타', 9500, 560, 18, '🍅', section: '파스타'),
    MenuItem('로제 파스타', 10500, 700, 22, '🍝', section: '파스타'),
    MenuItem('쉬림프 상하이 파스타', 11500, 680, 30, '🍤', section: '파스타'),

    // ── 리조또 ──
    MenuItem('크림 리조또', 9500, 720, 18, '🍚', section: '리조또'),
    MenuItem('토마토 리조또', 9500, 600, 16, '🍅', section: '리조또'),
    MenuItem('로제 리조또', 10500, 680, 18, '🍚', section: '리조또'),
    MenuItem('쉬림프 매콤 토마토 리조또', 12500, 650, 28, '🍤', section: '리조또'),

    // ── 필라프 ──
    MenuItem('베이컨 필라프', 9500, 700, 22, '🥓', section: '필라프'),
    MenuItem('쉬림프 필라프', 10500, 640, 28, '🍤', section: '필라프'),

    // ── 수제 피자 ──
    MenuItem('리코타 마르게리타 피자', 12500, 820, 34, '🍕', section: '수제 피자'),
    MenuItem('수제 고르곤졸라 피자', 12500, 860, 32, '🧀', section: '수제 피자'),
    MenuItem('수제 페퍼로니 피자', 12500, 900, 36, '🍕', section: '수제 피자'),
    MenuItem('수제 쉬림프 피자', 12500, 840, 38, '🍤', section: '수제 피자'),

    // ── 사이드 ──
    MenuItem('바게트 3조각', 1500, 210, 6, '🥖', section: '사이드'),
    MenuItem('소세지 오븐구이', 3500, 320, 14, '🌭', section: '사이드'),

    // ── 음료 ──
    MenuItem('콜라 뚱캔', 2500, 190, 0, '🥤', section: '음료'),
    MenuItem('사이다 뚱캔', 2500, 180, 0, '🥤', section: '음료'),
    MenuItem('미니 콜라', 1500, 100, 0, '🥤', section: '음료'),
    MenuItem('미니 사이다', 1500, 95, 0, '🥤', section: '음료'),
  ];

  /// ═══ 잭슨 블러바드 (JACKSON BLVD) 실제 메뉴판 ═══
  /// 가격은 메뉴판 그대로(단위: 원). 칼로리·단백질은 비슷한 음식 기준 추정값이에요.
  static final List<MenuItem> jacksonBlvd = [
    // ── 오리지널 크러스트 피자 (퍼스널 8" / 레귤러 10" / 라지 13") ──
    ..._pizza('마가리타', '🍕', 620, 26, 8800, 16800, 26800),
    ..._pizza('파이브 치즈', '🧀', 760, 34, 9800, 19300, 31000),
    ..._pizza('페퍼로니', '🍕', 720, 30, 9300, 18300, 28300),
    ..._pizza('페퍼로니 딜라이트', '🍕', 790, 34, 10800, 20300, 32300),
    ..._pizza('하와이안', '🍍', 740, 32, 11000, 21800, 33800),
    ..._pizza('아메리칸 스피릿', '🥓', 800, 36, 11300, 22000, 34000),
    ..._pizza('그릭콜로지', '🫒', 700, 28, 11000, 21800, 33800),
    ..._pizza('멜팅 치즈 버거', '🍔', 880, 40, 13800, 25800, 38800),
    ..._pizza('수퍼 잭슨', '🍕', 860, 38, 13800, 25800, 38800),
    ..._pizza('레전드', '🍕', 820, 36, 13800, 25800, 38800),
    ..._pizza('제스티 잭슨', '🌶️', 850, 38, 14000, 26000, 39300),
    ..._pizza('베이컨 체다 할라피뇨', '🥓', 830, 36, 11800, 23300, 36000),

    // ── 딥디쉬 피자 ──
    const MenuItem('오리지널 치즈 딥디쉬', 17300, 1400, 60, '🥧', section: '딥디쉬 피자'),
    const MenuItem('닥터 페퍼로니 딥디쉬', 18300, 1550, 66, '🥧', section: '딥디쉬 피자'),
    const MenuItem('잭슨 파이브 딥디쉬', 19800, 1650, 70, '🥧', section: '딥디쉬 피자'),

    // ── 클래식 오븐 베이크 스파게티 ──
    const MenuItem('토마토 치즈 스파게티', 9800, 650, 24, '🍝', section: '오븐 스파게티'),
    const MenuItem('토마토 미트볼 스파게티', 13800, 820, 36, '🍝', section: '오븐 스파게티'),
    const MenuItem('핑크소스 치즈 스파게티', 9800, 720, 24, '🍝', section: '오븐 스파게티'),
    const MenuItem('핑크소스 미트볼 스파게티', 13800, 890, 36, '🍝', section: '오븐 스파게티'),
    const MenuItem('케토 볼로네제', 12000, 560, 34, '🍝', section: '오븐 스파게티'),

    // ── 사이드 ──
    const MenuItem('잭슨 미트볼', 17800, 780, 48, '🥩', section: '사이드'),
    const MenuItem('고추장파마산 윙 (8조각)', 16800, 880, 56, '🍗', section: '사이드'),
    const MenuItem('크리스피 핫 치킨 텐더 (4조각)', 6800, 420, 28, '🍗', section: '사이드'),
    const MenuItem('크리스피 핫 윙 (4조각)', 7800, 440, 28, '🍗', section: '사이드'),
    const MenuItem('프렌치 프라이즈', 6000, 380, 4, '🍟', section: '사이드'),
    const MenuItem('치즈 프라이즈', 8000, 520, 12, '🍟', section: '사이드'),
    const MenuItem('잭슨 프라이즈', 11000, 680, 20, '🍟', section: '사이드'),
    const MenuItem('어니언링', 8000, 410, 5, '🧅', section: '사이드'),
    const MenuItem('코울슬로 샐러드', 3000, 150, 2, '🥗', section: '사이드'),
    const MenuItem('할라피뇨', 500, 10, 0, '🌶️', section: '사이드'),
    const MenuItem('홈메이드 피클', 500, 15, 0, '🥒', section: '사이드'),

    // ── 시그니처 소스 ──
    const MenuItem('홀스레디시 랜치 소스', 500, 70, 0, '🥣', section: '소스'),
    const MenuItem('케이준 소스', 500, 60, 0, '🥣', section: '소스'),

    // ── 음료 ──
    const MenuItem('생수 500ml', 1000, 0, 0, '💧', section: '음료'),
    const MenuItem('탄산수 325ml', 3000, 0, 0, '🫧', section: '음료'),
    const MenuItem('코카콜라 355ml', 3000, 150, 0, '🥤', section: '음료'),
    const MenuItem('제로콜라 355ml', 3000, 0, 0, '🥤', section: '음료'),
    const MenuItem('스프라이트 355ml', 3000, 140, 0, '🥤', section: '음료'),
    const MenuItem('닥터페퍼 355ml', 3000, 150, 0, '🥤', section: '음료'),
  ];

  /// ② 가게 종류별 샘플 메뉴판 (카카오 category 글자로 판단)
  static const Map<String, List<MenuItem>> _byType = {
    '분식': [
      MenuItem('떡볶이', 4500, 480, 8, '🍢'),
      MenuItem('치즈떡볶이', 5500, 620, 14, '🧀'),
      MenuItem('김밥', 3500, 480, 14, '🍙'),
      MenuItem('참치김밥', 4500, 550, 18, '🍙'),
      MenuItem('라면', 4000, 500, 10, '🍜'),
      MenuItem('순대', 4000, 380, 14, '🥟'),
      MenuItem('튀김 3개', 3000, 350, 6, '🍤'),
      MenuItem('계란 추가', 1000, 75, 6, '🥚'),
    ],
    '한식': [
      MenuItem('김치찌개', 8000, 620, 28, '🍲'),
      MenuItem('된장찌개', 8000, 580, 25, '🍲'),
      MenuItem('제육볶음', 9000, 750, 32, '🥩'),
      MenuItem('불고기덮밥', 9000, 700, 30, '🍛'),
      MenuItem('비빔밥', 8500, 600, 20, '🥗'),
      MenuItem('생선구이 정식', 10000, 600, 34, '🐟'),
      MenuItem('공기밥 추가', 1000, 300, 5, '🍚'),
    ],
    '돈까스': [
      MenuItem('등심돈까스', 9500, 900, 35, '🍱'),
      MenuItem('치즈돈까스', 10500, 1000, 38, '🧀'),
      MenuItem('생선까스', 9500, 780, 30, '🐟'),
      MenuItem('우동 세트', 3000, 450, 14, '🍜'),
    ],
    '일식': [
      MenuItem('연어덮밥', 12000, 640, 30, '🍣'),
      MenuItem('규동', 8500, 690, 26, '🍛'),
      MenuItem('우동', 7000, 450, 14, '🍜'),
      MenuItem('가라아게 덮밥', 9000, 780, 30, '🍗'),
      MenuItem('메밀소바', 8000, 480, 16, '🍜'),
    ],
    '중식': [
      MenuItem('짜장면', 7000, 800, 22, '🍜'),
      MenuItem('짬뽕', 8000, 700, 28, '🍜'),
      MenuItem('볶음밥', 8000, 700, 18, '🍚'),
      MenuItem('탕수육(소)', 14000, 900, 30, '🍖'),
      MenuItem('군만두', 5000, 420, 16, '🥟'),
    ],
    '치킨': [
      MenuItem('후라이드(반)', 10000, 1050, 68, '🍗'),
      MenuItem('양념(반)', 10500, 1150, 65, '🍗'),
      MenuItem('순살(소)', 11000, 900, 60, '🍗'),
      MenuItem('치킨 샐러드', 8000, 380, 32, '🥗'),
      MenuItem('콜라 500ml', 2000, 210, 0, '🥤'),
    ],
    '피자': [
      MenuItem('페퍼로니(R) 2조각', 6000, 560, 24, '🍕'),
      MenuItem('고르곤졸라(R) 2조각', 6500, 520, 20, '🍕'),
      MenuItem('치킨 샐러드', 7000, 380, 32, '🥗'),
      MenuItem('콜라 500ml', 2000, 210, 0, '🥤'),
    ],
    '햄버거': [
      MenuItem('불고기버거', 5000, 480, 18, '🍔'),
      MenuItem('치즈버거', 5500, 520, 25, '🍔'),
      MenuItem('그릴치킨버거', 6000, 450, 28, '🍔'),
      MenuItem('감자튀김(중)', 2500, 330, 4, '🍟'),
      MenuItem('제로콜라', 2000, 0, 0, '🥤'),
    ],
    '샐러드': [
      MenuItem('닭가슴살 샐러드', 9500, 380, 32, '🥗'),
      MenuItem('연어 포케', 12500, 560, 28, '🍣'),
      MenuItem('소고기 포케', 12500, 580, 32, '🥩'),
      MenuItem('두부 샐러드', 8500, 320, 18, '🥗'),
      MenuItem('그릭요거트 볼', 7500, 300, 15, '🥣'),
    ],
    '카페': [
      MenuItem('아메리카노', 3500, 10, 0, '☕'),
      MenuItem('카페라떼', 4500, 180, 8, '☕'),
      MenuItem('샌드위치', 5500, 350, 14, '🥪'),
      MenuItem('베이글+크림치즈', 4500, 400, 12, '🥯'),
      MenuItem('딸기 스무디', 5500, 230, 8, '🍓'),
    ],
    '국수': [
      MenuItem('잔치국수', 6000, 480, 15, '🍜'),
      MenuItem('칼국수', 8000, 560, 20, '🍜'),
      MenuItem('비빔국수', 7000, 560, 14, '🍜'),
      MenuItem('만두 6개', 5000, 420, 16, '🥟'),
    ],
    '고기': [
      MenuItem('삼겹살 1인분', 14000, 900, 40, '🥓'),
      MenuItem('목살 1인분', 14000, 800, 42, '🥩'),
      MenuItem('된장찌개', 3000, 200, 10, '🍲'),
      MenuItem('공기밥', 1000, 300, 5, '🍚'),
    ],
  };

  /// 기본 메뉴판 (종류를 못 알아냈을 때)
  static const List<MenuItem> _generic = [
    MenuItem('오늘의 정식', 9000, 650, 26, '🍱'),
    MenuItem('덮밥', 8500, 700, 28, '🍛'),
    MenuItem('국수', 7000, 500, 16, '🍜'),
    MenuItem('샐러드', 8000, 380, 25, '🥗'),
  ];

  /// 이 가게의 메뉴판 돌려주기
  /// 띄어쓰기 빼고 비교 ("행복한 찜닭" == "행복한찜닭")
  static String _norm(String s) => s.replaceAll(' ', '');

  /// 가게 이름에 맞는 제휴 키워드 찾기 — 여러 개 맞으면 가장 긴 키워드 우선
  /// (예: "백마모퉁이"는 '모퉁이'보다 '백마모퉁이'가 먼저)
  static String? _partnerKey(Place p) {
    final name = _norm(p.name);
    String? best;
    for (final k in partnerMenus.keys) {
      if (name.contains(_norm(k)) && (best == null || k.length > best.length)) best = k;
    }
    return best;
  }

  static List<MenuItem> forPlace(Place p) {
    // ① 제휴 가게?
    final key = _partnerKey(p);
    if (key != null) return partnerMenus[key]!;
    // ② 종류로 판단
    final text = '${p.category} ${p.name}';
    for (final e in _byType.entries) {
      if (text.contains(e.key)) return e.value;
    }
    if (text.contains('버거')) return _byType['햄버거']!;
    if (text.contains('커피') || text.contains('디저트') || text.contains('베이커리')) return _byType['카페']!;
    if (text.contains('찌개') || text.contains('백반') || text.contains('국밥')) return _byType['한식']!;
    if (text.contains('족발') || text.contains('갈비') || text.contains('구이')) return _byType['고기']!;
    if (text.contains('포케') || text.contains('샌드위치')) return _byType['샐러드']!;
    return _generic;
  }

  /// 제휴 가게인지 (진짜 메뉴가 있는지)
  static bool isPartner(Place p) => _partnerKey(p) != null;
}
