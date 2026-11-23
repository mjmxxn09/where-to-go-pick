import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_scope.dart';
import '../../core/life/life_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/votes/vote_repository.dart';
import '../votes/pickle_ask_bubble.dart';
import '../shared/weather_icon.dart';
import '../trip_card/trip_card_screen.dart';
import 'check_in_edit_sheet.dart';
import 'trip_controller.dart';
import 'trip_dates_sheet.dart';
import 'trip_models.dart';

/// 3 · 여행 중: 그날 날씨, 가볼 곳(☆로 담은 곳), 명소·맛집 추천과 이름 검색, 버튼 한 번 체크인, 시간순 기록.
class TripScreen extends StatefulWidget {
  const TripScreen({super.key});

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  /// 인기 장소에서 고른 칸(명소·맛집·카페·문화).
  String _section = 'sights';
  String? _loadedCity;
  String? _weatherKey;
  Future<PopularPlaces>? _popular;
  Future<DayWeather>? _weather;

  /// 날씨를 아직 보여 줄 수 없을 때 한 줄(출발이 3일보다 더 남았을 때).
  String? _weatherNote;

  /// 다녀온 곳에 준 "나도 한 표".
  Set<String> _myVotes = {};

  /// 체크인 직후 픽클이의 질문(방금 간 곳, 그 전에 간 곳). null이면 말풍선 없음.
  ({CheckIn just, CheckIn other})? _ask;
  String? _picked;
  int? _points;

  final _searchCtrl = TextEditingController();
  String _query = '';

  /// 검색 결과(쪽을 넘기며 이어 붙인다).
  List<PlaceSuggestion> _found = const [];
  int _searchPage = 0;
  bool _searchHasMore = false;
  bool _searchOutside = false;
  bool _searching = false;
  bool _searchFailed = false;
  PlaceSource? _searchSource;

  /// 검색할 때마다 늘려, 늦게 온 이전 검색 결과를 버린다.
  int _searchSeq = 0;

  /// 인기 장소 제목 옆 한 줄.
  String get _popularNote => '종류별로 많이 찾는 5곳';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _search(String cityId, String text) {
    final query = text.trim();
    setState(() {
      _resetSearch();
      _query = query;
    });
    if (query.isNotEmpty) _searchMore(cityId);
  }

  void _resetSearch() {
    _searchSeq++;
    _query = '';
    _found = const [];
    _searchPage = 0;
    _searchHasMore = false;
    _searchOutside = false;
    _searching = false;
    _searchFailed = false;
    _searchSource = null;
  }

