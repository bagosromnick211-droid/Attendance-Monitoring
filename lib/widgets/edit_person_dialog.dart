// Reusable interface component.
import 'package:flutter/material.dart';

import '../models/person.dart';

// Controller-free editor. Inputs belong to this route, so dismiss animations.
class EditPersonDialog extends StatefulWidget {
  const EditPersonDialog({
    super.key,
    required this.person,
    required this.onSave,
  });
  final Person person;
  final Future<void> Function(Person) onSave;

  @override
  State<EditPersonDialog> createState() => _EditPersonDialogState();
}

class _EditPersonDialogState extends State<EditPersonDialog> {
  late String _name;
  late String _code;
  late String _group;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = widget.person.name;
    _code = widget.person.memberCode ?? '';
    _group = widget.person.groupName ?? '';
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (_name.trim().isEmpty) {
      setState(() => _error = 'Name is required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(widget.person.copyWith(
          name: _name.trim(),
          memberCode: _code.trim(),
          groupName: _group.trim()));
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Edit Person'),
        content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(
              initialValue: _name,
              maxLength: 150,
              onChanged: (value) => _name = value,
              decoration: const InputDecoration(labelText: 'Name *')),
          TextFormField(
              initialValue: _code,
              maxLength: 60,
              onChanged: (value) => _code = value,
              decoration:
                  const InputDecoration(labelText: 'Student / employee ID')),
          TextFormField(
              initialValue: _group,
              maxLength: 100,
              onChanged: (value) => _group = value,
              decoration:
                  const InputDecoration(labelText: 'Class / department')),
          if (_error != null)
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ])),
        actions: [
          TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: _saving ? null : _submit,
              child: Text(_saving ? 'Saving…' : 'Save')),
        ],
      );
}
