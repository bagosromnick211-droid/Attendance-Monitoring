// Attendance app screen.
import 'package:flutter/material.dart';

import '../controllers/attendance_controller.dart';
import '../controllers/auth_controller.dart';
import '../models/attendance_form.dart';
import '../widgets/sheet_fields.dart';

// Sheet creation form: local input state is sent to AttendanceController.
class FormCreationScreen extends StatefulWidget {
  const FormCreationScreen({
    super.key,
    required this.attendanceController,
    required this.authController,
    this.onCreated,
  });
  final AttendanceController attendanceController;
  final AuthController authController;
  final VoidCallback? onCreated;

  @override
  State<FormCreationScreen> createState() => _FormCreationScreenState();
}

class _FormCreationScreenState extends State<FormCreationScreen> {
  final _title = TextEditingController();
  final _label = TextEditingController();
  late DateTimeRange _range;
  bool _ignoreWeekends = false;
  bool _timeIn = false;
  bool _timeOut = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _range = DateTimeRange(
        start: today, end: DateTime(today.year, today.month, today.day + 14));
  }

  @override
  void dispose() {
    _title.dispose();
    _label.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_saving) return;
    final userId = widget.authController.currentUser?.id;
    if (userId == null) return;
    setState(() => _saving = true);
    try {
      final form = AttendanceForm(
        userId: userId,
        title: _title.text.trim(),
        entityLabel: _label.text.trim(),
        startDate: _range.start,
        endDate: _range.end,
        ignoreWeekends: _ignoreWeekends,
        includeTimeIn: _timeIn,
        includeTimeOut: _timeOut,
      );
      AttendanceController.validateForm(form);
      await widget.attendanceController.createForm(form);
      if (mounted) widget.onCreated?.call();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AttendanceController.friendlyError(error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('Create a new sheet',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      const Text('Configure the dates and attendance rules for your folder.'),
      const SizedBox(height: 18),
      Card(
          child: Padding(
              padding: const EdgeInsets.all(18),
              child: SheetFields(
                title: _title,
                label: _label,
                range: _range,
                ignoreWeekends: _ignoreWeekends,
                timeIn: _timeIn,
                timeOut: _timeOut,
                onRangeChanged: (v) => setState(() => _range = v),
                onWeekendsChanged: (v) => setState(() => _ignoreWeekends = v),
                onTimeInChanged: (v) => setState(() => _timeIn = v),
                onTimeOutChanged: (v) => setState(() => _timeOut = v),
              ))),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: _saving ? null : _create,
        icon: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.add),
        label: Text(_saving ? 'Creating…' : 'Create attendance sheet'),
      ),
    ]);
  }
}