  /// 다음 쪽을 받아 이어 붙인다(처음이면 1쪽).
  Future<void> _searchMore(String cityId) async {
    final seq = _searchSeq;
    final query = _query;
    setState(() {
      _searching = true;
      _searchFailed = false;
    });
    try {
      final r = await AppScope.of(context).life.search(cityId: cityId, query: query, page: _searchPage + 1);
      if (!mounted || seq != _searchSeq) return;
      final seen = {for (final p in _found) p.id};
      setState(() {
        _found = [..._found, ...r.places.where((p) => !seen.contains(p.id))];
        _searchPage++;
        _searchHasMore = r.hasMore;
        _searchOutside = r.outside;
        _searchSource = r.source;
        _searching = false;
      });
    } on Object {
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _searching = false;
        _searchFailed = true;
      });
    }
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(_resetSearch);
  }

  void _ensureLoaded(Trip trip) {
    final scope = AppScope.of(context);
    // 날씨: 출발 전이면 출발일(단기예보는 3일 앞까지), 여행 중이면 오늘.
    final now = DateTime.now();
    final until = daysBetween(now, trip.startDate);
    final weatherKey = '${trip.cityId}|${until > 0 ? dateOnly(trip.startDate) : dateOnly(now)}';
    if (_weatherKey != weatherKey) {
      _weatherKey = weatherKey;
      if (until > 2) {
        _weather = null;
        _weatherNote = '출발 3일 전부터 ${monthDayLabel(trip.startDate)} 날씨가 보여요.';
      } else {
        _weatherNote = null;
        _weather = scope.life.weather(cityId: trip.cityId, date: until > 0 ? trip.startDate : now);
      }
    }
    if (_loadedCity == trip.cityId) return;
    _loadedCity = trip.cityId;
    _popular = scope.life.popular(cityId: trip.cityId);
    _section = 'sights';
    _myVotes = {};
    _resetSearch();
    // 빌드 중이라 글자 지우기는 다음 프레임에(입력창이 듣고 있으면 빌드 중 갱신 오류가 난다).
    if (_searchCtrl.text.isNotEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => _searchCtrl.clear());
    scope.votes.myPlaceVotes(trip.cityId).then((v) {
      if (mounted && _loadedCity == trip.cityId) setState(() => _myVotes = v);
    });
  }

  void _checkIn(TripController controller, PlaceSuggestion place) {
    controller.checkIn(place);
    // 잘못 눌렀을 때 바로 되돌릴 수 있게.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('${place.name} 체크인!'),
        action: SnackBarAction(
          label: '취소',
          onPressed: () {
            controller.removeCheckIn(place.id);
            if (mounted && _ask?.just.id == place.id) setState(() => _ask = null);
          },
        ),
      ));
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

  Future<void> _endTrip(TripController controller, Trip trip) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${trip.title}을 마칠까요?'),
        content: Text(trip.checkIns.isEmpty
            ? '체크인한 곳 없이 마쳐요. 지난 여행에서 다시 이어갈 수 있어요.'
            : '체크인 ${trip.checkIns.length}곳이 지난 여행에 남아요. 카드는 내 지도의 지난 여행에서 다시 볼 수 있어요.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('계속 여행하기')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('여행 마치기')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final ended = controller.endTrip();
    if (ended == null) return;
    setState(() => _ask = null);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${ended.title}을 마쳤어요.'),
      action: SnackBarAction(label: '되돌리기', onPressed: () => controller.resumeTrip(ended.id)),
    ));
  }

  Widget _tile(TripController controller, Trip trip, PlaceSuggestion p, {int? rank}) => _PlaceTile(
        place: p,
        rank: rank,
        done: controller.isCheckedIn(p.id),
        planned: controller.isPlanned(p.id),
        voted: _myVotes.contains(p.id),
        // 출발 전에는 체크인을 막는다(가볼 곳 담기는 된다).
        onCheckIn: trip.isBeforeStart(DateTime.now()) ? null : () => _checkIn(controller, p),
        onTogglePlan: () => controller.togglePlanned(p),
        onVote: () => _togglePlaceVote(trip.cityId, p.id),
      );

  Future<void> _editDates(TripController controller, Trip trip) async {
    final dates = await showTripDatesSheet(
      context,
      title: '여행 기간 바꾸기',
      confirmLabel: '바꾸기',
      initialStart: trip.startDate,
      initialDays: trip.plannedDays,
    );
    if (dates == null || !mounted) return;
    controller.updateDates(startDate: dates.start, plannedDays: dates.days);
  }

  Future<void> _editCheckIn(TripController controller, Trip trip, CheckIn checkIn) async {
    final edit = await showCheckInEditSheet(context, trip: trip, checkIn: checkIn);
    if (edit == null || !mounted) return;
    final at = edit.at;
    if (at != null) {
      controller.updateCheckIn(checkIn.id, at);
      return;
    }
    final removed = controller.removeCheckIn(checkIn.id);
    if (removed == null) return;
    if (_ask?.just.id == removed.id || _ask?.other.id == removed.id) setState(() => _ask = null);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('${removed.placeName} 체크인을 지웠어요.'),
        action: SnackBarAction(label: '되돌리기', onPressed: () => controller.restoreCheckIn(removed)),
      ));
  }

  Widget _list(BuildContext context, TripController controller, Trip trip) {
    final now = DateTime.now();
    final beforeStart = trip.isBeforeStart(now);
    return ListView(
      padding: const EdgeInsets.all(Gap.m),
      children: [
        Row(
          children: [
            Expanded(child: Text(trip.title, style: titleStyle(26))),
            IconButton(
              tooltip: '여행 기간 바꾸기',
              onPressed: () => _editDates(controller, trip),
              icon: const Icon(Icons.edit_calendar_outlined),
            ),
          ],
        ),
        Text(
          '${trip.provinceName} · ${dateRangeLabel(trip.startDate, trip.lastDate)} · ${trip.lengthLabel}',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: Gap.s),
        _DayStrip(trip: trip, now: now),
        if (beforeStart) ...[
          const SizedBox(height: Gap.s),
          _Notice(
            icon: Icons.flight_takeoff,
            text: '출발 ${trip.statusOn(now)} · 가볼 곳을 미리 담아 둬요. 체크인은 ${monthDayLabel(trip.startDate)}부터 할 수 있어요.',
          ),
        ],
        const SizedBox(height: Gap.s + 4),
        _WeatherCard(future: _weather, note: _weatherNote),
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
          const _LoadProblem(message: '아래 인기 장소나 검색에서 ☆를 눌러 가볼 곳을 담아 둬요.')
        else
          for (final p in trip.planned)
            _tile(controller, trip, PlaceSuggestion(id: p.id, name: p.name, type: p.type, meta: p.meta, url: p.url)),
        const SizedBox(height: Gap.m),
        _SectionTitle(title: '인기 장소', note: _popularNote),
        const SizedBox(height: Gap.xs),
        FutureBuilder<PopularPlaces>(
          future: _popular,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(padding: EdgeInsets.all(Gap.m), child: LinearProgressIndicator());
            }
            if (snap.hasError) {
              return _LoadProblem(message: '인기 장소를 불러오지 못했어요.', onRetry: () => setState(() => _loadedCity = null));
            }
            final popular = snap.data;
            final sections = popular?.sections ?? const <PlaceSection>[];
            if (sections.isEmpty) return const _LoadProblem(message: '이 지역 인기 장소를 아직 못 찾았어요. 아래에서 찾아 담아 봐요.');
            final section = sections.firstWhere((x) => x.key == _section, orElse: () => sections.first);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final x in sections)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(x.label),
                            selected: x.key == section.key,
                            showCheckmark: false,
                            onSelected: (_) => setState(() => _section = x.key),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: Gap.s),
                for (final (i, p) in section.places.indexed) _tile(controller, trip, p, rank: i + 1),
                _SourceNote(source: popular!.source),
              ],
            );
          },
        ),
        const SizedBox(height: Gap.m),
        const _SectionTitle(title: '찾아서 담기'),
        const SizedBox(height: Gap.xs),
        TextField(
          controller: _searchCtrl,
          textInputAction: TextInputAction.search,
          onSubmitted: (text) => _search(trip.cityId, text),
          decoration: InputDecoration(
            hintText: '가게·장소 이름 (예: 스타벅스 경포, 순두부)',
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
        if (_query.isNotEmpty) ...[
          if (_searchOutside)
            _LoadProblem(message: '${trip.cityName}에서는 못 찾아서 다른 지역 결과를 보여 줘요.'),
          for (final p in _found) _tile(controller, trip, p),
          if (_searching)
            const Padding(padding: EdgeInsets.all(Gap.m), child: LinearProgressIndicator())
          else if (_searchFailed)
            _LoadProblem(message: '찾지 못했어요.', onRetry: () => _searchMore(trip.cityId))
          else if (_found.isEmpty)
            _LoadProblem(message: "'$_query'(으)로 찾은 곳이 없어요.")
          else if (_searchHasMore)
            Center(
              child: TextButton.icon(
                onPressed: () => _searchMore(trip.cityId),
                icon: const Icon(Icons.expand_more),
                label: const Text('더 보기'),
              ),
            ),
          if (_found.isNotEmpty && _searchSource != null) _SourceNote(source: _searchSource!),
        ],
        const SizedBox(height: Gap.m),
        _Timeline(trip: trip, onTap: (c) => _editCheckIn(controller, trip, c)),
        const SizedBox(height: Gap.m),
        // 여행 중에도 카드를 미리 볼 수 있다. 여행을 끝내는 건 아래 "여행 마치기"뿐.
        OutlinedButton.icon(
          onPressed: trip.checkIns.isEmpty
              ? null
              : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TripCardScreen(trip: trip))),
          icon: const Icon(Icons.auto_stories_outlined),
          label: const Text('여행 카드 보기'),
        ),
        const SizedBox(height: Gap.xs),
        TextButton.icon(
          onPressed: () => _endTrip(controller, trip),
          icon: const Icon(Icons.flag_outlined),
          label: const Text('여행 마치기'),
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
  const _WeatherCard({required this.future, this.note});

  final Future<DayWeather>? future;

  /// 날씨 대신 보여 줄 한 줄(예: 출발이 많이 남았을 때).
  final String? note;

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
                    child: note != null
                        ? Text(note!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary))
                        : snap.hasError
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
  const _SectionTitle({required this.title, this.count, this.done = 0, this.note});

  final String title;
  final int? count;
  final int done;

  /// 제목 옆 회색 한 줄(예: "종류별로 많이 찾는 5곳").
  final String? note;

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
        if (note != null) ...[
          const SizedBox(width: 6),
          Flexible(
            child: Text(note!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ),
        ],
      ],
    );
  }
}

