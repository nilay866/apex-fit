import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'supabase_service.dart';
import 'ai_service.dart';

class PlanGeneratorService {
  static Future<Map<String, dynamic>> generateMacrocycle(Map<String, dynamic> profile) async {
    try {
      final goal = profile['goal'] ?? 'Build Muscle';
      final age = profile['age'] ?? 25;
      final level = profile['fitness_level'] ?? 5; // 1-10
      
      final prompt = '''
You are an elite fitness coach and kinesiology expert.
Design a 4-week structured macrocycle program for a user with the following profile:
- Age: $age
- Fitness Level: $level / 10
- Primary Goal: $goal

Return ONLY valid JSON covering Week 1 to Week 4. For each week, define 'focus' and an array of 'days' (e.g., Day 1 to Day 7). Each day should have 'title' (e.g. "Push Day", "Rest", "Cardio"), 'intensity' (Low/Med/High), and a brief 'description'. No markdown wrappers or other text!
''';
      final response = await AIService.generate(prompt);
      final jsonStr = response.replaceAll(RegExp(r'```json\n?|```'), '').trim();
      
      return jsonDecode(jsonStr);
    } catch (e) {
      // Mock deterministic structure 
      return {
        'week_1': {
          'focus': 'Hypertrophy Base',
          'days': [
            {'title': 'Push Day', 'intensity': 'High', 'description': 'Chest, Shoulders, Triceps focusing on 8-12 reps.'},
            {'title': 'Pull Day', 'intensity': 'High', 'description': 'Back and Biceps focusing on lat engagement.'},
            {'title': 'Active Rest', 'intensity': 'Low', 'description': 'Light cardio and mobility work.'},
            {'title': 'Leg Day', 'intensity': 'High', 'description': 'Quads, Hamstrings, Calves.'},
            {'title': 'Upper Body Mix', 'intensity': 'Med', 'description': 'Compound upper body movements.'},
            {'title': 'Lower Body Mix', 'intensity': 'Med', 'description': 'Accessory lower body work.'},
            {'title': 'Full Rest', 'intensity': 'Low', 'description': 'Complete recovery.'},
          ]
        }
      };
    }
  }
}

class SmartCoach {
  /// Brzycki formula 1RM estimation
  static double estimate1RM(double weight, int reps) {
    if (reps == 1) return weight;
    return weight * (36 / (37 - reps));
  }

  static double prescribedWeight(double oneRm, double percentage) {
    return oneRm * percentage;
  }
}
