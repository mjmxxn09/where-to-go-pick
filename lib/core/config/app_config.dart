/// 실행 환경 설정. 값은 `--dart-define` 또는 `--dart-define-from-file=env/dev.json`으로 주입한다.
///
/// `PICKLE_API_BASE_URL`이 비어 있으면 서버 없이 예시 데이터(fixture)로 동작한다.
class AppConfig {
  const AppConfig({
    required this.pickleApiBaseUrl,
    required this.lifeApiBaseUrl,
    required this.appVersion,
  });

  factory AppConfig.fromEnvironment() => const AppConfig(
        pickleApiBaseUrl: String.fromEnvironment('PICKLE_API_BASE_URL'),
        lifeApiBaseUrl: String.fromEnvironment('LIFE_API_BASE_URL'),
        appVersion: String.fromEnvironment('APP_VERSION', defaultValue: '0.1.0'),
      );

  /// 픽클(VoteLock) Backend `/v1` 주소. 예: https://dev-api.example.com
  final String pickleApiBaseUrl;

  /// 날씨·관광정보 프록시와 여행 기록을 맡는 생활 서버 주소(신규, 아직 없음).
  final String lifeApiBaseUrl;

  final String appVersion;

  bool get usePickleFixtures => pickleApiBaseUrl.isEmpty;
  bool get useLifeFixtures => lifeApiBaseUrl.isEmpty;
}
