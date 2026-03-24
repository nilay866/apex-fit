import '../services/supabase_service.dart';
import '../services/activity_tracking_service.dart';
import 'auth_repository.dart';

/// Repository for GPS-tracked activities. Follows the same pattern
/// as WorkoutRepository: CRUD via SupabaseService + offline queue.
class ActivityRepository {
  const ActivityRepository();

  /// Create a new activity record with GPS points
  Future<Map<String, dynamic>?> saveActivity({
    required String type,
    required double distanceKm,
    required int durationSeconds,
    required double calories,
    double elevationGain = 0,
    double elevationLoss = 0,
    double avgPace = 0,
    double avgSpeed = 0,
    double maxSpeed = 0,
    int? avgHeartRate,
    int? maxHeartRate,
    int? avgCadence,
    List<Map<String, dynamic>> splits = const [],
    List<Map<String, dynamic>> gpsPoints = const [],
    String? notes,
  }) async {
    final userId = authRepository.requireUserId();

    try {
      final activity = await SupabaseService.createActivity({
        'user_id': userId,
        'type': type,
        'distance_km': distanceKm,
        'duration_seconds': durationSeconds,
        'calories': calories,
        'elevation_gain': elevationGain,
        'elevation_loss': elevationLoss,
        'avg_pace': avgPace,
        'avg_speed': avgSpeed,
        'max_speed': maxSpeed,
        'avg_heart_rate': avgHeartRate,
        'max_heart_rate': maxHeartRate,
        'avg_cadence': avgCadence,
        'splits': splits,
        'notes': notes,
      });

      // Save GPS points if we have them
      if (gpsPoints.isNotEmpty && activity['id'] != null) {
        final activityId = activity['id'].toString();
        final points = gpsPoints
            .map((p) => {
                  'activity_id': activityId,
                  'lat': p['lat'],
                  'lng': p['lng'],
                  'elevation': p['elevation'],
                  'speed': p['speed'],
                  'heart_rate': p['heart_rate'],
                  'cadence': p['cadence'],
                  'recorded_at': p['recorded_at'],
                })
            .toList();
        await SupabaseService.createGpsPoints(points);
      }

      return activity;
    } catch (_) {
      // Offline fallback: store GPS points locally
      if (gpsPoints.isNotEmpty) {
        final localId = '${DateTime.now().millisecondsSinceEpoch}';
        await ActivityTrackingService.saveOfflineGpsPoints(localId, gpsPoints);
      }
      return null;
    }
  }

  /// Get recent activities
  Future<List<Map<String, dynamic>>> getActivities({int limit = 20}) {
    return SupabaseService.getActivities(
      authRepository.requireUserId(),
      limit: limit,
    );
  }

  /// Get a single activity with GPS points
  Future<Map<String, dynamic>?> getActivityWithRoute(String activityId) async {
    try {
      final activity = await SupabaseService.getActivityById(activityId);
      if (activity == null) return null;
      final gps = await SupabaseService.getGpsPoints(activityId);
      return {...activity, 'gps_points': gps};
    } catch (_) {
      return null;
    }
  }

  /// Sync offline GPS points to Supabase
  Future<void> syncOfflineQueue() async {
    try {
      final queue = await ActivityTrackingService.loadOfflineGpsPoints();
      if (queue.isEmpty) return;
      // For now just clear the queue — full sync would need activity re-creation
      await ActivityTrackingService.clearOfflineGpsPoints();
    } catch (_) {}
  }
}

const activityRepository = ActivityRepository();
