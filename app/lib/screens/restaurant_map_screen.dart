import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../config/app_keys.dart';
import '../data/partner_menus.dart';
import '../data/partner_store_names.dart';
import '../services/kakao_local_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/food_thumb.dart';
import 'reservation_sheet.dart';

/// "식당 찾기" 탭: 내 위치 반경 1km 안의 식당을 지도 + 목록으로 표시
/// 지도 그림은 OpenStreetMap(무료, 키 필요 없음), 식당 데이터는 카카오에서 받아요.
class RestaurantMapScreen extends StatefulWidget {
  const RestaurantMapScreen({super.key});

  @override
  State<RestaurantMapScreen> createState() => _RestaurantMapScreenState();
}

class _RestaurantMapScreenState extends State<RestaurantMapScreen> {
  final _local = KakaoLocalService();
  final _keyword = TextEditingController();
  final _mapController = MapController();
  bool _mapReady = false;

  // GPS를 못 받으면 여기(백마 학원가 근처)를 기준으로 찾아요
  static const _fallbackLat = 37.6595;
  static const _fallbackLng = 126.7855;

  // ── 검색 구역 ──
  // "백마 학원가"는 GPS와 상관없이 항상 학원가 블록만 (백마역 남쪽 마두동 학원가 중심 · 반경 420m)
  // "내 주변"은 내 위치 반경 1km
  static const _zoneLat = 37.6562;
  static const _zoneLng = 126.7893;
  static const _zoneRadiusM = 420;
  static const _nearbyRadiusM = 1000;
  static const _zoom = 14.4; // 1km 원이 화면에 딱 들어오는 정도

  // (아이콘, 검색어, 라벨) — 검색어가 비면 "전체"
  static const _categories = [
    (Icons.restaurant_rounded, '', '전체'),
    (Icons.rice_bowl_rounded, '덮밥', '덮밥'),
    (Icons.ramen_dining_rounded, '국수', '국수'),
    (Icons.tapas_rounded, '분식', '분식'),
    (Icons.eco_rounded, '샐러드', '샐러드'),
    (Icons.lunch_dining_rounded, '햄버거', '버거'),
    (Icons.kebab_dining_rounded, '치킨', '치킨'),
    (Icons.set_meal_rounded, '돈까스', '돈까스'),
    (Icons.soup_kitchen_rounded, '국밥', '국밥'),
    (Icons.local_cafe_rounded, '카페', '카페'),
  ];

  double _lat = _fallbackLat;
  double _lng = _fallbackLng;
  bool _usingFallback = true;
  bool _hakwonga = true; // true = 백마 학원가만, false = 내 주변 1km
  bool _partnerMode = false; // true = ⭐ 제휴 가게(메뉴판 있는 곳)만 이름으로 찾아서 보여줘요
  List<Place>? _partnerCache; // 제휴 가게 목록은 한 번 찾으면 기억해둬요 (카카오 요청 아끼기)
  static const _partnerRadiusM = 2500; // 학원가 중심에서 이 안에 있는 제휴 가게만

  // 지금 구역의 중심·반경 (모든 검색·지도 그리기가 이걸 써요)
  double get _cLat => _hakwonga ? _zoneLat : _lat;
  double get _cLng => _hakwonga ? _zoneLng : _lng;
  int get _radiusM => _hakwonga ? _zoneRadiusM : _nearbyRadiusM;
  String get _zoneLabel => _partnerMode ? '제휴 가게' : _hakwonga ? '백마 학원가' : '내 주변 1km';

  List<Place> _places = [];
  bool _loading = false;
  String? _error;
  // 학원가 안에서 못 찾아서 근처(1.5km)까지 넓혀 찾았는지
  bool _widened = false;
  static const _widenRadiusM = 1500;
  String? _selectedId; // 목록/핀에서 고른 식당

  // 검색하기 전 목록을 기억해뒀다가 "← 뒤로" 누르면 되돌려요
  List<Place>? _beforeSearch;
  bool get _isSearching => _keyword.text.trim().isNotEmpty;

  /// ← 뒤로: 검색어 지우고 검색 전 목록으로
  void _backToList() {
    final prev = _beforeSearch;
    _keyword.clear();
    FocusScope.of(context).unfocus();
    if (prev != null) {
      setState(() {
        _places = prev;
        _widened = false;
        _selectedId = null;
        _beforeSearch = null;
      });
      _moveMapToCenter();
    } else {
      _search(); // 기억해둔 게 없으면 전체 목록 다시 받아오기
    }
  }

  @override
  void initState() {
    super.initState();
    _locateThenSearch();
  }

