import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'card_image.dart';

/// 저장되는 곳(안내 문구용).
const cardSaveTarget = '다운로드 폴더';

/// 웹에는 갤러리가 없어서 PNG 파일로 내려받는다.
Future<void> saveCardImages(List<CardImage> images, {String album = cardAlbumName}) async {
  for (final image in images) {
    final blob = web.Blob(<JSAny>[image.bytes.toJS].toJS, web.BlobPropertyBag(type: 'image/png'));
    final url = web.URL.createObjectURL(blob);
    web.HTMLAnchorElement()
      ..href = url
      ..download = image.fileName
      ..click();
    // 바로 지우면 일부 브라우저에서 내려받기가 취소된다.
    unawaited(Future<void>.delayed(const Duration(seconds: 2), () => web.URL.revokeObjectURL(url)));
  }
}
