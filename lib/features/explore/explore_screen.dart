import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/life/life_repository.dart';
import '../../core/pickle/pickle_models.dart';
import '../../core/theme/app_theme.dart';
import '../korea_map/korea_map_data.dart';
import '../korea_map/korea_map_view.dart';
import '../shared/weather_icon.dart';
import '../votes/poll_screen.dart';

/// 2 · 여행지 고르기: 관심사(픽클 계정) → 도 → 시·군·구 → 여행 만들기.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key, required this.onTripStarted});

  final VoidCallback onTripStarted;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  Future<(List<InterestCategory>, List<String>)>? _interests;
  final Set<String> _selected = {};
  bool _selectionLoaded = false;

  // 처음엔 강원 → 강릉시가 골라진 상태로 연다(예시).
  SelectedCity? _city = const SelectedCity(
    id: '32030',
    name: '강릉시',
    provinceCode: '32',
    provinceName: '강원특별자치도',
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final pickle = AppScope.of(context).pickle;
    _interests ??= (() async => (await pickle.interestCategories(), await pickle.myInterestKeys()))();
  }

  /// ♡로 담은 여행지 후보(최대 4곳). 2곳부터 친구한테 물어볼 수 있다.
  final List<SelectedCity> _candidates = [];

  bool _isCandidate(SelectedCity c) => _candidates.any((x) => x.id == c.id);

  void _toggleCandidate(SelectedCity c) => setState(() {
        if (_isCandidate(c)) {
          _candidates.removeWhere((x) => x.id == c.id);
        } else {
          _candidates.add(c);
          if (_candidates.length > 4) _candidates.removeAt(0);
        }
      });

  void _askFriends() {
    final votes = AppScope.of(context).votes;
    final picked = List.of(_candidates);
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (routeContext) => PollScreen(
        poll: votes.askFriends(
          question: '이번 주말 어디 갈까?',
          cities: [for (final c in picked) (key: c.id, label: c.name)],
        ),
        winnerAction: (
          label: (w) => '${w.label}로 여행 만들기',
          onPressed: (w) {
            Navigator.of(routeContext).pop();
            final city = picked.firstWhere((c) => c.id == w.key, orElse: () => picked.first);
            setState(() => _city = city);
            _startTrip();
          },
        ),
      ),
    ));
  }

  void _startTrip() {
    final city = _city;
    if (city == null) return;
    AppScope.of(context).trip.startTrip(cityId: city.id, cityName: city.name, provinceName: city.provinceName);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${city.name} 여행을 시작했어요!')));
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
        FutureBuilder<(List<InterestCategory>, List<String>)>(
          future: _interests,
          builder: (context, snap) {
            final data = snap.data;
            if (data == null) return const SizedBox(height: 36);
            if (!_selectionLoaded) {
              _selected.addAll(data.$2);
              _selectionLoaded = true;
            }
            return Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in data.$1)
                  FilterChip(
                    label: Text(c.displayNameKo),
                    selected: _selected.contains(c.key),
                    onSelected: (on) => setState(() => on ? _selected.add(c.key) : _selected.remove(c.key)),
                  ),
              ],
            );
          },
        ),
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
        _CandidateBar(candidates: _candidates, onAsk: _askFriends),
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
          '도를 누르고, 가고 싶은 시·군·구를 골라봐!',
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
                Text(city.provinceName, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                Text(city.name, style: titleStyle(22)),
                FutureBuilder<DayWeather>(
                  future: life.weather(cityId: city.id, date: DateTime.now()),
                  builder: (context, snap) {
                    final w = snap.data;
                    if (w == null) return const SizedBox(height: 18);
                    return Row(
                      children: [
                        WeatherIcon(sky: w.sky, size: 16),
                        const SizedBox(width: 4),
                        Text('오늘 ${w.temperature}° · 최저 ${w.min}°',
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

/// 담은 후보 줄. 2곳부터 "친구한테 물어보기"(픽클 투표로 공유).
class _CandidateBar extends StatelessWidget {
  const _CandidateBar({required this.candidates, required this.onAsk});

  final List<SelectedCity> candidates;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) {
    final names = candidates.map((c) => c.name.replaceAll(RegExp(r'(시|군|구)$'), '')).join(' · ');
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
