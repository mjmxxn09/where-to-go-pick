import 'package:gal/gal.dart';

import 'card_image.dart';

/// 저장되는 곳(안내 문구용).
const cardSaveTarget = '갤러리';

/// 사진 갤러리의 [album] 앨범에 저장한다. 처음이면 사진 접근 허용을 묻는다.
/// Android 10 이상은 권한 없이 저장되고, 9 이하는 매니페스트의 WRITE_EXTERNAL_STORAGE(maxSdkVersion 29)가 필요하다.
Future<void> saveCardImages(List<CardImage> images, {String album = cardAlbumName}) async {
  try {
    if (!await Gal.hasAccess(toAlbum: true)) {
      final granted = await Gal.requestAccess(toAlbum: true);
      if (!granted) throw const CardSaveException('사진 접근을 허용해야 갤러리에 저장할 수 있어요. 설정에서 바꿀 수 있어요.');
    }
    for (final image in images) {
      await Gal.putImageBytes(image.bytes, album: album, name: image.baseName);
    }
  } on GalException catch (e) {
    throw CardSaveException(switch (e.type) {
      GalExceptionType.accessDenied => '사진 접근을 허용해야 갤러리에 저장할 수 있어요. 설정에서 바꿀 수 있어요.',
      GalExceptionType.notEnoughSpace => '저장 공간이 부족해요.',
      _ => '갤러리에 저장하지 못했어요. 잠시 뒤 다시 해 주세요.',
    });
  }
}
