import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'sticker_book.dart';

/// 스티커 서랍: 분류 칩 + 가로로 넘기는 스티커 목록.
/// 누르면 [onPick], 위로 끌어 카드에 놓으면 카드의 `DragTarget`이 받는다.
class StickerTray extends StatefulWidget {
  const StickerTray({super.key, required this.book, required this.onPick});

  /// null이면 아직 불러오는 중.
  final StickerBook? book;
  final ValueChanged<String> onPick;

  static const height = 116.0;

  @override
  State<StickerTray> createState() => _StickerTrayState();
}

class _StickerTrayState extends State<StickerTray> {
  var _category = 0;

  @override
  Widget build(BuildContext context) {
    final book = widget.book;
    if (book == null) {
      return const SizedBox(height: StickerTray.height, child: Center(child: CircularProgressIndicator()));
    }
    final categories = [
      for (final c in StickerBook.catalog)
        if (c.names.any(book.has)) (label: c.label, names: c.names.where(book.has).toList()),
    ];
    if (categories.isEmpty) {
      return const SizedBox(
        height: StickerTray.height,
        child: Center(child: Text('스티커 그림을 불러오지 못했어요', style: TextStyle(color: AppColors.textSecondary))),
      );
    }
    final index = _category < categories.length ? _category : 0;
    final names = categories[index].names;

    return SizedBox(
      height: StickerTray.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (_, i) => ChoiceChip(
                    label: Text(categories[i].label),
                    selected: i == index,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => setState(() => _category = i),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: ListView.separated(
                  key: ValueKey(categories[index].label),
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: names.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => _item(book, names[i]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(StickerBook book, String name) {
    final image = book.image(name)!;
    Widget picture(double side) => SizedBox(
          width: side,
          height: side,
          child: RawImage(image: image, fit: BoxFit.contain, filterQuality: FilterQuality.medium),
        );
    final tile = Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => widget.onPick(name),
        child: Padding(padding: const EdgeInsets.all(3), child: picture(58)),
      ),
    );
    // 세로로 끌 때만 끌기 시작 — 가로로 밀면 목록이 넘어간다.
    return Draggable<String>(
      data: name,
      affinity: Axis.vertical,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Transform.translate(offset: const Offset(-36, -36), child: picture(72)),
      childWhenDragging: Opacity(opacity: 0.35, child: tile),
      child: tile,
    );
  }
}
