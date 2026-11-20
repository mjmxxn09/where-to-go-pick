import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/life/life_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/votes/vote_repository.dart';
import '../votes/pickle_ask_bubble.dart';
import '../shared/weather_icon.dart';
import '../trip_card/trip_card_screen.dart';
import 'place_filter.dart';
import 'trip_controller.dart';
import 'trip_models.dart';

/// 3 · 여행 중: 그날 날씨, 가볼 곳(☆로 담은 곳), 명소·맛집 추천과 이름 검색, 버튼 한 번 체크인, 시간순 기록.
class TripScreen extends StatefulWidget {
  const TripScreen({super.key});

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  PlaceFilter _filter = PlaceFilter.all;
  String? _loadedCity;
  Future<List<PlaceSuggestion>>? _places;
  Future<DayWeather>? _weather;

  /// 다녀온 곳에 준 "나도 한 표".
  Set<String> _myVotes = {};

  /// 체크인 직후 픽클이의 질문(방금 간 곳, 그 전에 간 곳). null이면 말풍선 없음.
  ({CheckIn just, CheckIn other})? _ask;
  String? _picked;
  int? _points;

  final _searchCtrl = TextEditingController();
  String _query = '';
  Future<List<PlaceSuggestion>>? _results;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _search(String cityId, String text) {
    final query = text.trim();
    setState(() {
      _query = query;
      _results = query.isEmpty ? null : AppScope.of(context).life.search(cityId: cityId, query: query);
    });
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() {
      _query = '';
      _results = null;
    });
  }

  void _ensureLoaded(Trip trip) {
    if (_loadedCity == trip.cityId) return;
    final scope = AppScope.of(context);
    _loadedCity = trip.cityId;
    _places = scope.pickle.myInterestKeys().then((keys) => scope.life.places(cityId: trip.cityId, interestKeys: keys));
    _weather = scope.life.weather(cityId: trip.cityId, date: DateTime.now());
    _myVotes = {};
    _query = '';
    _results = null;
    // 빌드 중이라 글자 지우기는 다음 프레임에(입력창이 듣고 있으면 빌드 중 갱신 오류가 난다).
    if (_searchCtrl.text.isNotEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => _searchCtrl.clear());
    scope.votes.myPlaceVotes(trip.cityId).then((v) {
      if (mounted && _loadedCity == trip.cityId) setState(() => _myVotes = v);
    });
  }

  void _checkIn(TripController controller, PlaceSuggestion place) {
    controller.checkIn(place);
    final checkIns = controller.trip?.checkIns ?? const <CheckIn>[];
    final just = checkIns.where((c) => c.id == place.id).firstOrNull;
    final before = just == null ? const <CheckIn>[] : checkIns.where((c) => c.id != place.id && !c.at.isAfter(just.at));
    // 비교할 곳이 있어야 묻는다(그날 첫 체크인이면 묻지 않음).
    setState(() {
      _ask = just == null || before.isEmpty ? null : (just: just, other: before.last);
      _picked = null;
      _points = null;
    });
  }

  Future<void> _answer(String cityId, bool justWon) async {
    final ask = _ask;
    if (ask == null) return;
    final winner = justWon ? ask.just : ask.other;
    final loser = justWon ? ask.other : ask.just;
    setState(() => _picked = winner.placeName);
    final points = await AppScope.of(context)
        .votes
        .answerPair(cityId: cityId, winnerPlaceId: winner.id, otherPlaceId: loser.id);
    if (mounted && identical(_ask, ask)) setState(() => _points = points);
  }

  Future<void> _togglePlaceVote(String cityId, String placeId) async {
    final on = !_myVotes.contains(placeId);
    setState(() => _myVotes = {..._myVotes}..toggle(placeId, on));
    await AppScope.of(context).votes.setPlaceVote(cityId: cityId, placeId: placeId, on: on);
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context).trip;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final trip = controller.trip;
        if (trip == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(Gap.l),
              child: Text('여행지 탭에서 지역을 골라 여행을 시작해 봐!', textAlign: TextAlign.center),
            ),
          );
        }
        _ensureLoaded(trip);
        final ask = _ask;
        return Stack(
          children: [
            _list(context, controller, trip),
            if (ask != null)
              Positioned(
                left: 10,
                right: 12,
                bottom: 12,
                child: PickleAskBubble(
                  justVisited: ask.just.placeName,
                  other: ask.other.placeName,
                  picked: _picked,
                  points: _points,
                  onPick: (justWon) => _answer(trip.cityId, justWon),
                  onClose: () => setState(() => _ask = null),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _tile(TripController controller, Trip trip, PlaceSuggestion p) => _PlaceTile(
        place: p,
        done: controller.isCheckedIn(p.id),
        planned: controller.isPlanned(p.id),
        voted: _myVotes.contains(p.id),
        onCheckIn: () => _checkIn(controller, p),
        onTogglePlan: () => controller.togglePlanned(p),
        onVote: () => _togglePlaceVote(trip.cityId, p.id),
      );

  Widget _list(BuildContext context, TripController controller, Trip trip) {
    return ListView(
      padding: const EdgeInsets.all(Gap.m),
      children: [
        Text(trip.title, style: titleStyle(26)),
        Text('${trip.provinceName} · ${trip.lengthLabel}',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: Gap.s + 4),
        _WeatherCard(future: _weather),
        const SizedBox(height: Gap.s + 4),
        _RouteToggle(controller: controller),
        const SizedBox(height: Gap.s + 4),
        _SectionTitle(
          title: '가볼 곳',
          count: trip.planned.length,
          done: trip.planned.where((p) => controller.isCheckedIn(p.id)).length,
        ),
        const SizedBox(height: Gap.xs),
        if (trip.planned.isEmpty)
          const _LoadProblem(message: '아래 추천이나 검색에서 ☆를 눌러 가볼 곳을 담아 둬요.')
        else
          for (final p in trip.planned) _tile(controller, trip, PlaceSuggestion(id: p.id, name: p.name, type: p.type, meta: p.meta)),
        const SizedBox(height: Gap.m),
        const _SectionTitle(title: '더 찾아보기'),
        const SizedBox(height: Gap.xs),
        TextField(
          controller: _searchCtrl,
          textInputAction: TextInputAction.search,
          onSubmitted: (text) => _search(trip.cityId, text),
          decoration: InputDecoration(
            hintText: '장소 이름으로 찾기 (예: 커피, 해수욕장)',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(tooltip: '검색 지우기', icon: const Icon(Icons.close), onPressed: _clearSearch),
            filled: true,
            fillColor: AppColors.surface,
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: Gap.s),
        if (_query.isNotEmpty)
          FutureBuilder<List<PlaceSuggestion>>(
            future: _results,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(padding: EdgeInsets.all(Gap.m), child: LinearProgressIndicator());
              }
              if (snap.hasError) {
                return _LoadProblem(message: '찾지 못했어요.', onRetry: () => _search(trip.cityId, _query));
              }
              final found = snap.data ?? const <PlaceSuggestion>[];
              if (found.isEmpty) return _LoadProblem(message: "'$_query'(으)로 찾은 곳이 없어요.");
              return Column(children: [for (final p in found) _tile(controller, trip, p)]);
            },
          )
        else ...[
          FutureBuilder<List<PlaceSuggestion>>(
            future: _places,
            builder: (context, snap) {
              final all = snap.data ?? const <PlaceSuggestion>[];
              final filters = PlaceFilter.available(all.map((p) => p.type));
              final filter = filters.contains(_filter) ? _filter : PlaceFilter.all;
              final places = all.where((p) => filter.matches(p.type)).toList();
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(padding: EdgeInsets.all(Gap.m), child: LinearProgressIndicator());
              }
              if (snap.hasError) {
                return _LoadProblem(
                  message: '추천 장소를 불러오지 못했어요.',
                  onRetry: () => setState(() => _loadedCity = null),
                );
              }
              if (all.isEmpty) return const _LoadProblem(message: '이 지역 추천 장소를 아직 못 찾았어요.');
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final f in filters)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(f == PlaceFilter.all
                                  ? '${f.label} ${all.length}'
                                  : '${f.label} ${all.where((p) => f.matches(p.type)).length}'),
                              selected: f == filter,
                              showCheckmark: false,
                              onSelected: (_) => setState(() => _filter = f),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Gap.s),
                  for (final p in places) _tile(controller, trip, p),
                ],
              );
            },
          ),
        ],
        const SizedBox(height: Gap.m),
        _Timeline(trip: trip),
        const SizedBox(height: Gap.m),
        OutlinedButton.icon(
          onPressed: trip.checkIns.isEmpty
              ? null
              : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TripCardScreen(trip: trip))),
          icon: const Icon(Icons.auto_stories_outlined),
          label: const Text('여행 마치고 카드 만들기'),
        ),
        // 픽클이 말풍선이 마지막 항목을 가리지 않게
        if (_ask != null) const SizedBox(height: 170),
      ],
    );
  }
}

