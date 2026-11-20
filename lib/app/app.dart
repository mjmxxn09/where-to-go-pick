import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/auth/token_store.dart';
import '../core/cloud/cloud_session.dart';
import '../core/cloud/supabase_rest.dart';
import '../core/config/app_config.dart';
import '../core/life/life_repository.dart';
import '../core/life/supabase_life_repository.dart';
import '../core/pickle/pickle_api_client.dart';
import '../core/pickle/pickle_repository.dart';
import '../core/votes/vote_repository.dart';
import '../core/theme/app_surfaces.dart';
import '../core/theme/app_theme.dart';
import '../features/explore/explore_screen.dart';
import '../features/home/my_map_screen.dart';
import '../features/korea_map/korea_map_data.dart';
import '../features/splash/pickle_login_sheet.dart';
import '../features/splash/splash_character.dart';
import '../features/splash/start_screen.dart';
import '../features/trip/sample_trip.dart';
import '../features/trip/trip_cloud.dart';
import '../features/trip/trip_controller.dart';
import '../features/trip/trip_screen.dart';
import '../features/trip/trip_store.dart';
import 'app_scope.dart';

class WhereToGoPickApp extends StatefulWidget {
  const WhereToGoPickApp({super.key, required this.config, this.pickle, this.life, this.votes, this.mapData});

  final AppConfig config;

  /// 테스트에서 주입. null이면 설정에 따라 서버/예시 데이터를 고른다.
  final PickleRepository? pickle;
  final LifeRepository? life;
  final VoteRepository? votes;
  final Future<KoreaMapData>? mapData;

  @override
  State<WhereToGoPickApp> createState() => _WhereToGoPickAppState();
}

class _WhereToGoPickAppState extends State<WhereToGoPickApp> {
  late final PickleApiClient? _pickleClient = widget.config.usePickleFixtures
      ? null
      : PickleApiClient(
          baseUrl: widget.config.pickleApiBaseUrl,
          tokenStore: SecureTokenStore(),
          appVersion: widget.config.appVersion,
        );
  late final PickleRepository _pickle = widget.pickle ?? _createPickle();
  // 여행 기록 서버(Supabase). 주소·키가 없으면 null이고 기록은 폰에만 남는다.
  late final SupabaseRest? _cloud = _createCloud();
  // 여행지 정보: Supabase가 연결되면 Edge Function `life`(TourAPI·기상청), 아니면 강릉 예시 데이터.
  late final LifeRepository _life = widget.life ?? _createLife();
  // 픽클 투표는 서버 쪽 정책(채널·지역 연결·다녀온 사람 표)이 정해질 때까지 예시 구현만 쓴다.
  late final VoteRepository _votes = widget.votes ?? FixtureVoteRepository();
  // 서버가 하나도 없을 때(화면 확인용)만 예시 여행(강릉 2박 3일)과 예시 방문 지역을 보여 준다.
  // 여행 기록 서버(Supabase)가 연결되면 빈 지도에서 시작하고, 직접 시작한 여행만 보인다.
  late final bool _showSamples = widget.config.useLifeFixtures && !widget.config.useCloud;
  late final TripController _trip = TripController(
    initial: _showSamples ? sampleGangneungTrip() : null,
    store: PrefsTripStore(),
    cloud: _tripCloud(),
  )..restore();
  late final Future<KoreaMapData> _mapData = widget.mapData ?? KoreaMapData.load(rootBundle);

  PickleRepository _createPickle() {
    final client = _pickleClient;
    if (client == null) return const FixturePickleRepository();
    return RemotePickleRepository(client);
  }

  LifeRepository _createLife() {
    final cloud = _cloud;
    if (cloud == null) return const FixtureLifeRepository();
    return SupabaseLifeRepository(cloud, _cityOf);
  }

  /// 지도 id → 도 코드·시·군·구 이름(`31:수원시`처럼 합친 시도 앞 두 자리가 도 코드).
  Future<({String provinceCode, String cityName})?> _cityOf(String cityId) async {
    if (cityId.length < 2) return null;
    final code = cityId.substring(0, 2);
    final detail = (await _mapData).details[code];
    for (final city in detail?.cities ?? const <MapRegion>[]) {
      if (city.id == cityId) return (provinceCode: code, cityName: city.name);
    }
    return null;
  }

