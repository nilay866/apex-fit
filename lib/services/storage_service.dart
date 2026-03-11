import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class StorageService {
  static const _cfgKey = 'apexcfg_v4';
  static const _ssKey = 'apex_session_v4';

  static Future<void> saveConfig({
    required String url,
    required String key,
    required String aiKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cfgKey, jsonEncode({'url': url, 'key': key, 'aiKey': aiKey}));
  }

  static Future<Map<String, dynamic>?> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_cfgKey);
    if (s == null) return null;
    return jsonDecode(s) as Map<String, dynamic>;
  }

  static Future<void> saveSession({
    required Map<String, dynamic> user,
    required String token,
    String? refreshToken,
    required String name,
    required String goal,
    Map<String, dynamic>? profile,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ssKey, jsonEncode({
      'user': user,
      'token': token,
      'refreshToken': refreshToken,
      'name': name,
      'goal': goal,
      'profile': profile ?? {},
      'savedAt': DateTime.now().millisecondsSinceEpoch,
    }));
  }

  static Future<Map<String, dynamic>?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_ssKey);
    if (s == null) return null;
    return jsonDecode(s) as Map<String, dynamic>;
  }

  static const _offlineLogsKey = 'apex_offline_workouts_v1';

  static Future<void> saveOfflineWorkout(Map<String, dynamic> workoutPayload) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_offlineLogsKey);
    List<dynamic> logs = [];
    if (existing != null) {
      logs = jsonDecode(existing) as List<dynamic>;
    }
    // Add timestamp to log when it was completed locally
    workoutPayload['local_timestamp'] = DateTime.now().toIso8601String();
    logs.add(workoutPayload);
    await prefs.setString(_offlineLogsKey, jsonEncode(logs));
  }

  static Future<List<Map<String, dynamic>>> loadOfflineWorkouts() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_offlineLogsKey);
    if (existing == null) return [];
    final logs = jsonDecode(existing) as List<dynamic>;
    return logs.map((e) => e as Map<String, dynamic>).toList();
  }

  static Future<void> clearOfflineWorkouts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_offlineLogsKey);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cfgKey);
    await prefs.remove(_ssKey);
    await prefs.remove(_offlineLogsKey);
  }
}
