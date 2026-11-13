import 'package:flutter_test/flutter_test.dart';
import 'package:where_to_go_pick/features/trip/sample_trip.dart';
import 'package:where_to_go_pick/features/trip_card/trip_card_layout.dart';

void main() {
  group('layoutTripCard', () {
    test('체크인 수만큼 줄이 늘고 페이지가 길어진다 (한 줄에 3곳)', () {
      final one = layoutTripCard(3);
      final three = layoutTripCard(9);
      expect(one.rows, 1);
      expect(three.rows, 3);
      expect(layoutTripCard(10).rows, 4);
      expect(three.pageHeight, greaterThan(one.pageHeight));
      expect(three.stops, hasLength(9));
    });

    test('줄마다 진행 방향이 바뀌고 줄 사이는 반원으로 꺾인다', () {
      final layout = layoutTripCard(7); // 3줄
      final arcs = layout.road.whereType<RoadArc>().toList();
      expect(arcs, hasLength(2));
      expect(arcs[0].clockwise, isTrue); // 첫 줄 끝은 오른쪽으로 꺾임
      expect(arcs[1].clockwise, isFalse); // 둘째 줄 끝은 왼쪽으로 꺾임

      // 첫 줄은 왼→오, 둘째 줄은 오→왼
      expect(layout.stops[0].x, lessThan(layout.stops[1].x));
      expect(layout.stops[3].x, greaterThan(layout.stops[4].x));
    });

    test('이름은 길 아래·위를 번갈아 쓴다(첫 장소는 아래)', () {
      final layout = layoutTripCard(6);
      expect(layout.stops.map((s) => s.labelAbove), [false, true, false, true, false, true]);
    });

    test('같은 쪽 이웃 이름과 겹치지 않는 폭이 확보된다', () {
      final layout = layoutTripCard(3);
      final sameSideGap = (layout.stops[2].x - layout.stops[0].x).abs();
      expect(layout.labelMaxWidth, greaterThan(80));
      expect(sameSideGap - layout.labelMaxWidth, greaterThanOrEqualTo(7.99));
    });

    test('반원마다 그림 자리가 하나씩 있고, 줄 끝 이름과 겹치지 않는다', () {
      const config = TripCardLayoutConfig();
      final layout = layoutTripCard(9);
      expect(layout.stickers, hasLength(layout.rows - 1));
      for (final st in layout.stickers) {
        expect(st.maxWidth, greaterThan(36));
        final left = st.centerX - st.maxWidth / 2;
        final right = st.centerX + st.maxWidth / 2;
        final labelsLeft = config.stopsLeft + config.slotWidth / 2 - config.labelMaxWidth / 2;
        final labelsRight = config.stopsRight - config.slotWidth / 2 + config.labelMaxWidth / 2;
        expect(right <= labelsLeft || left >= labelsRight, isTrue, reason: 'sticker ${st.afterRow}');
        expect(left, greaterThanOrEqualTo(0));
        expect(right, lessThanOrEqualTo(config.pageWidth));
      }
    });

    test('마지막 줄 방향에 따라 끝 깃발 위치가 정해진다', () {
      expect(layoutTripCard(3).endsOnRight, isTrue);
      expect(layoutTripCard(4).endsOnRight, isFalse);
      expect(layoutTripCard(7).endsOnRight, isTrue);
    });

    test('모든 장소가 페이지 폭 안에 놓인다', () {
      const config = TripCardLayoutConfig();
      for (final s in layoutTripCard(12).stops) {
        expect(s.x, inInclusiveRange(40, config.pageWidth - 40));
      }
    });

    test('체크인이 없어도 길 한 줄은 그린다', () {
      final layout = layoutTripCard(0);
      expect(layout.rows, 1);
      expect(layout.stops, isEmpty);
      expect(layout.stickers, isEmpty);
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
