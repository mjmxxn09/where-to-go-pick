import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../trip/trip_models.dart';
import 'sticker_book.dart';
import 'trip_card_layout.dart';
import 'trip_note_view.dart';

/// 4 · 여행 카드: 체크인 순서대로 길 위에 놓인 모눈종이 여행 노트.
/// "한 장에 모아보기" 또는 "하루씩 나눠보기(폴더)"를 고른다.
class TripCardScreen extends StatefulWidget {
  const TripCardScreen({super.key, required this.trip});

  final Trip trip;

  @override
  State<TripCardScreen> createState() => _TripCardScreenState();
}

class _TripCardScreenState extends State<TripCardScreen> {
  TripCardMode _mode = TripCardMode.onePage;
  PaperStyle _paper = PaperStyle.grid;
  int _pageIndex = 0;
  final _boundaryKey = GlobalKey();
  Future<StickerBook>? _stickers;
  StickerBook? _loadedStickers;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stickers ??= StickerBook.load(DefaultAssetBundle.of(context)).then((book) {
      _loadedStickers = book;
      return book;
    });
  }

  @override
  void dispose() {
    _loadedStickers?.dispose();
    super.dispose();
  }

  void _notReady(String what) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$what 기능은 다음 단계에서 붙여요.')));
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final pages = paginateTrip(trip, _mode);
    final index = _pageIndex < pages.length ? _pageIndex : 0;
    final folder = pages.length > 1;

    return Scaffold(
      backgroundColor: AppColors.primaryContainer,
      appBar: AppBar(
        title: const Text('여행 카드'),
        backgroundColor: AppColors.primaryContainer,
        actions: [
          PopupMenuButton<PaperStyle>(
            tooltip: '종이 모양',
            icon: const Icon(Icons.grid_on),
            initialValue: _paper,
            onSelected: (p) => setState(() => _paper = p),
            itemBuilder: (_) => const [
              PopupMenuItem(value: PaperStyle.grid, child: Text('모눈')),
              PopupMenuItem(value: PaperStyle.dot, child: Text('점')),
              PopupMenuItem(value: PaperStyle.plain, child: Text('무지')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.m, 0, Gap.m, Gap.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<TripCardMode>(
                segments: const [
                  ButtonSegment(value: TripCardMode.onePage, label: Text('한 장에 모아보기')),
                  ButtonSegment(value: TripCardMode.perDay, label: Text('하루씩 나눠보기')),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() {
                  _mode = s.first;
                  _pageIndex = 0;
                }),
              ),
              const SizedBox(height: Gap.s + 2),
              if (folder) ...[
                Row(
                  children: [
                    const Icon(Icons.folder_outlined, size: 18, color: AppColors.primaryDeep),
                    const SizedBox(width: 4),
                    Text('${trip.title} 폴더 · ${pages.length}장',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryDeep)),
                  ],
                ),
                const SizedBox(height: Gap.xs),
                Wrap(
                  spacing: Gap.xs,
                  children: [
                    for (var i = 0; i < pages.length; i++)
                      ChoiceChip(
                        label: Text(pages[i].days.first.label),
                        selected: i == index,
                        onSelected: (_) => setState(() => _pageIndex = i),
                      ),
                  ],
                ),
              ],
              if (folder) const SizedBox(height: Gap.s),
              Expanded(
                child: Center(
                  child: FutureBuilder<StickerBook>(
                    future: _stickers,
                    builder: (context, snap) => TripNoteView(
                      trip: trip,
                      page: pages[index],
                      paper: _paper,
                      boundaryKey: _boundaryKey,
                      stickers: snap.data,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Gap.s + 2),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _notReady('공유'),
                      icon: const Icon(Icons.ios_share),
                      label: Text(folder ? '이 장 공유' : '공유하기'),
                    ),
                  ),
                  const SizedBox(width: Gap.s),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _notReady('이미지 저장'),
                      icon: const Icon(Icons.download),
                      label: Text(folder ? '${pages.length}장 모두 저장' : '이미지 저장'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
