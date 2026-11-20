import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:where_to_go_pick/features/trip/sample_trip.dart';
import 'package:where_to_go_pick/features/trip_card/card_stickers.dart';
import 'package:where_to_go_pick/features/trip_card/sticker_book.dart';
import 'package:where_to_go_pick/features/trip_card/trip_card_layout.dart';

void main() {
  group('PlacedSticker', () {
    test('회전한 스티커도 그림 안쪽만 눌린다', () {
      const s = PlacedSticker(id: 'a', name: 'move_car', x: 100, y: 100, size: 80);
      expect(s.contains(100, 100), isTrue);
      expect(s.contains(135, 135), isTrue); // 모서리 근처
      expect(s.contains(150, 100), isFalse);

      final turned = s.copyWith(rotation: math.pi / 4);
      expect(turned.contains(135, 135), isFalse); // 45° 돌리면 모서리 자리가 비어 있다
      expect(turned.contains(100, 148), isTrue); // 대신 아래 꼭짓점 쪽이 늘어난다
    });

    test('나중에 붙인 스티커가 먼저 잡힌다', () {
      const bottom = PlacedSticker(id: 'bottom', name: 'a', x: 100, y: 100);
      const top = PlacedSticker(id: 'top', name: 'b', x: 110, y: 100);
      expect(stickerAt(const [bottom, top], 105, 100)?.id, 'top');
      expect(stickerAt(const [bottom, top], 70, 100)?.id, 'bottom');
      expect(stickerAt(const [bottom, top], 300, 300), isNull);
    });

    test('JSON으로 저장했다가 그대로 되살린다', () {
      final pages = {
        'trip:all': [const PlacedSticker(id: 'a', name: 'place_food_beer', x: 12.5, y: 40, size: 90, rotation: 0.3)],
        'trip:day1': <PlacedSticker>[],
      };
      final restored = decodeStickerPages(encodeStickerPages(pages));
      expect(restored.keys, ['trip:all']); // 빈 장은 저장하지 않는다
      final s = restored['trip:all']!.single;
      expect([s.id, s.name, s.x, s.y, s.size, s.rotation], ['a', 'place_food_beer', 12.5, 40, 90, 0.3]);
    });

    test('깨진 저장값은 무시한다', () {
      expect(decodeStickerPages('not json'), isEmpty);
      expect(decodeStickerPages('{"k":[{"id":1}]}'), isEmpty);
      expect(decodeStickerPages(null), isEmpty);
    });
  });

  group('카드 키', () {
    final trip = sampleGangneungTrip();

    test('한 장 모아보기와 하루씩 나눠보기는 다른 장으로 저장한다', () {
      final one = paginateTrip(trip, TripCardMode.onePage);
      final perDay = paginateTrip(trip, TripCardMode.perDay);
      expect(cardPageKey(trip, TripCardMode.onePage, one.single), 'sample-gangneung:all');
      expect([for (final p in perDay) cardPageKey(trip, TripCardMode.perDay, p)],
          ['sample-gangneung:day0', 'sample-gangneung:day1', 'sample-gangneung:day2']);
    });
  });

  group('자동으로 꾸미기', () {
    final trip = sampleGangneungTrip();
    final checkIns = trip.checkIns;
    final layout = layoutTripCard(checkIns.length);
    var n = 0;
    String id() => 'id${n++}';

    test('장소마다 이름표 반대쪽 길가, 장소 막대 가운데에 붙는다', () {
      final result = autoDecorate(layout, checkIns, has: (_) => true, newId: id);
      expect(result.length, checkIns.length);
      for (final (i, slot) in layout.stops.indexed) {
        final s = result[i];
        expect(s.x, slot.x);
        // 이름이 아래면 스티커는 위(길 가운데보다 작은 y), 이름이 위면 아래
        expect(slot.labelAbove ? s.y > slot.y : s.y < slot.y, isTrue);
        expect((s.y - slot.y).abs(), 8 + 4 + autoStickerSize / 2);
      }
      expect(result.take(3).map((s) => s.name),
          ['place_beach_parasol', 'place_cafe_coffee', 'place_heritage_hanok']); // 경포해변·안목 커피거리·오죽헌
      expect(result.map((s) => s.name), isNot(contains('move_car')));
      expect(result.map((s) => s.id).toSet().length, result.length);
    });

    test('이름표와 겹치면 비켜 보고, 그래도 겹치면 건너뛴다', () {
      final first = layout.stops.first;
      final spot = Offset(first.x, first.labelAbove ? first.y + 39 : first.y - 39);
      // 첫 장소 스티커 자리 오른쪽만 막으면 왼쪽으로 비킨다
      final shifted = autoDecorate(layout, checkIns, has: (_) => true, newId: id,
          avoid: [Rect.fromLTWH(spot.dx + 14, spot.dy - 10, 40, 20)]);
      expect(shifted.first.x, lessThan(first.x));
      // 자리 전체를 막으면 그 장소는 건너뛴다
      final skipped = autoDecorate(layout, checkIns, has: (_) => true, newId: id,
          avoid: [Rect.fromCenter(center: spot, width: 120, height: 60)]);
      expect(skipped.length, checkIns.length - 1);
      expect(skipped.first.name, isNot('place_beach_parasol'));
    });

    test('그림이 없는 스티커는 고르지 않는다', () {
      expect(autoDecorate(layout, checkIns, has: (_) => false, newId: id), isEmpty);
    });
  });

  group('CardStickerStore', () {
    test('붙이기·맨 위로·떼기', () {
      final store = CardStickerStore.memory();
      var changes = 0;
      store.addListener(() => changes++);
      store
        ..add('k', const PlacedSticker(id: 'a', name: 'x', x: 0, y: 0))
        ..add('k', const PlacedSticker(id: 'b', name: 'y', x: 0, y: 0))
        ..bringToFront('k', 'a');
      expect(store.stickersOf('k').map((s) => s.id), ['b', 'a']);
      store.update('k', store.stickersOf('k').last.copyWith(size: 100), save: false);
      expect(store.stickersOf('k').last.size, 100);
      store.remove('k', 'b');
      expect(store.stickersOf('k').map((s) => s.id), ['a']);
      store.clear('k');
      expect(store.stickersOf('k'), isEmpty);
      expect(changes, 6);
    });

    test('기기에 저장했다가 다시 열면 그대로 있다', () async {
      SharedPreferences.setMockInitialValues({});
      final first = await CardStickerStore.load();
      first.add('trip:all', const PlacedSticker(id: 'a', name: 'move_bus', x: 50, y: 60));
      await first.persist();

      final second = await CardStickerStore.load();
      expect(second.stickersOf('trip:all').single.name, 'move_bus');
    });
  });

  group('장소 막대 편집 저장', () {
    test('옮기고 되돌리고, 저장했다가 다시 연다', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await CardStickerStore.load();
      store
        ..setStopEdit('trip:all', 'c1', const StopEdit(x: 120))
        ..setStopEdit('trip:all', 'c2', const StopEdit(labelAbove: true));
      expect(store.stopEditsOf('trip:all').keys, ['c1', 'c2']);
      store.setStopEdit('trip:all', 'c2', null);
      expect(store.stopEditsOf('trip:all').keys, ['c1']);
      await store.persist();

      final again = await CardStickerStore.load();
      expect(again.stopEditsOf('trip:all')['c1']?.x, 120);
      expect(again.stopEditsOf('trip:all')['c1']?.labelAbove, isNull);
    });

    test('깨진 저장값은 무시한다', () {
      expect(decodeStopEdits('[]'), isEmpty);
      expect(decodeStopEdits('{"p":{"c":{"x":"a"}}}'), isEmpty);
    });
  });
}
