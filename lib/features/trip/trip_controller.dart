import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/life/life_repository.dart';
import 'trip_cloud.dart';
import 'trip_models.dart';
import 'trip_store.dart';

/// 여행 기록 상태: 지금 진행 중인 여행과 지난 여행들.
///
/// - [store]가 있으면 바뀔 때마다 폰에 저장한다(앱을 껐다 켜도 남는다).
/// - [cloud]가 있으면 서버(Supabase)에도 올린다. 실패해도 기록은 폰에 남고, 다음 [sync] 때 다시 올린다.
/// - 예시 여행([initial], id가 `sample-`로 시작)은 저장하지도 올리지도 않는다.
class TripController extends ChangeNotifier {
  TripController({Trip? initial, DateTime Function()? clock, TripStore? store, TripCloud? cloud})
      : _trip = initial,
        _clock = clock ?? DateTime.now,
        _store = store,
        _cloud = cloud;

  Trip? _trip;
  List<Trip> _trips = const [];
  final DateTime Function() _clock;
  final TripStore? _store;
  final TripCloud? _cloud;
  bool _recordingRoute = false;
  bool _needsPush = false;

  /// 지웠지만 아직 서버에서 지우지 못한 것(폰에도 저장). 서버 기록과 합칠 때 되살아나지 않게 한다.
  Set<String> _deletedTrips = {};
  Set<String> _deletedCheckIns = {};
  Future<void>? _syncing;
  bool _disposed = false;

  Trip? get trip => _trip;
  bool get recordingRoute => _recordingRoute;

  /// 저장된 모든 여행(진행 중 포함, 예시 여행 제외), 시작일 최신순.
  List<Trip> get trips => _trips;

  /// 지금 여행을 뺀 지난 여행들, 시작일 최신순.
  List<Trip> get pastTrips => [
        for (final t in _trips)
          if (t.id != _trip?.id) t,
      ];

  /// 체크인이 하나라도 있는 여행의 시·군·구 코드. 내 지도에 칠한다.
  Set<String> get visitedCityIds => {
        for (final t in _trips)
          if (t.checkIns.isNotEmpty) t.cityId,
      };

  /// 폰에 저장된 기록을 불러오고, 서버와 맞춘다. 앱을 열 때 한 번 부른다.
  Future<void> restore() async {
    final store = _store;
    if (store != null) {
      try {
        final log = await store.load();
        if (_disposed) return;
        _deletedTrips = {..._deletedTrips, ...log.deletedTrips};
        _deletedCheckIns = {..._deletedCheckIns, ...log.deletedCheckIns};
        if (!log.isEmpty) {
          // 불러오는 사이에 이미 시작한 여행이 있으면 그쪽을 남긴다.
          _trips = mergeTrips(_trips, log.trips, deletedTrips: _deletedTrips, deletedCheckIns: _deletedCheckIns);
          final current = _trip;
          if (current == null || isSampleTrip(current)) {
            final saved = _find(log.currentId);
            _trip = saved == null || saved.isEnded ? null : saved;
          }
          _needsPush = true; // 지난번에 못 올린 것이 있을 수 있다
          notifyListeners();
        }
      } on Object catch (e) {
        debugPrint('여행 기록을 불러오지 못했어요: $e');
      }
    }
    await sync();
  }

  /// 서버의 기록을 받아 합치고, 폰의 기록을 올린다. 로그인 직후에도 부른다.
  Future<void> sync() {
    final cloud = _cloud;
    if (cloud == null) return Future.value();
    return _syncing ??= _sync(cloud).whenComplete(() => _syncing = null);
  }

  Future<void> _sync(TripCloud cloud) async {
    try {
      final remote = await cloud.pull();
      if (_disposed) return;
      await _flushDeletes(cloud);
      final merged = mergeTrips(_trips, remote, deletedTrips: _deletedTrips, deletedCheckIns: _deletedCheckIns);
      final changed = !_sameTrips(merged, _trips);
      _trips = merged;
      final current = _trip;
      if (current != null && !isSampleTrip(current)) _trip = _find(current.id) ?? current;
      if (changed) {
        notifyListeners();
        await _save();
      }
      // 서버에 없는 여행·체크인이 있으면 올린다(순서만 달라도 올리지만 덮어쓰기라 괜찮다).
      if (_needsPush || !_sameTrips(merged, remote)) {
        await cloud.push(_trips);
      }
      _needsPush = false;
    } on Object catch (e) {
      _needsPush = true;
      debugPrint('여행 기록을 서버와 맞추지 못했어요(폰에는 남아 있어요): $e');
    }
  }

