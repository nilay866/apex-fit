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
}
