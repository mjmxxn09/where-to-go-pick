import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/pickle/pickle_models.dart';
import '../../core/theme/app_surfaces.dart';
import '../../core/theme/app_theme.dart';
import '../korea_map/korea_map_data.dart';
import '../korea_map/korea_map_view.dart';
import '../trip/trip_controller.dart';
import '../trip/trip_models.dart';
import '../trip/visited_cities.dart';
import '../trip_card/trip_card_screen.dart';

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

  void _openCard(Trip trip) {
    if (trip.checkIns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('체크인한 곳이 없어서 카드가 비어 있어요.')));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TripCardScreen(trip: trip)));
  }

  Future<void> _delete(TripController controller, Trip trip) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${trip.title}을 지울까요?'),
        content: Text('체크인 ${trip.checkIns.length}곳, 가볼 곳, 카드 꾸미기가 모두 지워져요. 되돌릴 수 없어요.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('그대로 두기')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('지우기')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    controller.deleteTrip(trip.id);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${trip.title}을 지웠어요.')));
  }

  void _resume(TripController controller, Trip trip) {
    final current = controller.trip;
    controller.resumeTrip(trip.id);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(current == null ? '${trip.title}을 다시 이어가요.' : '${current.title}을 마치고 ${trip.title}을 이어가요.'),
    ));
    widget.onOpenTrip();
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
              // 도 전체 여행은 체크인한 곳이 든 시·군·구까지 칠한다.
              final painted = {...visited, ...citiesFromWholeProvinceTrips(snap.data!, scope.trip.trips)};
              return KoreaMapView(data: snap.data!, mode: KoreaMapMode.visited, visitedCityIds: painted);
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
                        Text(
                          trip.isBeforeStart(DateTime.now()) ? '● 다가오는 여행' : '● 지금 여행 중',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.secondary),
                        ),
                        Text(
                          '${trip.title} · ${trip.statusOn(DateTime.now())}',
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
        if (scope.trip.pastTrips.isNotEmpty) ...[
          const SizedBox(height: Gap.m),
          Text('지난 여행', style: titleStyle(18)),
          const SizedBox(height: Gap.s),
          for (final t in scope.trip.pastTrips)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.s),
              child: _PastTripTile(
                trip: t,
                onOpen: () => _openCard(t),
                onResume: () => _resume(scope.trip, t),
                onDelete: () => _delete(scope.trip, t),
              ),
            ),
        ],
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

/// 지난 여행 한 줄: 누르면 카드, 오른쪽 메뉴에서 다시 이어가기.
class _PastTripTile extends StatelessWidget {
  const _PastTripTile({required this.trip, required this.onOpen, required this.onResume, required this.onDelete});

  final Trip trip;
  final VoidCallback onOpen;
  final VoidCallback onResume;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onOpen,
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.primaryContainer, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.auto_stories_outlined, color: AppColors.primaryDeep),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(trip.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                Text(
                  '${trip.startDate.year}. ${dateRangeLabel(trip.startDate, trip.lastDate)} · ${trip.lengthLabel} · 체크인 ${trip.checkIns.length}곳',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: '더 보기',
            onSelected: (v) => v == 'delete' ? onDelete() : onResume(),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'resume', child: Text('다시 이어가기')),
              PopupMenuItem(value: 'delete', child: Text('지우기')),
            ],
          ),
        ],
      ),
    );
  }
}
