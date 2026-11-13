import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/life/life_repository.dart';
import '../../core/theme/app_theme.dart';
import '../shared/weather_icon.dart';
import '../trip_card/trip_card_screen.dart';
import 'trip_controller.dart';
import 'trip_models.dart';

/// 3 · 여행 중: 그날 날씨, 명소·맛집 추천, 버튼 한 번 체크인, 시간순 기록.
class TripScreen extends StatefulWidget {
  const TripScreen({super.key});

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  bool _food = false;
  String? _loadedCity;
  Future<List<PlaceSuggestion>>? _places;
  Future<DayWeather>? _weather;

  void _ensureLoaded(Trip trip) {
    if (_loadedCity == trip.cityId) return;
    final scope = AppScope.of(context);
    _loadedCity = trip.cityId;
    _places = scope.pickle.myInterestKeys().then((keys) => scope.life.places(cityId: trip.cityId, interestKeys: keys));
    _weather = scope.life.weather(cityId: trip.cityId, date: DateTime.now());
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
        return ListView(
          padding: const EdgeInsets.all(Gap.m),
          children: [
            Text(trip.title, style: const TextStyle(fontFamily: AppFonts.title, fontSize: 24)),
            Text('${trip.provinceName} · ${trip.lengthLabel}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: Gap.s + 4),
            _WeatherCard(future: _weather),
            const SizedBox(height: Gap.s + 4),
            _RouteToggle(controller: controller),
            const SizedBox(height: Gap.s + 4),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('명소')),
                ButtonSegment(value: true, label: Text('맛집')),
              ],
              selected: {_food},
              onSelectionChanged: (s) => setState(() => _food = s.first),
            ),
            const SizedBox(height: Gap.s),
            FutureBuilder<List<PlaceSuggestion>>(
              future: _places,
              builder: (context, snap) {
                final places = (snap.data ?? const <PlaceSuggestion>[]).where((p) => p.isFood == _food).toList();
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(padding: EdgeInsets.all(Gap.m), child: LinearProgressIndicator());
                }
                return Column(children: [for (final p in places) _PlaceTile(place: p, controller: controller)]);
              },
            ),
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
          ],
        );
      },
    );
  }
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
          decoration: BoxDecoration(color: AppColors.tertiaryContainer, borderRadius: BorderRadius.circular(16)),
          child: w == null
              ? const SizedBox(height: 56, child: Center(child: CircularProgressIndicator()))
              : Row(
                  children: [
                    WeatherIcon(sky: w.sky, size: 28),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${w.temperature}°', style: const TextStyle(fontFamily: AppFonts.title, fontSize: 24)),
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
  const _PlaceTile({required this.place, required this.controller});

  final PlaceSuggestion place;
  final TripController controller;

  @override
  Widget build(BuildContext context) {
    final done = controller.isCheckedIn(place.id);
    return Card(
      elevation: 0,
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: Gap.s),
      child: ListTile(
        title: Text(place.name, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Row(
          children: [
            Flexible(child: Text(place.meta)),
            if (place.pickleVoteBadge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  place.pickleVoteBadge!,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFA3245F)),
                ),
              ),
            ],
          ],
        ),
        trailing: done
            ? const Chip(label: Text('체크인 완료'))
            : FilledButton(onPressed: () => controller.checkIn(place), child: const Text('체크인')),
      ),
    );
  }
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
