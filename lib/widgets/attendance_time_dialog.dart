// Reusable interface component.
import 'package:flutter/material.dart';

import '../models/attendance_form.dart';
import '../models/attendance_record.dart';
import '../utils/time_utils.dart';

// Quick time-in and time-out editor.
class AttendanceTimeDialog extends StatefulWidget {
  const AttendanceTimeDialog({
    super.key,
    required this.record,
    required this.form,
    required this.date,
    required this.onSave,
    required this.errorMessage,
  });

  final AttendanceRecord record;
  final AttendanceForm form;
  final DateTime date;
  final Future<void> Function(String? timeIn, String? timeOut) onSave;
  final String Function(Object error) errorMessage;

  @override
  State<AttendanceTimeDialog> createState() => _AttendanceTimeDialogState();
}

class _AttendanceTimeDialogState extends State<AttendanceTimeDialog> {
  TimeOfDay? _timeIn;
  TimeOfDay? _timeOut;
  bool _saving = false;

  // Initialize saved times.
  @override
  void initState() {
    super.initState();
    _timeIn = parseSqlTime(widget.record.timeIn);
    _timeOut = parseSqlTime(widget.record.timeOut);
  }

  // Manual time selection.
  Future<void> _chooseTime(bool forIn) async {
    final result = await showTimePicker(
      context: context,
      initialTime: (forIn ? _timeIn : _timeOut) ?? TimeOfDay.now(),
    );
    if (!mounted || result == null) return;
    setState(() {
      if (forIn) { _timeIn = result; } else { _timeOut = result; }
    });
  }

  // Current device time shortcut.
  void _useNow(bool forIn) {
    setState(() {
      if (forIn) { _timeIn = TimeOfDay.now(); } else { _timeOut = TimeOfDay.now(); }
    });
  }

  // Save both time values.
  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(formatSqlTime(_timeIn), formatSqlTime(_timeOut));
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save times: ${widget.errorMessage(error)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // Single time field with picker, Now, and Clear actions.
  Widget _timeField(String title, bool forIn, TimeOfDay? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _saving ? null : () => _chooseTime(forIn),
                icon: const Icon(Icons.schedule, size: 17),
                label: Text(value?.format(context) ?? 'Not set',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
            const SizedBox(width: 6),
            TextButton(onPressed: _saving ? null : () => _useNow(forIn),
                child: const Text('Now')),
            IconButton(
              tooltip: 'Clear $title',
              onPressed: _saving ? null : () => setState(() {
                if (forIn) { _timeIn = null; } else { _timeOut = null; }
              }),
              icon: const Icon(Icons.close, size: 19),
            ),
          ]),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Attendance times'),
    content: SizedBox(
      width: 330,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${widget.date.month}/${widget.date.day}/${widget.date.year}',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          if (widget.form.includeTimeIn) _timeField('Time In', true, _timeIn),
          if (widget.form.includeTimeOut) _timeField('Time Out', false, _timeOut),
          Text('Leave a time empty if it has not been recorded yet.',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel')),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: _saving
            ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Save times'),
      ),
    ],
  );
}
