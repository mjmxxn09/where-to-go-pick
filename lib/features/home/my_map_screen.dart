import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/pickle/pickle_models.dart';
import '../../core/theme/app_surfaces.dart';
import '../../core/theme/app_theme.dart';
import '../korea_map/korea_map_data.dart';
import '../korea_map/korea_map_view.dart';
import '../trip/trip_controller.dart';

/// 1 · 내 여행 지도: 다녀온 시·군·구가 색칠된 지도와 지금 여행 바로가기.
class MyMapScreen extends StatefulWidget {
  const MyMapScreen({super.key, required this.onNewTrip, required this.onOpenTrip});

  final VoidCallback onNewTrip;
  final VoidCallback onOpenTrip;

  @override
  State<MyMapScreen> createState() => _MyMapScreenState();
}

class _MyMapScreenState extends State<MyMapScreen> {
  Future<PickleFriend?>? _friend;
  TripController? _listening;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = AppScope.of(context);
    _friend ??= scope.pickle.myFriend();
    // 체크인하거나 서버에서 지난 여행을 받아 오면 지도를 다시 칠한다.
    if (!identical(_listening, scope.trip)) {
      _listening?.removeListener(_onTripChanged);
      _listening = scope.trip..addListener(_onTripChanged);
    }
  }

  void _onTripChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _listening?.removeListener(_onTripChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final visited = {...scope.visitedCityIds, ...scope.trip.visitedCityIds};
    final paintedProvinces = visited.map((id) => id.substring(0, 2)).toSet().length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.m, 18, Gap.m, Gap.l),
      children: [
        Row(
          children: [
            FutureBuilder<PickleFriend?>(
              future: _friend,
              builder: (context, snap) => _FriendAvatar(friend: snap.data),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FutureBuilder<PickleFriend?>(
                    future: _friend,
                    builder: (context, snap) => Text(
                      snap.data == null ? '픽클 친구랑 다닌 곳' : '${snap.data!.name}랑 다닌 곳',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                    ),
                  ),
                  Text('내 여행 지도', style: titleStyle(26)),
                ],
              ),
            ),
            DecoratedBox(
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(999)),
                boxShadow: AppDecorations.buttonShadow,
              ),
              child: FilledButton.icon(
                onPressed: widget.onNewTrip,
                icon: const Icon(Icons.add),
                label: const Text('새 여행'),
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.s + 4),
        _ProgressCard(painted: paintedProvinces),
        const SizedBox(height: Gap.s + 4),
        DecoratedBox(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(24)),
            boxShadow: AppDecorations.cardShadow,
          ),
          child: FutureBuilder<KoreaMapData>(
            future: scope.mapData,
            builder: (context, snap) {
              if (snap.hasError) return const _MapError();
              if (!snap.hasData) return const SizedBox(height: 460, child: Center(child: CircularProgressIndicator()));
              return KoreaMapView(data: snap.data!, mode: KoreaMapMode.visited, visitedCityIds: visited);
            },
          ),
        ),
        const SizedBox(height: Gap.s + 4),
        ListenableBuilder(
          listenable: scope.trip,
          builder: (context, _) {
            final trip = scope.trip.trip;
            if (trip == null) return const SizedBox.shrink();
            return AppCard(
              onTap: widget.onOpenTrip,
              padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: AppColors.secondaryContainer, borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.luggage, color: AppColors.secondary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '● 지금 여행 중',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.secondary),
                        ),
                        Text(
                          '${trip.title} · ${trip.dayCount}일차',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  Text('체크인 ${trip.checkIns.length}곳',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                  const Icon(Icons.chevron_right, color: AppColors.muted),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: Gap.m),
        const Text(
          '지도: 통계청 SGIS 행정구역 경계(2018) · 공공누리 제1유형',
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.painted});

  final int painted;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '$painted', style: const TextStyle(fontSize: 38)),
                const TextSpan(text: '/17', style: TextStyle(fontSize: 18, color: Color(0xFFA9A3D6))),
              ],
            ),
            style: const TextStyle(fontFamily: AppFonts.title, height: 1, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('시·도를 색칠했어요', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: painted / 17,
                    minHeight: 10,
                    semanticsLabel: '색칠한 시·도',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 캐릭터 이미지는 픽클 쪽 자산 사용 승인 전까지 이름 배지로 대신한다.
class _FriendAvatar extends StatelessWidget {
  const _FriendAvatar({required this.friend});

  final PickleFriend? friend;

  @override
  Widget build(BuildContext context) {
    final f = friend;
    return Tooltip(
      message: f == null ? '픽클 친구' : '${f.name} · ${f.stage.label}',
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Color(0x1F4A35C8), blurRadius: 16, offset: Offset(0, 6))],
        ),
        child: Text(
          f == null ? '픽' : f.name.characters.first,
          style: const TextStyle(fontFamily: AppFonts.title, fontSize: 20, color: AppColors.primaryDeep),
        ),
      ),
    );
  }
}

class _MapError extends StatelessWidget {
  const _MapError();

  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 120,
        child: Center(child: Text('지도를 불러오지 못했어요.')),
      );
}
