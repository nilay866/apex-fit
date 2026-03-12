import 'dart:convert';
import 'ai/ai_provider.dart';
import 'ai/gemini_provider.dart';
import 'ai/bedrock_provider.dart';

class AIService {
  static AIProvider? _activeProvider;

  static void useGemini(String apiKey) {
    _activeProvider = GeminiProvider(apiKey);
  }

  static void useBedrock({String? modelId}) {
    _activeProvider = BedrockProvider(modelId: modelId);
  }

  static Future<String> generate(String prompt) async {
    if (_activeProvider == null) throw Exception('AI is not configured. Go to Settings.');
    return await _activeProvider!.generate(prompt);
  }

  static Map<String, dynamic> _extractJson(String raw) {
    String cleaned = raw.replaceAll(RegExp(r'```json', caseSensitive: false), '').replaceAll('```', '').trim();
    try {
      return jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (_) {}
    final a = cleaned.indexOf('{');
    final b = cleaned.lastIndexOf('}');
    if (a != -1 && b > a) {
      try {
        return jsonDecode(cleaned.substring(a, b + 1)) as Map<String, dynamic>;
      } catch (_) {}
    }
    throw Exception('Could not parse JSON from AI');
  }

  static Future<Map<String, dynamic>> generateWorkout({
    required String goal,
    required String level,
    required String equipment,
    required String focus,
  }) async {
    final prompt = '''You are a fitness coach. Create a $goal workout for a $level using $equipment. Focus: $focus.
Reply with ONLY valid JSON no markdown:
{"name":"Workout Name","type":"Gym","exercises":[{"name":"Exercise","sets":3,"reps":"8-12","target_weight":"60"}]}
Include 6 exercises. type must be one of: Gym, Calisthenics, HIIT, Mobility.''';
    final raw = await generate(prompt);
    final parsed = _extractJson(raw);
    if (parsed['name'] == null || parsed['exercises'] == null) {
      throw Exception('Invalid AI response');
    }
    return parsed;
  }

  static Future<Map<String, dynamic>> lookupNutrition(String food, String? quantity) async {
    final prompt = '''Nutrition for "$food"${quantity != null && quantity.isNotEmpty ? " quantity $quantity" : ""}.
Reply ONLY JSON no markdown: {"calories":250,"protein_g":20,"carbs_g":30,"fat_g":8}
Realistic values, 100g default if no qty given.''';
    final raw = await generate(prompt);
    return _extractJson(raw);
  }

  static Future<String> getDailySuggestion({
    required String goal,
    required List<String> recentWorkouts,
    required String dayOfWeek,
  }) async {
    final recent = recentWorkouts.isNotEmpty ? recentWorkouts.join(', ') : 'none';
    final prompt = '''Athlete goal: $goal. Recent workouts: $recent. Today is $dayOfWeek.
Suggest one workout in 1 sentence. Max 25 words. Name specific muscles.''';
    try {
      final result = await generate(prompt);
      return result.trim();
    } catch (_) {
      return 'Focus on compound lifts — squat, bench, or deadlift today.';
    }
  }

  static Future<String> chat({
    required List<Map<String, String>> messages,
    required String athleteName,
    required String goal,
    double? weightKg,
    double? heightCm,
    required List<String> recentLogs,
  }) async {
    final history = messages.map((m) => '${m["role"] == "user" ? "User" : "Coach"}: ${m["content"]}').join('\n');
    final system = '''You are an expert AI fitness coach in the APEX AI app. Be direct, specific, and motivating. Max 150 words unless asked more. Bullet points for lists.
Athlete: $athleteName | Goal: $goal | Weight: ${weightKg ?? '?'}kg | Height: ${heightCm ?? '?'}cm
Recent: ${recentLogs.isNotEmpty ? recentLogs.join(', ') : 'none'}''';
    return await generate('$system\n\n---\n$history\nCoach:');
  }

  static Future<bool> testConnection() async {
    if (_activeProvider == null) return false;
    return await _activeProvider!.testConnection();
  }
}