  /// 새 여행을 시작한다. 진행 중이던 여행이 있으면 지금 시각으로 마친다.
  /// [startDate]는 출발일(없으면 오늘), [plannedDays]는 정한 기간(일 수, 없으면 정하지 않음).
  void startTrip({
    required String cityId,
    required String cityName,
    required String provinceName,
    DateTime? startDate,
    int? plannedDays,
  }) {
    final now = _clock();
    final previous = _trip;
    if (previous != null && !isSampleTrip(previous) && !previous.isEnded) {
      final ended = previous.copyWith(ended: true, endedAt: now);
      _trips = [for (final t in _trips) t.id == ended.id ? ended : t];
      _changed(ended);
    }
    final trip = Trip(
      id: 'trip-${now.millisecondsSinceEpoch}',
      cityId: cityId,
      cityName: cityName,
      provinceName: provinceName,
      startDate: dateOnly(startDate ?? now),
      plannedDays: plannedDays,
    );
    _trip = trip;
    _trips = mergeTrips([trip], _trips);
    notifyListeners();
    _changed(trip);
  }

  /// 지금 여행의 출발일·기간을 바꾼다.
  void updateDates({required DateTime startDate, int? plannedDays}) {
    final current = _trip;
    if (current == null) return;
    _replaceCurrent(current.copyWith(startDate: startDate, setPlannedDays: true, plannedDays: plannedDays));
  }

  /// 체크인 시각을 바꾼다(깜빡한 체크인을 어제로, 순서 바로잡기). 목록은 다시 시간순으로.
  void updateCheckIn(String checkInId, DateTime at) {
    final current = _trip;
    if (current == null) return;
    _replaceCurrent(current.copyWith(checkIns: [
      for (final c in current.checkIns)
        c.id == checkInId ? CheckIn(id: c.id, placeName: c.placeName, type: c.type, at: at) : c,
    ]));
  }

  /// 체크인을 지운다(잘못 누른 체크인, 체크인 직후 "취소"). 지운 체크인을 돌려준다(되돌리기용).
  CheckIn? removeCheckIn(String checkInId) {
    final current = _trip;
    if (current == null) return null;
    final removed = current.checkIns.where((c) => c.id == checkInId).firstOrNull;
    if (removed == null) return null;
    if (!isSampleTrip(current)) _deletedCheckIns = {..._deletedCheckIns, checkInKey(current.id, checkInId)};
    _replaceCurrent(current.copyWith(checkIns: [
      for (final c in current.checkIns)
        if (c.id != checkInId) c,
    ]));
    _flushSoon();
    return removed;
  }

  /// 지운 체크인을 되돌린다.
  void restoreCheckIn(CheckIn checkIn) {
    final current = _trip;
    if (current == null || isCheckedIn(checkIn.id)) return;
    _deletedCheckIns = {..._deletedCheckIns}..remove(checkInKey(current.id, checkIn.id));
    _replaceCurrent(current.copyWith(checkIns: [...current.checkIns, checkIn]));
  }

  /// 여행을 통째로 지운다(체크인·가볼 곳·카드 꾸미기 포함). 지금 여행이면 여행 중 화면이 빈다.
  void deleteTrip(String tripId) {
    final target = _find(tripId);
    if (target == null) return;
    _trips = [for (final t in _trips) if (t.id != tripId) t];
    if (_trip?.id == tripId) _trip = null;
    if (!isSampleTrip(target)) _deletedTrips = {..._deletedTrips, tripId};
    notifyListeners();
    unawaited(_save());
    _flushSoon();
  }

  bool isCheckedIn(String placeId) => _trip?.checkIns.any((c) => c.id == placeId) ?? false;

  /// 장소에서 버튼 한 번으로 체크인한다. 시간은 지금 시각이며, 목록은 항상 시간순으로 정렬된다.
  void checkIn(PlaceSuggestion place) {
    final current = _trip;
    if (current == null || isCheckedIn(place.id)) return;
    _replaceCurrent(current.copyWith(checkIns: [
      ...current.checkIns,
      CheckIn(id: place.id, placeName: place.name, type: place.type, at: _clock()),
    ]));
  }

