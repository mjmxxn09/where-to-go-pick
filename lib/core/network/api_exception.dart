import 'dart:convert';

/// 픽클 API 공통 오류 본문 `{code, message, requestId, reason?, retryAfterSeconds?}`.
class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.requestId,
    this.reason,
  });

  factory ApiException.fromResponse(int statusCode, String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map<String, dynamic>) {
        return ApiException(
          statusCode: statusCode,
          code: json['code'] as String? ?? 'UNKNOWN',
          message: json['message'] as String? ?? '요청을 처리하지 못했어요.',
          requestId: json['requestId'] as String?,
          reason: json['reason'] as String?,
        );
      }
    } on FormatException {
      // 본문이 JSON이 아니면 아래 기본값으로 접는다.
    }
    return ApiException(statusCode: statusCode, code: 'UNKNOWN', message: '요청을 처리하지 못했어요.');
  }

  final int statusCode;
  final String code;
  final String message;
  final String? requestId;
  final String? reason;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => 'ApiException($statusCode $code ${reason ?? ''} requestId=$requestId)';
}

/// 로그인 409 `SESSION_REPLACEMENT_REQUIRED`.
/// 픽클은 회원당 활성 모바일 세션을 하나만 허용한다. 이 앱이 자동으로 교체하면 사용자의 픽클 앱이
/// 로그아웃되므로, 교체 여부는 반드시 사용자에게 묻는다(docs/architecture.md "세션 충돌" 참고).
class SessionConflictException extends ApiException {
  const SessionConflictException({
    required super.statusCode,
    required super.code,
    required super.message,
    super.requestId,
    this.activePlatformLabel,
  });

  final String? activePlatformLabel;
}
