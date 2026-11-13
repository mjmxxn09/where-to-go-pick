import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/pickle/pickle_models.dart';
import '../../core/theme/app_theme.dart';
import '../korea_map/korea_map_data.dart';
import '../korea_map/korea_map_view.dart';

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _friend ??= AppScope.of(context).pickle.myFriend();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final visited = scope.visitedCityIds;
    final paintedProvinces = visited.map((id) => id.substring(0, 2)).toSet().length;

    return ListView(
      padding: const EdgeInsets.all(Gap.m),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('내 여행 지도', style: TextStyle(fontFamily: AppFonts.title, fontSize: 26)),
            ),
            FilledButton.icon(
              onPressed: widget.onNewTrip,
              icon: const Icon(Icons.add),
              label: const Text('새 여행'),
            ),
          ],
        ),
        const SizedBox(height: Gap.s + 4),
        _ProgressCard(friend: _friend, painted: paintedProvinces),
        const SizedBox(height: Gap.s + 4),
        FutureBuilder<KoreaMapData>(
          future: scope.mapData,
          builder: (context, snap) {
            if (snap.hasError) return const _MapError();
            if (!snap.hasData) return const SizedBox(height: 460, child: Center(child: CircularProgressIndicator()));
            return KoreaMapView(data: snap.data!, mode: KoreaMapMode.visited, visitedCityIds: visited);
          },
        ),
        const SizedBox(height: Gap.s + 4),
        ListenableBuilder(
          listenable: scope.trip,
          builder: (context, _) {
            final trip = scope.trip.trip;
            if (trip == null) return const SizedBox.shrink();
            return Material(
              color: AppColors.secondaryContainer,
              borderRadius: BorderRadius.circular(16),
              child: ListTile(
                onTap: widget.onOpenTrip,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                leading: const Icon(Icons.luggage, color: AppColors.secondary),
                title: Text(
                  '${trip.title} · ${trip.dayCount}일차',
                  style: const TextStyle(fontFamily: AppFonts.title, fontSize: 18),
                ),
                subtitle: Text('체크인 ${trip.checkIns.length}곳'),
                trailing: const Icon(Icons.chevron_right),
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
  const _ProgressCard({required this.friend, required this.painted});

  final Future<PickleFriend?>? friend;
  final int painted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          FutureBuilder<PickleFriend?>(
            future: friend,
            builder: (context, snap) => _FriendAvatar(friend: snap.data),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('17개 시·도 중 $painted곳 색칠했어요', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: painted / 17,
                    minHeight: 8,
                    color: AppColors.primary,
                    backgroundColor: const Color(0xFFECE9F7),
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
      child: CircleAvatar(
        radius: 22,
        backgroundColor: AppColors.primaryContainer,
        child: Text(
          f == null ? '픽' : f.name.characters.first,
          style: const TextStyle(fontFamily: AppFonts.title, fontSize: 18, color: AppColors.primaryDeep),
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
