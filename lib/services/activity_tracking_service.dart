import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// GPS activity tracking service with start/stop/pause,
/// distance calculation, split tracking, and offline GPS point storage.
class ActivityTrackingService {
  static const String _offlineKey = 'apex_offline_gps_v1';

  // ── MET values for calorie estimation ──────────────────────────────────
  static const Map<String, double> _metValues = {
    'run': 9.8,
    'walk': 3.8,
    'cycle': 7.5,
    'hike': 6.0,
    'row': 7.0,
  };

  /// Estimate calories using MET formula: kcal = MET × weight_kg × hours
  static double estimateCalories({
    required String activityType,
    required double weightKg,
    required int durationSeconds,
  }) {
    final met = _metValues[activityType] ?? 5.0;
    final hours = durationSeconds / 3600;
    return met * weightKg * hours;
  }

  /// Calculate distance between two GPS points in meters
  static double distanceBetween(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }

  /// Calculate elevation gain/loss from a list of elevation readings
  static Map<String, double> calculateElevation(List<double?> elevations) {
    double gain = 0;
    double loss = 0;
    double? prev;

    for (final e in elevations) {
      if (e == null) continue;
      if (prev != null) {
        final diff = e - prev;
        if (diff > 0.5) {
          gain += diff;
        } else if (diff < -0.5) {
          loss += diff.abs();
        }
      }
      prev = e;
    }
    return {'gain': gain, 'loss': loss};
  }

  /// Calculate pace (min/km) from distance and duration
  static double calculatePace(double distanceKm, int durationSeconds) {
    if (distanceKm < 0.01) return 0;
    return (durationSeconds / 60) / distanceKm;
  }

  /// Format pace as mm:ss string
  static String formatPace(double paceMinPerKm) {
    if (paceMinPerKm <= 0 || paceMinPerKm > 60) return '--:--';
    final m = paceMinPerKm.floor();
    final s = ((paceMinPerKm - m) * 60).floor();
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Format seconds as HH:MM:SS
  static String formatDuration(int seconds) =>
      '${(seconds ~/ 3600).toString().padLeft(2, '0')}:'
      '${((seconds % 3600) ~/ 60).toString().padLeft(2, '0')}:'
      '${(seconds % 60).toString().padLeft(2, '0')}';

  /// Auto-detect activity type from average speed (m/s)
  static String detectActivityType(double avgSpeedMs) {
    final kmh = avgSpeedMs * 3.6;
    if (kmh > 25) return 'cycle';
    if (kmh > 8) return 'run';
    if (kmh > 3) return 'walk';
    return 'walk';
  }

  /// Build splits data from route + timestamps
  static List<Map<String, dynamic>> buildSplits(
    List<Map<String, dynamic>> gpsPoints,
  ) {
    if (gpsPoints.length < 2) return [];

    final splits = <Map<String, dynamic>>[];
    double accumDist = 0;
    int splitKm = 1;
    int splitStartIdx = 0;

    for (int i = 1; i < gpsPoints.length; i++) {
      final prev = gpsPoints[i - 1];
      final curr = gpsPoints[i];
      accumDist += distanceBetween(
        (prev['lat'] as num).toDouble(),
        (prev['lng'] as num).toDouble(),
        (curr['lat'] as num).toDouble(),
        (curr['lng'] as num).toDouble(),
      );

      if (accumDist / 1000 >= splitKm) {
        final startTime =
            DateTime.tryParse(gpsPoints[splitStartIdx]['recorded_at'] ?? '');
        final endTime = DateTime.tryParse(curr['recorded_at'] ?? '');
        final splitDuration =
            (startTime != null && endTime != null)
                ? endTime.difference(startTime).inSeconds
                : 0;

        splits.add({
          'km': splitKm,
          'duration_seconds': splitDuration,
          'pace': calculatePace(1.0, splitDuration),
        });

        splitKm++;
        splitStartIdx = i;
      }
    }
    return splits;
  }

  // ── Offline GPS queue ──────────────────────────────────────────────────

  /// Store GPS points locally when offline
  static Future<void> saveOfflineGpsPoints(
    String localActivityId,
    List<Map<String, dynamic>> points,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString(_offlineKey);
      final queue = existing != null
          ? Map<String, dynamic>.from(jsonDecode(existing) as Map)
          : <String, dynamic>{};
      queue[localActivityId] = points;
      await prefs.setString(_offlineKey, jsonEncode(queue));
    } catch (_) {}
  }

  /// Load all offline GPS queues
  static Future<Map<String, List<Map<String, dynamic>>>>
      loadOfflineGpsPoints() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString(_offlineKey);
      if (existing == null) return {};
      final raw = Map<String, dynamic>.from(jsonDecode(existing) as Map);
      return raw.map(
        (k, v) => MapEntry(
          k,
          (v as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
        ),
      );
    } catch (_) {
      return {};
    }
  }

  /// Clear offline GPS queue after successful sync
  static Future<void> clearOfflineGpsPoints() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_offlineKey);
    } catch (_) {}
  }
}
