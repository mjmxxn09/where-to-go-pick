import 'package:flutter_test/flutter_test.dart';
import 'package:where_to_go_pick/core/config/app_config.dart';

void main() {
  test('옵션 없이 실행하면 우리 Supabase에 붙는다(공개 값만 기본값)', () {
    final config = AppConfig.fromEnvironment();
    expect(config.useCloud, isTrue);
    expect(config.supabaseUrl, AppConfig.defaultSupabaseUrl);
    expect(AppConfig.defaultSupabasePublishableKey, startsWith('sb_publishable_'), reason: 'secret 키는 넣지 않는다');
  });
}
