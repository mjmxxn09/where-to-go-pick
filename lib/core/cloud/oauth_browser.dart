import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import 'cloud_session.dart';

/// [OAuthBrowser]: 안드로이드는 Custom Tabs, iOS는 ASWebAuthenticationSession으로 로그인 페이지를 열고
/// `wheretogopick://…`로 돌아온 주소를 받는다. 안드로이드는 매니페스트에 콜백 액티비티가 있어야 한다(docs/kakao-login.md).
Future<Uri> openOAuthBrowser(Uri url, String callbackScheme) async {
  try {
    final back = await FlutterWebAuth2.authenticate(url: url.toString(), callbackUrlScheme: callbackScheme);
    return Uri.parse(back);
  } on PlatformException catch (e) {
    if (e.code == 'CANCELED') throw const OAuthCanceled();
    rethrow;
  }
}
