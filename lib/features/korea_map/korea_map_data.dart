import 'dart:convert';
import 'dart:ui';

import 'package:flutter/services.dart';

import 'svg_path.dart';

/// `assets/maps/korea-map.json`을 읽은 결과.
///
/// 데이터 출처: 통계청 SGIS 행정구역 경계(2018), 공공누리 제1유형 — 앱 안에 출처 표시가 필요하다.
/// southkorea-maps 저장소의 가공본을 다시 단순화했고, 일반구는 시 단위로 합쳤다.
/// 좌표는 이미 화면 좌표(전국 340×400, 도 상세 340×380)로 투영돼 있다.
class KoreaMapData {
  const KoreaMapData({
    required this.source,
    required this.overviewSize,
    required this.provinces,
    required this.overviewInset,
    required this.details,
  });

  static const assetPath = 'assets/maps/korea-map.json';
  static const detailSize = Size(340, 380);

  static Future<KoreaMapData> load(AssetBundle bundle) async =>
      KoreaMapData.fromJson(jsonDecode(await bundle.loadString(assetPath)) as Map<String, dynamic>);

  factory KoreaMapData.fromJson(Map<String, dynamic> json) {
    final overview = json['overview'] as Map<String, dynamic>;
    final provinces = (overview['regions'] as List<dynamic>)
        .map((e) => MapRegion.fromJson(e as Map<String, dynamic>, isProvince: true))
        .toList();
    final details = <String, ProvinceDetail>{};
    (json['provinces'] as Map<String, dynamic>).forEach((code, value) {
      details[code] = ProvinceDetail.fromJson(code, value as Map<String, dynamic>);
    });
    return KoreaMapData(
      source: json['source'] as String? ?? '',
      overviewSize: Size((overview['w'] as num).toDouble(), (overview['h'] as num).toDouble()),
      provinces: provinces,
      overviewInset: MapInset.maybeFromJson(overview['inset'] as Map<String, dynamic>?),
      details: details,
    );
  }

  final String source;
  final Size overviewSize;
  final List<MapRegion> provinces;
  final MapInset? overviewInset;
  final Map<String, ProvinceDetail> details;

  MapRegion? province(String code) {
    for (final p in provinces) {
      if (p.id == code) return p;
    }
    return null;
  }
}

/// 도·광역시(전국 지도) 또는 시·군·구(도 상세 지도) 한 칸.
class MapRegion {
  MapRegion({
    required this.id,
    required this.name,
    required this.shortName,
    required this.fill,
    required this.path,
    required this.label,
    required this.showLabel,
    required this.small,
  });

  factory MapRegion.fromJson(Map<String, dynamic> json, {required bool isProvince}) => MapRegion(
        id: json['id'] as String,
        name: json['name'] as String,
        shortName: (json['short'] as String?) ?? json['name'] as String,
        fill: _hex(json['fill'] as String),
        path: pathFromSvg(json['d'] as String),
        label: Offset((json['lx'] as num).toDouble(), (json['ly'] as num).toDouble()),
        showLabel: isProvince || (json['label'] as bool? ?? true),
        small: json['small'] as bool? ?? false,
      );

  /// 도: 통계청 2자리 코드(예: 32). 시·군·구: 5자리 코드 또는 합친 시는 `31:수원시` 형태.
  final String id;
  final String name;
  final String shortName;
  final Color fill;
  final Path path;
  final Offset label;

  /// 작은 시·군·구는 겹치지 않도록 이름을 숨기고, 선택했을 때만 보여 준다.
  final bool showLabel;
  final bool small;

  /// 이 지역이 속한 도 코드(앞 2자리).
  String get provinceCode => id.substring(0, 2);
}

class ProvinceDetail {
  ProvinceDetail({
    required this.code,
    required this.name,
    required this.shortName,
    required this.cities,
    required this.context,
    required this.inset,
  });

  factory ProvinceDetail.fromJson(String code, Map<String, dynamic> json) {
    final ctx = json['context'] as String?;
    return ProvinceDetail(
      code: code,
      name: json['name'] as String,
      shortName: json['short'] as String,
      cities: (json['cities'] as List<dynamic>)
          .map((e) => MapRegion.fromJson(e as Map<String, dynamic>, isProvince: false))
          .toList(),
      context: ctx == null || ctx.isEmpty ? null : pathFromSvg(ctx),
      inset: MapInset.maybeFromJson(json['inset'] as Map<String, dynamic>?),
    );
  }

  final String code;
  final String name;
  final String shortName;
  final List<MapRegion> cities;

  /// 주변 도를 흐리게 깔아 위치감을 주는 배경.
  final Path? context;

  /// 울릉도·독도처럼 멀리 떨어진 섬을 따로 그린 상자.
  final MapInset? inset;
}

class MapInset {
  MapInset({required this.path, required this.bounds, required this.label});

  static MapInset? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final b = (json['box'] as List<dynamic>).map((e) => (e as num).toDouble()).toList();
    return MapInset(
      path: pathFromSvg(json['d'] as String),
      bounds: Rect.fromLTRB(b[0], b[1], b[2], b[3]),
      label: json['label'] as String? ?? '울릉도·독도',
    );
  }

  final Path path;
  final Rect bounds;
  final String label;
}

Color _hex(String hex) => Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
