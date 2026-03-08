import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';

class AIService {
  static GenerativeModel? _model;

  static void init(String apiKey) {
    _model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: apiKey,
    );
  }

  static Future<String> _generate(String prompt) async {
    if (_model == null) throw Exception('AI is not configured for this build');
    try {
      final response = await _model!.generateContent([Content.text(prompt)]);
      return response.text ?? '';
    } catch (e) {
      if (e.toString().contains('429')) {
        throw Exception('Rate limit — wait a moment and retry');
      }
      if (e.toString().contains('API key')) {
        throw Exception('Invalid Gemini API key — check at aistudio.google.com');
      }
      throw Exception('AI error: $e');
    }
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
    final raw = await _generate(prompt);
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
    final raw = await _generate(prompt);
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
      final result = await _generate(prompt);
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
    return await _generate('$system\n\n---\n$history\nCoach:');
  }

  static Future<bool> testConnection(String apiKey) async {
    try {
      final testModel = GenerativeModel(model: 'gemini-2.0-flash', apiKey: apiKey);
      final response = await testModel.generateContent([Content.text('Reply with exactly: APEX AI ready')]);
      return response.text != null && response.text!.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
