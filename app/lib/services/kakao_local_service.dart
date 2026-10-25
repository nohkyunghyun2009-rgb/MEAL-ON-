import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../config/app_keys.dart';
import '../data/hidden_stores.dart';

/// 카카오가 알려주는 "장소 한 곳"
class Place {
  final String id;
  final String name;
  final String category; // 예: 음식점 > 한식 > 덮밥
  final String address;
  final String phone;
  final double lat;
  final double lng;
  final int distanceM; // 나와의 거리(m)
  final String url; // 카카오맵 상세 페이지

  const Place({
    required this.id,
    required this.name,
    required this.category,
    required this.address,
    required this.phone,
    required this.lat,
    required this.lng,
    required this.distanceM,
    required this.url,
  });

  /// "음식점 > 한식 > 덮밥" 에서 마지막 "덮밥"만 꺼내기
  String get shortCategory {
    final parts = category.split('>').map((s) => s.trim()).toList();
    return parts.isEmpty ? '' : parts.last;
  }

  String get distanceText =>
      distanceM >= 1000 ? '${(distanceM / 1000).toStringAsFixed(1)}km' : '${distanceM}m';

  /// 거리만 바꾼 복사본 (내 위치 기준으로 다시 잰 값을 넣을 때)
  Place withDistance(int d) => Place(
        id: id,
        name: name,
        category: category,
        address: address,
        phone: phone,
        lat: lat,
        lng: lng,
        distanceM: d,
        url: url,
      );

  factory Place.fromKakao(Map<String, dynamic> d) => Place(
        id: d['id'] as String,
        name: d['place_name'] as String,
        category: (d['category_name'] ?? '') as String,
        address: ((d['road_address_name'] as String?)?.isNotEmpty ?? false)
            ? d['road_address_name'] as String
            : (d['address_name'] ?? '') as String,
        phone: (d['phone'] ?? '') as String,
        lat: double.parse(d['y'] as String),
        lng: double.parse(d['x'] as String),
        distanceM: int.tryParse((d['distance'] ?? '0') as String) ?? 0,
        url: (d['place_url'] ?? '') as String,
      );
}

/// 카카오 로컬 API로 "내 주변 1km 음식점" 찾기
///
/// ⚠️ 카카오 검색은 한 번에 **최대 45곳**(15개 × 3페이지)까지만 알려줘요.
/// 학원가처럼 1km 안에 100곳 넘게 있으면 잘려 나가요.
/// 그래서 1km 원을 **작은 구역 여러 개(바둑판)** 로 쪼개서 구역마다 따로 검색하고,
/// 결과를 합친 뒤 같은 가게는 하나로 정리해요. 그러면 빠짐없이 다 나와요.
class KakaoLocalService {
  Future<List<Place>> searchNearby({
    required double lat,
    required double lng,
    String keyword = '',
    int radiusM = 1000,
  }) async {
    if (!AppKeys.kakaoReady) {
      throw Exception('카카오 키가 아직 없어요. lib/config/app_keys.dart 를 확인하세요.');
    }

    // ── 1) 바둑판 칸 만들기 ──
    // 500m 간격으로 점을 찍고, 각 점에서 반경 380m 검색 (칸을 원이 덮도록 살짝 크게)
    const step = 500.0;
    const subRadius = 380;
    final centers = <(double, double)>[];
    for (double dy = -radiusM + step / 2; dy <= radiusM; dy += step) {
      for (double dx = -radiusM + step / 2; dx <= radiusM; dx += step) {
        // 원 밖 칸은 건너뛰기 (칸 중심이 원에서 너무 멀면)
        if (sqrt(dx * dx + dy * dy) > radiusM + step / 2) continue;
        centers.add(_offset(lat, lng, dx, dy));
      }
    }

    // ── 2) 칸마다 동시에 검색 (한 칸당 최대 45곳) ──
    final results = await Future.wait(
      centers.map((c) => _searchOne(lat: c.$1, lng: c.$2, keyword: keyword, radiusM: subRadius)),
    );

    // ── 3) 합치고 중복 제거, 진짜 거리(내 위치 기준)로 다시 계산 ──
    final seen = <String>{};
    final all = <Place>[];
    for (final list in results) {
      for (final p in list) {
        if (!seen.add(p.id)) continue;
        if (HiddenStores.isHidden(p.name)) continue; // 숨김 목록에 있는 가게는 빼요
        final d = _distanceM(lat, lng, p.lat, p.lng).round();
        if (d > radiusM) continue; // 1km 밖은 빼기
        all.add(p.withDistance(d));
      }
    }
    all.sort((a, b) => a.distanceM.compareTo(b.distanceM));
    return all;
  }

  /// 가게 이름으로 찾기 (제휴 가게 목록용) — 중심에서 radiusM 안, 가까운 순 최대 15곳
  Future<List<Place>> searchByName({
    required String name,
    required double lat,
    required double lng,
    int radiusM = 2500,
  }) async {
    if (!AppKeys.kakaoReady) return [];
    try {
      final found = await _searchOne(lat: lat, lng: lng, keyword: name, radiusM: radiusM, maxPages: 1);
      return found
          .where((p) => !HiddenStores.isHidden(p.name))
          .map((p) => p.withDistance(_distanceM(lat, lng, p.lat, p.lng).round()))
          .toList();
    } catch (_) {
      return []; // 한 가게가 실패해도 나머지는 계속
    }
  }

  /// 한 칸 검색: 카카오가 주는 최대 3페이지(45곳)까지 받아요
  Future<List<Place>> _searchOne({
    required double lat,
    required double lng,
    required String keyword,
    required int radiusM,
    int maxPages = 3,
  }) async {
    final q = keyword.trim();
    final out = <Place>[];
    for (var page = 1; page <= maxPages; page++) {
      final params = {
        'x': '$lng', // 카카오는 x가 경도(lng), y가 위도(lat)예요
        'y': '$lat',
        'radius': '$radiusM',
        'category_group_code': 'FD6', // FD6 = 음식점
        'sort': 'distance',
        'size': '15',
        'page': '$page',
      };
      final uri = q.isEmpty
          ? Uri.https('dapi.kakao.com', '/v2/local/search/category.json', params)
          : Uri.https('dapi.kakao.com', '/v2/local/search/keyword.json', {...params, 'query': q});

      final res = await http.get(uri, headers: {
        'Authorization': 'KakaoAK ${AppKeys.kakaoRestApiKey}',
      }).timeout(const Duration(seconds: 20));

      if (res.statusCode != 200) {
        throw Exception('카카오 검색 오류 (${res.statusCode}): ${utf8.decode(res.bodyBytes)}');
      }
      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final docs = data['documents'] as List<dynamic>;
      for (final d in docs) {
        out.add(Place.fromKakao(d as Map<String, dynamic>));
      }
      final meta = data['meta'] as Map<String, dynamic>?;
      if (meta?['is_end'] == true || docs.isEmpty) break;
    }
    return out;
  }

  /// 기준점에서 동쪽으로 dx미터, 북쪽으로 dy미터 떨어진 위도·경도
  static (double, double) _offset(double lat, double lng, double dx, double dy) {
    const mPerDegLat = 111320.0;
    final mPerDegLng = 111320.0 * cos(lat * pi / 180);
    return (lat + dy / mPerDegLat, lng + dx / mPerDegLng);
  }

  /// 두 좌표 사이 거리(m) — 하버사인 공식
  static double _distanceM(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLng = (lng2 - lng1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLng / 2) * sin(dLng / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }
}
