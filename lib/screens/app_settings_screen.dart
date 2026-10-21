// Attendance app screen.
import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';
import '../widgets/delete_account_dialog.dart';

// Application settings and account management.
class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key, required this.onOpenSheets,
    required this.authController});

  final VoidCallback onOpenSheets;
  final AuthController authController;

  // Account deletion confirmation.
  Future<void> _confirmDelete(BuildContext context) async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DeleteAccountDialog(onDelete: authController.deleteAccount),
    );
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text('Settings', style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      const Card(child: ListTile(
        leading: Icon(Icons.lock_outline),
        title: Text('Login on each launch'),
        subtitle: Text('Enabled. A new app process requires a fresh sign-in.'),
      )),
      Card(child: ListTile(
        leading: const Icon(Icons.folder_outlined),
        title: const Text('Folder settings'),
        subtitle: const Text('Edit dates, names, time fields and folders.'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onOpenSheets,
      )),
      const Card(child: ListTile(
        leading: Icon(Icons.palette_outlined),
        title: Text('Appearance'),
        subtitle: Text('Minimalist light theme with soft-purple accents.'),
      )),
      const SizedBox(height: 24),
      Text('Danger zone', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Card(child: ListTile(
        leading: Icon(Icons.delete_forever_outlined,
            color: Theme.of(context).colorScheme.error),
        title: Text('Delete account',
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
        subtitle: const Text('Permanently remove this account and its attendance data.'),
        onTap: authController.isLoading ? null : () => _confirmDelete(context),
      )),
    ],
  );
}
