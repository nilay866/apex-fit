import 'dart:math' as math;

/// Cardio analytics engine — VO2max, training load, calorie models, race prediction.
/// Complements the existing StrengthAnalytics for strength metrics.
class CardioAnalytics {
  // ── VO2max Estimation ──────────────────────────────────────────────────

  /// Cooper test: VO2max = (distance_meters - 504.9) / 44.73
  static double estimateVo2maxCooper(double distanceMetersIn12Min) {
    if (distanceMetersIn12Min <= 0) return 0;
    return (distanceMetersIn12Min - 504.9) / 44.73;
  }

  /// Jack Daniels VDOT from race distance and time
  /// Simplified: VO2max ≈ -4.60 + 0.182258 * velocity + 0.000104 * velocity²
  /// where velocity = meters / minutes
  static double estimateVo2maxFromRace(
    double distanceMeters,
    int durationSeconds,
  ) {
    if (distanceMeters <= 0 || durationSeconds <= 0) return 0;
    final minutes = durationSeconds / 60;
    final velocity = distanceMeters / minutes;
    return -4.60 + 0.182258 * velocity + 0.000104 * velocity * velocity;
  }

  /// Estimate VO2max from best effort pace (min/km) for running
  static double estimateVo2maxFromPace(double paceMinPerKm) {
    if (paceMinPerKm <= 0 || paceMinPerKm > 20) return 0;
    // Rough approximation: faster pace = higher VO2max
    return 210 / paceMinPerKm - 3.5;
  }

  // ── Calorie Estimation ────────────────────────────────────────────────

  /// MET-based calorie estimation
  static double caloriesFromMet(double met, double weightKg, int durationSec) {
    return met * weightKg * (durationSec / 3600);
  }

  /// Running calorie estimation (more precise)
  /// kcal/min = (0.2 × speed_m_per_min + 0.9) × weight_kg / 200
  static double runningCalories(double speedMs, double weightKg, int durationSec) {
    final speedMperMin = speedMs * 60;
    final kcalPerMin = (0.2 * speedMperMin + 0.9) * weightKg / 200;
    return kcalPerMin * (durationSec / 60);
  }

  // ── Training Stress Score ──────────────────────────────────────────────

  /// TSS = (seconds × NP × IF) / (FTP × 3600) × 100
  /// Simplified version using heart rate zones
  static double trainingStressScore({
    required int durationSeconds,
    required double intensityFactor, // 0.0 - 1.5+
    double ftpOrThreshold = 200,
  }) {
    return (durationSeconds * intensityFactor * intensityFactor) /
        3600 *
        100;
  }

  /// Relative Effort from heart rate (simplified Strava-like)
  /// Uses TRIMP (Training Impulse) concept
  static double relativeEffort({
    required int avgHeartRate,
    required int maxHeartRate,
    required int restingHeartRate,
    required int durationMinutes,
    required bool isMale,
  }) {
    if (maxHeartRate <= restingHeartRate) return 0;
    final hrReserve =
        (avgHeartRate - restingHeartRate) / (maxHeartRate - restingHeartRate);
    final y = isMale ? 1.92 : 1.67;
    return durationMinutes * hrReserve * 0.64 * math.exp(y * hrReserve);
  }

  /// Suffer Score (intensity × duration weighted)
  static int sufferScore({
    required int durationMinutes,
    required double avgPaceMinPerKm,
    required double elevationGainM,
  }) {
    double score = durationMinutes.toDouble();

    // Pace factor: faster = more suffering
    if (avgPaceMinPerKm > 0 && avgPaceMinPerKm < 20) {
      score *= (10 / avgPaceMinPerKm);
    }

    // Elevation factor
    score += elevationGainM * 0.1;

    return score.round().clamp(0, 999);
  }

  // ── Fitness & Freshness (CTL/ATL/TSB) ─────────────────────────────────

