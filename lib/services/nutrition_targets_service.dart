import 'package:apex_ai/services/supabase_service.dart';

class NutritionTargets {
  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final bool isTrainingDay;

  const NutritionTargets({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.isTrainingDay,
  });
}

class NutritionTargetsService {
  /// Computes dynamic daily nutrition targets based on training day status.
  static Future<NutritionTargets> computeForToday(
    String userId,
    Map<String, dynamic> profile,
  ) async {
    try {
      // Check if user has a workout log for today
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      final todayLogs = await SupabaseService.getWorkoutLogsSince(
        userId,
        DateTime.now().subtract(const Duration(hours: 20)),
      );
      final isTrainingDay = todayLogs.any((l) {
        final d = (l['completed_at']?.toString() ?? '').split('T')[0];
        return d == todayStr;
      });

      // Base targets from profile (with safe fallbacks)
      final baseCalories = (profile['calorie_goal'] as int?) ?? 2200;
      final baseProtein = (profile['goal_protein_g'] as int?) ?? 150;
      final baseCarbs = (profile['goal_carbs_g'] as int?) ?? 220;
      final baseFat = (profile['goal_fat_g'] as int?) ?? 80;

      if (isTrainingDay) {
        // Add +300 kcal carbs on training days
        return NutritionTargets(
          calories: baseCalories + 300,
          proteinG: baseProtein,
          carbsG: baseCarbs + 60, // 60g carbs ≈ 240 kcal
          fatG: baseFat,
          isTrainingDay: true,
        );
      } else {
        // Reduce carbs on rest days for recomposition
        return NutritionTargets(
          calories: baseCalories - 200,
          proteinG: baseProtein + 10, // keep protein high on rest
          carbsG: (baseCarbs - 50).clamp(50, 500),
          fatG: baseFat,
          isTrainingDay: false,
        );
      }
    } catch (_) {
      // Fallback: safe defaults
      return const NutritionTargets(
        calories: 2200,
        proteinG: 150,
        carbsG: 220,
        fatG: 80,
        isTrainingDay: false,
      );
    }
  }
}
