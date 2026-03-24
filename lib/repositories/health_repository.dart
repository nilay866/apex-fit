import '../services/supabase_service.dart';
import '../services/health_monitoring_service.dart';
import 'auth_repository.dart';

/// Repository for persisting health metrics from Apple Health to Supabase
class HealthRepository {
  const HealthRepository();

  /// Sync today's Apple Health data to Supabase
  Future<Map<String, dynamic>> syncToday() {
    return HealthMonitoringService.syncDailyMetrics();
  }

  /// Get health metrics for last N days
  Future<List<Map<String, dynamic>>> getMetricsHistory({int days = 30}) {
    return HealthMonitoringService.getMetricsTrend(days: days);
  }

  /// Get weekly averages
  Future<Map<String, double>> getWeeklyAverages() async {
    final metrics = await getMetricsHistory(days: 7);
    return HealthMonitoringService.weeklyAverages(metrics);
  }

  /// Get recovery score for today
  Future<int> getTodayRecoveryScore() async {
    final metrics = await getMetricsHistory(days: 1);
    if (metrics.isEmpty) return 50;
    final today = metrics.first;

    final profile = await SupabaseService.getProfile(
      authRepository.requireUserId(),
    );

    return HealthMonitoringService.recoveryScore(
      sleepHours: (today['sleep_hours'] as num?)?.toDouble(),
      hrvMs: (today['hrv_ms'] as num?)?.toDouble(),
      restingHr: (today['resting_hr'] as num?)?.toInt(),
      restingHrBaseline: (profile?['resting_hr_baseline'] as num?)?.toInt(),
    );
  }
}

const healthRepository = HealthRepository();
