import '../../core/cloud/supabase_rest.dart';
import 'card_stickers.dart';
import 'trip_card_layout.dart';

/// 카드 한 쪽의 꾸미기: 붙인 스티커와 옮긴 장소 막대.
class CardDecoration {
  const CardDecoration({required this.pageKey, this.stickers = const [], this.stopEdits = const {}});

  final String pageKey;
  final List<PlacedSticker> stickers;
  final Map<String, StopEdit> stopEdits;

  bool get isEmpty => stickers.isEmpty && stopEdits.isEmpty;
}

abstract interface class CardCloud {
  Future<List<CardDecoration>> pull();

  /// 빈 꾸미기도 올린다(다 지운 것을 서버에도 알린다).
  Future<void> push(List<CardDecoration> pages);
}

/// Supabase 테이블 `card_decorations` (supabase/migrations 참고).
class SupabaseCardCloud implements CardCloud {
  SupabaseCardCloud(this._rest);

  final SupabaseRest _rest;

  @override
  Future<List<CardDecoration>> pull() async {
    final rows = await _rest.select('card_decorations', {'select': 'page_key,stickers,stop_edits'});
    return rows.map(cardDecorationFromRow).whereType<CardDecoration>().toList();
  }

  @override
  Future<void> push(List<CardDecoration> pages) async {
    if (pages.isEmpty) return;
    final userId = await _rest.userId();
    if (userId == null) throw const CloudSignedOut();
    await _rest.upsert(
      'card_decorations',
      [for (final p in pages) cardDecorationToRow(p, userId)],
      onConflict: 'user_id,page_key',
    );
  }
}

Map<String, Object?> cardDecorationToRow(CardDecoration page, String userId) => {
      'user_id': userId,
      'page_key': page.pageKey,
      'stickers': [for (final s in page.stickers) s.toJson()],
      'stop_edits': {for (final e in page.stopEdits.entries) e.key: e.value.toJson()},
    };

CardDecoration? cardDecorationFromRow(Map<String, dynamic> row) {
  final key = row['page_key'];
  if (key is! String) return null;
  final stickers = row['stickers'];
  final stops = row['stop_edits'];
  return CardDecoration(
    pageKey: key,
    stickers: [
      if (stickers is List<dynamic>)
        for (final s in stickers)
          if (PlacedSticker.fromJson(s) case final sticker?) sticker,
    ],
    stopEdits: {
      if (stops is Map<String, dynamic>)
        for (final e in stops.entries)
          if (StopEdit.fromJson(e.value) case final edit?) e.key: edit,
    },
  );
}
