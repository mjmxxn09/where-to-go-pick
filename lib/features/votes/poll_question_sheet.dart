import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 투표 질문 최대 글자 수(공유 미리보기·잠금화면 한 줄에 들어가게).
const pollQuestionMaxLength = 40;

/// 여행지 후보 투표의 기본 질문: "강릉 vs 속초, 어디 갈까?" / "강릉·속초·양양 중 어디 갈까?".
/// 너무 길면 "어디로 여행 갈까?".
String defaultRegionQuestion(List<String> names) {
  final q = switch (names.length) {
    0 || 1 => '어디로 여행 갈까?',
    2 => '${names[0]} vs ${names[1]}, 어디 갈까?',
    _ => '${names.join('·')} 중 어디 갈까?',
  };
  return q.length > pollQuestionMaxLength ? '어디로 여행 갈까?' : q;
}

/// 여행지 후보 투표에서 골라 쓰는 질문.
const regionQuestionIdeas = ['이번 주말 어디 갈까?', '당일치기로 어디가 좋아?', '다음 여행지 골라 줘!', '1박 2일이면 어디?'];

/// 여행 카드 투표에서 골라 쓰는 질문.
List<String> cardQuestionIdeas(String place) =>
    ['$place 가면 어디부터 가야 해?', '여기 중에 제일 좋아 보이는 곳은?', '다음에 또 간다면 어디?'];

/// 투표 질문을 고치는 시트. 물어보기를 누르면 다듬은 질문, 닫으면 null.
Future<String?> showPollQuestionSheet(
  BuildContext context, {
  required String initial,
  required List<String> ideas,
  required List<String> candidates,
  String confirmLabel = '이 질문으로 물어보기',
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _PollQuestionSheet(initial: initial, ideas: ideas, candidates: candidates, confirmLabel: confirmLabel),
  );
}

class _PollQuestionSheet extends StatefulWidget {
  const _PollQuestionSheet({required this.initial, required this.ideas, required this.candidates, required this.confirmLabel});

  final String initial;
  final List<String> ideas;
  final List<String> candidates;
  final String confirmLabel;

  @override
  State<_PollQuestionSheet> createState() => _PollQuestionSheetState();
}

class _PollQuestionSheetState extends State<_PollQuestionSheet> {
  late final _ctrl = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _text => _ctrl.text.trim();

  void _submit() {
    if (_text.isEmpty) return;
    Navigator.of(context).pop(_text);
  }

  @override
  Widget build(BuildContext context) {
    final ideas = {widget.initial, ...widget.ideas}.toList();
    return Padding(
      padding: EdgeInsets.fromLTRB(Gap.m, 0, Gap.m, Gap.m + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('친구들한테 뭐라고 물어볼까?', style: titleStyle(20)),
          const SizedBox(height: 4),
          Text('후보: ${widget.candidates.join(' · ')}',
              maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: Gap.s),
          TextField(
            controller: _ctrl,
            autofocus: false,
            maxLength: pollQuestionMaxLength,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: '질문',
              border: const OutlineInputBorder(),
              suffixIcon: _ctrl.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '지우기',
                      onPressed: () => setState(_ctrl.clear),
                      icon: const Icon(Icons.close),
                    ),
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final idea in ideas)
                ChoiceChip(
                  label: Text(idea),
                  selected: _text == idea,
                  onSelected: (_) => setState(() {
                    _ctrl.text = idea;
                    _ctrl.selection = TextSelection.collapsed(offset: idea.length);
                  }),
                ),
            ],
          ),
          const SizedBox(height: Gap.m),
          FilledButton(onPressed: _text.isEmpty ? null : _submit, child: Text(widget.confirmLabel)),
        ],
      ),
    );
  }
}
