import 'health_service.dart';
import 'supabase_service.dart';

/// Extends HealthService by persisting daily snapshots to the health_metrics table.
class HealthMonitoringService {
  /// Pull today's data from Apple Health and upsert to Supabase
  static Future<Map<String, dynamic>> syncDailyMetrics() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return {};

    try {
      // Fetch from Apple Health
      final daily = await HealthService.fetchDailySummary();
      final snapshot = await HealthService.getTodayHealthSnapshot();

      final metrics = {
        'user_id': uid,
        'steps': daily['steps'] ?? 0,
        'active_calories': (daily['energy'] as num?)?.toDouble() ?? 0,
        'heart_rate': null, // filled if available
        'resting_hr': snapshot['resting_hr'] != null
            ? (snapshot['resting_hr'] as num).round()
            : null,
        'sleep_hours': snapshot['sleep_hours'],
        'hrv_ms': snapshot['hrv_ms'],
        'recorded_at': DateTime.now().toIso8601String().split('T').first,
      };

      // Upsert to Supabase
      await SupabaseService.upsertHealthMetrics(metrics);
      return metrics;
    } catch (_) {
      return {};
    }
  }

  /// Get health metrics trend for last N days
  static Future<List<Map<String, dynamic>>> getMetricsTrend({
    int days = 30,
  }) async {
    try {
      final uid = SupabaseService.currentUser?.id;
      if (uid == null) return [];
      final since = DateTime.now()
          .subtract(Duration(days: days))
          .toIso8601String()
          .split('T')
          .first;
      return await SupabaseService.getHealthMetricsSince(uid, since);
    } catch (_) {
      return [];
    }
  }

  /// Calculate weekly averages from daily metrics
  static Map<String, double> weeklyAverages(
    List<Map<String, dynamic>> metrics,
  ) {
    if (metrics.isEmpty) {
      return {
        'avg_steps': 0,
        'avg_sleep': 0,
        'avg_hrv': 0,
        'avg_resting_hr': 0,
        'avg_calories': 0,
      };
    }

    double steps = 0, sleep = 0, hrv = 0, rhr = 0, cal = 0;
    int sC = 0, slC = 0, hC = 0, rC = 0, cC = 0;

    for (final m in metrics) {
      final s = (m['steps'] as num?)?.toDouble();
      if (s != null && s > 0) { steps += s; sC++; }
      final sl = (m['sleep_hours'] as num?)?.toDouble();
      if (sl != null && sl > 0) { sleep += sl; slC++; }
      final h = (m['hrv_ms'] as num?)?.toDouble();
      if (h != null && h > 0) { hrv += h; hC++; }
      final r = (m['resting_hr'] as num?)?.toDouble();
      if (r != null && r > 0) { rhr += r; rC++; }
      final c = (m['active_calories'] as num?)?.toDouble();
      if (c != null && c > 0) { cal += c; cC++; }
    }

    return {
      'avg_steps': sC > 0 ? steps / sC : 0,
      'avg_sleep': slC > 0 ? sleep / slC : 0,
      'avg_hrv': hC > 0 ? hrv / hC : 0,
      'avg_resting_hr': rC > 0 ? rhr / rC : 0,
      'avg_calories': cC > 0 ? cal / cC : 0,
    };
  }

  /// Simple stress level from HRV (lower HRV = higher stress)
  static int stressFromHrv(double? hrvMs) {
    if (hrvMs == null || hrvMs <= 0) return 50; // neutral
    if (hrvMs > 80) return 20; // low stress
    if (hrvMs > 50) return 40;
    if (hrvMs > 30) return 60;
    return 80; // high stress
  }

  /// Recovery readiness score (0-100)
  static int recoveryScore({
    double? sleepHours,
    double? hrvMs,
    int? restingHr,
    int? restingHrBaseline,
  }) {
    int score = 50;

    // Sleep factor
    if (sleepHours != null) {
      if (sleepHours >= 7.5) {
        score += 20;
      } else if (sleepHours >= 6.5) {
        score += 10;
      } else if (sleepHours < 5.5) {
        score -= 15;
      }
    }

    // HRV factor
    if (hrvMs != null) {
      if (hrvMs > 60) {
        score += 15;
      } else if (hrvMs > 40) {
        score += 5;
      } else if (hrvMs < 25) {
        score -= 15;
      }
    }

    // Resting HR factor
    if (restingHr != null && restingHrBaseline != null) {
      final diff = restingHr - restingHrBaseline;
      if (diff <= 0) {
        score += 10;
      } else if (diff > 5) {
        score -= 15;
      } else if (diff > 3) {
        score -= 5;
      }
    }

    return score.clamp(0, 100);
  }
}
