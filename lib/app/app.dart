import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/auth/token_store.dart';
import '../core/config/app_config.dart';
import '../core/life/life_repository.dart';
import '../core/pickle/pickle_api_client.dart';
import '../core/pickle/pickle_repository.dart';
import '../core/theme/app_theme.dart';
import '../features/explore/explore_screen.dart';
import '../features/home/my_map_screen.dart';
import '../features/korea_map/korea_map_data.dart';
import '../features/trip/sample_trip.dart';
import '../features/trip/trip_controller.dart';
import '../features/trip/trip_screen.dart';
import '../features/walk/walk_screen.dart';
import 'app_scope.dart';

class WhereToGoPickApp extends StatefulWidget {
  const WhereToGoPickApp({super.key, required this.config, this.pickle, this.life, this.mapData});

  final AppConfig config;

  /// 테스트에서 주입. null이면 설정에 따라 서버/예시 데이터를 고른다.
  final PickleRepository? pickle;
  final LifeRepository? life;
  final Future<KoreaMapData>? mapData;

  @override
  State<WhereToGoPickApp> createState() => _WhereToGoPickAppState();
}

class _WhereToGoPickAppState extends State<WhereToGoPickApp> {
  late final PickleRepository _pickle = widget.pickle ?? _createPickle();
  late final LifeRepository _life = widget.life ?? const FixtureLifeRepository();
  // 서버가 없을 때는 예시 여행(강릉 2박 3일)으로 화면을 채운다.
  late final TripController _trip =
      TripController(initial: widget.config.useLifeFixtures ? sampleGangneungTrip() : null);
  late final Future<KoreaMapData> _mapData = widget.mapData ?? KoreaMapData.load(rootBundle);

  PickleRepository _createPickle() {
    if (widget.config.usePickleFixtures) return const FixturePickleRepository();
    return RemotePickleRepository(PickleApiClient(
      baseUrl: widget.config.pickleApiBaseUrl,
      tokenStore: SecureTokenStore(),
      appVersion: widget.config.appVersion,
    ));
  }

  @override
  void dispose() {
    _trip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      config: widget.config,
      pickle: _pickle,
      life: _life,
      trip: _trip,
      mapData: _mapData,
      visitedCityIds: widget.config.useLifeFixtures ? sampleVisitedCityIds : const <String>{},
      child: MaterialApp(
        title: '어디갈지 Pick!',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const HomeShell(),
      ),
    );
  }
}

/// 하단 4탭: 내 지도 · 여행지 · 여행 중 · 산책
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _go(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final pages = [
      MyMapScreen(onNewTrip: () => _go(1), onOpenTrip: () => _go(2)),
      ExploreScreen(onTripStarted: () => _go(2)),
      const TripScreen(),
      const WalkScreen(),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _index, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _go,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primaryContainer,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: '내 지도'),
          NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: '여행지'),
          NavigationDestination(icon: Icon(Icons.luggage_outlined), selectedIcon: Icon(Icons.luggage), label: '여행 중'),
          NavigationDestination(icon: Icon(Icons.route_outlined), selectedIcon: Icon(Icons.route), label: '산책'),
        ],
      ),
    );
  }
}
