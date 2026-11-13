/// 여행 노트(모눈종이 위 구불구불한 길) 배치 규칙. Flutter에 의존하지 않는 순수 계산이라 단위 테스트한다.
///
/// 규칙
/// - 체크인을 시간순으로 한 줄에 [TripCardLayoutConfig.stopsPerRow]곳씩 길 위에 놓고, 길을 가로지르는 눈금으로 표시한다.
/// - 줄은 왼→오, 오→왼 번갈아 진행하고, 줄 끝에서 반원으로 꺾여 다음 줄로 내려간다.
/// - 이름은 길 아래·위를 번갈아 쓴다(첫 장소는 아래). 같은 쪽 이웃과는 두 칸 떨어져 있어 넓게 쓸 수 있다.
/// - 스티커는 유저가 직접 붙인다. 길이 꺾이는 반원 안쪽 여백([StickerSlot])은 "자동으로 꾸미기"가 쓰는 추천 자리다.
/// - 체크인이 늘면 줄이 늘고 페이지 높이도 늘어난다.
library;

import '../trip/trip_models.dart';

class TripCardLayoutConfig {
  const TripCardLayoutConfig({
    this.pageWidth = 358,
    this.firstRowY = 170,
    this.rowGap = 140,
    this.startX = 24,
    this.turnInset = 80,
    this.endInset = 36,
    this.stopsPerRow = 3,
    this.stopsLeft = 94,
    this.stopsRight = 264,
    this.footerHeight = 150,
  });

  final double pageWidth;
  final double firstRowY;

  /// 줄 간격 = 반원 지름. 아래 이름(최대 2줄)과 다음 줄 위 이름이 겹치지 않는 최소값.
  final double rowGap;
  final double startX;

  /// 반원 중심의 x 여백(왼쪽 기준). 오른쪽은 pageWidth - turnInset.
  final double turnInset;
  final double endInset;
  final int stopsPerRow;

  /// 장소 눈금이 놓이는 가로 범위. 양 끝을 비워 반원 안쪽에 그림 자리를 남긴다.
  final double stopsLeft;
  final double stopsRight;
  final double footerHeight;

  double get radius => rowGap / 2;
  double get leftTurnX => turnInset;
  double get rightTurnX => pageWidth - turnInset;

  /// 눈금 사이 간격.
  double get slotWidth => (stopsRight - stopsLeft) / stopsPerRow;

  /// 장소 이름이 쓸 수 있는 최대 폭. 같은 쪽(위 또는 아래) 이웃은 두 칸 떨어져 있으므로 2칸 − 8px.
  double get labelMaxWidth => slotWidth * 2 - 18;
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
  const StopSlot({
    required this.index,
    required this.x,
    required this.y,
    required this.row,
    required this.labelAbove,
  });

  final int index;
  final double x;
  final double y;
  final int row;

  /// true면 이름을 길 위에, false면 아래에 쓴다.
  final bool labelAbove;
}

/// 반원 안쪽 추천 스티커 자리("자동으로 꾸미기"). [afterRow] 줄 끝에서 꺾이는 곳이며, 그 줄 마지막 장소의 스티커를 놓는다.
class StickerSlot {
  const StickerSlot({
    required this.afterRow,
    required this.stopIndex,
    required this.centerX,
    required this.centerY,
    required this.maxWidth,
  });

  final int afterRow;
  final int stopIndex;
  final double centerX;
  final double centerY;
  final double maxWidth;
}

class TripCardLayout {
  const TripCardLayout({
    required this.road,
    required this.stops,
    required this.stickers,
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
  final List<StickerSlot> stickers;
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

  // 칸 위치: 진행 방향을 따라 순서를 매긴다. 이름은 아래·위 번갈아.
  final stops = <StopSlot>[];
  for (var k = 0; k < stopCount; k++) {
    final row = k ~/ c.stopsPerRow;
    final slot = k % c.stopsPerRow;
    final y = c.firstRowY + row * c.rowGap;
    final fromLeft = c.stopsLeft + c.slotWidth * (slot + 0.5);
    final x = row.isEven ? fromLeft : c.stopsLeft + c.stopsRight - fromLeft;
    stops.add(StopSlot(index: k, x: x, y: y, row: row, labelAbove: k.isOdd));
  }

  // 반원 안쪽 그림 자리: 오른쪽 반원은 (줄 끝 장소 범위 ~ 반원) 사이, 왼쪽도 같은 방식.
  final stickers = <StickerSlot>[];
  for (var i = 0; i < rows - 1 && stopCount > 0; i++) {
    final lastInRow = ((i + 1) * c.stopsPerRow - 1).clamp(0, stopCount - 1);
    final rightSide = i.isEven;
    final innerEdge = rightSide ? c.rightTurnX + c.radius - 10 : c.leftTurnX - c.radius + 10;
    // 줄 끝 장소(가장 바깥 칸)의 이름 끝 + 4px
    final labelEdge = rightSide
        ? c.stopsRight - c.slotWidth / 2 + c.labelMaxWidth / 2 + 4
        : c.stopsLeft + c.slotWidth / 2 - c.labelMaxWidth / 2 - 4;
    final width = (innerEdge - labelEdge).abs() - 6;
    stickers.add(StickerSlot(
      afterRow: i,
      stopIndex: lastInRow.toInt(),
      centerX: (innerEdge + labelEdge) / 2,
      centerY: c.firstRowY + i * c.rowGap + c.rowGap / 2,
      maxWidth: width,
    ));
  }

  final lastY = c.firstRowY + (rows - 1) * c.rowGap;
  return TripCardLayout(
    road: road,
    stops: stops,
    stickers: stickers,
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

/// 장소 이름을 **띄어쓰기 단위로만** 줄바꿈한다("안목 커피거 / 리"가 아니라 "안목 / 커피거리").
/// 한 줄에 다 들어가면 한 줄. [measure]는 한 줄 폭을 잰다.
/// [maxLines] 안에 못 넣거나 한 단어가 [maxWidth]보다 넓으면 null(글자를 줄이거나 말줄임으로 처리).
List<String>? wrapByWords(String text, double maxWidth, double Function(String line) measure, {int maxLines = 2}) {
  final words = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return const [''];
  final lines = <String>[];
  var current = '';
  for (final word in words) {
    final candidate = current.isEmpty ? word : '$current $word';
    if (measure(candidate) <= maxWidth) {
      current = candidate;
      continue;
    }
    if (current.isEmpty || measure(word) > maxWidth) return null;
    lines.add(current);
    current = word;
  }
  lines.add(current);
  return lines.length <= maxLines ? lines : null;
}