/// 장소 정보 출처 한 줄(카카오맵·한국관광공사).
class _SourceNote extends StatelessWidget {
  const _SourceNote({required this.source});

  final PlaceSource source;

  @override
  Widget build(BuildContext context) {
    if (source == PlaceSource.sample) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        source == PlaceSource.kakao ? '장소 정보: 카카오맵 · 이름을 누르면 카카오맵에서 자세히' : '장소 정보: 한국관광공사',
        textAlign: TextAlign.right,
        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
      ),
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
    this.rank,
  });

  final PlaceSuggestion place;

  /// 인기 장소 순위(1~5). 없으면 숫자 표시 없음.
  final int? rank;
  final bool done;
  final bool planned;
  final bool voted;
  final VoidCallback? onCheckIn;
  final VoidCallback onTogglePlan;
  final VoidCallback onVote;

  Future<void> _openDetail(BuildContext context) async {
    final url = place.url;
    if (url == null) return;
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('카카오맵을 열지 못했어요.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final rank = place.visitorRank;
    final order = this.rank;
    return Container(
      margin: const EdgeInsets.only(bottom: Gap.s),
      padding: EdgeInsets.fromLTRB(order == null ? 14 : 10, 10, 10, 10),
      decoration: AppDecorations.card,
      child: Row(
        children: [
          if (order != null) ...[
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: order == 1 ? AppColors.primary : AppColors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$order',
                style: TextStyle(
                  fontFamily: AppFonts.title,
                  fontSize: 13,
                  color: order == 1 ? Colors.white : AppColors.primaryDeep,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            // 카카오 장소면 누르면 카카오맵 상세(사진·리뷰·길찾기).
            child: InkWell(
              onTap: place.url == null ? null : () => _openDetail(context),
              borderRadius: BorderRadius.circular(8),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(place.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                Row(
                  children: [
                    Flexible(
                      child: Text(place.meta,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ),
                    if (place.url != null) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.open_in_new, size: 13, color: AppColors.muted, semanticLabel: '카카오맵에서 보기'),
                    ],
                  ],
                ),
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
  const _Timeline({required this.trip, required this.onTap});

  final Trip trip;

  /// 기록을 누르면 날·시각 바꾸기, 지우기.
  final ValueChanged<CheckIn> onTap;

  @override
  Widget build(BuildContext context) {
    if (trip.checkIns.isEmpty) {
      return const Text('아직 체크인한 곳이 없어요.', style: TextStyle(color: AppColors.textSecondary));
    }
    String hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('체크인 기록 (시간순 · 눌러서 고치기)', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: Gap.s),
        for (final day in trip.days) ...[
          Text(day.label, style: const TextStyle(fontFamily: AppFonts.title, color: AppColors.primaryDeep)),
          for (final c in day.checkIns)
            InkWell(
              onTap: () => onTap(c),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Gap.s, 6, Gap.xs, 6),
                child: Row(
                  children: [
                    Expanded(child: Text('${hm(c.at)}  ${c.placeName}  · ${c.type.label}')),
                    const Icon(Icons.edit_outlined, size: 16, color: AppColors.muted),
                  ],
                ),
              ),
            ),
          const SizedBox(height: Gap.xs),
        ],
      ],
    );
  }
}

/// 여행 날짜 줄: "1일차 11/20 · 체크인 3", 오늘은 진하게. 기간을 정하지 않았으면 오늘까지.
class _DayStrip extends StatelessWidget {
  const _DayStrip({required this.trip, required this.now});

  final Trip trip;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final today = trip.dayIndexOf(now);
    // 기간을 정했으면 그 기간(체크인이 더 길면 그만큼), 안 정했으면 오늘까지.
    final count = math.min(30, trip.plannedDays == null ? math.max(trip.totalDays, today + 1) : trip.totalDays);
    final byDay = {for (final d in trip.days) d.index: d.checkIns.length};
    final start = dateOnly(trip.startDate);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < count; i++)
            Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: i == today ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: i == today ? AppColors.primary : AppColors.primaryContainer),
              ),
              child: Text(
                '${i + 1}일차 ${start.add(Duration(days: i)).month}/${start.add(Duration(days: i)).day}'
                '${(byDay[i] ?? 0) > 0 ? ' · ${byDay[i]}곳' : ''}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: i == today ? Colors.white : AppColors.primaryDeep,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 아이콘 + 한두 줄 안내(출발 전 등).
class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.primaryContainer, borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primaryDeep),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryDeep)),
          ),
        ],
      ),
    );
  }
}
