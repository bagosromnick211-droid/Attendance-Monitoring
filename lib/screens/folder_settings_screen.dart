// Attendance app screen.
import 'package:flutter/material.dart';

import '../controllers/attendance_controller.dart';
import '../models/attendance_form.dart';
import '../widgets/sheet_fields.dart';

// Edit a sheet's settings and confirm permanent folder deletion.
class FolderSettingsScreen extends StatefulWidget {
  const FolderSettingsScreen({
    super.key,
    required this.form,
    required this.controller,
    required this.onFinished,
    required this.onDeleted,
  });
  final AttendanceForm form;
  final AttendanceController controller;
  final VoidCallback onFinished;
  final VoidCallback onDeleted;

  @override
  State<FolderSettingsScreen> createState() => _FolderSettingsScreenState();
}

class _FolderSettingsScreenState extends State<FolderSettingsScreen> {
  late final TextEditingController _title;
  late final TextEditingController _label;
  late DateTimeRange _range;
  late bool _weekends;
  late bool _timeIn;
  late bool _timeOut;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final form = widget.form;
    _title = TextEditingController(text: form.title);
    _label = TextEditingController(text: form.entityLabel);
    _range = DateTimeRange(start: form.startDate, end: form.endDate);
    _weekends = form.ignoreWeekends;
    _timeIn = form.includeTimeIn;
    _timeOut = form.includeTimeOut;
  }

  @override
  void dispose() {
    _title.dispose();
    _label.dispose();
    super.dispose();
  }

  void _error(Object error) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AttendanceController.friendlyError(error))));
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final updated = widget.form.copyWith(
        title: _title.text.trim(),
        entityLabel: _label.text.trim(),
        startDate: _range.start,
        endDate: _range.end,
        ignoreWeekends: _weekends,
        includeTimeIn: _timeIn,
        includeTimeOut: _timeOut,
      );
      await widget.controller.updateForm(updated);
      if (mounted) widget.onFinished();
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this folder?'),
        content: Text('Permanently delete “${widget.form.title}”, all people in it, '
            'and all their attendance records? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    if (confirmed != true || _saving) return;
    setState(() => _saving = true);
    try {
      await widget.controller.deleteForm(widget.form.id!);
      if (mounted) widget.onDeleted();
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('Folder settings', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text('Editing ${widget.form.title}'),
      const SizedBox(height: 16),
      Card(child: Padding(padding: const EdgeInsets.all(18), child: SheetFields(
        title: _title,
        label: _label,
        range: _range,
        ignoreWeekends: _weekends,
        timeIn: _timeIn,
        timeOut: _timeOut,
        onRangeChanged: (v) => setState(() => _range = v),
        onWeekendsChanged: (v) => setState(() => _weekends = v),
        onTimeInChanged: (v) => setState(() => _timeIn = v),
        onTimeOutChanged: (v) => setState(() => _timeOut = v),
      ))),
      const SizedBox(height: 10),
      const Text('If you shorten the date range, older records are kept in Supabase but hidden from the grid.'),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: _saving ? null : _save,
        icon: const Icon(Icons.save_outlined),
        label: Text(_saving ? 'Saving…' : 'Save settings'),
      ),
      const SizedBox(height: 28),
      OutlinedButton.icon(
        onPressed: _saving ? null : _delete,
        icon: const Icon(Icons.delete_outline),
        label: const Text('Delete folder permanently'),
        style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
      ),
    ]);
  }
}
