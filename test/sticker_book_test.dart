import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:where_to_go_pick/features/trip/trip_models.dart';
import 'package:where_to_go_pick/features/trip_card/sticker_book.dart';

void main() {
  test('모든 장소 종류에 대응표가 있다', () {
    for (final type in PlaceType.values) {
      expect(StickerBook.placeStickers.containsKey(type), isTrue, reason: type.name);
    }
  });

  test('대응표에 적힌 스티커 파일이 모두 저장소에 있다', () {
    final names = [for (final list in StickerBook.placeStickers.values) ...list, ...StickerBook.moveStickers];
    for (final name in names) {
      expect(File('${StickerBook.folder}/$name.png').existsSync(), isTrue, reason: name);
    }
  });

  test('같은 장소 이름이면 늘 같은 그림을 고른다', () {
    const options = ['a', 'b', 'c'];
    expect(pickVariant(options, '경포해변'), pickVariant(options, '경포해변'));
    expect(pickVariant(const [], '경포해변'), isNull);
  });
}
