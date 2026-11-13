import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:where_to_go_pick/app/app.dart';
import 'package:where_to_go_pick/core/config/app_config.dart';
import 'package:where_to_go_pick/features/korea_map/korea_map_data.dart';

/// 서버 없이(예시 데이터) 앱이 뜨고 4개 탭이 보이는지 확인하는 연기 테스트.
/// 실제 지도 파일 대신 사각형 두 개짜리 작은 지도를 쓴다.
KoreaMapData _tinyMap() => KoreaMapData.fromJson({
    'source': 'test',
    'overview': {
      'w': 340,
      'h': 400,
      'regions': [
        {'id': '11', 'short': '서울', 'name': '서울특별시', 'fill': '#FFD3E2', 'd': 'M10 10L100 10L100 100L10 100Z', 'lx': 55, 'ly': 55},
        {'id': '32', 'short': '강원', 'name': '강원특별자치도', 'fill': '#C8EED6', 'd': 'M110 10L200 10L200 100L110 100Z', 'lx': 155, 'ly': 55},
      ],
      'inset': null,
    },
    'provinces': {
      '32': {
        'short': '강원',
        'name': '강원특별자치도',
        'context': '',
        'inset': null,
        'cities': [
          {'id': '32030', 'name': '강릉시', 'fill': '#CFE3FF', 'd': 'M10 10L300 10L300 300L10 300Z', 'lx': 150, 'ly': 150, 'label': true},
        ],
      },
    },
  });

void main() {
  testWidgets('예시 데이터로 앱이 열린다', (tester) async {
    await tester.pumpWidget(WhereToGoPickApp(
      config: const AppConfig(pickleApiBaseUrl: '', lifeApiBaseUrl: '', appVersion: 'test'),
      mapData: Future.value(_tinyMap()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('내 여행 지도'), findsWidgets);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('여행지'), findsOneWidget);
  });
}
