import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'trip_models.dart';

/// 체크인 고치기 결과: 새 시각, 또는 지우기([delete]).
class CheckInEdit {
  const CheckInEdit.at(DateTime this.at) : delete = false;
  const CheckInEdit.delete()
      : at = null,
        delete = true;

  final DateTime? at;
  final bool delete;
}

/// 체크인 한 건의 날(몇 일차)·시각을 바꾸거나 지우는 아래 시트.
/// 고를 수 있는 날은 여행 기간과 지금까지 날(체크인이 있던 날 포함) 중 긴 쪽, 최대 30일.
Future<CheckInEdit?> showCheckInEditSheet(BuildContext context, {required Trip trip, required CheckIn checkIn}) {
  return showModalBottomSheet<CheckInEdit>(
    context: context,
    showDragHandle: true,
    builder: (context) => _CheckInEditSheet(trip: trip, checkIn: checkIn),
  );
}

class _CheckInEditSheet extends StatefulWidget {
  const _CheckInEditSheet({required this.trip, required this.checkIn});

  final Trip trip;
  final CheckIn checkIn;

  @override
  State<_CheckInEditSheet> createState() => _CheckInEditSheetState();
}

class _CheckInEditSheetState extends State<_CheckInEditSheet> {
  late int _day = math.min(29, math.max(0, widget.trip.dayIndexOf(widget.checkIn.at)));
  late TimeOfDay _time = TimeOfDay.fromDateTime(widget.checkIn.at);

  DateTime get _start => dateOnly(widget.trip.startDate);

  int get _dayCount {
    final today = widget.trip.dayIndexOf(DateTime.now()) + 1;
    return math.min(30, math.max(1, math.max(widget.trip.totalDays, math.max(today, _day + 1))));
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time, helpText: '체크인 시각');
    if (picked != null && mounted) setState(() => _time = picked);
  }

  @override
  Widget build(BuildContext context) {
    final date = _start.add(Duration(days: _day));
    String hm(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.m, 0, Gap.m, Gap.m),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.checkIn.placeName, style: titleStyle(20)),
            const Text('깜빡한 체크인은 날짜·시각을 바꾸면 카드 순서도 따라 바뀌어요.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: Gap.m),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < _dayCount; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text('${i + 1}일차 · ${_start.add(Duration(days: i)).month}/${_start.add(Duration(days: i)).day}'),
                        selected: i == _day,
                        onSelected: (_) => setState(() => _day = i),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Gap.s),
            OutlinedButton.icon(
              onPressed: _pickTime,
              icon: const Icon(Icons.schedule),
              label: Text('${monthDayLabel(date)} ${hm(_time)}'),
            ),
            const SizedBox(height: Gap.m),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(const CheckInEdit.delete()),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('체크인 지우기'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.secondary),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.of(context)
                      .pop(CheckInEdit.at(DateTime(date.year, date.month, date.day, _time.hour, _time.minute))),
                  child: const Text('바꾸기'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
