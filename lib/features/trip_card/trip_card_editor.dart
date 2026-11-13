import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'card_stickers.dart';
import 'sticker_book.dart';

/// 여행 노트 위에 스티커를 붙이고 옮기는 편집 화면.
///
/// - 스티커 누르기: 고르기(맨 위로 올라옴). 빈 곳 누르기: 고르기 해제
/// - 한 손가락으로 끌기: 옮기기. 두 손가락: 크기·회전
/// - 마우스(웹)에서는 아래 도구 막대로 크기·회전·떼기
/// - 서랍에서 카드로 끌어다 놓거나, 서랍 스티커를 누르면 카드 가운데에 붙는다([TripCardEditorState.addSticker]).
///
/// 카드와 붙인 스티커는 [boundaryKey]의 `RepaintBoundary` 안에 있어 이미지 저장·공유에 그대로 쓴다.
/// 고른 스티커의 테두리는 그 바깥에 그려 저장 이미지에 남지 않는다.
class TripCardEditor extends StatefulWidget {
  const TripCardEditor({
    super.key,
    required this.card,
    required this.cardSize,
    required this.pageKey,
    required this.store,
    required this.book,
    this.boundaryKey,
  });

  /// 바탕 카드(TripNoteView).
  final Widget card;
  final Size cardSize;
  final String pageKey;

  /// null이면 아직 불러오는 중 — 보기만 한다.
  final CardStickerStore? store;
  final StickerBook? book;
  final GlobalKey? boundaryKey;

  @override
  State<TripCardEditor> createState() => TripCardEditorState();
}

class TripCardEditorState extends State<TripCardEditor> {
  final _boardKey = GlobalKey();
  String? _selectedId;

  // 끌기·두 손가락 제스처 상태
  String? _activeId;
  Offset _lastFocal = Offset.zero;
  double _startSize = defaultStickerSize;
  double _startRotation = 0;
  var _added = 0;

  List<PlacedSticker> get _stickers => widget.store?.stickersOf(widget.pageKey) ?? const [];

  PlacedSticker? _byId(String? id) {
    if (id == null) return null;
    for (final s in _stickers) {
      if (s.id == id) return s;
    }
    return null;
  }