  /// Compute Fitness, Fatigue, Form from daily TSS values
  /// CTL (Chronic Training Load) = 42-day exponential moving average of TSS
  /// ATL (Acute Training Load) = 7-day exponential moving average of TSS
  /// TSB (Training Stress Balance) = CTL - ATL (Form)
  static Map<String, double> fitnessFreshness(List<double> dailyTss) {
    if (dailyTss.isEmpty) {
      return {'fitness': 0, 'fatigue': 0, 'form': 0};
    }

    double ctl = 0; // fitness
    double atl = 0; // fatigue

    for (final tss in dailyTss) {
      ctl = ctl + (tss - ctl) / 42;
      atl = atl + (tss - atl) / 7;
    }

    return {
      'fitness': ctl,
      'fatigue': atl,
      'form': ctl - atl,
    };
  }

  // ── Race Prediction ────────────────────────────────────────────────────

  /// Predict race times from VO2max using Riegel formula
  /// T2 = T1 × (D2/D1)^1.06
  static Map<String, String> predictRaceTimes(
    double knownDistanceKm,
    int knownDurationSeconds,
  ) {
    if (knownDistanceKm <= 0 || knownDurationSeconds <= 0) return {};

    String fmt(double seconds) {
      final h = (seconds / 3600).floor();
      final m = ((seconds % 3600) / 60).floor();
      final s = (seconds % 60).floor();
      if (h > 0) return '${h}h ${m}m ${s}s';
      return '${m}m ${s}s';
    }

    double predict(double targetKm) {
      return knownDurationSeconds * math.pow(targetKm / knownDistanceKm, 1.06).toDouble();
    }

    return {
      '5K': fmt(predict(5)),
      '10K': fmt(predict(10)),
      'Half Marathon': fmt(predict(21.0975)),
      'Marathon': fmt(predict(42.195)),
    };
  }

  // ── Weekly Summary ────────────────────────────────────────────────────

  /// Aggregate weekly activity stats
  static Map<String, dynamic> weeklySummary(
    List<Map<String, dynamic>> activities,
  ) {
    double totalDist = 0, totalCal = 0, totalElev = 0;
    int totalDuration = 0, count = 0;
    final types = <String, int>{};

    for (final a in activities) {
      totalDist += (a['distance_km'] as num?)?.toDouble() ?? 0;
      totalCal += (a['calories'] as num?)?.toDouble() ?? 0;
      totalElev += (a['elevation_gain'] as num?)?.toDouble() ?? 0;
      totalDuration += (a['duration_seconds'] as int?) ?? 0;
      count++;
      final t = a['type']?.toString() ?? 'other';
      types[t] = (types[t] ?? 0) + 1;
    }

    return {
      'total_distance_km': totalDist,
      'total_calories': totalCal,
      'total_elevation': totalElev,
      'total_duration_seconds': totalDuration,
      'session_count': count,
      'activity_breakdown': types,
    };
  }

  /// Power curve placeholder — best average power for each duration
  static List<Map<String, dynamic>> powerCurve(
    List<Map<String, dynamic>> powerData,
  ) {
    // Simplified: requires per-second power data
    // Returns best power for 5s, 30s, 1m, 5m, 20m, 60m
    final durations = [5, 30, 60, 300, 1200, 3600];
    return durations
        .map((d) => {'duration_seconds': d, 'best_watts': 0})
        .toList();
  }

  // ── FTP Detection ──────────────────────────────────────────────────────

  /// Estimate FTP from 20-minute power test
  /// FTP = 0.95 × 20-min average power
  static double estimateFtp(double twentyMinAvgPower) {
    return twentyMinAvgPower * 0.95;
  }

  // ── Strength Score ─────────────────────────────────────────────────────

  /// Overall Strength Score composite
  static double overallStrengthScore({
    required double benchPressMax,
    required double squatMax,
    required double deadliftMax,
    required double bodyWeight,
  }) {
    if (bodyWeight <= 0) return 0;
    final total = benchPressMax + squatMax + deadliftMax;
    return total / bodyWeight; // Wilks-like simplification
  }

  /// Strength level classification
  static String strengthLevel(double strengthScore) {
    if (strengthScore >= 6.0) return 'Elite';
    if (strengthScore >= 4.5) return 'Advanced';
    if (strengthScore >= 3.5) return 'Intermediate';
    if (strengthScore >= 2.5) return 'Novice';
    return 'Beginner';
  }
}
