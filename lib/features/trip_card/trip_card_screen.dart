import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../trip/trip_models.dart';
import '../votes/poll_question_sheet.dart';
import '../votes/poll_screen.dart';
import 'card_cloud.dart';
import 'card_stickers.dart';
import 'export/card_image.dart';
import 'export/card_saver.dart';
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
  /// 크게 보기: 보기 방식·스티커 서랍·버튼을 접고 카드만 화면 가득 보여준다.
  var _zoomed = false;
  final _boundaryKey = GlobalKey();
  var _busy = false;
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
    final cloud = AppScope.of(context).cloud;
    CardStickerStore.load(cloud: cloud == null ? null : SupabaseCardCloud(cloud)).then((store) {
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
    // 이름표를 덮지 않게, 지금 장소 막대 자리(옮긴 것 포함)와 이름표 칸을 재서 넘긴다.
    final boxes = TripNoteView.stopBoxes(page, store.stopEditsOf(key));
    store.replaceAll(
      key,
      autoDecorate(
        TripNoteView.layoutOf(page),
        page.checkIns,
        has: book.has,
        newId: store.newId,
        stops: [for (final b in boxes) b.slot],
        avoid: [for (final b in boxes) b.label],
        pageWidth: TripNoteView.config.pageWidth,
      ),
    );
  }

  Future<void> _clearStickers(String key) async {
    final store = _store;
    if (store == null || store.stickersOf(key).isEmpty) return;
    if (!await _confirm('이 카드의 스티커를 모두 뗄까요?')) return;
    store.clear(key);
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// 지금 화면의 카드(스티커 포함)를 PNG로. 고를 때 보이는 테두리는 경계 밖이라 담기지 않는다.
  Future<Uint8List> _captureCurrent() async {
    // 방금 바꾼 장이나 스티커가 다 그려진 뒤에 찍는다.
    await WidgetsBinding.instance.endOfFrame;
    final boundary = _boundaryKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) throw StateError('카드가 화면에 없어요');
    final image = await boundary.toImage(pixelRatio: 3);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('PNG로 바꾸지 못했어요');
      return data.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  /// [indexes] 장을 차례로 화면에 띄워 찍고, 원래 보던 장으로 돌아온다.
  Future<List<CardImage>> _capturePages(List<TripCardPage> pages, List<int> indexes, {required bool folder}) async {
    final original = _pageIndex;
    final images = <CardImage>[];
    try {
      for (final i in indexes) {
        if (_pageIndex != i) {
          setState(() => _pageIndex = i);
          await WidgetsBinding.instance.endOfFrame;
        }
        images.add(CardImage(bytes: await _captureCurrent(), baseName: cardBaseName(widget.trip, pages[i], folder: folder)));
      }
    } finally {
      if (mounted && _pageIndex != original) setState(() => _pageIndex = original);
    }
    return images;
  }

  /// 갤러리(웹은 다운로드)에 저장. 나눠 보기면 체크인이 있는 모든 장(빈 날은 뺀다).
  Future<void> _saveImages(List<TripCardPage> pages, {required bool folder}) async {
    if (_busy) return;
    final indexes = [
      for (var i = 0; i < pages.length; i++)
        if (!folder || pages[i].checkIns.isNotEmpty) i,
    ];
    if (indexes.isEmpty) {
      _snack('아직 체크인한 날이 없어요.');
      return;
    }
    setState(() => _busy = true);
    try {
      final images = await _capturePages(pages, indexes, folder: folder);
      await saveCardImages(images);
      if (mounted) _snack(images.length > 1 ? '$cardSaveTarget에 ${images.length}장 저장했어요.' : '$cardSaveTarget에 저장했어요.');
    } on CardSaveException catch (e) {
      if (mounted) _snack(e.message);
    } on Object catch (e) {
      debugPrint('카드 이미지 저장 실패: $e');
      if (mounted) _snack('이미지를 만들지 못했어요. 잠시 뒤 다시 해 주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 지금 보는 장을 이미지로 공유(카톡·인스타 등 공유 시트). [origin]은 아이패드 공유 창 위치.
  Future<void> _shareImage(List<TripCardPage> pages, int index, {required bool folder, Rect? origin}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final image = (await _capturePages(pages, [index], folder: folder)).single;
      await SharePlus.instance.share(ShareParams(
        text: '${widget.trip.title} · 어디갈지 Pick!',
        files: [XFile.fromData(image.bytes, mimeType: 'image/png')],
        fileNameOverrides: [image.fileName],
        sharePositionOrigin: origin,
      ));
    } on Object catch (e) {
      debugPrint('카드 이미지 공유 실패: $e');
      if (mounted) _snack('공유하지 못했어요. 잠시 뒤 다시 해 주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// "한 표 핀" 옆의 장소들 = 투표 후보(최대 4곳).
  List<CheckIn> _voteCandidates(TripCardPage page, String key) {
    final store = _store;
    if (store == null) return const [];
    final layout = TripNoteView.layoutOf(page);
    final edits = store.stopEditsOf(key);
    final ids = [for (final c in page.checkIns) c.id];
    final stops = [
      for (final base in layout.stops)
        if (base.index < ids.length)
          () {
            final slot = applyStopEdit(base, edits[ids[base.index]], layout.rows);
            return (id: ids[base.index], x: slot.x, y: slot.y);
          }(),
    ];
    final found = voteCandidates(store.stickersOf(key), stops, pinName: StickerBook.votePin);
    return [
      for (final id in found.take(4)) page.checkIns.firstWhere((c) => c.id == id),
    ];
  }

  Future<void> _shareAsPoll(List<CheckIn> candidates) async {
    final trip = widget.trip;
    final votes = AppScope.of(context).votes;
    final place = trip.title.replaceAll(RegExp(r'\s*여행$'), '');
    final ideas = cardQuestionIdeas(place);
    final question = await showPollQuestionSheet(
      context,
      initial: ideas.first,
      ideas: ideas,
      candidates: [for (final c in candidates) c.placeName],
      confirmLabel: '이 질문으로 공유하기',
    );
    if (question == null || !mounted) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PollScreen(
        title: '여행 카드 투표',
        poll: votes.shareCardPoll(
          tripId: trip.id,
          question: question,
          places: [for (final c in candidates) (key: c.id, label: c.placeName)],
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    // 스티커가 바뀌면 투표 후보·공유 버튼도 다시 그린다.
    return ListenableBuilder(listenable: Listenable.merge([if (_store != null) _store!]), builder: (context, _) => _build(context));
  }

  Widget _build(BuildContext context) {
    final trip = widget.trip;
    final pages = paginateTrip(trip, _mode);
    final index = _pageIndex < pages.length ? _pageIndex : 0;
    final folder = pages.length > 1;
    final page = pages[index];
    final key = cardPageKey(trip, _mode, page);
    final ready = _store != null && _book != null;
    final candidates = _voteCandidates(page, key);
    final voteHint = candidates.isEmpty
        ? null
        : '투표 후보 ${candidates.length}곳: ${candidates.map((c) => c.placeName).join(' · ')}'
            '${candidates.length >= 2 ? ' — 공유하면 픽클 투표가 돼요' : ' — 한 곳 더 붙여 봐요'}';

    return Scaffold(
      backgroundColor: AppColors.bgTop,
      appBar: AppBar(
        title: const Text('여행 카드'),
        actions: [
          IconButton(
            tooltip: _zoomed ? '작게 보기' : '크게 보기',
            isSelected: _zoomed,
            icon: const Icon(Icons.open_in_full),
            selectedIcon: const Icon(Icons.close_fullscreen),
            onPressed: () => setState(() => _zoomed = !_zoomed),
          ),
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
          padding: EdgeInsets.fromLTRB(_zoomed ? Gap.s : Gap.m, 0, _zoomed ? Gap.s : Gap.m, Gap.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_zoomed) ...[
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
              ],
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
                        // 체크인이 없는 날은 흐린 글자로(빈 장)
                        label: Text(
                          pages[i].days.first.label,
                          style: pages[i].checkIns.isEmpty && i != index
                              ? const TextStyle(color: AppColors.textSecondary)
                              : null,
                        ),
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
                  cardBuilder: (stopEdits) => TripNoteView(trip: trip, page: page, paper: _paper, stopEdits: stopEdits),
                  cardSize: TripNoteView.pageSize(page),
                  layout: TripNoteView.layoutOf(page),
                  checkInIds: [for (final c in page.checkIns) c.id],
                  pageKey: key,
                  store: _store,
                  book: _book,
                  boundaryKey: _boundaryKey,
                  hint: voteHint ?? (_zoomed ? '크게 보는 중 · 스티커 서랍은 작게 보기에서 열려요' : null),
                ),
              ),
              if (!_zoomed) ...[
                StickerTray(book: _book, onPick: (name) => _editorKey.currentState?.addSticker(name)),
                const SizedBox(height: Gap.s + 2),
                Row(
                  children: [
                    Expanded(
                      child: Builder(
                        builder: (buttonContext) => FilledButton.icon(
                          onPressed: !ready || _busy
                              ? null
                              : candidates.length >= 2
                                  ? () => _shareAsPoll(candidates)
                                  : () {
                                      final box = buttonContext.findRenderObject() as RenderBox?;
                                      _shareImage(pages, index,
                                          folder: folder,
                                          origin: box == null ? null : box.localToGlobal(Offset.zero) & box.size);
                                    },
                          icon: Icon(candidates.length >= 2 ? Icons.how_to_vote_outlined : Icons.ios_share),
                          label: Text(candidates.length >= 2 ? '투표로 공유' : (folder ? '이 장 공유' : '공유하기')),
                        ),
                      ),
                    ),
                    const SizedBox(width: Gap.s),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: !ready || _busy ? null : () => _saveImages(pages, folder: folder),
                        icon: _busy
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.download),
                        label: Text(_busy
                            ? '만드는 중…'
                            : (folder ? '${pages.where((p) => p.checkIns.isNotEmpty).length}장 모두 저장' : '이미지 저장')),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
