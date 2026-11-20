import 'dart:typed_data';

import '../../trip/trip_models.dart';
import '../trip_card_layout.dart';

/// 저장·공유할 카드 한 장(PNG).
class CardImage {
  const CardImage({required this.bytes, required this.baseName});

  final Uint8List bytes;

  /// 확장자 없는 파일 이름. 예: `어디갈지Pick_강릉_여행_1일차`
  final String baseName;

  String get fileName => '$baseName.png';
}

/// 갤러리 권한이 없거나 저장 공간이 부족할 때 등. [message]는 그대로 화면에 띄운다.
class CardSaveException implements Exception {
  const CardSaveException(this.message);

  final String message;

  @override
  String toString() => 'CardSaveException: $message';
}

/// 사진첩 앨범 이름.
const cardAlbumName = '어디갈지 Pick';

/// 파일 이름: 앱 이름 + 여행 제목(+ 나눠 보기면 그 날). 공백·파일에 못 쓰는 글자는 `_`.
String cardBaseName(Trip trip, TripCardPage page, {required bool folder}) {
  final parts = ['어디갈지Pick', trip.title, if (folder && page.days.isNotEmpty) page.days.first.label];
  return parts.join(' ').replaceAll(RegExp(r'[\s\\/:*?"<>|]+'), '_');
}
