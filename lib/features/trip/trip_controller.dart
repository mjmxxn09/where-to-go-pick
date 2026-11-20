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
  Future<void>? _syncing;
  bool _disposed = false;

  Trip? get trip => _trip;
  bool get recordingRoute => _recordingRoute;

  /// 저장된 모든 여행(진행 중 포함, 예시 여행 제외), 시작일 최신순.
  List<Trip> get trips => _trips;

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
        if (!log.isEmpty) {
          // 불러오는 사이에 이미 시작한 여행이 있으면 그쪽을 남긴다.
          _trips = mergeTrips(_trips, log.trips);
          final current = _trip;
          if (current == null || isSampleTrip(current)) {
            _trip = _find(log.currentId);
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
      final merged = mergeTrips(_trips, remote);
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

  void startTrip({required String cityId, required String cityName, required String provinceName}) {
    final now = _clock();
    final trip = Trip(
      id: 'trip-${now.millisecondsSinceEpoch}',
      cityId: cityId,
      cityName: cityName,
      provinceName: provinceName,
      startDate: DateTime(now.year, now.month, now.day),
    );
    _trip = trip;
    _trips = mergeTrips([trip], _trips);
    notifyListeners();
    _changed(trip);
  }

  bool isCheckedIn(String placeId) => _trip?.checkIns.any((c) => c.id == placeId) ?? false;

  /// 장소에서 버튼 한 번으로 체크인한다. 시간은 지금 시각이며, 목록은 항상 시간순으로 정렬된다.
  void checkIn(PlaceSuggestion place) {
    final current = _trip;
    if (current == null || isCheckedIn(place.id)) return;
    final next = current.copyWith(checkIns: [
      ...current.checkIns,
      CheckIn(id: place.id, placeName: place.name, type: place.type, at: _clock()),
    ]);
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

  Future<void> _save() async {
    final store = _store;
    if (store == null) return;
    final current = _trip;
    try {
      await store.save(TripLog(
        trips: _trips,
        currentId: current == null || isSampleTrip(current) ? null : current.id,
      ));
    } on Object catch (e) {
      debugPrint('여행 기록을 폰에 저장하지 못했어요: $e');
    }
  }
}

bool _sameTrips(List<Trip> a, List<Trip> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].id != b[i].id || a[i].checkIns.length != b[i].checkIns.length) return false;
  }
  return true;
}
