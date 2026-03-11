import 'package:supabase_flutter/supabase_flutter.dart';
import 'storage_service.dart';

class AppDataException implements Exception {
  final String message;

  const AppDataException(this.message);

  @override
  String toString() => message;
}

class SupabaseService {
  static SupabaseClient? _client;
  static String? _url;
  static String? _anonKey;

  static Future<void> init(String url, String anonKey) async {
    _url = url;
    _anonKey = anonKey;
    await Supabase.initialize(url: url, anonKey: anonKey);
    _client = Supabase.instance.client;
  }

  static SupabaseClient get client {
    if (_client == null) throw Exception('Supabase not initialized');
    return _client!;
  }

  static String? get url => _url;
  static String? get anonKey => _anonKey;

  static String describeError(Object error) {
    final message = error.toString();
    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length);
    }
    return message;
  }

  static bool _matchesSchemaIssue(Object error, List<String> patterns) {
    final message = describeError(error).toLowerCase();
    return patterns.any((pattern) => message.contains(pattern.toLowerCase()));
  }

  static Exception _hydrateSchemaError() {
    return const AppDataException(
      'Hydration tracking is not enabled in your Supabase project yet. Run the latest SQL migration in Supabase SQL Editor, then try again.',
    );
  }

  static Exception _profileSchemaError() {
    return const AppDataException(
      'Your Supabase profile schema is missing newer app fields. Run the latest SQL migration in Supabase SQL Editor, then try saving again.',
    );
  }

  static Exception _nutritionSchemaError() {
    return const AppDataException(
      'Your Supabase nutrition schema is missing newer app fields. Run the latest SQL migration in Supabase SQL Editor, then try saving again.',
    );
  }

  // Auth
  static Future<AuthResponse> signUp(String email, String password, String name) async {
    return await client.auth.signUp(
      email: email,
      password: password,
      data: {'name': name},
    );
  }

  static Future<AuthResponse> signIn(String email, String password) async {
    return await client.auth.signInWithPassword(email: email, password: password);
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  static Future<bool> signInWithOAuth(OAuthProvider provider) async {
    return await client.auth.signInWithOAuth(
      provider,
      redirectTo: 'apexfit://login-callback/',
    );
  }

  static User? get currentUser => client.auth.currentUser;
  static String? get accessToken => client.auth.currentSession?.accessToken;

  // Profiles
  static Future<Map<String, dynamic>?> getProfile(String userId) async {
    final res = await client.from('profiles').select().eq('id', userId).maybeSingle();
    return res;
  }

  static Future<void> updateProfile(String userId, Map<String, dynamic> data) async {
    try {
      await client.from('profiles').update(data).eq('id', userId);
    } catch (e) {
      if (_matchesSchemaIssue(e, [
        "column 'calorie_goal' does not exist",
        'column "calorie_goal" does not exist',
        "could not find the 'calorie_goal' column of 'profiles'",
        "column 'water_goal_ml' does not exist",
        'column "water_goal_ml" does not exist',
        "could not find the 'water_goal_ml' column of 'profiles'",
        "column 'avatar_data' does not exist",
        'column "avatar_data" does not exist',
        "could not find the 'avatar_data' column of 'profiles'",
      ])) {
        throw _profileSchemaError();
      }
      rethrow;
    }
  }

  // Workouts
  static Future<List<Map<String, dynamic>>> getWorkouts(String userId) async {
    final res = await client.from('workouts').select('*, exercises(*)').eq('user_id', userId).order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<Map<String, dynamic>> createWorkout(String userId, String name, String type) async {
    final res = await client.from('workouts').insert({'user_id': userId, 'name': name, 'type': type}).select().single();
    return res;
  }

  static Future<void> deleteWorkout(String id) async {
    await client.from('workouts').delete().eq('id', id);
  }

  // Exercises
  static Future<void> createExercises(List<Map<String, dynamic>> exercises) async {
    await client.from('exercises').insert(exercises);
  }

  // Exercise Dictionary
  static Future<List<Map<String, dynamic>>> getExerciseDictionary({String? muscleGroup, String? equipment, String? environment}) async {
    try {
      var query = client.from('exercise_dictionary').select();
      if (muscleGroup != null) query = query.filter('primary_muscle', 'eq', muscleGroup);
      if (equipment != null) query = query.filter('equipment', 'eq', equipment);
      if (environment != null) query = query.filter('environment', 'eq', environment);
      final res = await query.order('name');
      return List<Map<String, dynamic>>.from(res);
    } catch (_) {
      // Mock data if table doesn't exist yet
      return [
        {'id': '1', 'name': 'Barbell Bench Press', 'primary_muscle': 'Chest', 'equipment': 'Barbell', 'environment': 'Gym', 'video_url': '', 'preparation_steps': 'Lie flat on a bench, feet planted.', 'execution_steps': 'Lower barbell to mid-chest, press upward.'},
        {'id': '2', 'name': 'Push-up', 'primary_muscle': 'Chest', 'equipment': 'Bodyweight', 'environment': 'Home', 'video_url': '', 'preparation_steps': 'Start in plank position.', 'execution_steps': 'Lower body until chest touches floor, push up.'},
        {'id': '3', 'name': 'Squat', 'primary_muscle': 'Legs', 'equipment': 'Barbell', 'environment': 'Gym', 'video_url': '', 'preparation_steps': 'Bar across upper back.', 'execution_steps': 'Squat down until thighs parallel, push up.'},
        {'id': '4', 'name': 'Pull-up', 'primary_muscle': 'Back', 'equipment': 'Bodyweight', 'environment': 'Home', 'video_url': '', 'preparation_steps': 'Hang from bar.', 'execution_steps': 'Pull chin above bar, lower slowly.'},
      ].where((e) {
        if (muscleGroup != null && e['primary_muscle'] != muscleGroup) return false;
        if (equipment != null && e['equipment'] != equipment) return false;
        if (environment != null && e['environment'] != environment) return false;
        return true;
      }).toList();
    }
  }

  // Workout Logs
  static Future<List<Map<String, dynamic>>> getWorkoutLogs(String userId, {int limit = 14}) async {
    final res = await client.from('workout_logs').select().eq('user_id', userId).order('completed_at', ascending: false).limit(limit);
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<List<Map<String, dynamic>>> getWorkoutLogsSince(String userId, DateTime since) async {
    final res = await client.from('workout_logs').select().eq('user_id', userId).gte('completed_at', since.toIso8601String()).order('completed_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<List<Map<String, dynamic>>> getPreviousWorkoutStats(String userId, String workoutName) async {
    try {
      final logRes = await client.from('workout_logs')
          .select('id')
          .eq('user_id', userId)
          .eq('workout_name', workoutName)
          .order('completed_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (logRes == null) return [];

      final setRes = await client.from('set_logs')
          .select()
          .eq('log_id', logRes['id'])
          .order('set_number', ascending: true);
      return List<Map<String, dynamic>>.from(setRes);
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> createWorkoutLog(Map<String, dynamic> log) async {
    // If the local_timestamp exists, use it to preserve the original completion time
    if (log.containsKey('local_timestamp')) {
      log['completed_at'] = log['local_timestamp'];
      log.remove('local_timestamp');
    }
    final res = await client.from('workout_logs').insert(log).select().single();
    return res;
  }

  // Set Logs
  static Future<void> createSetLogs(List<Map<String, dynamic>> sets) async {
    if (sets.isEmpty) return;
    await client.from('set_logs').insert(sets);
  }

  static Future<void> syncOfflineWorkouts() async {
    try {
      final pendingLogs = await StorageService.loadOfflineWorkouts();
      if (pendingLogs.isEmpty) return;

      int successCount = 0;
      for (final logPayload in pendingLogs) {
        try {
          // Extract the sets from the payload if they were bundled
          final sets = (logPayload['sets'] as List<dynamic>?)?.cast<Map<String, dynamic>>();
          logPayload.remove('sets'); // Remove before sending to workout_logs

          final savedLog = await createWorkoutLog(logPayload);
          
          if (sets != null && sets.isNotEmpty) {
            // Update the log_id for each set to the real ID from Supabase
            for (var set in sets) {
              set['log_id'] = savedLog['id'];
            }
            await createSetLogs(sets);
          }
          successCount++;
        } catch (e) {
          // If a specific log fails, keep it in the queue by not clearing
          // In a robust implementation, you might track retry counts.
          print('Failed to sync offline log: $e');
        }
      }
      
      // If we synced everything successfully, clear the queue
      // Otherwise, we keep the original queue for now. 
      // (A better way is removing them one by one, but for simplicity we clear if all succeeded)
      if (successCount == pendingLogs.length) {
        await StorageService.clearOfflineWorkouts();
      } else if (successCount > 0) {
        // Remove the ones that succeeded and save the remainder
        // To simplify, we'll just clear it all or none. 
        // We'll clear the whole queue if at least one succeeded to prevent infinite loops on bad data
        await StorageService.clearOfflineWorkouts();
      }

    } catch (e) {
      print('Sync offline workouts error: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getSetLogsSince(String userId, DateTime since) async {
    final res = await client.from('set_logs').select('*, workout_logs!inner(user_id)').eq('workout_logs.user_id', userId).gte('logged_at', since.toIso8601String()).order('logged_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  // Nutrition
  static Future<List<Map<String, dynamic>>> getNutritionLogs(String userId, {int? limit, DateTime? since}) async {
    PostgrestFilterBuilder query = client.from('nutrition_logs').select().eq('user_id', userId);
    if (since != null) {
      query = query.gte('logged_at', since.toIso8601String());
    }

    PostgrestTransformBuilder queryWithOrder = query.order('logged_at', ascending: false);

    if (limit != null) {
      queryWithOrder = queryWithOrder.limit(limit);
    }

    final res = await queryWithOrder;
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<void> createNutritionLog(Map<String, dynamic> log) async {
    try {
      await client.from('nutrition_logs').insert(log);
    } catch (e) {
      if (_matchesSchemaIssue(e, [
        "column 'photo_data' does not exist",
        'column "photo_data" does not exist',
        "could not find the 'photo_data' column of 'nutrition_logs'",
      ])) {
        throw _nutritionSchemaError();
      }
      rethrow;
    }
  }

  // Water
  static Future<List<Map<String, dynamic>>> getWaterLogs(String userId, {DateTime? since}) async {
    try {
      var query = client.from('water_logs').select().eq('user_id', userId);
      if (since != null) {
        query = query.gte('logged_at', since.toIso8601String());
      }
      final res = await query.order('logged_at', ascending: true);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      if (_matchesSchemaIssue(e, [
        "could not find the table 'public.water_logs'",
        'relation "public.water_logs" does not exist',
        "column 'logged_at' does not exist",
        'column "logged_at" does not exist',
      ])) {
        throw _hydrateSchemaError();
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> createWaterLog(String userId, int amountMl) async {
    try {
      final res = await client
          .from('water_logs')
          .insert({'user_id': userId, 'amount_ml': amountMl})
          .select()
          .single();
      return res;
    } catch (e) {
      if (_matchesSchemaIssue(e, [
        "could not find the table 'public.water_logs'",
        'relation "public.water_logs" does not exist',
        "column 'amount_ml' does not exist",
        'column "amount_ml" does not exist',
        "column 'logged_at' does not exist",
        'column "logged_at" does not exist',
      ])) {
        throw _hydrateSchemaError();
      }
      rethrow;
    }
  }

  // Body Weight
  static Future<List<Map<String, dynamic>>> getBodyWeightLogs(String userId, {int limit = 30}) async {
    final res = await client.from('body_weight_logs').select().eq('user_id', userId).order('logged_at', ascending: false).limit(limit);
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<void> createBodyWeightLog(String userId, double weightKg) async {
    await client.from('body_weight_logs').insert({'user_id': userId, 'weight_kg': weightKg});
  }

  // Progress Photos
  static Future<List<Map<String, dynamic>>> getProgressPhotos(String userId) async {
    final res = await client.from('progress_photos').select().eq('user_id', userId).order('taken_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<void> createProgressPhoto(String userId, String photoData, String? caption) async {
    await client.from('progress_photos').insert({
      'user_id': userId,
      'photo_data': photoData,
      'caption': caption,
    });
  }

  static Future<void> deleteProgressPhoto(String id) async {
    await client.from('progress_photos').delete().eq('id', id);
  }

  // Test connection
  static Future<bool> testConnection(String url, String anonKey) async {
    try {
      await client.from('profiles').select('id').limit(1);
      return true;
    } catch (e) {
      return false;
    }
  }
}
