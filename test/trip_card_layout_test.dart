import 'package:flutter_test/flutter_test.dart';
import 'package:where_to_go_pick/features/trip/sample_trip.dart';
import 'package:where_to_go_pick/features/trip_card/trip_card_layout.dart';

void main() {
  group('layoutTripCard', () {
    test('체크인 수만큼 줄이 늘고 페이지가 길어진다', () {
      final one = layoutTripCard(2);
      final five = layoutTripCard(9);
      expect(one.rows, 1);
      expect(five.rows, 5);
      expect(five.pageHeight, greaterThan(one.pageHeight));
      expect(five.stops, hasLength(9));
    });

    test('줄마다 진행 방향이 바뀌고 줄 사이는 반원으로 꺾인다', () {
      final layout = layoutTripCard(5); // 3줄
      final arcs = layout.road.whereType<RoadArc>().toList();
      expect(arcs, hasLength(2));
      expect(arcs[0].clockwise, isTrue); // 첫 줄 끝은 오른쪽으로 꺾임
      expect(arcs[1].clockwise, isFalse); // 둘째 줄 끝은 왼쪽으로 꺾임

      // 첫 줄은 왼→오, 둘째 줄은 오→왼
      expect(layout.stops[0].x, lessThan(layout.stops[1].x));
      expect(layout.stops[2].x, greaterThan(layout.stops[3].x));
    });

    test('마지막 줄 방향에 따라 끝 깃발 위치가 정해진다', () {
      expect(layoutTripCard(2).endsOnRight, isTrue);
      expect(layoutTripCard(4).endsOnRight, isFalse);
      expect(layoutTripCard(6).endsOnRight, isTrue);
    });

    test('모든 장소가 페이지 폭 안에 놓인다', () {
      const config = TripCardLayoutConfig();
      for (final s in layoutTripCard(12).stops) {
        expect(s.x, inInclusiveRange(40, config.pageWidth - 40));
      }
    });

    test('긴 장소 이름도 옆 장소와 겹치지 않는 폭 안에 들어간다', () {
      final layout = layoutTripCard(4);
      final gap = (layout.stops[1].x - layout.stops[0].x).abs();
      expect(layout.labelMaxWidth, greaterThan(70));
      expect(gap - layout.labelMaxWidth, greaterThanOrEqualTo(8));
    });

    test('체크인이 없어도 길 한 줄은 그린다', () {
      final layout = layoutTripCard(0);
      expect(layout.rows, 1);
      expect(layout.stops, isEmpty);
    });
  });

  group('paginateTrip', () {
    final trip = sampleGangneungTrip();

    test('한 장에 모아보기는 모든 날을 한 장에 담는다', () {
      final pages = paginateTrip(trip, TripCardMode.onePage);
      expect(pages, hasLength(1));
      expect(pages.single.checkIns, hasLength(9));
    });

    test('하루씩 나눠보기는 날짜 수만큼 장을 만든다', () {
      final pages = paginateTrip(trip, TripCardMode.perDay);
      expect(pages, hasLength(3));
      expect(pages.map((p) => p.checkIns.length), [4, 3, 2]);
    });
  });
}
