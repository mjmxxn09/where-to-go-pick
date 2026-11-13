import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/life/life_repository.dart';
import '../../core/pickle/pickle_models.dart';
import '../../core/theme/app_theme.dart';
import '../korea_map/korea_map_data.dart';
import '../korea_map/korea_map_view.dart';
import '../shared/weather_icon.dart';

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
        const Text('어디로 떠나볼까?', style: TextStyle(fontFamily: AppFonts.title, fontSize: 24)),
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
          _CityCard(city: _city!, life: scope.life, onStart: _startTrip),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
        child: const Text(
          '도를 누르고, 가고 싶은 시·군·구를 골라봐!',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
}

class _CityCard extends StatelessWidget {
  const _CityCard({required this.city, required this.life, required this.onStart});

  final SelectedCity city;
  final LifeRepository life;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(city.provinceName, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                Text(city.name, style: const TextStyle(fontFamily: AppFonts.title, fontSize: 20)),
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
          FilledButton(onPressed: onStart, child: const Text('여행 만들기')),
        ],
      ),
    );
  }
}
