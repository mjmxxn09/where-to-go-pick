import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:where_to_go_pick/features/korea_map/korea_map_data.dart';

void main() {
  final data = KoreaMapData.fromJson(
    jsonDecode(File(KoreaMapData.assetPath).readAsStringSync()) as Map<String, dynamic>,
  );

  test('경상북도 지도에선 울릉도·독도 상자가 울진 앞바다(오른쪽 위)에 있다', () {
    final gb = data.details['37']!;
    final box = gb.inset!.bounds;
    expect(box.topLeft, ProvinceDetail.seaInsetTopLeft);
    // 상자가 들어가게 지도 칸이 넓어지고, 상자는 경상북도 땅 오른쪽 끝보다 오른쪽에서 시작한다
    expect(gb.size.width, greaterThanOrEqualTo(box.right + 12));
    final land = gb.cities.map((c) => c.path.getBounds()).reduce((a, b) => a.expandToInclude(b));
    expect(box.left, greaterThan(land.left + land.width * 0.85));
    // 상자 안에서 섬 그림도 같이 옮겨졌다
    expect(box.inflate(1).contains(gb.inset!.path.getBounds().center), isTrue);
  });

  test('다른 도는 크기 그대로, 전국 지도의 상자는 그대로', () {
    expect(data.details['32']!.size, KoreaMapData.detailSize);
    expect(data.overviewInset!.bounds, const Rect.fromLTRB(299, 8, 331.6, 25.6));
  });
}
