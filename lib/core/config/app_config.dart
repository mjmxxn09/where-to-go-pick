/// 실행 환경 설정.
///
/// 그냥 `flutter run`이면 우리 Supabase 프로젝트에 붙는다(주소·publishable 키는 공개해도 되는 값이라 기본값으로 둔다).
/// 서버 없이 예시 데이터로 보려면 `flutter run --dart-define=SAMPLE_MODE=true`.
/// 다른 Supabase 프로젝트를 쓰려면 `--dart-define-from-file=env/dev.json`(또는 `--dart-define`)으로 덮어쓴다.
/// `PICKLE_API_BASE_URL`이 비어 있으면 픽클 쪽은 예시 데이터(fixture)로 동작한다.
class AppConfig {
  const AppConfig({
    required this.pickleApiBaseUrl,
    required this.lifeApiBaseUrl,
    required this.appVersion,
    this.supabaseUrl = '',
    this.supabasePublishableKey = '',
  });

  /// 우리 Supabase 프로젝트(서울). 앱에 들어가는 공개 값이다 — 권한은 RLS와 함수의 토큰 확인이 막는다.
  /// secret·service_role 키는 여기에도, 저장소 어디에도 두지 않는다.
  static const defaultSupabaseUrl = 'https://vwgtsqjpemvyhmjvlgoe.supabase.co';
  static const defaultSupabasePublishableKey = 'sb_publishable_1E2NWZgFZ9smKRHVM4MY9g_axLKSM09';

  factory AppConfig.fromEnvironment() {
    const sample = bool.fromEnvironment('SAMPLE_MODE');
    const url = String.fromEnvironment('SUPABASE_URL', defaultValue: defaultSupabaseUrl);
    const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY', defaultValue: defaultSupabasePublishableKey);
    return const AppConfig(
      pickleApiBaseUrl: String.fromEnvironment('PICKLE_API_BASE_URL'),
      lifeApiBaseUrl: String.fromEnvironment('LIFE_API_BASE_URL'),
      appVersion: String.fromEnvironment('APP_VERSION', defaultValue: '0.1.0'),
      supabaseUrl: sample ? '' : url,
      supabasePublishableKey: sample ? '' : key,
    );
  }

  /// 픽클(VoteLock) Backend `/v1` 주소. 예: https://dev-api.example.com
  final String pickleApiBaseUrl;

  /// 날씨·관광정보 프록시와 여행 기록을 맡는 생활 서버 주소(신규, 아직 없음).
  final String lifeApiBaseUrl;

  final String appVersion;

  /// 여행 기록을 보관하는 Supabase 프로젝트 주소. 예: https://xxxx.supabase.co
  final String supabaseUrl;

  /// Supabase publishable(anon) 키. 앱에 들어가도 되는 공개 키다. secret·service_role 키는 절대 넣지 않는다.
  final String supabasePublishableKey;

  bool get usePickleFixtures => pickleApiBaseUrl.isEmpty;
  bool get useLifeFixtures => lifeApiBaseUrl.isEmpty;

  /// 둘 다 있어야 여행 기록을 Supabase에 올린다. 없으면 폰에만 저장한다.
  bool get useCloud => supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
}
