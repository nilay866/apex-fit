import 'dart:math' as math;

/// Analytics engine for strength progression.
/// Calculates 1RM, strength curves, and rep-range buckets from set log data.
class StrengthAnalytics {
  /// Epley formula: 1RM = weight × (1 + reps/30)
  static double estimate1RM(double weight, int reps) {
    if (reps <= 0 || weight <= 0) return 0;
    if (reps == 1) return weight;
    return weight * (1 + reps / 30.0);
  }

  /// Bucket a rep count into a named range.
  static String repRangeBucket(int reps) {
    if (reps <= 5) return '1–5 (Power)';
    if (reps <= 8) return '6–8 (Strength)';
    if (reps <= 12) return '9–12 (Hypertrophy)';
    return '13+ (Endurance)';
  }

  /// Given a flat list of set_logs (with 'weight_kg', 'reps_done', 'exercise_name', 'logged_at'),
  /// returns a timeline of estimated 1RMs for a given exercise, sorted oldest first.
  static List<Map<String, dynamic>> build1RMTimeline(
    List<Map<String, dynamic>> setLogs,
    String exerciseName,
  ) {
    // Group by date
    final byDate = <String, List<Map<String, dynamic>>>{};
    for (final s in setLogs) {
      if ((s['exercise_name'] as String? ?? '').toLowerCase() != exerciseName.toLowerCase()) continue;
      final date = (s['logged_at'] as String? ?? s['completed_at'] as String? ?? '').split('T').first;
      if (date.isEmpty) continue;
      byDate.putIfAbsent(date, () => []).add(s);
    }

    final timeline = byDate.entries.map((e) {
      double best1RM = 0;
      for (final s in e.value) {
        final w = (s['weight_kg'] as num?)?.toDouble() ?? 0;
        final r = (s['reps_done'] as num?)?.toInt() ?? 0;
        final estimated = estimate1RM(w, r);
        if (estimated > best1RM) best1RM = estimated;
      }
      return {'date': e.key, '1rm': best1RM};
    }).toList();

    timeline.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    return timeline;
  }

  /// Returns best set (by estimated 1RM) for each exercise across all logs.
  static Map<String, double> bestOneRMPerExercise(List<Map<String, dynamic>> setLogs) {
    final result = <String, double>{};
    for (final s in setLogs) {
      final name = s['exercise_name'] as String? ?? '';
      final w = (s['weight_kg'] as num?)?.toDouble() ?? 0;
      final r = (s['reps_done'] as num?)?.toInt() ?? 0;
      final estimated = estimate1RM(w, r);
      if (estimated > (result[name] ?? 0)) result[name] = estimated;
    }
    return result;
  }

  /// Returns weekly total volume for a given exercise.
  static List<Map<String, dynamic>> weeklyVolumeTimeline(
    List<Map<String, dynamic>> setLogs,
    String exerciseName,
  ) {
    final byWeek = <String, double>{};
    for (final s in setLogs) {
      if ((s['exercise_name'] as String? ?? '').toLowerCase() != exerciseName.toLowerCase()) continue;
      final dateStr = (s['logged_at'] as String? ?? s['completed_at'] as String? ?? '').split('T').first;
      if (dateStr.isEmpty) continue;
      final date = DateTime.tryParse(dateStr);
      if (date == null) continue;
      final weekStart = date.subtract(Duration(days: date.weekday - 1));
      final key = '${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';
      final vol = ((s['reps_done'] as num?)?.toDouble() ?? 0) * ((s['weight_kg'] as num?)?.toDouble() ?? 0);
      byWeek[key] = (byWeek[key] ?? 0) + vol;
    }

    final result = byWeek.entries.map((e) => {'week': e.key, 'volume': e.value}).toList();
    result.sort((a, b) => (a['week'] as String).compareTo(b['week'] as String));
    return result;
  }

  /// Muscle volume heatmap: sums (weight × reps × sets) per muscle group.
  static Map<String, double> muscleVolumeHeatmap(
    List<Map<String, dynamic>> setLogs,
    Map<String, String> exerciseToMuscle, // exercise_name -> primary_muscle
  ) {
    final result = <String, double>{};
    for (final s in setLogs) {
      final name = s['exercise_name'] as String? ?? '';
      final muscle = exerciseToMuscle[name] ?? 'Other';
      final vol = ((s['reps_done'] as num?)?.toDouble() ?? 0) * ((s['weight_kg'] as num?)?.toDouble() ?? 0);
      result[muscle] = (result[muscle] ?? 0) + vol;
    }
    return result;
  }

  /// Best set volume (weight × reps) across all time for an exercise.
  static double bestVolume(List<Map<String, dynamic>> setLogs, String exerciseName) {
    return setLogs
        .where((s) => (s['exercise_name'] as String? ?? '').toLowerCase() == exerciseName.toLowerCase())
        .fold(0.0, (best, s) {
      final vol = ((s['reps_done'] as num?)?.toDouble() ?? 0) * ((s['weight_kg'] as num?)?.toDouble() ?? 0);
      return math.max(best, vol);
    });
  }
}
