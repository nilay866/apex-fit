import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';

class StorageService {
  static const _cfgKey = 'apexcfg_v4';
  static const _ssKey = 'apex_session_v4';
  static const _offlineActionsKey = 'apex_offline_actions_v1';

  static Future<void> saveConfig({
    required String url,
    required String key,
    required String aiKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cfgKey,
      jsonEncode({'url': url, 'key': key, 'aiKey': aiKey}),
    );
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
    await prefs.setString(
      _ssKey,
      jsonEncode({
        'user': user,
        'token': token,
        'refreshToken': refreshToken,
        'name': name,
        'goal': goal,
        'profile': profile ?? {},
        'savedAt': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  }

  static Future<Map<String, dynamic>?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_ssKey);
    if (s == null) return null;
    return jsonDecode(s) as Map<String, dynamic>;
  }

  static const _offlineLogsKey = 'apex_offline_workouts_v1';

  static Future<void> saveOfflineWorkout(
    Map<String, dynamic> workoutPayload,
  ) async {
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

  static Future<void> replaceOfflineWorkouts(
    List<Map<String, dynamic>> workouts,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    if (workouts.isEmpty) {
      await prefs.remove(_offlineLogsKey);
      return;
    }
    await prefs.setString(_offlineLogsKey, jsonEncode(workouts));
  }

  static Future<void> enqueueOfflineAction(Map<String, dynamic> action) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_offlineActionsKey);
    final actions = existing == null
        ? <dynamic>[]
        : jsonDecode(existing) as List<dynamic>;
    actions.add({...action, 'queued_at': DateTime.now().toIso8601String()});
    await prefs.setString(_offlineActionsKey, jsonEncode(actions));
  }

  static Future<List<Map<String, dynamic>>> loadOfflineActions() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_offlineActionsKey);
    if (existing == null) return [];
    final actions = jsonDecode(existing) as List<dynamic>;
    return actions.cast<Map<String, dynamic>>();
  }

  static Future<void> replaceOfflineActions(
    List<Map<String, dynamic>> actions,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    if (actions.isEmpty) {
      await prefs.remove(_offlineActionsKey);
      return;
    }
    await prefs.setString(_offlineActionsKey, jsonEncode(actions));
  }

  static const _activeWorkoutKey = 'apex_active_workout_v1';
  static const _awsCfgKey = 'apex_aws_v1';
  static const _aiProviderKey = 'apex_ai_provider_v1';
  static const _exerciseApiKey = 'apex_exercise_api_key_v1';

  static Future<void> saveAWSConfig({
    required String accessKey,
    required String secretKey,
    required String region,
    String? modelId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _awsCfgKey,
      jsonEncode({
        'accessKey': accessKey,
        'secretKey': secretKey,
        'region': region,
        'modelId': modelId ?? 'anthropic.claude-3-haiku-20240307-v1:0',
      }),
    );
  }

  static Future<Map<String, dynamic>?> loadAWSConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_awsCfgKey);
    if (s == null) return null;
    return jsonDecode(s) as Map<String, dynamic>;
  }

  static Future<void> saveAIProvider(String provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_aiProviderKey, provider);
  }

  static Future<String> loadAIProvider() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_aiProviderKey) ?? 'bedrock';
  }

  static Future<void> saveExerciseApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(_exerciseApiKey);
      return;
    }
    await prefs.setString(_exerciseApiKey, trimmed);
  }

  static Future<String> loadExerciseApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_exerciseApiKey) ?? '';
  }

  static Future<void> saveActiveWorkoutState(Map<String, dynamic> state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeWorkoutKey, jsonEncode(state));
  }

  static Future<Map<String, dynamic>?> loadActiveWorkoutState() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_activeWorkoutKey);
    if (s == null) return null;
    return jsonDecode(s) as Map<String, dynamic>;
  }

  static Future<void> clearActiveWorkoutState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeWorkoutKey);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cfgKey);
    await prefs.remove(_ssKey);
    await prefs.remove(_offlineLogsKey);
    await prefs.remove(_activeWorkoutKey);
    await prefs.remove(_awsCfgKey);
    await prefs.remove(_aiProviderKey);
    await prefs.remove(_exerciseApiKey);
    await prefs.remove(_offlineActionsKey);
  }
}
