/// App configuration — all secrets MUST be passed via --dart-define at build time.
/// Never commit default API keys to source control.
///
/// Build example:
///   flutter build web \
///     --dart-define=SUPABASE_URL=https://your-project.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=your-anon-key \
///     --dart-define=GEMINI_API_KEY=your-gemini-key
class AppConfig {
  AppConfig._();

  // SEC-FIX: Removed hardcoded Supabase URL — must be provided at build time
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  // SEC-FIX: Removed hardcoded Supabase JWT token — must be provided at build time
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  // SEC-FIX: Removed hardcoded Gemini API key — must be provided at build time
  // Move Gemini calls server-side before public distribution.
  static const geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

  static bool get hasSupabase =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  static bool get hasGemini => geminiApiKey.trim().isNotEmpty;
}
