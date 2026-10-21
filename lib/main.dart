// Application startup.
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/attendance_app.dart';
import 'app/supabase_setup_required_app.dart';
import 'config/supabase_config.dart';

// Keep this export so earlier navigation tests/imports continue to work.
export 'app/home_router.dart' show AttendanceHomeRouter;

// Starts the app and configures authentication before showing any screens.
Future<void> main() async { 
  // Native Flutter plugins (including Supabase) need the binding first.
  WidgetsFlutterBinding.ensureInitialized();

  if (!SupabaseConfig.isConfigured) {
    runApp(const SupabaseSetupRequiredApp());
    return;
  }

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  // Product requirement: a *new process* needs a fresh login.
  // A local sign-out leaves sessions on other devices alone.
  if (Supabase.instance.client.auth.currentSession != null) {
    try {
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    } catch (error) {
      // Fail closed: do not show a restored signed-in screen if clearing fails.
      runApp(_SessionCleanupErrorApp(message: error.toString()));
      return;
    }
  }

  runApp(const AttendanceApp());
}

// Startup error UI used only when a previous session cannot be cleared.
class _SessionCleanupErrorApp extends StatelessWidget {
  const _SessionCleanupErrorApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
            body: Center(
          child: Text(
            'Could not clear the previous login session. Check your connection '
            'and restart.\n$message',
            textAlign: TextAlign.center,
          ),
        )),
      );
}
