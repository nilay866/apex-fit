class AppConfig {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://lmnjkjekqragujmznpgy.supabase.co',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxtbmpramVrcXJhZ3VqbXpucGd5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI3MDE1MDYsImV4cCI6MjA4ODI3NzUwNn0.OJ0kkRX8dXyA9A_9Mnw27TSPBB6lhE7INDuv-JhdbMw',
  );

  // Fastest path for a private build. Move Gemini calls server-side before public distribution.
  static const geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'AIzaSyAqwn9nf1qWNZuTGjXA_3e_IBnCJZGLySo',
  );

  static bool get hasSupabase =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  static bool get hasGemini => geminiApiKey.trim().isNotEmpty;
}
