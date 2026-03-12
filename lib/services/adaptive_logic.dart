import 'dart:math';

class AdaptiveLogic {
  static const double minIncrement = 2.5; // kg
  
  /// Calculates the recommended weight and reps for the next session.
  /// Uses a standard progressive overload algorithm: 
  /// If all sets were completed easily, increase weight by 2.5-5.0%.
  static Map<String, dynamic> recommendNextSession({
    required List<Map<String, dynamic>> previousSets,
    required String intensity,
  }) {
    if (previousSets.isEmpty) return {};

    // Calculate total volume and completion rate
    final doneSets = previousSets.where((s) => s['reps_done'] > 0).toList();
    if (doneSets.isEmpty) return {};

    double totalWeight = 0;
    int totalReps = 0;
    double maxWeight = 0;

    for (var s in doneSets) {
      final w = (s['weight_kg'] as num).toDouble();
      final r = (s['reps_done'] as num).toInt();
      totalWeight += w;
      totalReps += r;
      if (w > maxWeight) maxWeight = w;
    }

    final avgWeight = totalWeight / doneSets.length;
    final avgReps = totalReps / doneSets.length;

    double recommendedWeight = maxWeight;
    int recommendedReps = avgReps.round();

    // Logic: If intensity was 'light' or 'moderate' and completion was high, increase.
    if (intensity == 'light') {
      recommendedWeight += maxWeight * 0.05; // 5% jump
    } else if (intensity == 'moderate') {
      recommendedWeight += maxWeight * 0.025; // 2.5% jump
    } else {
      // 'heavy' - stay the same or increase only if reps were very high
      if (avgReps >= 12) {
        recommendedWeight += maxWeight * 0.025;
      }
    }

    // Round to nearest 2.5kg (standard gym increment)
    recommendedWeight = (recommendedWeight / minIncrement).round() * minIncrement;
    
    // Ensure we don't recommend less than max weight if we succeeded
    if (recommendedWeight < maxWeight) recommendedWeight = maxWeight;

    return {
      'weight': recommendedWeight,
      'reps': recommendedReps,
      'reason': intensity == 'light' ? 'Increasing for progressive overload' : 'Maintaining and refining current intensity',
    };
  }

  /// Adjusts the current session dynamically based on fatigue.
  /// If a user marks a set as 'failure' too early, it might suggest dropping weight or sets.
  static String? getLiveAdjustmentSuggest({
    required int setNumber,
    required String setType,
    required int actualReps,
    required int targetReps,
  }) {
    if (setType == 'failure' && actualReps < targetReps - 2) {
      return 'High fatigue detected. Consider dropping weight by 10% for the next set.';
    }
    if (setNumber >= 3 && actualReps > targetReps + 2) {
      return 'Exceptional performance. Try increasing weight for the next set.';
    }
    return null;
  }
}