extension on Set<String> {
  void toggle(String value, bool on) => on ? add(value) : remove(value);
}

class _WeatherCard extends StatelessWidget {
  const _WeatherCard({required this.future});

  final Future<DayWeather>? future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DayWeather>(
      future: future,
      builder: (context, snap) {
        final w = snap.data;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: AppDecorations.card,
          child: w == null
              ? SizedBox(
                  height: 56,
                  child: Center(
                    child: snap.hasError
                        ? const Text('날씨를 불러오지 못했어요.', style: TextStyle(color: AppColors.textSecondary))
                        : const CircularProgressIndicator(),
                  ),
                )
              : Row(
                  children: [
                    WeatherIcon(sky: w.sky, size: 28),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${w.temperature}°', style: titleStyle(24)),
                        Text('${skyLabel(w.sky)} · 최저 ${w.min}° 최고 ${w.max}°',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                    const Spacer(),
                    for (final h in w.hourly)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Column(
                          children: [
                            Text('${h.hour}시', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            Text('${h.temperature}°', style: const TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }
}

/// "가볼 곳 3 · 1곳 다녀옴"
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.count, this.done = 0});

  final String title;
  final int? count;
  final int done;

  @override
  Widget build(BuildContext context) {
    final count = this.count;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(title, style: titleStyle(18)),
        if (count != null && count > 0) ...[
          const SizedBox(width: 6),
          Text(done > 0 ? '$count곳 · $done곳 다녀옴' : '$count곳',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ],
    );
  }
}

/// 장소를 못 불러왔거나 없을 때 한 줄 안내(+ 다시 시도).
class _LoadProblem extends StatelessWidget {
  const _LoadProblem({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.s),
      child: Row(
        children: [
          Expanded(child: Text(message, style: const TextStyle(color: AppColors.textSecondary))),
          if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}

class _RouteToggle extends StatelessWidget {
  const _RouteToggle({required this.controller});

  final TripController controller;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: controller.recordingRoute,
      onChanged: (_) => controller.toggleRouteRecording(),
      title: const Text('걸은 길 기록'),
      subtitle: const Text('켤 때만 위치를 기록해요. 끄면 바로 멈춰요.'),
      tileColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}

class _PlaceTile extends StatelessWidget {
  const _PlaceTile({
    required this.place,
    required this.done,
    required this.planned,
    required this.voted,
    required this.onCheckIn,
    required this.onTogglePlan,
    required this.onVote,
  });

  final PlaceSuggestion place;
  final bool done;
  final bool planned;
  final bool voted;
  final VoidCallback onCheckIn;
  final VoidCallback onTogglePlan;
  final VoidCallback onVote;

  @override
  Widget build(BuildContext context) {
    final rank = place.visitorRank;
    return Container(
      margin: const EdgeInsets.only(bottom: Gap.s),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: AppDecorations.card,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(place.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                Text(place.meta,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                // 순위와 "나도 한 표"는 늘 한 줄. 좁으면 순위 글자 끝이 말줄임으로 줄어든다.
                if (rank != null || done) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (rank != null) Flexible(child: _RankLine(rank: rank)),
                      if (rank != null && done) const SizedBox(width: 4),
                      if (done) _VoteChip(voted: voted, onTap: onVote),
                    ],
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: planned ? '가볼 곳에서 빼기' : '가볼 곳에 담기',
            isSelected: planned,
            onPressed: onTogglePlan,
            visualDensity: VisualDensity.compact,
            color: const Color(0xFFF2A900),
            icon: const Icon(Icons.star_border),
            selectedIcon: const Icon(Icons.star),
          ),
          const SizedBox(width: 2),
          done
              ? Semantics(
                  label: '체크인 완료',
                  excludeSemantics: true,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                    decoration: BoxDecoration(color: const Color(0xFFF0EDFF), borderRadius: BorderRadius.circular(12)),
                    child: const Text('✓ 다녀옴',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primaryDeep)),
                  ),
                )
              : FilledButton(onPressed: onCheckIn, child: const Text('체크인')),
        ],
      ),
    );
  }
}

/// "다녀온 1,240명이 고른 해변 1위"
class _RankLine extends StatelessWidget {
  const _RankLine({required this.rank});

  final VisitorRank rank;

  static const _color = Color(0xFFA3245F);

  @override
  Widget build(BuildContext context) => Text(
        rank.label,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _color),
      );
}

/// 다녀온 곳에만 보이는 "나도 한 표".
class _VoteChip extends StatelessWidget {
  const _VoteChip({required this.voted, required this.onTap});

  final bool voted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        toggled: voted,
        child: Material(
          color: voted ? _RankLine._color : const Color(0xFFFCEEF5),
          borderRadius: BorderRadius.circular(99),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(99),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              child: Text(
                voted ? '내 표 ✓' : '나도 한 표',
                maxLines: 1,
                softWrap: false,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: voted ? Colors.white : _RankLine._color),
              ),
            ),
          ),
        ),
      );
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    if (trip.checkIns.isEmpty) {
      return const Text('아직 체크인한 곳이 없어요.', style: TextStyle(color: AppColors.textSecondary));
    }
    String hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('체크인 기록 (시간순)', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: Gap.s),
        for (final day in trip.days) ...[
          Text(day.label, style: const TextStyle(fontFamily: AppFonts.title, color: AppColors.primaryDeep)),
          for (final c in day.checkIns)
            Padding(
              padding: const EdgeInsets.only(left: Gap.s, top: 2, bottom: 2),
              child: Text('${hm(c.at)}  ${c.placeName}  · ${c.type.label}'),
            ),
          const SizedBox(height: Gap.xs),
        ],
      ],
    );
  }
}
