// Supabase connection configuration.
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = 'https://zwskyuypfsxpexjaflfg.supabase.co';

  static const String publishableKey =
      'sb_publishable_o8UzlUF85gF8Uq0QMG3wOw_C76Y2Hy7';

  static const String redirectScheme = 'com.example.attendanceapp3a';

  static const String redirectHost = 'login-callback';

  static const String redirectUrl = '$redirectScheme://$redirectHost/';

  static bool get isConfigured =>
      url.trim().isNotEmpty && publishableKey.trim().isNotEmpty;
}
