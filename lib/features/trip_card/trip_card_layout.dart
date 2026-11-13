/// 여행 노트(모눈종이 위 구불구불한 길) 배치 규칙. Flutter에 의존하지 않는 순수 계산이라 단위 테스트한다.
///
/// 규칙
/// - 체크인을 시간순으로 한 줄에 [TripCardLayoutConfig.stopsPerRow]곳씩 놓는다.
/// - 줄은 왼→오, 오→왼 번갈아 진행하고, 줄 끝에서 반원으로 꺾여 다음 줄로 내려간다.
/// - 체크인이 늘면 줄이 늘고 페이지 높이도 늘어난다.
library;

import '../trip/trip_models.dart';

class TripCardLayoutConfig {
  const TripCardLayoutConfig({
    this.pageWidth = 358,
    this.firstRowY = 150,
    this.rowGap = 140,
    this.startX = 24,
    this.turnInset = 80,
    this.endInset = 36,
    this.stopsPerRow = 2,
    this.footerHeight = 160,
  });

  final double pageWidth;
  final double firstRowY;

  /// 줄 간격 = 반원 지름. 위 줄 이름(최대 2줄)·아이콘과 아래 줄 시간 라벨이 겹치지 않는 최소값.
  final double rowGap;
  final double startX;

  /// 반원 중심의 x 여백(왼쪽 기준). 오른쪽은 pageWidth - turnInset.
  final double turnInset;
  final double endInset;
  final int stopsPerRow;
  final double footerHeight;

  double get radius => rowGap / 2;

  /// 한 줄 안에서 장소 하나가 쓸 수 있는 가로 폭(점 사이 간격).
  double get slotWidth => (rightTurnX - leftTurnX - 20) / stopsPerRow;

  /// 장소 이름이 쓸 수 있는 최대 폭. 옆 장소 이름과 8px 이상 떨어진다.
  double get labelMaxWidth => slotWidth - 8;
  double get leftTurnX => turnInset;
  double get rightTurnX => pageWidth - turnInset;
}

/// 길 그리기 명령. 화면에서는 Flutter Path로 바꾼다.
sealed class RoadStep {
  const RoadStep();
}

class RoadMove extends RoadStep {
  const RoadMove(this.x, this.y);
  final double x;
  final double y;
}

class RoadLine extends RoadStep {
  const RoadLine(this.x, this.y);
  final double x;
  final double y;
}

/// 반원. [clockwise]=true면 오른쪽으로 불룩(화면 좌표 기준 시계 방향).
class RoadArc extends RoadStep {
  const RoadArc(this.x, this.y, {required this.radius, required this.clockwise});
  final double x;
  final double y;
  final double radius;
  final bool clockwise;
}

class StopSlot {
  const StopSlot({required this.index, required this.x, required this.y, required this.row});

  final int index;
  final double x;
  final double y;
  final int row;
}

class TripCardLayout {
  const TripCardLayout({
    required this.road,
    required this.stops,
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    required this.rows,
    required this.pageHeight,
    required this.labelMaxWidth,
  });

  final List<RoadStep> road;
  final List<StopSlot> stops;
  final double startX;
  final double startY;
  final double endX;
  final double endY;
  final int rows;
  final double pageHeight;
  final double labelMaxWidth;

  bool get endsOnRight => (rows - 1).isEven;
}

TripCardLayout layoutTripCard(int stopCount, {TripCardLayoutConfig config = const TripCardLayoutConfig()}) {
  final c = config;
  final rows = stopCount <= 0 ? 1 : (stopCount + c.stopsPerRow - 1) ~/ c.stopsPerRow;
  final road = <RoadStep>[RoadMove(c.startX, c.firstRowY)];
  for (var i = 0; i < rows; i++) {
    final y = c.firstRowY + i * c.rowGap;
    final last = i == rows - 1;
    final goingRight = i.isEven;
    if (last) {
      road.add(RoadLine(goingRight ? c.pageWidth - c.endInset : c.endInset, y));
    } else {
      final turnX = goingRight ? c.rightTurnX : c.leftTurnX;
      road
        ..add(RoadLine(turnX, y))
        ..add(RoadArc(turnX, y + c.rowGap, radius: c.radius, clockwise: goingRight));
    }
  }

  // 한 줄 안 칸 위치: 줄 폭을 (칸 수 + 1)로 나눈 자리. 진행 방향을 따라 순서를 매긴다.
  final usableLeft = c.leftTurnX + 10;
  final usableRight = c.rightTurnX - 10;
  final step = c.slotWidth;
  final stops = <StopSlot>[];
  for (var k = 0; k < stopCount; k++) {
    final row = k ~/ c.stopsPerRow;
    final slot = k % c.stopsPerRow;
    final y = c.firstRowY + row * c.rowGap;
    final fromLeft = usableLeft + step * (slot + 0.5);
    final x = row.isEven ? fromLeft : usableLeft + usableRight - fromLeft;
    stops.add(StopSlot(index: k, x: x, y: y, row: row));
  }

  final lastY = c.firstRowY + (rows - 1) * c.rowGap;
  return TripCardLayout(
    road: road,
    stops: stops,
    startX: c.startX,
    startY: c.firstRowY,
    endX: (rows - 1).isEven ? c.pageWidth - c.endInset : c.endInset,
    endY: lastY,
    rows: rows,
    pageHeight: lastY + c.footerHeight,
    labelMaxWidth: c.labelMaxWidth,
  );
}

/// 카드 보기 방식.
enum TripCardMode {
  /// 모든 날을 한 장에.
  onePage,

  /// 하루씩 나눠 여러 장(폴더).
  perDay,
}

/// 한 장(페이지)에 들어갈 내용.
class TripCardPage {
  const TripCardPage({required this.days});

  final List<TripDay> days;

  List<CheckIn> get checkIns => [for (final d in days) ...d.checkIns];
  bool get isSingleDay => days.length == 1;
}

/// 보기 방식에 따라 페이지를 나눈다. 당일 여행은 항상 한 장이다.
List<TripCardPage> paginateTrip(Trip trip, TripCardMode mode) {
  final days = trip.days;
  if (days.isEmpty) return const [TripCardPage(days: [])];
  if (mode == TripCardMode.onePage || days.length == 1) return [TripCardPage(days: days)];
  return [for (final d in days) TripCardPage(days: [d])];
}
