import 'package:flutter/foundation.dart';

import '../../core/life/life_repository.dart';
import 'trip_models.dart';

/// 지금 진행 중인 여행 상태. 서버 저장은 생활 서버가 생긴 뒤 붙인다(지금은 메모리).
class TripController extends ChangeNotifier {
  TripController({Trip? initial, DateTime Function()? clock})
      : _trip = initial,
        _clock = clock ?? DateTime.now;

  Trip? _trip;
  final DateTime Function() _clock;
  bool _recordingRoute = false;

  Trip? get trip => _trip;
  bool get recordingRoute => _recordingRoute;

  void startTrip({required String cityId, required String cityName, required String provinceName}) {
    final now = _clock();
    _trip = Trip(
      id: 'trip-${now.millisecondsSinceEpoch}',
      cityId: cityId,
      cityName: cityName,
      provinceName: provinceName,
      startDate: DateTime(now.year, now.month, now.day),
    );
    notifyListeners();
  }

  bool isCheckedIn(String placeId) => _trip?.checkIns.any((c) => c.id == placeId) ?? false;

  /// 장소에서 버튼 한 번으로 체크인한다. 시간은 지금 시각이며, 목록은 항상 시간순으로 정렬된다.
  void checkIn(PlaceSuggestion place) {
    final current = _trip;
    if (current == null || isCheckedIn(place.id)) return;
    _trip = current.copyWith(checkIns: [
      ...current.checkIns,
      CheckIn(id: place.id, placeName: place.name, type: place.type, at: _clock()),
    ]);
    notifyListeners();
  }

  /// 경로 기록은 사용자가 켤 때만 동작한다(백그라운드 상시 추적 없음).
  void toggleRouteRecording() {
    _recordingRoute = !_recordingRoute;
    notifyListeners();
  }
}
