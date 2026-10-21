// Reusable interface component.
import 'package:flutter/material.dart';

// Called after the dialog validates a person's name.
typedef SavePersonCallback = Future<void> Function(
  String name, {
  String? memberCode,
  String? groupName,
});

// Owns its input state for the full lifetime of the dialog route.
class AddPersonDialog extends StatefulWidget {
  const AddPersonDialog({
    super.key,
    required this.entityLabel,
    required this.onSave,
    required this.errorMessage,
  });

  final String entityLabel;
  final SavePersonCallback onSave;
  final String Function(Object error) errorMessage;

  @override
  State<AddPersonDialog> createState() => _AddPersonDialogState();
}

class _AddPersonDialogState extends State<AddPersonDialog> {
  String _name = '';
  String _code = '';
  String _group = '';
  bool _submitting = false;
  String? _saveError;

  Future<void> _submit() async {
    if (_submitting) return;

    final name = _name.trim();
    if (name.isEmpty) {
      setState(() => _saveError = 'Please enter a name.');
      return;
    }

    setState(() {
      _submitting = true;
      _saveError = null;
    });

    try {
      await widget.onSave(
        name,
        memberCode: _code.trim(),
        groupName: _group.trim(),
      );
      // Saving notifies the attendance controller and rebuilds the screen
      // beneath this route. Only pop the dialog if it is still mounted.
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _saveError = widget.errorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add ${widget.entityLabel}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('person_name_field'),
              autofocus: true,
              maxLength: 150,
              onChanged: (value) => _name = value,
              decoration: const InputDecoration(labelText: 'Name *'),
            ),
            TextField(
              key: const Key('person_code_field'),
              maxLength: 60,
              onChanged: (value) => _code = value,
              decoration: const InputDecoration(
                labelText: 'Student / employee ID (optional)',
              ),
            ),
            TextField(
              key: const Key('person_group_field'),
              maxLength: 100,
              onChanged: (value) => _group = value,
              decoration: const InputDecoration(
                labelText: 'Class / department (optional)',
              ),
            ),
            if (_submitting)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Saving to Supabase…', style: TextStyle(fontSize: 12)),
              ),
            if (_saveError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _saveError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add'),
        ),
      ],
    );
  }
}
