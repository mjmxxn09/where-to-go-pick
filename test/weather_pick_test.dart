import 'package:flutter_test/flutter_test.dart';
import 'package:where_to_go_pick/features/trip/trip_models.dart';
import 'package:where_to_go_pick/features/trip/trip_screen.dart';

Trip _trip(DateTime start, {int days = 3}) => Trip(
      id: 't',
      cityId: '32030',
      cityName: '강릉시',
      provinceName: '강원특별자치도',
      startDate: start,
      plannedDays: days,
    );

void main() {
  final now = DateTime(2026, 11, 23, 14, 30);

  test('여행 중 전체 → 오늘, 날짜 칸 → 그날', () {
    final trip = _trip(DateTime(2026, 11, 23));
    final all = weatherPickFor(trip, null, now);
    expect(all.date, DateTime(2026, 11, 23));
    expect(all.isToday, isTrue);
    expect(all.label, '오늘 날씨');

    final second = weatherPickFor(trip, 1, now);
    expect(second.date, DateTime(2026, 11, 24));
    expect(second.isToday, isFalse);
    expect(second.label, startsWith('2일차 · 11월 24일'));
  });

  test('출발 전 전체 → 출발일, 사흘 넘게 남으면 안내만', () {
    expect(weatherPickFor(_trip(DateTime(2026, 11, 25)), null, now).date, DateTime(2026, 11, 25));
    final far = weatherPickFor(_trip(DateTime(2026, 11, 28)), null, now);
    expect(far.date, isNull);
    expect(far.note, contains('3일 전부터'));
    expect(weatherPickFor(_trip(DateTime(2026, 11, 25)), 2, now).date, DateTime(2026, 11, 27));
  });

  test('지난 날은 예보 없음', () {
    final trip = _trip(DateTime(2026, 11, 21));
    final first = weatherPickFor(trip, 0, now);
    expect(first.date, isNull);
    expect(first.note, contains('지난 날'));
    expect(weatherPickFor(trip, 2, now).isToday, isTrue);
  });
}
