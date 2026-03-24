import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HealthService {
  static final Health _health = Health();
  static const String _syncKey = 'apex_health_sync_enabled';

  static Future<bool> isSyncEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_syncKey) ?? false;
  }

  static Future<void> setSyncEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_syncKey, enabled);
  }

  static Future<bool> requestPermissions() async {
    final types = [
      HealthDataType.STEPS,
      HealthDataType.ACTIVE_ENERGY_BURNED,
    ];

    try {
      final authorized = await _health.requestAuthorization(types);
      if (authorized) {
        await setSyncEnabled(true);
      }
      return authorized;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> fetchDailySummary() async {
    if (!await isSyncEnabled()) return {'steps': 0, 'energy': 0.0};

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    
    int steps = 0;
    double energy = 0.0;

    try {
      final types = [
        HealthDataType.STEPS,
        HealthDataType.ACTIVE_ENERGY_BURNED,
      ];
      
      final healthData = await _health.getHealthDataFromTypes(
        startTime: startOfDay,
        endTime: now,
        types: types,
      );

      for (var data in healthData) {
        if (data.type == HealthDataType.STEPS) {
          steps += (data.value as NumericHealthValue).numericValue.toInt();
        } else if (data.type == HealthDataType.ACTIVE_ENERGY_BURNED) {
          energy += (data.value as NumericHealthValue).numericValue.toDouble();
        }
      }
    } catch (e) {
      // Ignore health fetch errors, just return 0s
    }

    return {
      'steps': steps,
      'energy': energy,
    };
  }

  /// NEW: Pull HRV, sleep, and resting HR for NFI computation.
  /// Returns safe defaults when data is unavailable from Apple Health.
  static Future<Map<String, dynamic>> getTodayHealthSnapshot() async {
    double? hrvMs;
    double? sleepHours;
    double? restingHr;

    if (!await isSyncEnabled()) {
      return {
        'hrv_ms': hrvMs,
        'sleep_hours': sleepHours,
        'resting_hr': restingHr,
      };
    }

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final yesterday = startOfDay.subtract(const Duration(hours: 12));

    try {
      final types = <HealthDataType>[];

      // HRV
      try {
        types.add(HealthDataType.HEART_RATE_VARIABILITY_SDNN);
      } catch (_) {}

      // Resting HR
      try {
        types.add(HealthDataType.RESTING_HEART_RATE);
      } catch (_) {}

      if (types.isNotEmpty) {
        try {
          await _health.requestAuthorization(types);
        } catch (_) {}

        try {
          final healthData = await _health.getHealthDataFromTypes(
            startTime: yesterday,
            endTime: now,
            types: types,
          );

          for (var data in healthData) {
            try {
              if (data.type == HealthDataType.HEART_RATE_VARIABILITY_SDNN) {
                final val =
                    (data.value as NumericHealthValue).numericValue.toDouble();
                if (hrvMs == null || val > hrvMs) hrvMs = val;
              } else if (data.type == HealthDataType.RESTING_HEART_RATE) {
                final val =
                    (data.value as NumericHealthValue).numericValue.toDouble();
                if (restingHr == null || val < restingHr) restingHr = val;
              }
            } catch (_) {}
          }
        } catch (_) {}
      }

      // Sleep — try to read SLEEP_ASLEEP or SLEEP_IN_BED
      try {
        final sleepTypes = [HealthDataType.SLEEP_ASLEEP];
        try {
          await _health.requestAuthorization(sleepTypes);
        } catch (_) {}

        final sleepData = await _health.getHealthDataFromTypes(
          startTime: yesterday,
          endTime: now,
          types: sleepTypes,
        );

        double totalSleepMin = 0;
        for (var data in sleepData) {
          try {
            final durationMin =
                data.dateTo.difference(data.dateFrom).inMinutes.toDouble();
            totalSleepMin += durationMin;
          } catch (_) {}
        }
        if (totalSleepMin > 0) {
          sleepHours = totalSleepMin / 60.0;
        }
      } catch (_) {}
    } catch (_) {
      // Ignore all health fetch errors
    }

    return {
      'hrv_ms': hrvMs,
      'sleep_hours': sleepHours,
      'resting_hr': restingHr,
    };
  }
}
