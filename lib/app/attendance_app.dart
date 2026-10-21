// App navigation and routing.
import 'package:flutter/material.dart';

import '../controllers/attendance_controller.dart';
import '../controllers/auth_controller.dart';
import '../screens/login_screen.dart';
import '../theme/app_theme.dart';
import 'app_workspace.dart';
import 'home_router.dart';

// Owns the two controllers for the life of the application.
class AttendanceApp extends StatefulWidget {
  const AttendanceApp({super.key});

  @override
  State<AttendanceApp> createState() => _AttendanceAppState();
}

// Observes auth changes and loads sheets for the currently signed-in user.
class _AttendanceAppState extends State<AttendanceApp> {
  late final AuthController authController;
  late final AttendanceController attendanceController;
  late final Listenable _combinedState;
  String? _lastUserId;

  @override
  void initState() {
    super.initState();
    authController = AuthController();
    attendanceController = AttendanceController();
    _combinedState = Listenable.merge([authController, attendanceController]);
    _lastUserId = authController.currentUser?.id;
    authController.addListener(_handleAuthChange);
    if (_lastUserId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadForms(_lastUserId!);
      });
    }
  }

  // Clears the previous account's cached attendance when auth changes.
  void _handleAuthChange() {
    final id = authController.currentUser?.id;
    if (id == _lastUserId) return;
    _lastUserId = id;
    attendanceController.clearUserState();
    if (id != null) _loadForms(id);
  }

  // Loads folders. The sheets page shows errors and offers a retry action.
  Future<void> _loadForms(String id) async {
    try {
      await attendanceController.loadUserForms(id);
    } catch (_) {
      // The sheets page exposes an error and retry action.
    }
  }

  @override
  void dispose() {
    authController.removeListener(_handleAuthChange);
    authController.dispose();
    attendanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Attendance',
      theme: AppTheme.light,
      home: AttendanceHomeRouter(
        animation: _combinedState,
        screenBuilder: (_) {
          if (authController.currentSession == null) {
            return LoginScreen(authController: authController);
          }
          return AppWorkspace(
            authController: authController,
            controller: attendanceController,
          );
        },
      ),
    );
  }
}

