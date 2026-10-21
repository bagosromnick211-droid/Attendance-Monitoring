// App navigation and routing.
import 'package:flutter/material.dart';

// Friendly setup screen shown when the URL or publishable key is missing.
class SupabaseSetupRequiredApp extends StatelessWidget {
  const SupabaseSetupRequiredApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('Supabase setup required')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 700),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.settings_rounded, size: 56, color: Colors.indigo),
                  SizedBox(height: 16),
                  Text(
                    'The app is ready, but Supabase credentials were not supplied.',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  SelectableText(
                    'Run with:\n\n'
                    'flutter run '
                    '--dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co '
                    '--dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_KEY',
                  ),
                  SizedBox(height: 12),
                  Text(
                    'See README.md and supabase/schema.sql for the remaining setup steps.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
