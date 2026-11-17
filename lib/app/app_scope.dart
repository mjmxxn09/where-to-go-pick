import 'package:flutter/widgets.dart';

import '../core/config/app_config.dart';
import '../core/life/life_repository.dart';
import '../core/pickle/pickle_repository.dart';
import '../core/votes/vote_repository.dart';
import '../features/korea_map/korea_map_data.dart';
import '../features/trip/trip_controller.dart';

/// 앱 전역 의존성. 상태 관리 패키지 없이 InheritedWidget 하나로 시작한다(필요해지면 교체).
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.config,
    required this.pickle,
    required this.life,
    required this.votes,
    required this.trip,
    required this.mapData,
    required this.visitedCityIds,
    required super.child,
  });

  final AppConfig config;
  final PickleRepository pickle;
  final LifeRepository life;

  /// 픽클 투표(체크인 질문·나도 한 표·후보 투표·카드 투표). 지금은 예시 구현.
  final VoteRepository votes;
  final TripController trip;
  final Future<KoreaMapData> mapData;

  /// 다녀온 시·군·구 코드. 생활 서버가 생기면 서버 값으로 바꾼다.
  final Set<String> visitedCityIds;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope가 위젯 트리에 없어요.');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      pickle != oldWidget.pickle || life != oldWidget.life || votes != oldWidget.votes || trip != oldWidget.trip;
}
