import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'trip_models.dart';

/// 여행 만들기·기간 바꾸기에서 고른 값. [days]가 null이면 기간을 정하지 않음(다녀온 날로 정해짐).
class TripDates {
  const TripDates({required this.start, this.days});

  final DateTime start;
  final int? days;
}

/// 출발일(오늘·내일·날짜 고르기)과 기간(당일 ~ 4박 5일, 정하지 않기)을 고르는 아래 시트.
Future<TripDates?> showTripDatesSheet(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  DateTime? initialStart,
  int? initialDays = 1,
  String? warning,
  DateTime Function()? clock,
}) {
  return showModalBottomSheet<TripDates>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _TripDatesSheet(
      title: title,
      confirmLabel: confirmLabel,
      initialStart: initialStart,
      initialDays: initialDays,
      warning: warning,
      now: (clock ?? DateTime.now)(),
    ),
  );
}

class _TripDatesSheet extends StatefulWidget {
  const _TripDatesSheet({
    required this.title,
    required this.confirmLabel,
    required this.initialStart,
    required this.initialDays,
    required this.warning,
    required this.now,
  });

  final String title;
  final String confirmLabel;
  final DateTime? initialStart;
  final int? initialDays;
  final String? warning;
  final DateTime now;

  @override
  State<_TripDatesSheet> createState() => _TripDatesSheetState();
}

class _TripDatesSheetState extends State<_TripDatesSheet> {
  late DateTime _start = dateOnly(widget.initialStart ?? widget.now);
  late int? _days = widget.initialDays;

  static const _lengths = [1, 2, 3, 4, 5];

  DateTime get _today => dateOnly(widget.now);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      // 지난 여행을 늦게 기록하는 경우도 있어 한 달 전까지 고를 수 있다.
      firstDate: _today.subtract(const Duration(days: 31)),
      lastDate: _today.add(const Duration(days: 365)),
      helpText: '출발일',
    );
    if (picked != null && mounted) setState(() => _start = dateOnly(picked));
  }

  @override
  Widget build(BuildContext context) {
    final tomorrow = _today.add(const Duration(days: 1));
    final days = _days;
    final summary = days == null
        ? '${monthDayLabel(_start)}부터 · 기간은 다녀온 날로 정해져요'
        : '${dateRangeLabel(_start, _start.add(Duration(days: days - 1)))} · ${lengthLabelOf(days)}';
    final dday = daysBetween(_today, _start);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(Gap.m, 0, Gap.m, Gap.m + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: titleStyle(22)),
            const SizedBox(height: Gap.m),
            const Text('출발일', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: Gap.xs),
            Wrap(
              spacing: Gap.xs,
              runSpacing: Gap.xs,
              children: [
                ChoiceChip(
                  label: const Text('오늘'),
                  selected: _start == _today,
                  onSelected: (_) => setState(() => _start = _today),
                ),
                ChoiceChip(
                  label: const Text('내일'),
                  selected: _start == tomorrow,
                  onSelected: (_) => setState(() => _start = tomorrow),
                ),
                ActionChip(
                  avatar: const Icon(Icons.calendar_month, size: 18),
                  label: Text(_start == _today || _start == tomorrow ? '날짜 고르기' : monthDayLabel(_start)),
                  onPressed: _pickDate,
                ),
              ],
            ),
            const SizedBox(height: Gap.m),
            const Text('기간', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: Gap.xs),
            Wrap(
              spacing: Gap.xs,
              runSpacing: Gap.xs,
              children: [
                for (final n in _lengths)
                  ChoiceChip(
                    label: Text(n == 1 ? '당일' : lengthLabelOf(n)),
                    selected: days == n,
                    onSelected: (_) => setState(() => _days = n),
                  ),
                ChoiceChip(
                  label: const Text('정하지 않기'),
                  selected: days == null,
                  onSelected: (_) => setState(() => _days = null),
                ),
              ],
            ),
            const SizedBox(height: Gap.m),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.primaryContainer, borderRadius: BorderRadius.circular(16)),
              child: Text(
                dday > 0 ? '$summary · D-$dday' : summary,
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryDeep),
              ),
            ),
            if (widget.warning != null) ...[
              const SizedBox(height: Gap.s),
              Text(widget.warning!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
            const SizedBox(height: Gap.m),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(TripDates(start: _start, days: _days)),
                child: Text(widget.confirmLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
