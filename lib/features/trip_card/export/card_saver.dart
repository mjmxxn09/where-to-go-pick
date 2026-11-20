/// 카드 이미지를 기기에 저장한다. 앱(Android·iOS)은 사진 갤러리, 웹은 파일 다운로드.
library;

export 'card_saver_io.dart' if (dart.library.js_interop) 'card_saver_web.dart';
