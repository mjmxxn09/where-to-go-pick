import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../trip/trip_models.dart';
import 'card_stickers.dart';
import 'sticker_book.dart';
import 'sticker_tray.dart';
import 'trip_card_editor.dart';
import 'trip_card_layout.dart';
import 'trip_note_view.dart';

/// 4 · 여행 카드: 체크인 순서대로 길 위에 놓인 모눈종이 여행 노트.
/// "한 장에 모아보기" 또는 "하루씩 나눠보기(폴더)"를 고른다.
/// 카드는 길·시간·장소만 그린 빈 카드로 시작하고, 스티커는 유저가 서랍에서 골라 붙인다.
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
  final _editorKey = GlobalKey<TripCardEditorState>();
  var _loadStarted = false;
  StickerBook? _book;
  CardStickerStore? _store;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadStarted) return;
    _loadStarted = true;
    StickerBook.load(DefaultAssetBundle.of(context)).then((book) {
      if (!mounted) {
        book.dispose();
        return;
      }
      setState(() => _book = book);
    });
    CardStickerStore.load().then((store) {
      if (!mounted) {
        store.dispose();
        return;
      }
      setState(() => _store = store);
    });
  }

  @override
  void dispose() {
    _book?.dispose();
    _store
      ?..persist()
      ..dispose();
    super.dispose();
  }

  Future<bool> _confirm(String message) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('확인')),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _autoDecorate(TripCardPage page, String key) async {
    final store = _store;
    final book = _book;
    if (store == null || book == null) return;
    if (store.stickersOf(key).isNotEmpty && !await _confirm('지금 붙인 스티커를 떼고 자동으로 꾸밀까요?')) return;
    store.replaceAll(key, autoDecorate(TripNoteView.layoutOf(page), page.checkIns, has: book.has, newId: store.newId));
  }

  Future<void> _clearStickers(String key) async {
    final store = _store;
    if (store == null || store.stickersOf(key).isEmpty) return;
    if (!await _confirm('이 카드의 스티커를 모두 뗄까요?')) return;
    store.clear(key);
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
    final page = pages[index];
    final key = cardPageKey(trip, _mode, page);
    final ready = _store != null && _book != null;

    return Scaffold(
      backgroundColor: AppColors.primaryContainer,
      appBar: AppBar(
        title: const Text('여행 카드'),
        backgroundColor: AppColors.primaryContainer,
        actions: [
          IconButton(
            tooltip: '자동으로 꾸미기',
            icon: const Icon(Icons.auto_awesome),
            onPressed: ready ? () => _autoDecorate(page, key) : null,
          ),
          IconButton(
            tooltip: '스티커 모두 떼기',
            icon: const Icon(Icons.layers_clear),
            onPressed: ready ? () => _clearStickers(key) : null,
          ),
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
                child: TripCardEditor(
                  key: _editorKey,
                  card: TripNoteView(trip: trip, page: page, paper: _paper),
                  cardSize: TripNoteView.pageSize(page),
                  pageKey: key,
                  store: _store,
                  book: _book,
                  boundaryKey: _boundaryKey,
                ),
              ),
              StickerTray(book: _book, onPick: (name) => _editorKey.currentState?.addSticker(name)),
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
