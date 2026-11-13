/// 픽클(VoteLock) `/v1` 응답 중 이 앱이 쓰는 부분만 옮긴 모델.
/// 정본은 VoteLock `docs/api/openapi.yaml`이며, 모르는 필드·enum 값은 무시하거나 안전한 기본값으로 접는다.
library;

class AuthTokens {
  const AuthTokens({
    required this.subjectId,
    required this.sessionId,
    required this.accessToken,
    required this.refreshToken,
    required this.accessExpiresInSeconds,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
        subjectId: json['subjectId'] as String,
        sessionId: json['sessionId'] as String,
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
        accessExpiresInSeconds: (json['accessExpiresInSeconds'] as num).toInt(),
      );

  final String subjectId;
  final String sessionId;
  final String accessToken;
  final String refreshToken;
  final int accessExpiresInSeconds;

  Map<String, dynamic> toJson() => {
        'subjectId': subjectId,
        'sessionId': sessionId,
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'accessExpiresInSeconds': accessExpiresInSeconds,
      };
}

class UserProfile {
  const UserProfile({required this.subjectId, this.nickname, this.avatarUrl});

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        subjectId: json['subjectId'] as String,
        nickname: json['nickname'] as String?,
        avatarUrl: json['avatarUrl'] as String?,
      );

  final String subjectId;
  final String? nickname;
  final String? avatarUrl;
}

class InterestCategory {
  const InterestCategory({
    required this.key,
    required this.displayNameKo,
    required this.sortOrder,
    this.icon,
  });

  factory InterestCategory.fromJson(Map<String, dynamic> json) => InterestCategory(
        key: json['key'] as String,
        displayNameKo: json['displayNameKo'] as String,
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
        icon: json['icon'] as String?,
      );

  final String key;
  final String displayNameKo;
  final int sortOrder;
  final String? icon;
}

/// 픽클 패밀리 6종. 서버 `species` 값과 1:1. 모르는 값은 DUCK(픽클이)로 접는다(OpenAPI 계약).
enum PickleSpecies {
  duck('DUCK', '픽클이'),
  otter('OTTER', '보리'),
  rabbit('RABBIT', '토리'),
  fox('FOX', '모아'),
  owl('OWL', '일디'),
  droplet('DROPLET', '리듬이');

  const PickleSpecies(this.wire, this.familyName);

  final String wire;
  final String familyName;

  static PickleSpecies fromWire(String? value) =>
      PickleSpecies.values.firstWhere((s) => s.wire == value, orElse: () => PickleSpecies.duck);
}

enum PickleStage {
  baby('BABY', '아기'),
  juvenile('JUVENILE', '성장기'),
  adult('ADULT', '성체');

  const PickleStage(this.wire, this.label);

  final String wire;
  final String label;

  static PickleStage fromWire(String? value) =>
      PickleStage.values.firstWhere((s) => s.wire == value, orElse: () => PickleStage.baby);
}

/// `GET /v1/me/companion/village`의 캐릭터 한 마리(이 앱은 읽기만 한다).
class PickleFriend {
  const PickleFriend({required this.name, required this.species, required this.stage});

  factory PickleFriend.fromJson(Map<String, dynamic> json) => PickleFriend(
        name: json['name'] as String,
        species: PickleSpecies.fromWire(json['species'] as String?),
        stage: PickleStage.fromWire(json['stage'] as String?),
      );

  final String name;
  final PickleSpecies species;
  final PickleStage stage;
}
