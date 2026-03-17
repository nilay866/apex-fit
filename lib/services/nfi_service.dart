import 'package:apex_ai/services/health_service.dart';
import 'package:apex_ai/services/supabase_service.dart';

class NfiService {
  /// Computes the Neural Fatigue Index (0–100) for today.
  /// Higher = better recovery. Returns null if no data available.
  static Future<NfiResult?> computeToday(String userId) async {
    try {
      // 1. Pull health data from existing HealthService
      final healthData = await HealthService.getTodayHealthSnapshot();

      // 2. Pull recent training load from Supabase (last 7 days volume)
      final recentLogs = await SupabaseService.getWorkoutLogsSince(
        userId,
        DateTime.now().subtract(const Duration(days: 7)),
      );

      // Score each component 0–100
      final double hrvScore = _scoreHrv(healthData['hrv_ms'] as double?);
      final double sleepScore =
          _scoreSleep(healthData['sleep_hours'] as double?);
      final double hrScore =
          _scoreRestingHr(healthData['resting_hr'] as double?);
      final double moodScore = 70.0; // Default; user can override via UI
      final double loadScore = _scoreTrainingLoad(recentLogs);

      final double nfi = (hrvScore * 0.35) +
          (sleepScore * 0.30) +
          (hrScore * 0.15) +
          (moodScore * 0.10) +
          (loadScore * 0.10);

      final int nfiInt = nfi.round().clamp(0, 100);

      return NfiResult(
        score: nfiInt,
        hrv: healthData['hrv_ms'] as double?,
        sleepHours: healthData['sleep_hours'] as double?,
        restingHr: healthData['resting_hr'] as double?,
        label: _label(nfiInt),
        recommendation: _recommendation(nfiInt),
      );
    } catch (_) {
      return null;
    }
  }

  static double _scoreHrv(double? hrv) {
    if (hrv == null) return 60.0; // neutral default
    if (hrv >= 80) return 100.0;
    if (hrv <= 20) return 0.0;
    return ((hrv - 20) / 60 * 100).clamp(0, 100);
  }

  static double _scoreSleep(double? hours) {
    if (hours == null) return 60.0;
    if (hours >= 8.0) return 100.0;
    if (hours <= 4.0) return 0.0;
    return ((hours - 4.0) / 4.0 * 100).clamp(0, 100);
  }

  static double _scoreRestingHr(double? hr) {
    if (hr == null) return 60.0;
    // Lower resting HR = better
    if (hr <= 50) return 100.0;
    if (hr >= 90) return 0.0;
    return ((90 - hr) / 40 * 100).clamp(0, 100);
  }

  static double _scoreTrainingLoad(List<Map<String, dynamic>> logs) {
    if (logs.isEmpty) return 80.0; // well-rested
    // High volume in last 2 days = fatigue
    final recent = logs.where((l) {
      final d = DateTime.tryParse(l['created_at']?.toString() ?? '');
      if (d == null) {
        // Try completed_at as fallback
        final ca = DateTime.tryParse(l['completed_at']?.toString() ?? '');
        if (ca == null) return false;
        return DateTime.now().difference(ca).inDays <= 2;
      }
      return DateTime.now().difference(d).inDays <= 2;
    }).length;
    if (recent == 0) return 85.0;
    if (recent >= 3) return 30.0;
    return 65.0;
  }

  static String _label(int score) {
    if (score >= 80) return 'Optimal';
    if (score >= 60) return 'Good';
    if (score >= 40) return 'Moderate';
    return 'Recovery Day';
  }

  static String _recommendation(int score) {
    if (score >= 80) return 'Great day to push hard. Your body is primed.';
    if (score >= 60) return 'Solid session recommended. Avoid max efforts.';
    if (score >= 40) return 'Moderate workout only. Focus on technique.';
    return 'Active recovery or rest today. Sleep is the priority.';
  }
}

class NfiResult {
  final int score;
  final double? hrv;
  final double? sleepHours;
  final double? restingHr;
  final String label;
  final String recommendation;

  const NfiResult({
    required this.score,
    this.hrv,
    this.sleepHours,
    this.restingHr,
    required this.label,
    required this.recommendation,
  });
}
