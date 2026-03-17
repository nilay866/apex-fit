import 'dart:convert';
import 'ai/ai_provider.dart';
import 'ai/gemini_provider.dart';
import 'ai/bedrock_provider.dart';

class AIService {
  static AIProvider? _activeProvider;
  static final Map<String, Map<String, dynamic>> _workoutCache = {};
  static final Map<String, Map<String, dynamic>> _nutritionCache = {};

  static void useGemini(String apiKey) {
    _activeProvider = GeminiProvider(apiKey);
  }

  static void useBedrock({String? modelId}) {
    _activeProvider = BedrockProvider(modelId: modelId);
  }

  static Future<String> generate(String prompt) async {
    if (_activeProvider == null) {
      throw Exception('AI is not configured. Go to Settings.');
    }
    return await _activeProvider!.generate(prompt);
  }

  static Map<String, dynamic> _extractJson(String raw) {
    try {
      // First try to find a JSON block
      final a = raw.indexOf('{');
      final b = raw.lastIndexOf('}');
      if (a != -1 && b != -1 && b > a) {
        final jsonStr = raw.substring(a, b + 1);
        final parsed = jsonDecode(jsonStr);
        if (parsed is Map<String, dynamic>) {
          return parsed;
        }
      }
      
      // Fallback to stripping markdown
      String cleaned = raw
          .replaceAll(RegExp(r'```json', caseSensitive: false), '')
          .replaceAll('```', '')
          .trim();
          
      final parsed = jsonDecode(cleaned);
      if (parsed is Map<String, dynamic>) {
        return parsed;
      }
      throw Exception('Parsed JSON is not a Map');
    } catch (e) {
      print('AI JSON Parse Error: $e');
      print('Raw AI Output: $raw');
      throw Exception('Could not parse JSON from AI: $e');
    }
  }

  static Map<String, dynamic> _defaultWorkout({
    required String goal,
    required String focus,
  }) {
    final normalizedFocus = focus.trim().isEmpty ? 'full body' : focus;
    return {
      'name': '$goal ${normalizedFocus.split(' ').first} Session',
      'type': 'Gym',
      'exercises': [
        {
          'name': 'Barbell Squat',
          'sets': 3,
          'reps': '6-8',
          'target_weight': '60',
        },
        {
          'name': 'Bench Press',
          'sets': 3,
          'reps': '8-10',
          'target_weight': '50',
        },
        {
          'name': 'Seated Cable Row',
          'sets': 3,
          'reps': '10-12',
          'target_weight': '40',
        },
        {
          'name': 'Romanian Deadlift',
          'sets': 3,
          'reps': '8-10',
          'target_weight': '60',
        },
        {
          'name': 'Overhead Press',
          'sets': 3,
          'reps': '8-10',
          'target_weight': '30',
        },
        {'name': 'Plank', 'sets': 3, 'reps': '45s', 'target_weight': '0'},
      ],
    };
  }

  static Future<Map<String, dynamic>> generateWorkout({
    required String goal,
    required String level,
    required String equipment,
    required String focus,
  }) async {
    final cacheKey = '$goal|$level|$equipment|$focus';
    final cached = _workoutCache[cacheKey];
    if (cached != null) return Map<String, dynamic>.from(cached);

    final prompt =
        '''You are a fitness coach. Create a $goal workout for a $level using $equipment. Focus: $focus.
Reply with ONLY valid JSON no markdown:
{"name":"Workout Name","type":"Gym","exercises":[{"name":"Exercise","sets":3,"reps":"8-12","target_weight":"60"}]}
Include 6 exercises. type must be one of: Gym, Calisthenics, HIIT, Mobility.''';

    try {
      final raw = await generate(prompt);
      final parsed = _extractJson(raw);
      if (parsed['name'] == null || parsed['exercises'] == null) {
        throw Exception('Invalid AI response');
      }
      _workoutCache[cacheKey] = Map<String, dynamic>.from(parsed);
      return parsed;
    } catch (_) {
      final fallback = _defaultWorkout(goal: goal, focus: focus);
      _workoutCache[cacheKey] = Map<String, dynamic>.from(fallback);
      return fallback;
    }
  }

  static Future<Map<String, dynamic>> lookupNutrition(
    String food,
    String? quantity,
  ) async {
    final cacheKey = '$food|${quantity ?? ''}'.toLowerCase();
    final cached = _nutritionCache[cacheKey];
    if (cached != null) return Map<String, dynamic>.from(cached);

    final prompt =
        '''Nutrition for "$food"${quantity != null && quantity.isNotEmpty ? " quantity $quantity" : ""}.
Reply ONLY JSON no markdown: {"calories":250,"protein_g":20,"carbs_g":30,"fat_g":8}
Realistic values, 100g default if no qty given.''';
    try {
      final raw = await generate(prompt);
      final parsed = _extractJson(raw);
      _nutritionCache[cacheKey] = Map<String, dynamic>.from(parsed);
      return parsed;
    } catch (e) {
      print('AI Nutrition Error for "$food": $e');
      final fallback = {
        'calories': 250,
        'protein_g': 15,
        'carbs_g': 20,
        'fat_g': 10,
      };
      _nutritionCache[cacheKey] = Map<String, dynamic>.from(fallback);
      return fallback;
    }
  }

  static Future<String> getDailySuggestion({
    required String goal,
    required List<String> recentWorkouts,
    required String dayOfWeek,
  }) async {
    final recent = recentWorkouts.isNotEmpty
        ? recentWorkouts.join(', ')
        : 'none';
    final prompt =
        '''Athlete goal: $goal. Recent workouts: $recent. Today is $dayOfWeek.
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
    final history = messages
        .map(
          (m) => '${m["role"] == "user" ? "User" : "Coach"}: ${m["content"]}',
        )
        .join('\n');
    final system =
        '''You are an expert AI fitness coach in the APEX AI app. Be direct, specific, and motivating. Max 150 words unless asked more. Bullet points for lists.
Athlete: $athleteName | Goal: $goal | Weight: ${weightKg ?? '?'}kg | Height: ${heightCm ?? '?'}cm
Recent: ${recentLogs.isNotEmpty ? recentLogs.join(', ') : 'none'}''';
    return await generate('$system\n\n---\n$history\nCoach:');
  }

  static Future<bool> testConnection({String? geminiApiKey}) async {
    final provider = geminiApiKey != null && geminiApiKey.trim().isNotEmpty
        ? GeminiProvider(geminiApiKey.trim())
        : _activeProvider;
    if (provider == null) return false;
    return await provider.testConnection();
  }
}
