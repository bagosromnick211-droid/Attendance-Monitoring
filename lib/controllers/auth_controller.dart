// Application state and actions.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../utils/email_utils.dart';

// Authentication and profile *state*, not login form text fields.
class AuthController extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;
  late final StreamSubscription<AuthState> _authSubscription;
  bool _isLoading = false;
  String? _profileUsername;
  String? _profileUserId;

  // Subscribe once, and release the subscription in dispose().
  AuthController() {
    _authSubscription = _client.auth.onAuthStateChange.listen((state) {
      if (state.session == null) {
        _profileUsername = null;
        _profileUserId = null;
      } else if (_profileUserId != state.session!.user.id) {
        _profileUserId = state.session!.user.id;
        unawaited(loadProfile());
      }
      notifyListeners();
    });
    if (currentUser != null) {
      _profileUserId = currentUser!.id;
      unawaited(loadProfile());
    }
  }

  bool get isLoading => _isLoading;
  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;
  String get email => currentUser?.email ?? '';
  String get username {
    final saved = _profileUsername;
    if (saved != null && saved.isNotEmpty) return saved;
    final metadata = currentUser?.userMetadata?['username']?.toString().trim();
    if (metadata != null && metadata.isNotEmpty) return metadata;
    // Existing accounts created before the v8 migration have no username.
    return email.isEmpty ? 'My account' : email.split('@').first;
  }

  // Kept as a convenience for older callers and regression tests.
  static String maskEmail(String email) => maskEmailAddress(email);

  // Get the user's display name from profiles.
  Future<void> loadProfile() async {
    final id = currentUser?.id;
    if (id == null) return;
    try {
      final row = await _client.from('profiles')
          .select('username').eq('id', id).maybeSingle();
      if (id != currentUser?.id) return;
      _profileUsername = row?['username']?.toString();
      notifyListeners();
    } catch (error) {
      // Older installations can still sign in before running the migration.
      if (kDebugMode) debugPrint('[Profile] Could not load: $error');
    }
  }

  // Update the profile row and auth metadata used as a fallback name.
  Future<void> updateUsername(String name) async {
    final normalized = name.trim();
    if (normalized.length < 2 || normalized.length > 60) {
      throw ArgumentError('Username must be between 2 and 60 characters.');
    }
    final id = currentUser?.id;
    if (id == null) throw AuthException('Please sign in again.');
    _setLoading(true);
    try {
      await _client.from('profiles').upsert({'id': id, 'username': normalized});
      await _client.auth.updateUser(UserAttributes(data: {'username': normalized}));
      _profileUsername = normalized;
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  // Resend a signup confirmation email.
  Future<void> resendConfirmation(String email) async {
    if (email.trim().isEmpty || !email.contains('@')) {
      throw AuthException('Enter the email address used during registration.');
    }
    _setLoading(true);
    try {
      await _client.auth.resend(
        type: OtpType.signup,
        email: email.trim(),
        emailRedirectTo: kIsWeb ? null : SupabaseConfig.redirectUrl,
      );
    } finally {
      _setLoading(false);
    }
  }

  // Permanently delete the current user's account on the server.
  Future<void> deleteAccount() async {
    if (currentSession == null) throw AuthException('Please sign in again.');
    _setLoading(true);
    try {
      final response = await _client.functions.invoke(
        'delete-account',
        body: {'confirmation': 'DELETE'},
      );
      if (response.data is! Map || response.data['deleted'] != true) {
        throw StateError('Account deletion was not confirmed by the server.');
      }
      // The server has deleted auth.users and its cascading child rows.
      await _client.auth.signOut(scope: SignOutScope.local);
      _profileUsername = null;
      _profileUserId = null;
    } finally {
      _setLoading(false);
    }
  }

  // Wrap Supabase email/password sign-in with a UI loading flag.
  Future<AuthResponse> signInWithEmail(String email, String password) async {
    if (email.trim().isEmpty || password.isEmpty) {
      throw AuthException('Email and password are required.');
    }
    _setLoading(true);
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim(), password: password);
      await loadProfile();
      return response;
    } finally {
      _setLoading(false);
    }
  }

  // Save username in signup metadata.
  Future<AuthResponse> signUpWithEmail(String username, String email, String password) async {
    final name = username.trim();
    if (name.length < 2 || name.length > 60) {
      throw AuthException('Username must be between 2 and 60 characters.');
    }
    if (email.trim().isEmpty || password.isEmpty) {
      throw AuthException('Email and password are required.');
    }
    _setLoading(true);
    try {
      return await _client.auth.signUp(
        email: email.trim(), password: password,
        data: {'username': name},
        emailRedirectTo: kIsWeb ? null : SupabaseConfig.redirectUrl,
      );
    } finally {
      _setLoading(false);
    }
  }

  // OAuth opens a browser and later returns through the configured deep link.
  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    try {
      return await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : SupabaseConfig.redirectUrl,
      );
    } finally {
      _setLoading(false);
    }
  }

  // End the session and clear profile data from memory.
  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _client.auth.signOut();
      _profileUsername = null;
      _profileUserId = null;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }
}
