// Reusable interface component.
import 'package:flutter/material.dart';

// Shared fields used when creating a sheet or updating its settings.
class SheetFields extends StatelessWidget {
  const SheetFields({
    super.key,
    required this.title,
    required this.label,
    required this.range,
    required this.ignoreWeekends,
    required this.timeIn,
    required this.timeOut,
    required this.onRangeChanged,
    required this.onWeekendsChanged,
    required this.onTimeInChanged,
    required this.onTimeOutChanged,
  });

  final TextEditingController title;
  final TextEditingController label;
  final DateTimeRange range;
  final bool ignoreWeekends;
  final bool timeIn;
  final bool timeOut;
  final ValueChanged<DateTimeRange> onRangeChanged;
  final ValueChanged<bool> onWeekendsChanged;
  final ValueChanged<bool> onTimeInChanged;
  final ValueChanged<bool> onTimeOutChanged;

  Future<void> _chooseDates(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: range,
      helpText: 'Select attendance period',
    );
    if (picked != null) onRangeChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        controller: title,
        maxLength: 150,
        decoration: const InputDecoration(labelText: 'Folder name *', prefixIcon: Icon(Icons.folder_outlined)),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: label,
        maxLength: 60,
        decoration: const InputDecoration(labelText: 'Person label (Student / Employee)', prefixIcon: Icon(Icons.badge_outlined)),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        icon: const Icon(Icons.calendar_month_outlined),
        onPressed: () => _chooseDates(context),
        label: Text('${_date(range.start)}  –  ${_date(range.end)}'),
      ),
      const SizedBox(height: 8),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Exclude weekends'),
        subtitle: const Text('Hide Saturdays and Sundays from the grid'),
        value: ignoreWeekends,
        onChanged: onWeekendsChanged,
      ),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Enable time in'),
        value: timeIn,
        onChanged: onTimeInChanged,
      ),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Enable time out'),
        value: timeOut,
        onChanged: onTimeOutChanged,
      ),
    ]);
  }

  static String _date(DateTime date) => '${date.month}/${date.day}/${date.year}';
}
