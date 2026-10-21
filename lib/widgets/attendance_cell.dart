// Reusable interface component.
import 'package:flutter/material.dart';

import '../models/attendance_record.dart';
import '../utils/time_utils.dart';

// Attendance status actions.
enum _CellAction { present, late, absent, noClass, clear }

// Attendance status and optional time fields for a single day.
class AttendanceCellTile extends StatelessWidget {
  const AttendanceCellTile({
    super.key,
    required this.status,
    required this.saving,
    required this.timeInEnabled,
    required this.timeOutEnabled,
    required this.timeIn,
    required this.timeOut,
    required this.onStatusSelected,
    required this.onEditTimes,
  });

  final AttendanceStatus? status;
  final bool saving;
  final bool timeInEnabled;
  final bool timeOutEnabled;
  final String? timeIn;
  final String? timeOut;
  final ValueChanged<AttendanceStatus?> onStatusSelected;
  final VoidCallback onEditTimes;

  bool get _showTimes =>
      (timeInEnabled || timeOutEnabled) &&
      (status == AttendanceStatus.present || status == AttendanceStatus.late);

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      AttendanceStatus.present => Colors.green,
      AttendanceStatus.late => Colors.amber.shade700,
      AttendanceStatus.absent => Colors.red,
      AttendanceStatus.noClass => Colors.blueGrey,
      null => Colors.grey.shade300,
    };
    final label = switch (status) {
      AttendanceStatus.present => 'P',
      AttendanceStatus.late => 'L',
      AttendanceStatus.absent => 'A',
      AttendanceStatus.noClass => '–',
      null => '?',
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Attendance status selector.
        SizedBox(
          width: 36,
          height: 36,
          child: saving
              ? const Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : PopupMenuButton<_CellAction>(
                  padding: EdgeInsets.zero,
                  tooltip: 'Mark attendance',
                  onSelected: (choice) {
                    final AttendanceStatus? selected = switch (choice) {
                      _CellAction.present => AttendanceStatus.present,
                      _CellAction.late => AttendanceStatus.late,
                      _CellAction.absent => AttendanceStatus.absent,
                      _CellAction.noClass => AttendanceStatus.noClass,
                      _CellAction.clear => null,
                    };
                    onStatusSelected(selected);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: _CellAction.present, child: Text('Present (P)')),
                    PopupMenuItem(value: _CellAction.late, child: Text('Late (L)')),
                    PopupMenuItem(value: _CellAction.absent, child: Text('Absent (A)')),
                    PopupMenuItem(value: _CellAction.noClass, child: Text('No Class (–)')),
                    PopupMenuItem(value: _CellAction.clear, child: Text('Clear / Unmarked (?)')),
                  ],
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: status == null ? Colors.black87 : Colors.white,
                      ),
                    ),
                  ),
                ),
        ),
        // Quick time editor; separate from changing attendance status.
        if (_showTimes)
          TextButton(
            onPressed: saving ? null : onEditTimes,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              minimumSize: const Size(75, 35),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (timeInEnabled)
                  Text('In: ${_displayTime(context, timeIn)}',
                      maxLines: 1, style: const TextStyle(fontSize: 10)),
                if (timeOutEnabled)
                  Text('Out: ${_displayTime(context, timeOut)}',
                      maxLines: 1, style: const TextStyle(fontSize: 10)),
              ],
            ),
          ),
      ],
    );
  }

  String _displayTime(BuildContext context, String? value) =>
      parseSqlTime(value)?.format(context) ?? '—';
}