  @override
  void dispose() {
    _keyword.dispose();
    _mapController.dispose();
    super.dispose();
  }

  /// 1) 내 위치 알아내기 → 2) 그 주변 식당 검색
  Future<void> _locateThenSearch() async {
    setState(() => _loading = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition().timeout(const Duration(seconds: 10));
        _lat = pos.latitude;
        _lng = pos.longitude;
        _usingFallback = false;
      }
    } catch (_) {
      // 위치를 못 받아도 괜찮아요. 기본 위치로 계속 진행.
    }
    await _search();
  }

  /// ⭐ 제휴 가게 전부 찾기: 메뉴판이 있는 가게 이름을 하나씩 카카오에 물어봐요
  Future<List<Place>> _findPartners() async {
    if (_partnerCache != null) return _partnerCache!;
    final names = PartnerStoreNames.byKey.values.toSet().toList();
    // 한 번에 다 보내면 카카오가 막을 수 있어서 12개씩 끊어서 보내요
    final results = <List<Place>>[];
    for (var i = 0; i < names.length; i += 12) {
      final chunk = names.sublist(i, (i + 12).clamp(0, names.length));
      results.addAll(await Future.wait(
        chunk.map((n) => _local.searchByName(name: n, lat: _zoneLat, lng: _zoneLng, radiusM: _partnerRadiusM)),
      ));
    }
    final seen = <String>{};
    final out = <Place>[];
    for (final list in results) {
      for (final p in list) {
        // 진짜 제휴 가게(메뉴판이 매칭되는 곳)만, 같은 가게는 한 번만
        if (!MenuCatalog.isPartner(p) || !seen.add(p.id)) continue;
        out.add(p);
      }
    }
    out.sort((a, b) => a.distanceM.compareTo(b.distanceM));
    _partnerCache = out;
    return out;
  }

  Future<void> _search() async {
    // 검색어로 찾기 시작할 때, 검색 전 "전체 목록"을 한 번 기억해둬요
    if (_isSearching) {
      _beforeSearch ??= List.of(_places);
    } else {
      _beforeSearch = null;
    }
    setState(() {
      _loading = true;
      _error = null;
      _selectedId = null;
    });
    try {
      if (_partnerMode) {
        // 제휴 가게 모드: 전체를 받아온 뒤 검색어로만 걸러요
        var all = await _findPartners();
        final q = _keyword.text.trim().replaceAll(' ', '');
        if (q.isNotEmpty) {
          all = all.where((p) => '${p.name}${p.category}'.replaceAll(' ', '').contains(q)).toList();
        }
        setState(() {
          _places = all;
          _widened = false;
        });
        _moveMapToCenter();
        return;
      }
      var places = await _local.searchNearby(
        lat: _cLat,
        lng: _cLng,
        keyword: _keyword.text,
        radiusM: _radiusM,
      );
      var widened = false;
      // 학원가 구역 안에서 검색어로 못 찾았으면 → 근처 1.5km까지 한 번 더 찾아보기
      // (예: "교촌치킨 백마강촌점"처럼 학원가 블록 바로 바깥에 있는 가게)
      if (places.isEmpty && _hakwonga && _keyword.text.trim().isNotEmpty) {
        places = await _local.searchNearby(
          lat: _zoneLat,
          lng: _zoneLng,
          keyword: _keyword.text,
          radiusM: _widenRadiusM,
        );
        widened = places.isNotEmpty;
      }
      setState(() {
        _places = places;
        _widened = widened;
      });
      _moveMapToCenter();
      // 검색어 없이 찾은 "전체 목록"은 AI 추천이 쓸 수 있게 기억해둬요
      if (_keyword.text.trim().isEmpty && mounted) {
        context.read<AppState>().setNearbyPlaces(places, _cLat, _cLng);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _moveMapToCenter() {
    if (!_mapReady) return;
    try {
      _mapController.move(LatLng(_cLat, _cLng), _partnerMode ? 14.6 : _hakwonga ? 16 : _zoom);
    } catch (_) {}
  }

  void _openReservation(Place place) {
    setState(() => _selectedId = place.id);
    try {
      _mapController.move(LatLng(place.lat, place.lng), 16);
    } catch (_) {}
    showReservationSheet(context, place);
  }

  // ───── 지도 위에 올릴 것들 ─────
  List<Marker> get _markers {
    final list = <Marker>[
      // 내 위치 (또는 기준점)
      Marker(
        point: LatLng(_lat, _lng),
        width: 22,
        height: 22,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.sky,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
          ),
        ),
      ),
    ];
    for (var i = 0; i < _places.length; i++) {
      final p = _places[i];
      final selected = p.id == _selectedId;
      list.add(
        Marker(
          point: LatLng(p.lat, p.lng),
          width: 34,
          height: 34,
          child: GestureDetector(
            onTap: () => _openReservation(p),
            child: Container(
              decoration: BoxDecoration(
                color: selected ? AppColors.ink : AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
              ),
              alignment: Alignment.center,
              child: Text(
                '${i + 1}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ),
          ),
        ),
      );
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('내 주변 1km 식당')),
      body: Column(
        children: [
          // ───── 검색창 ─────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: AppColors.cardShadow),
              child: TextField(
                controller: _keyword,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                onChanged: (_) => setState(() {}), // 글자가 바뀌면 ← / ✕ 버튼이 바로 바뀌게
                decoration: InputDecoration(
                  hintText: '덮밥, 국수, 롯데리아...',
                  // 검색 중이면 ← 뒤로, 아니면 🔍
                  prefixIcon: _isSearching
                      ? IconButton(
                          tooltip: '뒤로 (전체 목록으로)',
                          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
                          onPressed: _backToList,
                        )
                      : const Icon(Icons.search, color: AppColors.primary),
                  // 검색 중이면 ✕ 지우기, 아니면 내 위치
                  suffixIcon: _isSearching
                      ? IconButton(
                          tooltip: '지우기',
                          icon: const Icon(Icons.close_rounded, color: AppColors.muted),
                          onPressed: _backToList,
                        )
                      : IconButton(
                          tooltip: '내 위치로',
                          icon: const Icon(Icons.my_location, color: AppColors.muted),
                          onPressed: _locateThenSearch,
                        ),
                ),
              ),
            ),
          ),

          // ───── 구역 선택: 백마 학원가만 / 내 주변 1km (좁은 폰에선 옆으로 밀어서 봐요) ─────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                _ZoneChip(
                  icon: Icons.school_rounded,
                  label: '백마 학원가',
                  selected: _hakwonga && !_partnerMode,
                  onTap: () {
                    if (_hakwonga && !_partnerMode) return;
                    setState(() {
                      _hakwonga = true;
                      _partnerMode = false;
                    });
                    _search();
                  },
                ),
                const SizedBox(width: 8),
                _ZoneChip(
                  icon: Icons.my_location_rounded,
                  label: '내 주변 1km',
                  selected: !_hakwonga && !_partnerMode,
                  onTap: () {
                    if (!_hakwonga && !_partnerMode) return;
                    setState(() {
                      _hakwonga = false;
                      _partnerMode = false;
                    });
                    _locateThenSearch();
                  },
                ),
                const SizedBox(width: 8),
                _ZoneChip(
                  icon: Icons.star_rounded,
                  label: '제휴 가게',
                  selected: _partnerMode,
                  onTap: () {
                    if (_partnerMode) return;
                    setState(() {
                      _hakwonga = true; // 지도 중심은 학원가
                      _partnerMode = true;
                    });
                    _search();
                  },
                ),
              ],
            ),
          ),

          // ───── 카테고리 칩 (배달앱처럼) ─────
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final c = _categories[i];
                final selected = _keyword.text.trim() == c.$2;
                return ChoiceChip(
                  avatar: Icon(c.$1, size: 18, color: selected ? Colors.white : AppColors.primaryDark),
                  label: Text(c.$3),
                  selected: selected,
                  showCheckmark: false,
                  onSelected: (_) {
                    _keyword.text = c.$2;
                    _search();
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // ───── 지도 ─────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: SizedBox(
                height: 250,
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: LatLng(_cLat, _cLng),
                        initialZoom: _zoom,
                        onMapReady: () {
                          _mapReady = true;
                          _moveMapToCenter();
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.hankki.hankki',
                        ),
                        CircleLayer(
                          circles: [
                            CircleMarker(
                              point: LatLng(_cLat, _cLng),
                              radius: (_partnerMode ? _partnerRadiusM : _radiusM).toDouble(),
                              useRadiusInMeter: true,
                              color: AppColors.primary.withOpacity(0.08),
                              borderColor: AppColors.primary,
                              borderStrokeWidth: 2,
                            ),
                          ],
                        ),
                        MarkerLayer(markers: _markers),
                        SimpleAttributionWidget(
                          source: const Text('OpenStreetMap', style: TextStyle(fontSize: 10)),
                        ),
                      ],
                    ),
                    if (_usingFallback && !_hakwonga)
                      Positioned(
                        left: 12,
                        top: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999), boxShadow: AppColors.cardShadow),
                          child: const Text('📍 기준: 백마 학원가', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                        ),
                      ),
                    if (!AppKeys.kakaoReady)
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: AppColors.sun.withOpacity(0.9), borderRadius: BorderRadius.circular(12)),
                          child: const Text('카카오 REST 키를 넣으면 식당이 검색돼요 (lib/config/app_keys.dart)', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ───── 목록 ─────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _Message(icon: Icons.wifi_off, text: _error!)
                    : _places.isEmpty
                        ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            _Message(icon: Icons.search_off, text: _partnerMode
                            ? (_keyword.text.trim().isEmpty
                                ? '제휴 가게를 못 찾았어요. 카카오 키·인터넷을 확인해봐요.'
                                : '"${_keyword.text.trim()}" 이름의 제휴 가게가 없어요.')
                            : _hakwonga && _keyword.text.trim().isNotEmpty
                            ? '학원가 안과 근처 1.5km 모두 못 찾았어요.\n가게 이름을 다르게 써보거나 📍 내 주변으로 바꿔봐요.'
                            : '$_zoneLabel 안에서 못 찾았어요.\n다른 말로 검색해봐요.'),
                            if (_isSearching)
                              TextButton.icon(
                                onPressed: _backToList,
                                icon: const Icon(Icons.arrow_back_rounded),
                                label: const Text('전체 목록으로 돌아가기'),
                              ),
                          ])
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                            itemCount: _places.length + 1, // 맨 위 한 칸은 "N곳" 안내
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (_, index) {
                              if (index == 0) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(children: [
                                    if (_isSearching) ...[
                                      InkWell(
                                        onTap: _backToList,
                                        borderRadius: BorderRadius.circular(999),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(color: AppColors.mint, borderRadius: BorderRadius.circular(999)),
                                          child: const Text('← 전체 목록', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Expanded(child: Text(
                                    _partnerMode
                                        ? '⭐ 메뉴판 있는 제휴 가게 ${_places.length}곳 · 학원가에서 가까운 순${_keyword.text.trim().isEmpty ? '' : ' · "${_keyword.text.trim()}"'}'
                                        : _keyword.text.trim().isEmpty
                                        ? '$_zoneLabel 식당 ${_places.length}곳 · 가까운 순'
                                        : _widened
                                            ? '"${_keyword.text.trim()}" ${_places.length}곳 · 학원가 안엔 없어서 근처 1.5km에서 찾았어요'
                                            : '"${_keyword.text.trim()}" ${_places.length}곳 · 가까운 순',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  )),
                                  ]),
                                );
                              }
                              final i = index - 1;
                              final p = _places[i];
                              final selected = p.id == _selectedId;
                              return InkWell(
                                onTap: () => _openReservation(p),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: AppColors.cardShadow,
                                    border: selected ? Border.all(color: AppColors.primary, width: 2) : null,
                                  ),
                                  child: Row(
                                    children: [
                                      Stack(
                                        children: [
                                          FoodThumb(category: p.category, size: 64),
                                          Positioned(
                                            left: 4,
                                            top: 4,
                                            child: Container(
                                              width: 22,
                                              height: 22,
                                              decoration: BoxDecoration(color: selected ? AppColors.ink : AppColors.primary, shape: BoxShape.circle),
                                              alignment: Alignment.center,
                                              child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(p.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                                            const SizedBox(height: 4),
                                            Text(p.address, style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                _Tag(p.shortCategory.isEmpty ? '음식점' : p.shortCategory, AppColors.paper, AppColors.ink),
                                                const SizedBox(width: 6),
                                                _Tag('🚶 ${p.distanceText}', AppColors.mint, AppColors.green),
                                                const SizedBox(width: 6),
                                                if (MenuCatalog.isPartner(p))
                                                  _Tag('⭐ 제휴 · 선주문', AppColors.primary, Colors.white)
                                                else
                                                  _Tag('🍽 선주문', AppColors.peach, AppColors.primaryDark),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
                                        child: const Text('예약', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Message({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 36, color: AppColors.muted),
              const SizedBox(height: 10),
              Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      );
}

class _Tag extends StatelessWidget {
  final String text;
  final Color bg, fg;
  const _Tag(this.text, this.bg, this.fg);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w800)),
      );
}


/// 구역 선택 칩 (선택되면 초록으로 꽉 차요)
class _ZoneChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  const _ZoneChip({required this.label, required this.selected, required this.onTap, this.icon});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? AppColors.primary : AppColors.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: selected ? Colors.white : AppColors.primaryDark),
                const SizedBox(width: 5),
              ],
              Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: selected ? Colors.white : AppColors.ink)),
            ],
          ),
        ),
      );
}