  TripCloud? _tripCloud() {
    final cloud = _cloud;
    return cloud == null ? null : SupabaseTripCloud(cloud);
  }

  SupabaseRest? _createCloud() {
    final config = widget.config;
    if (!config.useCloud) return null;
    final client = _pickleClient;
    return SupabaseRest(CloudSession(
      url: config.supabaseUrl,
      publishableKey: config.supabasePublishableKey,
      pickleToken: client == null ? null : ({bool refresh = false}) => client.accessToken(refresh: refresh),
      // 픽클 서버 없이 개발할 때만 게스트(익명) 로그인으로 올린다.
      allowGuest: config.usePickleFixtures,
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
      votes: _votes,
      trip: _trip,
      mapData: _mapData,
      visitedCityIds: _showSamples ? sampleVisitedCityIds : const <String>{},
      cloud: _cloud,
      child: MaterialApp(
        title: '어디갈지 Pick!',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const StartGate(),
      ),
    );
  }
}

/// 시작 화면 → 홈.
///
/// - 실행할 때마다 픽클 친구 6명 중 한 명(바로 전과 다른 친구)이 얼굴을 내민다.
/// - 이미 로그인돼 있으면 스플래시만 잠깐 보여 주고 홈으로 간다.
/// - 아니면 "픽클 계정으로 시작하기"(이메일 로그인 시트) 또는 "카카오로 시작하기".
/// - 서버 없이(예시 데이터) 실행하면 버튼을 누르는 대로 바로 홈으로 간다.
class StartGate extends StatefulWidget {
  const StartGate({super.key, this.splashDuration = const Duration(milliseconds: 1200)});

  final Duration splashDuration;

  @override
  State<StartGate> createState() => _StartGateState();
}

class _StartGateState extends State<StartGate> {
  SplashCharacter? _character;
  var _signedIn = false;
  var _entered = false;
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load(AppScope.of(context));
  }

  Future<void> _load(AppScope scope) async {
    final character = await SplashCharacterPicker().next();
    var signedIn = false;
    if (!scope.config.usePickleFixtures) {
      try {
        signedIn = await scope.pickle.me() != null;
      } on Object {
        signedIn = false; // 세션이 만료됐거나 서버에 닿지 않으면 로그인부터
      }
    }
    if (!mounted) return;
    setState(() {
      _character = character;
      _signedIn = signedIn;
    });
    if (signedIn) {
      await Future<void>.delayed(widget.splashDuration);
      if (mounted) setState(() => _entered = true);
    }
  }

  Future<void> _pickleLogin() async {
    final scope = AppScope.of(context);
    if (scope.config.usePickleFixtures) {
      setState(() => _entered = true);
      return;
    }
    final ok = await showPickleLoginSheet(context, scope.pickle);
    if (!ok || !mounted) return;
    setState(() => _entered = true);
    // 로그인 전에 남긴 기록도 이제 픽클 계정으로 올린다.
    unawaited(scope.trip.sync());
  }

  void _kakaoLogin() {
    if (AppScope.of(context).config.usePickleFixtures) {
      setState(() => _entered = true);
      return;
    }
    // 카카오 SDK·픽클 카카오 앱 키 연결 전(docs/architecture.md "카카오 로그인").
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('카카오 로그인은 준비 중이에요. 픽클 계정으로 시작해 주세요.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_entered) return const HomeShell();
    final character = _character;
    if (character == null) return const ColoredBox(color: Color(0xFFF8F5FF));
    return StartScreen(
      character: character,
      busy: _signedIn,
      onPickleLogin: _pickleLogin,
      onKakaoLogin: _kakaoLogin,
    );
  }
}

/// 하단 3탭: 내 지도 · 여행지 · 여행 중
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
    ];
    return Scaffold(
      body: AppBackground(child: SafeArea(bottom: false, child: IndexedStack(index: _index, children: pages))),
      bottomNavigationBar: AppBottomBar(
        selectedIndex: _index,
        onSelected: _go,
        items: const [
          AppBottomBarItem(icon: Icons.map_outlined, label: '내 지도'),
          AppBottomBarItem(icon: Icons.explore_outlined, label: '여행지'),
          AppBottomBarItem(icon: Icons.luggage_outlined, label: '여행 중'),
        ],
      ),
    );
  }
}
