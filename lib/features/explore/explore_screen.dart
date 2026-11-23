import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/life/life_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/votes/vote_repository.dart';
import '../korea_map/korea_map_data.dart';
import '../korea_map/korea_map_view.dart';
import '../shared/weather_icon.dart';
import '../trip/trip_dates_sheet.dart';
import '../trip/trip_models.dart';
import '../votes/poll_screen.dart';
import 'trip_candidates.dart';

/// 2 · 여행지 고르기: 도(전체로도 여행 가능) → 시·군·구 → 여행 만들기.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key, required this.onTripStarted});

  final VoidCallback onTripStarted;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {

  /// 고른 여행지. 처음엔 아무것도 고르지 않은 전국 지도로 연다.
  SelectedCity? _city;

  /// ♡로 담은 여행지 후보(최대 4곳, 기기에 저장). 2곳부터 친구한테 물어볼 수 있다.
  TripCandidates? _cands;

  /// 최근 물어본 투표 불러오기(투표 화면에서 돌아오면 다시 불러온다).
  final Map<String, Future<Poll?>> _pollFutures = {};

  @override
  void initState() {
    super.initState();
    TripCandidates.load().then((store) {
      if (!mounted) return;
      store.addListener(_onCandidatesChanged);
      setState(() => _cands = store);
    });
  }

  @override
  void dispose() {
    _cands?.removeListener(_onCandidatesChanged);
    super.dispose();
  }

  void _onCandidatesChanged() {
    if (mounted) setState(() {});
  }

  bool _isCandidate(SelectedCity c) => _cands?.contains(c.id) ?? false;

  void _toggleCandidate(SelectedCity c) => _cands?.toggle(c);

  void _askFriends() {
    final store = _cands;
    if (store == null) return;
    final picked = List.of(store.items);
    final poll = AppScope.of(context).votes.askFriends(
      question: '이번 주말 어디 갈까?',
      cities: [for (final c in picked) (key: c.id, label: c.name)],
    ).then((p) {
      // 후보를 나중에 비워도 이 투표는 따로 남는다.
      store.addPoll(AskedPoll(id: p.id, cities: picked));
      return p;
    });
    _openPoll(poll, picked);
  }

  void _openPoll(Future<Poll> poll, List<SelectedCity> cities) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(
          builder: (routeContext) => PollScreen(
            poll: poll,
            winnerAction: cities.isEmpty
                ? null
                : (
                    label: (w) => '${w.label}로 여행 만들기',
                    onPressed: (w) {
                      Navigator.of(routeContext).pop();
                      final city = cities.firstWhere((c) => c.id == w.key, orElse: () => cities.first);
                      setState(() => _city = city);
                      _startTrip();
                    },
                  ),
          ),
        ))
        .then((_) {
      if (mounted) setState(_pollFutures.clear);
    });
  }

  void _openAskedPoll(AskedPoll asked) {
    final votes = AppScope.of(context).votes;
    _openPoll(votes.poll(asked.id).then((p) => p ?? (throw StateError('없는 투표'))), asked.cities);
  }

  /// 출발일·기간을 고르고 여행을 만든다. 진행 중인 여행이 있으면 마쳐진다고 미리 알린다.
  Future<void> _startTrip() async {
    final city = _city;
    if (city == null) return;
    final trips = AppScope.of(context).trip;
    final current = trips.trip;
    final title = '${regionShortName(city.name)} 여행 만들기';
    final dates = await showTripDatesSheet(
      context,
      title: title,
      confirmLabel: '여행 만들기',
      warning: current != null && !current.isEnded && !current.id.startsWith('sample-')
          ? '진행 중인 ${current.title}은 마쳐져요. 내 지도의 지난 여행에서 다시 이어갈 수 있어요.'
          : null,
    );
    if (dates == null || !mounted) return;
    trips.startTrip(
      cityId: city.id,
      cityName: city.name,
      provinceName: city.provinceName,
      startDate: dates.start,
      plannedDays: dates.days,
    );
    // 후보 중 한 곳으로 떠나면 고민이 끝난 것 → 후보를 비운다(물어본 투표는 남는다).
    final store = _cands;
    final removed = store != null && store.contains(city.id) ? store.clear() : const <SelectedCity>[];
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(removed.isEmpty ? '${city.name} 여행을 만들었어요!' : '${city.name} 여행을 만들었어요! 갈까 말까 후보는 비웠어요'),
      duration: const Duration(seconds: 4),
      persist: false,
      action: removed.isEmpty || store == null
          ? null
          : SnackBarAction(label: '되돌리기', onPressed: () => store.restore(removed)),
    ));
    widget.onTripStarted();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListView(
      padding: const EdgeInsets.all(Gap.m),
      children: [
        Text('어디로 떠나볼까?', style: titleStyle(26)),
        const SizedBox(height: Gap.s + 2),
        FutureBuilder<KoreaMapData>(
          future: scope.mapData,
          builder: (context, snap) {
            if (!snap.hasData) return const SizedBox(height: 460, child: Center(child: CircularProgressIndicator()));
            return KoreaMapView(
              data: snap.data!,
              initialProvince: _city?.provinceCode,
              initialCity: _city?.id,
              onCityChanged: (c) => setState(() => _city = c),
            );
          },
        ),
        const SizedBox(height: Gap.s + 2),
        if (_city == null)
          const _Hint()
        else
          _CityCard(
            city: _city!,
            life: scope.life,
            onStart: _startTrip,
            isCandidate: _isCandidate(_city!),
            onToggleCandidate: () => _toggleCandidate(_city!),
          ),
        const SizedBox(height: Gap.s),
        _CandidateBar(candidates: _cands?.items ?? const [], onAsk: _askFriends),
        if (_cands?.polls.firstOrNull case final asked?) ...[
          const SizedBox(height: Gap.s),
          _RecentPoll(
            poll: _pollFutures.putIfAbsent(asked.id, () => scope.votes.poll(asked.id)),
            onOpen: () => _openAskedPoll(asked),
          ),
        ],
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: AppDecorations.card,
        child: const Text(
          '도를 눌러 봐! 도 전체로도, 시·군·구까지 골라서도 여행을 만들 수 있어요.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
}

class _CityCard extends StatelessWidget {
  const _CityCard({
    required this.city,
    required this.life,
    required this.onStart,
    required this.isCandidate,
    required this.onToggleCandidate,
  });

  final SelectedCity city;
  final LifeRepository life;
  final VoidCallback onStart;
  final bool isCandidate;
  final VoidCallback onToggleCandidate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: AppDecorations.card,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  city.isWholeProvince ? '전체 · 지도에서 시·군·구를 누르면 좁혀져요' : city.provinceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                Text(city.name, style: titleStyle(22)),
                FutureBuilder<DayWeather>(
                  future: life.weather(cityId: city.id, date: DateTime.now()),
                  builder: (context, snap) {
                    final w = snap.data;
                    if (w == null) return const SizedBox(height: 18);
                    return Row(
                      children: [
                        WeatherIcon(sky: w.now?.sky ?? w.sky, size: 16),
                        const SizedBox(width: 4),
                        Text(
                            w.now != null
                                ? '지금 ${w.now!.temperature}° · 최저 ${w.min}° 최고 ${w.max}°'
                                : '오늘 ${w.temperature}° · 최저 ${w.min}°',
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: isCandidate ? '후보에서 빼기' : '후보에 담기',
            isSelected: isCandidate,
            onPressed: onToggleCandidate,
            style: IconButton.styleFrom(
              backgroundColor: isCandidate ? const Color(0xFFFFE3EF) : const Color(0xFFF6F3FF),
              foregroundColor: _heart,
            ),
            icon: const Icon(Icons.favorite_border),
            selectedIcon: const Icon(Icons.favorite),
          ),
          const SizedBox(width: 6),
          FilledButton(onPressed: onStart, child: const Text('여행 만들기')),
        ],
      ),
    );
  }
}

const _heart = Color(0xFFE0569B);

/// 지난번 친구한테 물어본 투표(후보를 비워도 남는다). 없어진 투표면 보이지 않는다.
class _RecentPoll extends StatelessWidget {
  const _RecentPoll({required this.poll, required this.onOpen});

  final Future<Poll?> poll;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => FutureBuilder<Poll?>(
        future: poll,
        builder: (context, snap) {
          final p = snap.data;
          if (p == null) return const SizedBox.shrink();
          final lead = p.leader.label;
          return Material(
            color: Colors.white.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(99),
            child: InkWell(
              onTap: onOpen,
              borderRadius: BorderRadius.circular(99),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
                child: Row(
                  children: [
                    const Icon(Icons.how_to_vote_outlined, size: 20, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        p.closed ? '지난번 투표 · $lead로 정해졌어요' : '친구들 답 기다리는 중 · 지금은 $lead 1위 · ${p.total}명',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.muted),
                  ],
                ),
              ),
            ),
          );
        },
      );
}

/// 담은 후보 줄. 2곳부터 "친구한테 물어보기"(픽클 투표로 공유).
class _CandidateBar extends StatelessWidget {
  const _CandidateBar({required this.candidates, required this.onAsk});

  final List<SelectedCity> candidates;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) {
    final names = candidates.map((c) => regionShortName(c.name)).join(' · ');
    final n = candidates.length;
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.fromLTRB(14, 4, 5, 4),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(99)),
      child: Row(
        children: [
          Icon(n == 0 ? Icons.favorite_border : Icons.favorite, size: 20, color: _heart),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(n == 0 ? '고민되면 ♡로 후보에 담아요' : '갈까 말까 후보 $n곳',
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                Text(
                  n == 0
                      ? '2곳부터 친구한테 투표로 물어볼 수 있어요'
                      : n == 1
                          ? '$names · 하나 더 담으면 물어볼 수 있어요'
                          : names,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (n >= 2)
            FilledButton.tonal(
              onPressed: onAsk,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primaryDeep,
                minimumSize: const Size(0, 42),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              child: const Text('친구한테 물어보기'),
            ),
        ],
      ),
    );
  }
}
