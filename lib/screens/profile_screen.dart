// Attendance app screen.
import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';

// Displays the signed-in account and allows editing the display name.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.authController});
  final AuthController authController;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _username;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _username = TextEditingController(text: widget.authController.username);
  }

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.authController.updateUsername(_username.text);
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Username updated.')));
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(20), children: [
        Text('My profile',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 18),
        Card(
            child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CircleAvatar(
                        radius: 35,
                        child: Text(widget.authController.username.isEmpty
                            ? '?'
                            : widget.authController.username[0].toUpperCase())),
                    const SizedBox(height: 18),
                    TextField(
                        controller: _username,
                        maxLength: 60,
                        decoration: const InputDecoration(
                            labelText: 'Username',
                            prefixIcon: Icon(Icons.person_outline))),
                    const SizedBox(height: 12),
                    FilledButton(
                        onPressed: _saving ? null : _save,
                        child: Text(_saving ? 'Saving…' : 'Save username')),
                  ],
                ))),
      ]);
}