  @override
  void didUpdateWidget(TripCardEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageKey != widget.pageKey) {
      _selectedId = null;
      _activeId = null;
    }
  }

  /// 서랍에서 누른 스티커를 카드에 붙인다. [at]이 없으면 가운데 근처(여러 번 누르면 조금씩 비켜서).
  void addSticker(String name, {Offset? at}) {
    final store = widget.store;
    if (store == null) return;
    final size = widget.cardSize;
    final shift = (_added++ % 5) * 14.0;
    final p = at ?? Offset(size.width / 2 - 28 + shift, size.height / 2 - 28 + shift);
    final sticker = PlacedSticker(
      id: store.newId(),
      name: name,
      x: p.dx.clamp(0, size.width).toDouble(),
      y: p.dy.clamp(0, size.height).toDouble(),
    );
    store.add(widget.pageKey, sticker);
    setState(() => _selectedId = sticker.id);
  }

  void _select(PlacedSticker? s) {
    setState(() => _selectedId = s?.id);
    if (s != null) widget.store?.bringToFront(widget.pageKey, s.id);
  }

  void _onTapUp(TapUpDetails d) => _select(stickerAt(_stickers, d.localPosition.dx, d.localPosition.dy));

  void _onScaleStart(ScaleStartDetails d) {
    var hit = stickerAt(_stickers, d.localFocalPoint.dx, d.localFocalPoint.dy);
    // 두 손가락이 스티커 밖에 있어도 고른 스티커의 크기·회전은 바꿀 수 있게
    if (hit == null && d.pointerCount >= 2) hit = _byId(_selectedId);
    if (hit == null) {
      _activeId = null;
      return;
    }
    if (_selectedId != hit.id) _select(hit);
    _activeId = hit.id;
    _lastFocal = d.localFocalPoint;
    _startSize = hit.size;
    _startRotation = hit.rotation;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final s = _byId(_activeId);
    final store = widget.store;
    if (s == null || store == null) return;
    final delta = d.localFocalPoint - _lastFocal;
    _lastFocal = d.localFocalPoint;
    final size = widget.cardSize;
    store.update(
      widget.pageKey,
      s.copyWith(
        x: (s.x + delta.dx).clamp(0, size.width).toDouble(),
        y: (s.y + delta.dy).clamp(0, size.height).toDouble(),
        size: (_startSize * d.scale).clamp(minStickerSize, maxStickerSize).toDouble(),
        rotation: _startRotation + d.rotation,
      ),
      save: false,
    );
  }

  void _onScaleEnd(ScaleEndDetails d) {
    if (_activeId == null) return;
    _activeId = null;
    widget.store?.persist();
  }

  void _onDrop(DragTargetDetails<String> d) {
    final box = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    addSticker(d.data, at: box.globalToLocal(d.offset));
  }

  void _resize(PlacedSticker s, double k) => widget.store?.update(
        widget.pageKey,
        s.copyWith(size: (s.size * k).clamp(minStickerSize, maxStickerSize).toDouble()),
      );

  void _rotate(PlacedSticker s, double by) =>
      widget.store?.update(widget.pageKey, s.copyWith(rotation: s.rotation + by));

  void _delete(PlacedSticker s) {
    widget.store?.remove(widget.pageKey, s.id);
    setState(() => _selectedId = null);
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    if (store == null) return _build(context);
    return ListenableBuilder(listenable: store, builder: (context, _) => _build(context));
  }

  Widget _build(BuildContext context) {
    final size = widget.cardSize;
    final stickers = _stickers;
    final selected = _byId(_selectedId);
    final editable = widget.store != null;

    Widget board = SizedBox.fromSize(
      key: _boardKey,
      size: size,
      child: Stack(
        children: [
          RepaintBoundary(
            key: widget.boundaryKey,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox.fromSize(
                size: size,
                child: Stack(
                  children: [
                    Positioned.fill(child: widget.card),
                    for (final s in stickers) _stickerImage(s),
                  ],
                ),
              ),
            ),
          ),
          if (selected != null) _selectionFrame(selected),
        ],
      ),
    );

    if (editable) {
      final inner = board;
      board = DragTarget<String>(
        onWillAcceptWithDetails: (_) => true,
        onAcceptWithDetails: _onDrop,
        builder: (context, candidates, _) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: _onTapUp,
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          onScaleEnd: _onScaleEnd,
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: candidates.isEmpty ? null : Border.all(color: AppColors.primary, width: 3),
            ),
            child: inner,
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(child: Center(child: FittedBox(fit: BoxFit.contain, child: board))),
        SizedBox(height: 48, child: selected == null ? _hint(stickers.isEmpty) : _toolbar(selected)),
      ],
    );
  }

  Widget _stickerImage(PlacedSticker s) {
    final image = widget.book?.image(s.name);
    return Positioned(
      left: s.x - s.size / 2,
      top: s.y - s.size / 2,
      width: s.size,
      height: s.size,
      child: Transform.rotate(
        angle: s.rotation,
        child: image == null
            ? const SizedBox.shrink()
            : RawImage(image: image, fit: BoxFit.contain, filterQuality: FilterQuality.medium),
      ),
    );
  }

  Widget _selectionFrame(PlacedSticker s) {
    final side = s.size * 0.92 + 8;
    return Positioned(
      left: s.x - side / 2,
      top: s.y - side / 2,
      width: side,
      height: side,
      child: IgnorePointer(
        child: Transform.rotate(
          angle: s.rotation,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.primary, width: 1.5),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }

  Widget _hint(bool empty) => Center(
        child: Text(
          empty ? '아래 서랍에서 스티커를 눌러 붙이거나 카드로 끌어다 놓아요' : '스티커를 눌러 고르면 옮기기·크기·회전을 바꿀 수 있어요',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
        ),
      );

  Widget _toolbar(PlacedSticker s) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(tooltip: '작게', icon: const Icon(Icons.zoom_out), onPressed: () => _resize(s, 1 / 1.15)),
          IconButton(tooltip: '크게', icon: const Icon(Icons.zoom_in), onPressed: () => _resize(s, 1.15)),
          IconButton(
            tooltip: '왼쪽으로 돌리기',
            icon: const Icon(Icons.rotate_left),
            onPressed: () => _rotate(s, -math.pi / 12),
          ),
          IconButton(
            tooltip: '오른쪽으로 돌리기',
            icon: const Icon(Icons.rotate_right),
            onPressed: () => _rotate(s, math.pi / 12),
          ),
          IconButton(tooltip: '떼기', icon: const Icon(Icons.delete_outline), onPressed: () => _delete(s)),
          TextButton(onPressed: () => _select(null), child: const Text('완료')),
        ],
      );
}
