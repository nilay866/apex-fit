/// Standalone nutrition service — wraps SupabaseService nutrition methods
/// and adds daily totals, macro calculations, and goal tracking.
class NutritionService {
  /// Calculate daily macro totals from a list of meal logs
  static Map<String, double> dailyTotals(List<Map<String, dynamic>> logs) {
    double cal = 0, prot = 0, carbs = 0, fat = 0, fiber = 0;
    for (final l in logs) {
      cal += (l['calories'] as num?)?.toDouble() ?? 0;
      prot += (l['protein_g'] as num?)?.toDouble() ?? 0;
      carbs += (l['carbs_g'] as num?)?.toDouble() ?? 0;
      fat += (l['fat_g'] as num?)?.toDouble() ?? 0;
      fiber += (l['fiber_g'] as num?)?.toDouble() ?? 0;
    }
    return {
      'calories': cal,
      'protein': prot,
      'carbs': carbs,
      'fat': fat,
      'fiber': fiber,
    };
  }

  /// Calculate macro split percentages
  static Map<String, double> macroPercentages(Map<String, double> totals) {
    final totalCal = totals['calories'] ?? 0;
    if (totalCal <= 0) {
      return {'protein_pct': 0, 'carbs_pct': 0, 'fat_pct': 0};
    }
    // 1g protein = 4 kcal, 1g carbs = 4 kcal, 1g fat = 9 kcal
    final protCal = (totals['protein'] ?? 0) * 4;
    final carbsCal = (totals['carbs'] ?? 0) * 4;
    final fatCal = (totals['fat'] ?? 0) * 9;
    final sum = protCal + carbsCal + fatCal;
    if (sum <= 0) return {'protein_pct': 0, 'carbs_pct': 0, 'fat_pct': 0};

    return {
      'protein_pct': (protCal / sum) * 100,
      'carbs_pct': (carbsCal / sum) * 100,
      'fat_pct': (fatCal / sum) * 100,
    };
  }

  /// TDEE estimation using Mifflin-St Jeor formula
  /// activityMultiplier: 1.2 (sedentary) to 1.9 (very active)
  static double estimateTdee({
    required double weightKg,
    required double heightCm,
    required int ageYears,
    required bool isMale,
    double activityMultiplier = 1.55,
  }) {
    final bmr = isMale
        ? 10 * weightKg + 6.25 * heightCm - 5 * ageYears + 5
        : 10 * weightKg + 6.25 * heightCm - 5 * ageYears - 161;
    return bmr * activityMultiplier;
  }

  /// Net calories = food consumed - exercise burned
  static double netCalories(double foodCalories, double exerciseCalories) {
    return foodCalories - exerciseCalories;
  }

  /// Suggest macro targets based on goal
  static Map<String, double> suggestMacros({
    required double tdee,
    required String goal, // 'lose_weight', 'maintain', 'build_muscle'
  }) {
    double targetCal;
    double protPct, carbPct, fatPct;

    switch (goal) {
      case 'lose_weight':
        targetCal = tdee * 0.8; // 20% deficit
        protPct = 0.35;
        carbPct = 0.35;
        fatPct = 0.30;
        break;
      case 'build_muscle':
        targetCal = tdee * 1.1; // 10% surplus
        protPct = 0.30;
        carbPct = 0.45;
        fatPct = 0.25;
        break;
      default: // maintain
        targetCal = tdee;
        protPct = 0.25;
        carbPct = 0.45;
        fatPct = 0.30;
    }

    return {
      'calories': targetCal,
      'protein_g': (targetCal * protPct) / 4,
      'carbs_g': (targetCal * carbPct) / 4,
      'fat_g': (targetCal * fatPct) / 9,
    };
  }

  /// Identify most logged foods from history
  static List<Map<String, dynamic>> mostLoggedFoods(
    List<Map<String, dynamic>> allLogs, {
    int limit = 10,
  }) {
    final freq = <String, int>{};
    final detail = <String, Map<String, dynamic>>{};
    for (final l in allLogs) {
      final name = l['food_name']?.toString() ?? '';
      if (name.isEmpty) continue;
      freq[name] = (freq[name] ?? 0) + 1;
      detail[name] = l;
    }
    final sorted = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted
        .take(limit)
        .map((e) => {...detail[e.key]!, 'log_count': e.value})
        .toList();
  }
}
