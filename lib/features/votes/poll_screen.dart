import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_surfaces.dart';
import '../../core/theme/app_theme.dart';
import '../../core/votes/vote_repository.dart';

/// 친구한테 물어본 투표 현황. 받은 친구는 같은 화면을 픽클 투표 미리보기 웹으로 본다.
///
/// - 후보를 누르면 내 표가 들어가고, 마감 전까지 바꿀 수 있다.
/// - 마감하면 1위를 크게 보여 주고, [winnerAction]이 있으면 "○○로 여행 만들기" 같은 다음 걸음으로 잇는다.
class PollScreen extends StatefulWidget {
  const PollScreen({super.key, required this.poll, this.title = '친구한테 물어본 후보', this.winnerAction});

  final Future<Poll> poll;
  final String title;

  /// 마감 후 1위로 할 일. (버튼 글자, 누르면 할 일)
  final ({String Function(PollOption winner) label, void Function(PollOption winner) onPressed})? winnerAction;

  @override
  State<PollScreen> createState() => _PollScreenState();
}

class _PollScreenState extends State<PollScreen> {
  Poll? _poll;
  Object? _error;

  @override
  void initState() {
    super.initState();
    widget.poll.then((p) {
      if (mounted) setState(() => _poll = p);
    }, onError: (Object e) {
      if (mounted) setState(() => _error = e);
    });
  }

  Future<void> _vote(String key) async {
    final poll = _poll;
    if (poll == null || poll.closed) return;
    final next = await AppScope.of(context).votes.vote(poll.id, key);
    if (mounted) setState(() => _poll = next);
  }

  Future<void> _close() async {
    final poll = _poll;
    if (poll == null) return;
    final next = await AppScope.of(context).votes.close(poll.id);
    if (mounted) setState(() => _poll = next);
  }

  Future<void> _copyLink() async {
    final poll = _poll;
    if (poll == null) return;
    await Clipboard.setData(ClipboardData(text: poll.shareUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('투표 링크를 복사했어요. 친구한테 보내 주세요!')));
  }

  @override
  Widget build(BuildContext context) {
    final poll = _poll;
    return Scaffold(
      backgroundColor: AppColors.bgTop,
      appBar: AppBar(title: Text(widget.title)),
      body: AppBackground(
        child: SafeArea(
          top: false,
          child: poll == null
              ? Center(
                  child: _error == null
                      ? const CircularProgressIndicator()
                      : const Text('투표를 불러오지 못했어요', style: TextStyle(color: AppColors.textSecondary)),
                )
              : _body(poll),
        ),
      ),
    );
  }

  Widget _body(Poll poll) {
    final winner = poll.leader;
    final action = widget.winnerAction;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.m, Gap.s, Gap.m, Gap.m),
            children: [
              if (poll.closed) _WinnerCard(poll: poll, winner: winner) else _QuestionCard(poll: poll),
              const SizedBox(height: Gap.s + 4),
              for (final (i, o) in poll.ranked.indexed) ...[
                _OptionCard(
                  poll: poll,
                  option: o,
                  rank: i + 1,
                  winner: poll.closed && o.key == winner.key,
                  onTap: poll.closed ? null : () => _vote(o.key),
                ),
                const SizedBox(height: Gap.s),
              ],
              if (!poll.closed)
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Text('후보를 눌러 투표해요 · 마감 전까지 바꿀 수 있어요',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.m, 0, Gap.m, Gap.m),
          child: poll.closed
              ? (action == null
                  ? Text('투표한 ${poll.total}명에게 결과를 알려 줄게요',
                      textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary))
                  : SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => action.onPressed(winner),
                        icon: const Icon(Icons.luggage_outlined),
                        label: Text(action.label(winner)),
                      ),
                    ))
              : Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _copyLink,
                        icon: const Icon(Icons.link),
                        label: const Text('링크 복사'),
                      ),
                    ),
                    const SizedBox(width: Gap.s),
                    Expanded(child: FilledButton(onPressed: _close, child: const Text('지금 마감하기'))),
                  ],
                ),
        ),
      ],
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.poll});

  final Poll poll;

  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFE4F6E8), borderRadius: BorderRadius.circular(99)),
              child: const Text('● 진행 중',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF1E8A4A))),
            ),
            const SizedBox(height: 10),
            Text(poll.question, style: titleStyle(26)),
            const SizedBox(height: 6),
            Text('${poll.total}명이 투표했어요',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          ],
        ),
      );
}

class _WinnerCard extends StatelessWidget {
  const _WinnerCard({required this.poll, required this.winner});

  final Poll poll;
  final PollOption winner;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const RadialGradient(
            center: Alignment(-0.9, -0.8),
            radius: 1.2,
            colors: [Color(0xFFFFD6EC), Color(0xFFEFE9FF)],
          ),
          boxShadow: AppDecorations.cardShadow,
        ),
        child: Column(
          children: [
            const Icon(Icons.emoji_events_rounded, size: 34, color: Color(0xFFFFB300)),
            Text('${poll.question} · ${poll.total}명 투표',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
            const SizedBox(height: 2),
            Text('${poll.votesOf(winner.key)}표로 1위!',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primaryDeep)),
            Text(winner.label, textAlign: TextAlign.center, style: titleStyle(32)),
          ],
        ),
      );
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({required this.poll, required this.option, required this.rank, required this.winner, this.onTap});

  final Poll poll;
  final PollOption option;
  final int rank;
  final bool winner;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mine = poll.myChoice == option.key;
    final pct = poll.percentOf(option.key);
    final count = poll.votesOf(option.key);
    final names = [if (mine) '나', ...option.voters];
    return Semantics(
      button: onTap != null,
      selected: mine,
      label: '${option.label} $count표 $pct퍼센트${mine ? ', 내 표' : ''}',
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                width: 2,
                color: winner ? const Color(0xFFFFD25E) : (mine ? AppColors.primary : Colors.transparent),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: rank == 1 ? AppColors.primary : const Color(0xFFC9BEFA),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$rank', style: const TextStyle(fontFamily: AppFonts.title, color: Colors.white)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(option.label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    ),
                    if (mine)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFEEE9FF), borderRadius: BorderRadius.circular(99)),
                        child: const Text('내 표',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.primaryDeep)),
                      ),
                    Text('$pct%',
                        style: TextStyle(
                          fontFamily: AppFonts.title,
                          fontSize: 20,
                          color: winner || mine ? AppColors.primaryDeep : AppColors.muted,
                        )),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    minHeight: 10,
                    backgroundColor: const Color(0xFFF0EDFA),
                    color: winner ? const Color(0xFFFFB84D) : (mine ? AppColors.primary : const Color(0xFFC9BEFA)),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  names.isEmpty ? '아직 표가 없어요' : '${names.join(', ')} · $count명',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