  /// 지금 여행을 마친다. 기록은 지난 여행으로 남고, 여행 중 화면은 비워진다. 마친 여행을 돌려준다.
  Trip? endTrip() {
    final current = _trip;
    if (current == null) return null;
    final ended = current.copyWith(ended: true, endedAt: _clock());
    if (!isSampleTrip(ended)) _trips = [for (final t in _trips) t.id == ended.id ? ended : t];
    _trip = null;
    notifyListeners();
    _changed(ended);
    return ended;
  }

  /// 마친 여행을 다시 지금 여행으로. 진행 중이던 다른 여행은 마친다.
  void resumeTrip(String tripId) {
    final target = _find(tripId);
    if (target == null) return;
    final now = _clock();
    final previous = _trip;
    if (previous != null && previous.id != tripId && !isSampleTrip(previous) && !previous.isEnded) {
      final ended = previous.copyWith(ended: true, endedAt: now);
      _trips = [for (final t in _trips) t.id == ended.id ? ended : t];
      _changed(ended);
    }
    _replaceCurrent(target.copyWith(ended: false));
  }

  bool isPlanned(String placeId) => _trip?.planned.any((p) => p.id == placeId) ?? false;

  /// 가볼 곳에 담거나 뺀다.
  void togglePlanned(PlaceSuggestion place) {
    final current = _trip;
    if (current == null) return;
    _replaceCurrent(current.copyWith(
      planned: isPlanned(place.id)
          ? [for (final p in current.planned) if (p.id != place.id) p]
          : [...current.planned, PlannedPlace(id: place.id, name: place.name, type: place.type, meta: place.meta)],
    ));
  }

  void _replaceCurrent(Trip next) {
    _trip = next;
    if (!isSampleTrip(next)) _trips = [for (final t in _trips) t.id == next.id ? next : t];
    notifyListeners();
    _changed(next);
  }

  /// 경로 기록은 사용자가 켤 때만 동작한다(백그라운드 상시 추적 없음).
  void toggleRouteRecording() {
    _recordingRoute = !_recordingRoute;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Trip? _find(String? id) {
    if (id == null) return null;
    for (final t in _trips) {
      if (t.id == id) return t;
    }
    return null;
  }

  void _changed(Trip trip) {
    if (isSampleTrip(trip)) return;
    unawaited(_save());
    final cloud = _cloud;
    if (cloud == null) return;
    unawaited(cloud.push([trip]).then((_) {}, onError: (Object e) {
      _needsPush = true;
      debugPrint('여행 기록을 올리지 못했어요(폰에는 남아 있어요): $e');
    }));
  }

  void _flushSoon() {
    final cloud = _cloud;
    if (cloud == null) return;
    unawaited(_flushDeletes(cloud).then((_) => _save()));
  }

  /// 지운 것을 서버에서도 지운다. 성공한 것만 목록에서 뺀다(실패하면 다음 sync 때 다시).
  Future<void> _flushDeletes(TripCloud cloud) async {
    for (final id in _deletedTrips.toList()) {
      try {
        await cloud.deleteTrip(id);
        _deletedTrips = {..._deletedTrips}..remove(id);
      } on Object catch (e) {
        debugPrint('여행을 서버에서 지우지 못했어요(다음에 다시): $e');
        return;
      }
    }
    for (final key in _deletedCheckIns.toList()) {
      final sep = key.indexOf('|');
      if (sep < 0) {
        _deletedCheckIns = {..._deletedCheckIns}..remove(key);
        continue;
      }
      try {
        await cloud.deleteCheckIn(key.substring(0, sep), key.substring(sep + 1));
        _deletedCheckIns = {..._deletedCheckIns}..remove(key);
      } on Object catch (e) {
        debugPrint('체크인을 서버에서 지우지 못했어요(다음에 다시): $e');
        return;
      }
    }
  }

  Future<void> _save() async {
    final store = _store;
    if (store == null) return;
    final current = _trip;
    try {
      await store.save(TripLog(
        trips: _trips,
        currentId: current == null || isSampleTrip(current) ? null : current.id,
        deletedTrips: _deletedTrips,
        deletedCheckIns: _deletedCheckIns,
      ));
    } on Object catch (e) {
      debugPrint('여행 기록을 폰에 저장하지 못했어요: $e');
    }
  }
}

bool _sameTrips(List<Trip> a, List<Trip> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].id != b[i].id ||
        a[i].checkIns.length != b[i].checkIns.length ||
        a[i].planned.length != b[i].planned.length ||
        a[i].endedAt != b[i].endedAt ||
        a[i].plannedDays != b[i].plannedDays ||
        a[i].startDate != b[i].startDate) {
      return false;
    }
  }
  return true;
}
