import 'dart:async';

/// A singleton orchestration layer for high-speed data persistence.
/// Designed for "Netflix-grade" zero-latency transitions.
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  // Primary memory stores
  final Map<String, dynamic> _dataStore = {};
  
  // Stream controllers for real-time delta updates
  final _updateController = StreamController<String>.broadcast();
  Stream<String> get onUpdate => _updateController.stream;

  /// Retrieves a cached object instantly.
  T? get<T>(String key) {
    return _dataStore[key] as T?;
  }

  /// Persists an object to memory and broadcasts the update.
  void set(String key, dynamic value) {
    if (_dataStore[key] == value) return; // Ignore identical updates
    _dataStore[key] = value;
    _updateController.add(key);
  }

  /// Specific helper for list-based data (Social Feed, Logs)
  void setList(String key, List<Map<String, dynamic>> list) {
    set(key, List<Map<String, dynamic>>.from(list));
  }

  /// Evicts a specific key or clears the entire cache.
  void invalidate(String? key) {
    if (key != null) {
      _dataStore.remove(key);
    } else {
      _dataStore.clear();
    }
  }

  // Common Key Constants
  static const String keyHomeLogs = 'home_logs';
  static const String keyHomeWorkouts = 'home_workouts';
  static const String keySocialFeed = 'social_feed';
  static const String keyProfile = 'user_profile';
  static const String keyWaterLogs = 'water_logs_today';
  static const String keyNutritionLogs = 'nutrition_logs_today';
}

/// Global accessor for the CacheService singleton.
final cache = CacheService();
