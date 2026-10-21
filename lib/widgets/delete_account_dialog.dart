// Reusable interface component.
import 'package:flutter/material.dart';

// Permanent account deletion confirmation.
class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({super.key, required this.onDelete});

  final Future<void> Function() onDelete;

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final TextEditingController _confirmation = TextEditingController();
  bool _deleting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _confirmation.addListener(_refresh);
  }

  void _refresh() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    _confirmation.removeListener(_refresh);
    _confirmation.dispose();
    super.dispose();
  }

  // Delete only after an exact confirmation.
  Future<void> _delete() async {
    if (_confirmation.text != 'DELETE' || _deleting) return;
    setState(() { _deleting = true; _error = null; });
    try {
      await widget.onDelete();
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error =
          'Unable to delete your account. Check the deployed delete-account '
          'Edge Function or connection. ${error.toString()}');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_deleting,
    child: AlertDialog(
      title: const Text('Delete account permanently?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This will permanently delete your account, profile, '
                'attendance folders, people, and all attendance history. '
                'This action cannot be undone.'),
            const SizedBox(height: 16),
            const Text('Type DELETE to confirm:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            TextField(
              controller: _confirmation,
              enabled: !_deleting,
              autocorrect: false,
              decoration: const InputDecoration(hintText: 'DELETE'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _deleting ? null : () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _deleting || _confirmation.text != 'DELETE' ? null : _delete,
          style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
          child: _deleting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Delete permanently'),
        ),
      ],
    ),
  );
}
