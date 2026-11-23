import 'dart:async';

import 'package:http/http.dart' as http;

/// 응답이 [timeout] 안에 안 오면 [TimeoutException]으로 끝내는 http 클라이언트.
/// 지하철·엘리베이터처럼 연결이 붙었다 끊겼다 할 때 로딩이 끝없이 도는 것을 막는다.
class TimeoutClient extends http.BaseClient {
  TimeoutClient({http.Client? inner, this.timeout = const Duration(seconds: 20)}) : _inner = inner ?? http.Client();

  final http.Client _inner;
  final Duration timeout;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => _inner.send(request).timeout(timeout);

  @override
  void close() => _inner.close();
}
