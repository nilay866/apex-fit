import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart' as google_auth;
import 'local_exercise_catalog_service.dart';
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
    if (_client == null) {
      throw const AppDataException(
        'Supabase is not initialized yet. Please restart the app.',
      );
    }
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

  static Exception _exerciseSchemaError() {
    return const AppDataException(
      'Your Supabase workout exercise schema is outdated. Run the latest SQL migration in Supabase SQL Editor so reps and target weights can be saved correctly.',
    );
  }

  // --- RELIABILITY ENGINE (Phase 14) ---

  /// Executes a function with exponential backoff retries.
  static Future<T> _retry<T>(
    Future<T> Function() action, {
    int maxRetries = 3,
  }) async {
    int attempt = 0;
    while (true) {
      try {
        return await action();
      } catch (e) {
        attempt++;
        if (attempt >= maxRetries || !_isRetryable(e)) rethrow;

        final delay = Duration(milliseconds: 500 * (1 << (attempt - 1)));
        await Future.delayed(delay);
      }
    }
  }

  static bool _isRetryable(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('network') ||
        msg.contains('timeout') ||
        msg.contains('connection') ||
        msg.contains('socket') ||
        msg.contains('failed to connect');
  }

  // Auth
  static Future<AuthResponse> signUp(
    String email,
    String password,
    String name,
  ) async {
    return _retry(
      () => client.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      ),
    );
  }

  static Future<AuthResponse> signIn(String email, String password) async {
    return _retry(
      () => client.auth.signInWithPassword(email: email, password: password),
    );
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  static Future<bool> signInWithOAuth(OAuthProvider provider) async {
    if (provider == OAuthProvider.google) {
      return _signInWithGoogle();
    }
    
    return _retry(
      () => client.auth.signInWithOAuth(
        provider,
        redirectTo: 'apexfit://login-callback/',
      ),
    );
  }

  static Future<bool> _signInWithGoogle() async {
    try {
      const webClientId = '789994193512-7lehqbflkrhtean4hnogd9c3pht9fdmj.apps.googleusercontent.com';
      // Use the iOS specific client ID for native iOS login flow
      const iosClientId = '789994193512-961jfnsk3nr116h58mpjt6s4uvu65fud.apps.googleusercontent.com';

      try {
        await google_auth.GoogleSignIn.instance.initialize(
          clientId: iosClientId,
          serverClientId: webClientId,
        );
      } catch (_) {
        // Safe to ignore if already initialized.
      }
      
      // Native sign in flow (do NOT retry this, as it opens a modal overlay)
      final googleUser = await google_auth.GoogleSignIn.instance.authenticate();
      
      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;
      
      final googleAuthz = await googleUser.authorizationClient.authorizationForScopes(['email', 'profile']);
      final accessToken = googleAuthz?.accessToken;
      
      if (idToken == null) {
        throw const AppDataException('Missing Google Auth Tokens (idToken is null)');
      }
      
      await _retry(() => client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      ));
      
      return true;
    } catch (e) {
      if (e is AppDataException) rethrow;
      throw AppDataException('Google Login Error: ${describeError(e)}');
    }
  }

  static User? get currentUser => client.auth.currentUser;
  static String? get accessToken => client.auth.currentSession?.accessToken;

  static String requireUserId({String action = 'continue'}) {
    final userId = currentUser?.id;
    if (userId == null) {
      throw AppDataException('Your session ended. Sign in again to $action.');
    }
    return userId;
  }

  // Profiles
  static Future<Map<String, dynamic>?> getProfile(String userId) async {
    return _retry(
      () => client.from('profiles').select().eq('id', userId).maybeSingle(),
    );
  }

  static Future<void> updateProfile(
    String userId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _retry(() => client.from('profiles').update(data).eq('id', userId));
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
    try {
      final res = await _retry(
        () => client
            .from('workouts')
            .select('*, exercises(*)')
            .eq('user_id', userId)
            .order('created_at', ascending: false),
      );
      if ((res as List).isNotEmpty) return List<Map<String, dynamic>>.from(res);
      throw Exception('Empty database');
    } catch (_) {
      return [
        {
          'id': 'mock_run_1',
          'name': 'Outdoor Run',
          'type': 'run',
          'exercises': [],
          'created_at': DateTime.now().toIso8601String(),
        },
        {
          'id': 'mock_hiit_1',
          'name': 'HIIT Bodyweight Circuit',
          'type': 'hiit',
          'exercises': [
            {'name': 'Jumping Jacks', 'sets': 3, 'reps': '45s'},
            {'name': 'Burpees', 'sets': 3, 'reps': '30s'},
            {'name': 'Mountain Climbers', 'sets': 3, 'reps': '45s'},
          ],
          'created_at': DateTime.now().toIso8601String(),
        },
        {
          'id': 'mock_gym_1',
          'name': 'Full Body Hypertrophy',
          'type': 'Gym',
          'exercises': [
            {'name': 'Barbell Squat', 'sets': 3, 'reps': '10'},
            {'name': 'Bench Press', 'sets': 3, 'reps': '10'},
            {'name': 'Deadlift', 'sets': 3, 'reps': '8'},
          ],
          'created_at': DateTime.now().toIso8601String(),
        },
      ];
    }
  }

  static Future<Map<String, dynamic>> createWorkout(
    String userId,
    String name,
    String type,
  ) async {
    final res = await _retry(
      () => client
          .from('workouts')
          .insert({'user_id': userId, 'name': name, 'type': type})
          .select()
          .single(),
    );
    return res;
  }

  static Future<void> deleteWorkout(String id) async {
    await _retry(() => client.from('workouts').delete().eq('id', id));
  }

  // ─── Routine Templates ──────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getRoutines(String userId) async {
    try {
      final res = await _retry(
        () => client
            .from('routine_templates')
            .select('*, routine_exercises(*)')
            .eq('user_id', userId)
            .order('created_at', ascending: false),
      );
      return List<Map<String, dynamic>>.from(res);
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> createRoutine(
    String userId,
    String name, {
    String folder = 'General',
  }) async {
    final res = await _retry(
      () => client
          .from('routine_templates')
          .insert({'user_id': userId, 'name': name, 'folder': folder})
          .select()
          .single(),
    );
    return res;
  }

  static Future<void> deleteRoutine(String routineId) async {
    await _retry(
      () => client.from('routine_templates').delete().eq('id', routineId),
    );
  }

  static Future<List<Map<String, dynamic>>> getRoutineExercises(
    String routineId,
  ) async {
    try {
      final res = await _retry(
        () => client
            .from('routine_exercises')
            .select()
            .eq('routine_id', routineId)
            .order('sort_order'),
      );
      return List<Map<String, dynamic>>.from(res);
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveRoutineExercises(
    String routineId,
    List<Map<String, dynamic>> exercises,
  ) async {
    // Delete existing exercises for this routine, then re-insert
    await _retry(
      () =>
          client.from('routine_exercises').delete().eq('routine_id', routineId),
    );
    if (exercises.isEmpty) return;
    final toInsert = exercises
        .asMap()
        .entries
        .map(
          (e) => {
            'routine_id': routineId,
            'exercise_name': e.value['exercise_name'],
            'sets': e.value['sets'] ?? 3,
            'reps': e.value['reps'] ?? '8-12',
            'rest_seconds': e.value['rest_seconds'] ?? 90,
            'sort_order': e.key,
          },
        )
        .toList();
    await _retry(() => client.from('routine_exercises').insert(toInsert));
  }

  // Exercises
  static Future<bool> createExercises(
    List<Map<String, dynamic>> exercises,
  ) async {
    if (exercises.isEmpty) return false;
    return _insertExercisesWithFallback(exercises);
  }

  static Future<bool> _insertExercisesWithFallback(
    List<Map<String, dynamic>> exercises, {
    Set<String> omittedColumns = const {},
  }) async {
    final payload = exercises.map((exercise) {
      final next = Map<String, dynamic>.from(exercise);
      for (final column in omittedColumns) {
        next.remove(column);
      }
      return next;
    }).toList();

    try {
      await _retry(() => client.from('exercises').insert(payload));
      return omittedColumns.isNotEmpty;
    } catch (e) {
      final nextOmittedColumns = {...omittedColumns};

      if (_matchesSchemaIssue(e, [
        "could not find the 'reps' column of 'exercises'",
        "column 'reps' does not exist",
        'column "reps" does not exist',
      ])) {
        nextOmittedColumns.add('reps');
      }

      if (_matchesSchemaIssue(e, [
        "could not find the 'target_weight' column of 'exercises'",
        "column 'target_weight' does not exist",
        'column "target_weight" does not exist',
      ])) {
        nextOmittedColumns.add('target_weight');
      }

      if (nextOmittedColumns.length > omittedColumns.length) {
        return _insertExercisesWithFallback(
          exercises,
          omittedColumns: nextOmittedColumns,
        );
      }

      if (_matchesSchemaIssue(e, [
        "could not find the 'workout_id' column of 'exercises'",
        "could not find the 'name' column of 'exercises'",
        "could not find the 'sets' column of 'exercises'",
        "could not find the 'reps' column of 'exercises'",
        "could not find the 'target_weight' column of 'exercises'",
        "column 'workout_id' does not exist",
        "column 'name' does not exist",
        "column 'sets' does not exist",
        "column 'reps' does not exist",
        "column 'target_weight' does not exist",
        'column "workout_id" does not exist',
        'column "name" does not exist',
        'column "sets" does not exist',
        'column "reps" does not exist',
        'column "target_weight" does not exist',
      ])) {
        throw _exerciseSchemaError();
      }

      rethrow;
    }
  }

  // Exercise Dictionary
  static Future<List<Map<String, dynamic>>> getExerciseDictionary({
    String? muscleGroup,
    String? equipment,
    String? environment,
  }) async {
    try {
      var query = client.from('exercise_dictionary').select();
      if (muscleGroup != null) {
        query = query.filter('primary_muscle', 'eq', muscleGroup);
      }
      if (equipment != null) query = query.filter('equipment', 'eq', equipment);
      if (environment != null) {
        query = query.filter('environment', 'eq', environment);
      }
      final res = await _retry(() => query.order('name'));
      return List<Map<String, dynamic>>.from(res);
    } catch (_) {
      // Mock data if table doesn't exist yet
      return [
        {
          'id': '1',
          'name': 'Barbell Bench Press',
          'primary_muscle': 'Chest',
          'equipment': 'Barbell',
          'environment': 'Gym',
          'video_url': '',
          'preparation_steps': 'Lie flat on a bench, feet planted.',
          'execution_steps': 'Lower barbell to mid-chest, press upward.',
        },
        {
          'id': '2',
          'name': 'Push-up',
          'primary_muscle': 'Chest',
          'equipment': 'Bodyweight',
          'environment': 'Home',
          'video_url': '',
          'preparation_steps': 'Start in plank position.',
          'execution_steps': 'Lower body until chest touches floor, push up.',
        },
        {
          'id': '3',
          'name': 'Squat',
          'primary_muscle': 'Legs',
          'equipment': 'Barbell',
          'environment': 'Gym',
          'video_url': '',
          'preparation_steps': 'Bar across upper back.',
          'execution_steps': 'Squat down until thighs parallel, push up.',
        },
        {
          'id': '4',
          'name': 'Pull-up',
          'primary_muscle': 'Back',
          'equipment': 'Bodyweight',
          'environment': 'Home',
          'video_url': '',
          'preparation_steps': 'Hang from bar.',
          'execution_steps': 'Pull chin above bar, lower slowly.',
        },
      ].where((e) {
        if (muscleGroup != null && e['primary_muscle'] != muscleGroup) {
          return false;
        }
        if (equipment != null && e['equipment'] != equipment) return false;
        if (environment != null && e['environment'] != environment) {
          return false;
        }
        return true;
      }).toList();
    }
  }

  // Workout Logs
  static Future<List<Map<String, dynamic>>> getWorkoutLogs(
    String userId, {
    int limit = 14,
  }) async {
    final res = await _retry(
      () => client
          .from('workout_logs')
          .select()
          .eq('user_id', userId)
          .order('completed_at', ascending: false)
          .limit(limit),
    );
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<List<Map<String, dynamic>>> getWorkoutLogsSince(
    String userId,
    DateTime since,
  ) async {
    final res = await _retry(
      () => client
          .from('workout_logs')
          .select()
          .eq('user_id', userId)
          .gte('completed_at', since.toIso8601String())
          .order('completed_at', ascending: false),
    );
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<List<Map<String, dynamic>>> getPreviousWorkoutStats(
    String userId,
    String workoutName,
  ) async {
    try {
      final logRes = await _retry(
        () => client
            .from('workout_logs')
            .select('id')
            .eq('user_id', userId)
            .eq('workout_name', workoutName)
            .order('completed_at', ascending: false)
            .limit(1)
            .maybeSingle(),
      );
      if (logRes == null) return [];

      final setRes = await _retry(
        () => client
            .from('set_logs')
            .select()
            .eq('log_id', logRes['id'])
            .order('set_number', ascending: true),
      );
      return List<Map<String, dynamic>>.from(setRes);
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> createWorkoutLog(
    Map<String, dynamic> log,
  ) async {
    // If the local_timestamp exists, use it to preserve the original completion time
    if (log.containsKey('local_timestamp')) {
      log['completed_at'] = log['local_timestamp'];
      log.remove('local_timestamp');
    }
    final res = await _retry(
      () => client.from('workout_logs').insert(log).select().single(),
    );
    return res;
  }

  static Future<void> deleteWorkoutLog(String id) async {
    await _retry(() => client.from('workout_logs').delete().eq('id', id));
  }

  // Set Logs
  static Future<void> createSetLogs(List<Map<String, dynamic>> sets) async {
    if (sets.isEmpty) return;
    await _retry(() => client.from('set_logs').insert(sets));
  }

  static Future<void> syncOfflineWorkouts() async {
    try {
      final pendingLogs = await StorageService.loadOfflineWorkouts();
      if (pendingLogs.isEmpty) return;

      final failedLogs = <Map<String, dynamic>>[];
      for (final logPayload in pendingLogs) {
        try {
          final mutablePayload = Map<String, dynamic>.from(logPayload);
          // Extract the sets from the payload if they were bundled
          final sets = (mutablePayload['sets'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>();
          mutablePayload.remove(
            'sets',
          ); // Remove before sending to workout_logs

          final savedLog = await createWorkoutLog(mutablePayload);

          if (sets != null && sets.isNotEmpty) {
            // Update the log_id for each set to the real ID from Supabase
            for (var set in sets) {
              set['log_id'] = savedLog['id'];
            }
            try {
              await createSetLogs(sets);
            } catch (error) {
              await deleteWorkoutLog(savedLog['id'] as String);
              rethrow;
            }
          }
        } catch (e) {
          failedLogs.add(Map<String, dynamic>.from(logPayload));
        }
      }

      await StorageService.replaceOfflineWorkouts(failedLogs);
    } catch (e) {
      // Sync offline workouts error
    }
  }

  static Future<List<Map<String, dynamic>>> getSetLogsSince(
    String userId,
    DateTime since,
  ) async {
    final res = await _retry(
      () => client
          .from('set_logs')
          .select('*, workout_logs!inner(user_id)')
          .eq('workout_logs.user_id', userId)
          .gte('logged_at', since.toIso8601String())
          .order('logged_at', ascending: false),
    );
    return List<Map<String, dynamic>>.from(res);
  }

  // Nutrition
  static Future<List<Map<String, dynamic>>> getNutritionLogs(
    String userId, {
    int? limit,
    DateTime? since,
  }) async {
    PostgrestFilterBuilder query = client
        .from('nutrition_logs')
        .select()
        .eq('user_id', userId);
    if (since != null) {
      query = query.gte('logged_at', since.toIso8601String());
    }

    PostgrestTransformBuilder queryWithOrder = query.order(
      'logged_at',
      ascending: false,
    );

    if (limit != null) {
      queryWithOrder = queryWithOrder.limit(limit);
    }

    final res = await _retry(() => queryWithOrder);
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<void> createNutritionLog(Map<String, dynamic> log) async {
    try {
      await _retry(() => client.from('nutrition_logs').insert(log));
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
  static Future<List<Map<String, dynamic>>> getWaterLogs(
    String userId, {
    DateTime? since,
  }) async {
    try {
      var query = client.from('water_logs').select().eq('user_id', userId);
      if (since != null) {
        query = query.gte('logged_at', since.toIso8601String());
      }
      final res = await _retry(() => query.order('logged_at', ascending: true));
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

  static Future<Map<String, dynamic>> createWaterLog(
    String userId,
    int amountMl,
  ) async {
    try {
      final res = await _retry(
        () => client
            .from('water_logs')
            .insert({'user_id': userId, 'amount_ml': amountMl})
            .select()
            .single(),
      );
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
  static Future<List<Map<String, dynamic>>> getBodyWeightLogs(
    String userId, {
    int limit = 30,
  }) async {
    final res = await _retry(
      () => client
          .from('body_weight_logs')
          .select()
          .eq('user_id', userId)
          .order('logged_at', ascending: false)
          .limit(limit),
    );
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<void> createBodyWeightLog(
    String userId,
    double weightKg,
  ) async {
    await _retry(
      () => client.from('body_weight_logs').insert({
        'user_id': userId,
        'weight_kg': weightKg,
      }),
    );
  }

  // Progress Photos
  static Future<List<Map<String, dynamic>>> getProgressPhotos(
    String userId,
  ) async {
    final res = await _retry(
      () => client
          .from('progress_photos')
          .select()
          .eq('user_id', userId)
          .order('taken_at', ascending: false),
    );
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<void> createProgressPhoto(
    String userId,
    String photoData,
    String? caption,
  ) async {
    await _retry(
      () => client.from('progress_photos').insert({
        'user_id': userId,
        'photo_data': photoData,
        'caption': caption,
      }),
    );
  }

  static Future<void> deleteProgressPhoto(String id) async {
    await _retry(() => client.from('progress_photos').delete().eq('id', id));
  }

  // --- EXERCISE INTELLIGENCE SYSTEM (Phase 13) ---

  /// Fetches normalized exercises with optional filters.
  static Future<List<Map<String, dynamic>>> getExercises({
    String? muscle,
    String? equipment,
    String? environment,
    String? taxonomy,
  }) async {
    final localCatalog = await LocalExerciseCatalogService.getExercises(
      muscle: muscle,
      equipment: equipment,
      environment: environment,
      taxonomy: taxonomy,
    );

    try {
      var query = client.from('exercises').select('*, muscle_heatmap(*)');

      if (muscle != null) query = query.eq('primary_muscle', muscle);
      if (equipment != null) query = query.eq('equipment', equipment);
      if (environment != null) query = query.eq('environment', environment);
      if (taxonomy != null) {
        // SEC-FIX: Escape LIKE wildcards to prevent filter bypass injection
        final escaped = taxonomy.replaceAll('%', r'\%').replaceAll('_', r'\_');
        query = query.ilike('taxonomy_folder', '%$escaped%');
      }

      final res = await _retry(() => query.order('name'));
      if ((res as List).isNotEmpty || localCatalog.isNotEmpty) {
        return _mergeExerciseCatalogs(
          localCatalog,
          List<Map<String, dynamic>>.from(res),
        );
      }
      throw Exception('Empty database');
    } catch (_) {
      if (localCatalog.isNotEmpty) {
        return localCatalog;
      }
      // Comprehensive mock data — 50+ exercises, all muscle groups, Home + Gym
      final List<Map<String, dynamic>> mock = [
        // ─── CHEST — GYM ──────────────────────────────────────────────────────
        {
          'id': 'chest_gym_1',
          'name': 'Barbell Bench Press',
          'primary_muscle': 'Chest',
          'equipment': 'Barbell',
          'environment': 'Gym',
          'difficulty': 'Intermediate',
          'video_url':
              'https://wger.de/media/exercise-images/192/Bench-press-1.png',
          'instructions': [
            'Lie flat on bench.',
            'Grip bar slightly wider than shoulders.',
            'Lower bar to mid-chest.',
            'Press back up until arms fully extended.',
            'Do not bounce bar off chest.',
          ],
          'muscle_heatmap': [
            {'muscle': 'Chest', 'intensity': 5},
            {'muscle': 'Triceps', 'intensity': 3},
            {'muscle': 'Shoulders', 'intensity': 2},
          ],
        },
        {
          'id': 'chest_gym_2',
          'name': 'Incline Dumbbell Press',
          'primary_muscle': 'Chest',
          'equipment': 'Dumbbell',
          'environment': 'Gym',
          'difficulty': 'Intermediate',
          'video_url':
              'https://wger.de/media/exercise-images/259/incline-bench-press-1.png',
          'instructions': [
            'Set bench to 30-45°.',
            'Hold dumbbells at chest level.',
            'Press up and slightly inward.',
            'Lower slowly to start.',
          ],
          'muscle_heatmap': [
            {'muscle': 'Upper Chest', 'intensity': 5},
            {'muscle': 'Shoulders', 'intensity': 3},
            {'muscle': 'Triceps', 'intensity': 2},
          ],
        },
        {
          'id': 'chest_gym_3',
          'name': 'Cable Chest Fly',
          'primary_muscle': 'Chest',
          'equipment': 'Cable',
          'environment': 'Gym',
          'difficulty': 'Beginner',
          'video_url':
              'https://wger.de/media/exercise-images/87/Cable-fly-1.png',
          'instructions': [
            'Set cables at mid-height.',
            'Stand in split stance.',
            'Bring handles together in arc motion.',
            'Squeeze chest at peak contraction.',
          ],
          'muscle_heatmap': [
            {'muscle': 'Chest', 'intensity': 5},
            {'muscle': 'Front Delt', 'intensity': 2},
          ],
        },
        {
          'id': 'chest_gym_4',
          'name': 'Dips (Chest)',
          'primary_muscle': 'Chest',
          'equipment': 'Bodyweight',
          'environment': 'Gym',
          'difficulty': 'Intermediate',
          'video_url': 'https://wger.de/media/exercise-images/91/Dips-1.png',
          'instructions': [
            'Grip parallel bars.',
            'Lean torso forward for chest emphasis.',
            'Lower until elbows at 90°.',
            'Press back up to start.',
          ],
          'muscle_heatmap': [
            {'muscle': 'Chest', 'intensity': 5},
            {'muscle': 'Triceps', 'intensity': 4},
            {'muscle': 'Shoulders', 'intensity': 2},
          ],
        },

        // ─── CHEST — HOME ─────────────────────────────────────────────────────
        {
          'id': 'chest_home_1',
          'name': 'Push-ups',
          'primary_muscle': 'Chest',
          'equipment': 'Bodyweight',
          'environment': 'Home',
          'difficulty': 'Beginner',
          'video_url':
              'https://wger.de/media/exercise-images/129/Push-up-1.png',
          'instructions': [
            'Plank position, hands shoulder-width.',
            'Lower chest to floor.',
            'Press back up, keep core tight.',
            'Full range of motion on every rep.',
          ],
          'muscle_heatmap': [
            {'muscle': 'Chest', 'intensity': 4},
            {'muscle': 'Triceps', 'intensity': 3},
            {'muscle': 'Core', 'intensity': 2},
          ],
        },
        {
          'id': 'chest_home_2',
          'name': 'Wide Push-ups',
          'primary_muscle': 'Chest',
          'equipment': 'Bodyweight',
          'environment': 'Home',
          'difficulty': 'Beginner',
          'video_url':
              'https://wger.de/media/exercise-images/129/Push-up-2.png',
          'instructions': [
            'Hands placed wider than shoulders.',
            'Elbows flare out to sides.',
            'Lower slowly until chest nearly touches floor.',
            'Push back up powerfully.',
          ],
          'muscle_heatmap': [
            {'muscle': 'Chest', 'intensity': 5},
            {'muscle': 'Shoulders', 'intensity': 3},
          ],
        },
        {
          'id': 'chest_home_3',
          'name': 'Pike Push-ups',
          'primary_muscle': 'Chest',
          'equipment': 'Bodyweight',
          'environment': 'Home',
          'difficulty': 'Intermediate',
          'video_url':
              'https://wger.de/media/exercise-images/130/Pike-push-up-1.png',
          'instructions': [
            'Start in downward-dog position.',
            'Bend elbows to lower head toward floor.',
            'Press back to start.',
            'Targets upper chest and shoulders.',
          ],
          'muscle_heatmap': [
            {'muscle': 'Shoulders', 'intensity': 5},
            {'muscle': 'Upper Chest', 'intensity': 4},
            {'muscle': 'Triceps', 'intensity': 3},
          ],
        },

        // ─── BACK — GYM ───────────────────────────────────────────────────────
        {
          'id': 'back_gym_1',
          'name': 'Deadlift',
          'primary_muscle': 'Back',
          'equipment': 'Barbell',
          'environment': 'Gym',
          'difficulty': 'Advanced',
          'video_url':
              'https://wger.de/media/exercise-images/57/Deadlift-1.png',
          'instructions': [
            'Bar over mid-foot.',
            'Hinge at hips, grip bar just outside knees.',
            'Chest up, back neutral.',
            'Drive through floor to lock out hips.',
            'Lower under control.',
          ],
          'muscle_heatmap': [
            {'muscle': 'Erectors', 'intensity': 5},
            {'muscle': 'Glutes', 'intensity': 4},
            {'muscle': 'Hamstrings', 'intensity': 4},
            {'muscle': 'Traps', 'intensity': 3},
          ],
        },
        {
          'id': 'back_gym_2',
          'name': 'Barbell Row',
          'primary_muscle': 'Back',
          'equipment': 'Barbell',
          'environment': 'Gym',
          'difficulty': 'Intermediate',
          'video_url':
              'https://wger.de/media/exercise-images/50/Barbell-row-1.png',
          'instructions': [
            'Hinge at hips, torso near parallel.',
            'Grip bar shoulder-width.',
            'Pull bar to lower chest.',
            'Squeeze lats at top.',
          ],
          'muscle_heatmap': [
            {'muscle': 'Lats', 'intensity': 5},
            {'muscle': 'Rhomboids', 'intensity': 4},
            {'muscle': 'Biceps', 'intensity': 3},
          ],
        },
        {
          'id': 'back_gym_3',
          'name': 'Lat Pulldown',
          'primary_muscle': 'Back',
          'equipment': 'Cable',
          'environment': 'Gym',
          'difficulty': 'Beginner',
          'video_url':
              'https://wger.de/media/exercise-images/76/Lat-pulldown-1.png',
          'instructions': [
            'Grip bar wide.',
            'Lean back slightly.',
            'Pull bar to upper chest.',
            'Control the return.',
          ],
          'muscle_heatmap': [
            {'muscle': 'Lats', 'intensity': 5},
            {'muscle': 'Biceps', 'intensity': 3},
            {'muscle': 'Rear Delt', 'intensity': 2},
          ],
        },
        {
          'id': 'back_gym_4',
          'name': 'Seated Cable Row',
          'primary_muscle': 'Back',
          'equipment': 'Cable',
          'environment': 'Gym',
          'difficulty': 'Beginner',
          'video_url':
              'https://wger.de/media/exercise-images/76/Lat-pulldown-2.png',
          'instructions': [
            'Sit upright, feet on platform.',
            'Pull handle to navel.',
            'Lead with elbows.',
            'Squeeze shoulder blades together.',
          ],
          'muscle_heatmap': [
            {'muscle': 'Rhomboids', 'intensity': 5},
            {'muscle': 'Lats', 'intensity': 4},
            {'muscle': 'Biceps', 'intensity': 2},
          ],
        },

        // ─── BACK — HOME ──────────────────────────────────────────────────────
        {
          'id': 'back_home_1',
          'name': 'Pull-ups',
          'primary_muscle': 'Back',
          'equipment': 'Bodyweight',
          'environment': 'Home',
          'difficulty': 'Intermediate',
          'video_url':
              'https://wger.de/media/exercise-images/265/Pull-up-1.png',
          'instructions': [
            'Hang from bar with overhand grip.',
            'Pull chest to bar.',
            'Lower fully to start.',
            'Avoid swinging.',
          ],
          'muscle_heatmap': [
            {'muscle': 'Lats', 'intensity': 5},
            {'muscle': 'Biceps', 'intensity': 4},
            {'muscle': 'Rhomboids', 'intensity': 3},
          ],
        },
        {
          'id': 'back_home_2',
          'name': 'Chin-ups',
          'primary_muscle': 'Back',
          'equipment': 'Bodyweight',
          'environment': 'Home',
          'difficulty': 'Intermediate',
          'video_url':
              'https://wger.de/media/exercise-images/265/Pull-up-2.png',
          'instructions': [
            'Underhand grip, shoulder-width.',
            'Pull until chin over bar.',
            'Slow descent.',
            'Full hang at bottom.',
          ],
          'muscle_heatmap': [
            {'muscle': 'Biceps', 'intensity': 5},
            {'muscle': 'Lats', 'intensity': 4},
          ],
        },
        {
          'id': 'back_home_3',
          'name': 'Superman Hold',
          'primary_muscle': 'Back',
          'equipment': 'Bodyweight',
          'environment': 'Home',
          'difficulty': 'Beginner',
          'video_url':
              'https://wger.de/media/exercise-images/301/Hyperextensions-1.png',
          'instructions': [
            'Lie face down.',
            'Raise arms and legs simultaneously.',
            'Hold for 2 seconds.',
            'Lower under control.',
          ],
          'muscle_heatmap': [
            {'muscle': 'Erectors', 'intensity': 5},
            {'muscle': 'Glutes', 'intensity': 3},
          ],
        },

        // ─── SHOULDERS — GYM ──────────────────────────────────────────────────
        {
          'id': 'shoulders_gym_1',
          'name': 'Overhead Press',
          'primary_muscle': 'Shoulders',
          'equipment': 'Barbell',
          'environment': 'Gym',
          'difficulty': 'Intermediate',
          'video_url':
              'https://wger.de/media/exercise-images/73/Barbell-military-press-1.png',
          'instructions': [
            'Stand with bar at collarbone.',
            'Press bar overhead until lockout.',
            'Lower slowly back to clavicle.',
            'Avoid arching lower back.',
          ],
          'muscle_heatmap': [
            {'muscle': 'Front Delt', 'intensity': 5},
            {'muscle': 'Triceps', 'intensity': 3},
            {'muscle': 'Upper Traps', 'intensity': 2},
          ],
        },
        {
          'id': 'shoulders_gym_2',
          'name': 'Lateral Raises',
          'primary_muscle': 'Shoulders',
          'equipment': 'Dumbbell',
          'environment': 'Gym',
          'difficulty': 'Beginner',
          'video_url':
              'https://wger.de/media/exercise-images/81/Side-laterals-1.png',
          'instructions': [
            'Stand with dumbbells at sides.',
            'Raise arms to shoulder height.',
            'Lead with elbows.',
            'Lower slowly.',
          ],
          'muscle_heatmap': [
            {'muscle': 'Side Delt', 'intensity': 5},
            {'muscle': 'Supraspinatus', 'intensity': 3},
          ],
        },
        {
          'id': 'shoulders_gym_3',
          'name': 'Face Pulls',
          'primary_muscle': 'Shoulders',
          'equipment': 'Cable',
          'environment': 'Gym',
          'difficulty': 'Beginner',
          'video_url':
              'https://wger.de/media/exercise-images/203/Cable-pull-1.png',
          'instructions': [
            'Cable at face height.',
            'Pull rope to forehead.',
            'Flare elbows high.',
            'External rotate at top.',
          ],
          'muscle_heatmap': [
            {'muscle': 'Rear Delt', 'intensity': 5},
            {'muscle': 'Rotator Cuff', 'intensity': 4},
            {'muscle': 'Traps', 'intensity': 3},
          ],
        },

        // ─── SHOULDERS — HOME ─────────────────────────────────────────────────
        {
          'id': 'shoulders_home_1',
          'name': 'Pike Push-ups',
          'primary_muscle': 'Shoulders',
          'equipment': 'Bodyweight',
          'environment': 'Home',
          'difficulty': 'Intermediate',
          'video_url':
              'https://wger.de/media/exercise-images/130/Pike-push-up-1.png',
          'instructions': [
            'Start in downward-dog.',
            'Lower head toward floor.',
            'Press back up.',
            'Keep hips high.',
          ],
          'muscle_heatmap': [
            {'muscle': 'Shoulders', 'intensity': 5},
            {'muscle': 'Triceps', 'intensity': 3},
          ],
        },
        {
          'id': 'shoulders_home_2',
          'name': 'Handstand Push-ups',
          'primary_muscle': 'Shoulders',
          'equipment': 'Bodyweight',
          'environment': 'Home',
          'difficulty': 'Advanced',
          'video_url':
              'https://wger.de/media/exercise-images/130/Pike-push-up-2.png',
          'instructions': [
            'Kick up into handstand against wall.',
            'Lower head to floor.',
            'Press back up.',
            'Keep core braced throughout.',
          ],
          'muscle_heatmap': [
            {'muscle': 'Shoulders', 'intensity': 5},
            {'muscle': 'Triceps', 'intensity': 4},
            {'muscle': 'Traps', 'intensity': 3},
          ],
        },

        // ─── ARMS — GYM ───────────────────────────────────────────────────────
        {
          'id': 'arms_gym_1',
          'name': 'Barbell Curl',
          'primary_muscle': 'Arms',
          'equipment': 'Barbell',
          'environment': 'Gym',
          'difficulty': 'Beginner',
          'video_url':
              'https://wger.de/media/exercise-images/95/Standing-biceps-curl-1.png',
          'instructions': [
            'Grip bar shoulder-width, underhand.',
            'Curl to shoulder height.',
            'Squeeze at top.',
            'Lower with full extension.',
          ],
          'muscle_heatmap': [
            {'muscle': 'Biceps', 'intensity': 5},
            {'muscle': 'Forearms', 'intensity': 2},
          ],
        },
        {
          'id': 'arms_gym_2',
          'name': 'Tricep Pushdown',
          'primary_muscle': 'Arms',
          'equipment': 'Cable',
          'environment': 'Gym',
          'difficulty': 'Beginner',
          'video_url':
              'https://wger.de/media/exercise-images/204/Tricep-pushdown-1.png',
          'instructions': [
            'Stand at cable machine.',
            'Keep elbows at sides.',
            'Push bar down to lockout.',
            'Squeeze triceps at bottom.',
          ],
          'muscle_heatmap': [
            {'muscle': 'Triceps', 'intensity': 5},
          ],
        },
        {
          'id': 'arms_gym_3',
          'name': 'Hammer Curls',
          'primary_muscle': 'Arms',
          'equipment': 'Dumbbell',
          'environment': 'Gym',
          'difficulty': 'Beginner',
          'video_url':
              'https://wger.de/media/exercise-images/202/Hammer-curl-1.png',
          'instructions': [
            'Neutral grip (thumbs up).',
            'Curl without rotating wrist.',
            'Targets brachialis for thicker arms.',
          ],
          'muscle_heatmap': [
            {'muscle': 'Brachialis', 'intensity': 5},
            {'muscle': 'Biceps', 'intensity': 3},
            {'muscle': 'Forearms', 'intensity': 3},
          ],
        },
        {
          'id': 'arms_gym_4',
          'name': 'Skull Crushers',
          'primary_muscle': 'Arms',
          'equipment': 'Barbell',
          'environment': 'Gym',
          'difficulty': 'Intermediate',
          'video_url':
              'https://wger.de/media/exercise-images/83/Skull-crusher-1.png',
          'instructions': [
            'Lie on bench, arms extended.',
            'Lower bar toward forehead.',
            'Extend arms back up.',
            'Keep elbows pointing up.',
          ],
          'muscle_heatmap': [
            {'muscle': 'Triceps', 'intensity': 5},
            {'muscle': 'Forearms', 'intensity': 1},
          ],
        },

        // ─── ARMS — HOME ──────────────────────────────────────────────────────
        {
          'id': 'arms_home_1',
          'name': 'Dumbbell Bicep Curls',
          'primary_muscle': 'Arms',
          'equipment': 'Dumbbell',
          'environment': 'Home',
          'difficulty': 'Beginner',
          'video_url':
              'https://wger.de/media/exercise-images/95/Standing-biceps-curl-2.png',
          'instructions': [
            'Stand tall, palms forward.',
            'Curl weight toward shoulder.',
            'Lower with full extension.',
          ],
          'muscle_heatmap': [
            {'muscle': 'Biceps', 'intensity': 5},
          ],
        },
        {
          'id': 'arms_home_2',
          'name': 'Diamond Push-ups',
          'primary_muscle': 'Arms',
          'equipment': 'Bodyweight',
          'environment': 'Home',
          'difficulty': 'Intermediate',
          'video_url':
              'https://wger.de/media/exercise-images/129/Push-up-1.png',
          'instructions': [
            'Form diamond shape with hands.',
            'Keep elbows close to body.',
            'Lower chest to hands.',
            'Best bodyweight triceps exercise.',
          ],
          'muscle_heatmap': [
            {'muscle': 'Triceps', 'intensity': 5},
            {'muscle': 'Chest', 'intensity': 2},
          ],
        },

        // ─── LEGS — GYM ───────────────────────────────────────────────────────
        {
          'id': 'legs_gym_1',
          'name': 'Barbell Squat',
          'primary_muscle': 'Legs',
          'equipment': 'Barbell',
          'environment': 'Gym',
          'difficulty': 'Intermediate',
          'video_url':
              'https://wger.de/media/exercise-images/253/Barbell-squat-1.png',
          'instructions': [
            'Bar across upper trap.',
            'Feet shoulder-width, toes out.',
            'Lower hips until thighs parallel.',
            'Drive through heels.',
            'Keep chest up.',
          ],
          'muscle_heatmap': [
            {'muscle': 'Quads', 'intensity': 5},
            {'muscle': 'Glutes', 'intensity': 4},
            {'muscle': 'Core', 'intensity': 3},
            {'muscle': 'Hamstrings', 'intensity': 2},
          ],
        },
        {
          'id': 'legs_gym_2',
          'name': 'Leg Press',
          'primary_muscle': 'Legs',
          'equipment': 'Machine',
          'environment': 'Gym',
          'difficulty': 'Beginner',
          'video_url':
              'https://wger.de/media/exercise-images/194/Leg-press-1.png',
          'instructions': [
            'Seat back at 45°.',
            'Feet shoulder-width on platform.',
            'Lower weight until 90° knee angle.',
            'Press back up but don\'t lock out.',
          ],
          'muscle_heatmap': [
            {'muscle': 'Quads', 'intensity': 5},
            {'muscle': 'Glutes', 'intensity': 3},
          ],
        },
        {
          'id': 'legs_gym_3',
          'name': 'Romanian Deadlift',
          'primary_muscle': 'Legs',
          'equipment': 'Barbell',
          'environment': 'Gym',
          'difficulty': 'Intermediate',
          'video_url':
              'https://wger.de/media/exercise-images/246/Romanian-deadlift-1.png',
          'instructions': [
            'Stand with bar at hip height.',
            'Push hips back, lower bar.',
            'Feel deep stretch in hamstrings.',
            'Push hips forward to stand.',
          ],
          'muscle_heatmap': [
            {'muscle': 'Hamstrings', 'intensity': 5},
            {'muscle': 'Glutes', 'intensity': 4},
            {'muscle': 'Erectors', 'intensity': 3},
          ],
        },
        {
          'id': 'legs_gym_4',
          'name': 'Leg Curl',
          'primary_muscle': 'Legs',
          'equipment': 'Machine',
          'environment': 'Gym',
          'difficulty': 'Beginner',
          'video_url':
              'https://wger.de/media/exercise-images/81/Side-laterals-1.png',
          'instructions': [
            'Lie face down on machine.',
            'Curl heels toward glutes.',
            'Squeeze hamstrings at peak.',
            'Lower slowly.',
          ],
          'muscle_heatmap': [
            {'muscle': 'Hamstrings', 'intensity': 5},
            {'muscle': 'Calves', 'intensity': 2},
          ],
        },
        {
          'id': 'legs_gym_5',
          'name': 'Calf Raises',
          'primary_muscle': 'Legs',
          'equipment': 'Machine',
          'environment': 'Gym',
          'difficulty': 'Beginner',
          'video_url':
              'https://wger.de/media/exercise-images/145/Calf-raise-1.png',
          'instructions': [
            'Stand on raised surface.',
            'Rise on toes as high as possible.',
            'Pause at top.',
            'Lower past neutral for full stretch.',
          ],
          'muscle_heatmap': [
            {'muscle': 'Calves', 'intensity': 5},
            {'muscle': 'Soleus', 'intensity': 3},
          ],
        },

        // ─── LEGS — HOME ──────────────────────────────────────────────────────
        {
          'id': 'legs_home_1',
          'name': 'Bodyweight Squat',
          'primary_muscle': 'Legs',
          'equipment': 'Bodyweight',
          'environment': 'Home',
          'difficulty': 'Beginner',
          'video_url': 'https://wger.de/media/exercise-images/237/Squat-1.png',
          'instructions': [
            'Feet shoulder-width.',
            'Lower until thighs parallel.',
            'Keep chest up, knees tracking toes.',
            'Stand back up powerfully.',
          ],
          'muscle_heatmap': [
            {'muscle': 'Quads', 'intensity': 4},
            {'muscle': 'Glutes', 'intensity': 4},
          ],
        },
        {
          'id': 'legs_home_2',
          'name': 'Bulgarian Split Squat',
          'primary_muscle': 'Legs',
          'equipment': 'Bodyweight',
          'environment': 'Home',
          'difficulty': 'Intermediate',
          'video_url': 'https://wger.de/media/exercise-images/313/Lunge-1.png',
          'instructions': [
            'Rear foot elevated on chair.',
            'Lower front knee toward floor.',
            'Keep torso upright.',
            'Drive through front heel to stand.',
          ],
          'muscle_heatmap': [
            {'muscle': 'Quads', 'intensity': 5},
            {'muscle': 'Glutes', 'intensity': 4},
            {'muscle': 'Balance', 'intensity': 3},
          ],
        },
        {
          'id': 'legs_home_3',
          'name': 'Lunges',
          'primary_muscle': 'Legs',
          'equipment': 'Bodyweight',
          'environment': 'Home',
          'difficulty': 'Beginner',
          'video_url':
              'https://wger.de/media/exercise-images/139/Walking-lunge-1.png',
          'instructions': [
            'Step forward, lower rear knee.',
            'Keep front shin vertical.',
            'Push back to standing position.',
            'Alternate legs.',
          ],
          'muscle_heatmap': [
            {'muscle': 'Quads', 'intensity': 4},
            {'muscle': 'Glutes', 'intensity': 4},
          ],
        },
        {
          'id': 'legs_home_4',
          'name': 'Jump Squats',
          'primary_muscle': 'Legs',
          'equipment': 'Bodyweight',
          'environment': 'Home',
          'difficulty': 'Intermediate',
          'video_url': 'https://wger.de/media/exercise-images/237/Squat-2.png',
          'instructions': [
            'Start in squat.',
            'Explode upward.',
            'Land softly with bent knees.',
            'Immediately descend into next rep.',
          ],
          'muscle_heatmap': [
            {'muscle': 'Quads', 'intensity': 5},
            {'muscle': 'Glutes', 'intensity': 4},
            {'muscle': 'Calves', 'intensity': 3},
          ],
        },

        // ─── CORE — GYM ───────────────────────────────────────────────────────
        {
          'id': 'core_gym_1',
          'name': 'Cable Crunch',
          'primary_muscle': 'Core',
          'equipment': 'Cable',
          'environment': 'Gym',
          'difficulty': 'Beginner',
          'video_url':
              'https://wger.de/media/exercise-images/167/Crunches-1.png',
          'instructions': [
            'Kneel at cable machine.',
            'Rope at neck.',
            'Crunch elbows toward knees.',
            'Hold 1 second.',
            'Return slowly.',
          ],
          'muscle_heatmap': [
            {'muscle': 'Upper Abs', 'intensity': 5},
            {'muscle': 'Obliques', 'intensity': 2},
          ],
        },
        {
          'id': 'core_gym_2',
          'name': 'Hanging Leg Raise',
          'primary_muscle': 'Core',
          'equipment': 'Bodyweight',
          'environment': 'Gym',
          'difficulty': 'Intermediate',
          'video_url':
              'https://wger.de/media/exercise-images/282/Leg-raise-1.png',
          'instructions': [
            'Hang from pull-up bar.',
            'Raise legs to 90°.',
            'Lower slowly without swinging.',
            'For advanced: raise to bar.',
          ],
          'muscle_heatmap': [
            {'muscle': 'Lower Abs', 'intensity': 5},
            {'muscle': 'Hip Flexors', 'intensity': 4},
          ],
        },
        {
          'id': 'core_gym_3',
          'name': 'Ab Wheel Rollout',
          'primary_muscle': 'Core',
          'equipment': 'Bodyweight',
          'environment': 'Gym',
          'difficulty': 'Advanced',
          'video_url':
              'https://wger.de/media/exercise-images/132/Ab-wheel-1.png',
          'instructions': [
            'Kneel, grip wheel.',
            'Roll forward as far as possible.',
            'Pull back using core.',
            'Do not let hips sag.',
          ],
          'muscle_heatmap': [
            {'muscle': 'Abs', 'intensity': 5},
            {'muscle': 'Lats', 'intensity': 3},
            {'muscle': 'Hip Flexors', 'intensity': 2},
          ],
        },

        // ─── CORE — HOME ──────────────────────────────────────────────────────
        {
          'id': 'core_home_1',
          'name': 'Plank',
          'primary_muscle': 'Core',
          'equipment': 'Bodyweight',
          'environment': 'Home',
          'difficulty': 'Beginner',
          'video_url': 'https://wger.de/media/exercise-images/172/Plank-1.png',
          'instructions': [
            'Forearms and toes on floor.',
            'Body in straight line.',
            'Brace core.',
            'Hold for time — build up to 60s.',
          ],
          'muscle_heatmap': [
            {'muscle': 'Core', 'intensity': 5},
            {'muscle': 'Shoulders', 'intensity': 2},
          ],
        },
        {
          'id': 'core_home_2',
          'name': 'Crunches',
          'primary_muscle': 'Core',
          'equipment': 'Bodyweight',
          'environment': 'Home',
          'difficulty': 'Beginner',
          'video_url':
              'https://wger.de/media/exercise-images/167/Crunches-1.png',
          'instructions': [
            'Lie on back, knees bent.',
            'Curl upper body toward knees.',
            'Pause and squeeze.',
            'Lower slowly.',
            'Do not pull on neck.',
          ],
          'muscle_heatmap': [
            {'muscle': 'Upper Abs', 'intensity': 5},
          ],
        },
        {
          'id': 'core_home_3',
          'name': 'Mountain Climbers',
          'primary_muscle': 'Core',
          'equipment': 'Bodyweight',
          'environment': 'Home',
          'difficulty': 'Intermediate',
          'video_url':
              'https://wger.de/media/exercise-images/285/Mountain-climber-1.png',
          'instructions': [
            'Start in plank.',
            'Drive knees alternately to chest.',
            'Keep hips level.',
            'Move fast for cardio benefit.',
          ],
          'muscle_heatmap': [
            {'muscle': 'Core', 'intensity': 5},
            {'muscle': 'Hip Flexors', 'intensity': 4},
            {'muscle': 'Shoulders', 'intensity': 2},
          ],
        },
        {
          'id': 'core_home_4',
          'name': 'Bicycle Crunches',
          'primary_muscle': 'Core',
          'equipment': 'Bodyweight',
          'environment': 'Home',
          'difficulty': 'Beginner',
          'video_url':
              'https://wger.de/media/exercise-images/173/Bicycle-crunch-1.png',
          'instructions': [
            'Lie on back.',
            'Bring opposite elbow to knee.',
            'Extend other leg.',
            'Alternate in pedaling motion.',
          ],
          'muscle_heatmap': [
            {'muscle': 'Obliques', 'intensity': 5},
            {'muscle': 'Abs', 'intensity': 4},
          ],
        },

        // ─── GLUTES — GYM ─────────────────────────────────────────────────────
        {
          'id': 'glutes_gym_1',
          'name': 'Hip Thrust',
          'primary_muscle': 'Glutes',
          'equipment': 'Barbell',
          'environment': 'Gym',
          'difficulty': 'Intermediate',
          'video_url':
              'https://wger.de/media/exercise-images/294/Hip-thrust-1.png',
          'instructions': [
            'Shoulders on bench.',
            'Bar across hips.',
            'Drive hips to ceiling.',
            'Squeeze glutes at top for 2 seconds.',
          ],
          'muscle_heatmap': [
            {'muscle': 'Glutes', 'intensity': 5},
            {'muscle': 'Hamstrings', 'intensity': 3},
            {'muscle': 'Core', 'intensity': 2},
          ],
        },
        {
          'id': 'glutes_gym_2',
          'name': 'Cable Kickback',
          'primary_muscle': 'Glutes',
          'equipment': 'Cable',
          'environment': 'Gym',
          'difficulty': 'Beginner',
          'video_url':
              'https://wger.de/media/exercise-images/171/Kickbacks-1.png',
          'instructions': [
            'Ankle cuff attached to cable.',
            'Kick leg back and up.',
            'Squeeze glute at top.',
            'Do not arch lower back.',
          ],
          'muscle_heatmap': [
            {'muscle': 'Glutes', 'intensity': 5},
            {'muscle': 'Hamstrings', 'intensity': 2},
          ],
        },

        // ─── GLUTES — HOME ────────────────────────────────────────────────────
        {
          'id': 'glutes_home_1',
          'name': 'Glute Bridge',
          'primary_muscle': 'Glutes',
          'equipment': 'Bodyweight',
          'environment': 'Home',
          'difficulty': 'Beginner',
          'video_url':
              'https://wger.de/media/exercise-images/289/Glute-bridge-1.png',
          'instructions': [
            'Lie on back, knees bent.',
            'Drive hips up until shoulder-to-knee line.',
            'Squeeze glutes hard.',
            'Lower slowly.',
          ],
          'muscle_heatmap': [
            {'muscle': 'Glutes', 'intensity': 5},
            {'muscle': 'Hamstrings', 'intensity': 3},
          ],
        },
        {
          'id': 'glutes_home_2',
          'name': 'Donkey Kicks',
          'primary_muscle': 'Glutes',
          'equipment': 'Bodyweight',
          'environment': 'Home',
          'difficulty': 'Beginner',
          'video_url':
              'https://wger.de/media/exercise-images/291/Donkey-kick-1.png',
          'instructions': [
            'On hands and knees.',
            'Kick one leg back and up.',
            'Squeeze glute at top.',
            'Avoid rotating hips.',
          ],
          'muscle_heatmap': [
            {'muscle': 'Glutes', 'intensity': 5},
            {'muscle': 'Hamstrings', 'intensity': 2},
          ],
        },

        // ─── CARDIO — GYM ─────────────────────────────────────────────────────
        {
          'id': 'cardio_gym_1',
          'name': 'Treadmill Run',
          'primary_muscle': 'Cardio',
          'equipment': 'Machine',
          'environment': 'Gym',
          'difficulty': 'Beginner',
          'video_url':
              'https://wger.de/media/exercise-images/177/Running-1.png',
          'instructions': [
            'Set pace to comfortable level.',
            'Maintain upright posture.',
            'Land midfoot.',
            'Keep shoulders relaxed.',
          ],
          'muscle_heatmap': [
            {'muscle': 'Quads', 'intensity': 4},
            {'muscle': 'Calves', 'intensity': 4},
            {'muscle': 'Heart', 'intensity': 5},
          ],
        },
        {
          'id': 'cardio_gym_2',
          'name': 'Battle Ropes',
          'primary_muscle': 'Cardio',
          'equipment': 'Rope',
          'environment': 'Gym',
          'difficulty': 'Intermediate',
          'video_url': 'https://wger.de/media/exercise-images/112/Rope-1.png',
          'instructions': [
            'Hold one end each.',
            'Create waves alternately.',
            'Maintain athletic stance.',
            '20–30 sec intense, 10s rest.',
          ],
          'muscle_heatmap': [
            {'muscle': 'Shoulders', 'intensity': 4},
            {'muscle': 'Core', 'intensity': 4},
            {'muscle': 'Arms', 'intensity': 3},
          ],
        },

        // ─── CARDIO — HOME ────────────────────────────────────────────────────
        {
          'id': 'cardio_home_1',
          'name': 'Burpees',
          'primary_muscle': 'Cardio',
          'equipment': 'Bodyweight',
          'environment': 'Home',
          'difficulty': 'Intermediate',
          'video_url': 'https://wger.de/media/exercise-images/260/Burpee-1.png',
          'instructions': [
            'Squat, place hands on floor.',
            'Jump feet back to plank.',
            'Do a push-up.',
            'Jump feet in, then jump up with arms overhead.',
          ],
          'muscle_heatmap': [
            {'muscle': 'Full Body', 'intensity': 5},
          ],
        },
        {
          'id': 'cardio_home_2',
          'name': 'Jumping Jacks',
          'primary_muscle': 'Cardio',
          'equipment': 'Bodyweight',
          'environment': 'Home',
          'difficulty': 'Beginner',
          'video_url':
              'https://wger.de/media/exercise-images/165/Jumping-jack-1.png',
          'instructions': [
            'Stand upright.',
            'Jump, spreading feet and raising arms.',
            'Return to start.',
            'Great warmup exercise.',
          ],
          'muscle_heatmap': [
            {'muscle': 'Calves', 'intensity': 3},
            {'muscle': 'Shoulders', 'intensity': 2},
            {'muscle': 'Core', 'intensity': 2},
          ],
        },
        {
          'id': 'cardio_home_3',
          'name': 'High Knees',
          'primary_muscle': 'Cardio',
          'equipment': 'Bodyweight',
          'environment': 'Home',
          'difficulty': 'Beginner',
          'video_url':
              'https://wger.de/media/exercise-images/222/High-knee-1.png',
          'instructions': [
            'Run in place.',
            'Drive knees to waist height.',
            'Pump arms in sync.',
            'Stay on balls of feet.',
          ],
          'muscle_heatmap': [
            {'muscle': 'Hip Flexors', 'intensity': 4},
            {'muscle': 'Core', 'intensity': 3},
            {'muscle': 'Calves', 'intensity': 3},
          ],
        },
      ];

      mock.addAll([
        {
          'id': 'beginner_chest_1',
          'name': 'Incline Push-ups',
          'primary_muscle': 'Chest',
          'equipment': 'Bodyweight',
          'environment': 'Home',
          'difficulty': 'Beginner',
          'animation_key': 'push',
          'video_url': '',
          'instructions': [
            'Place hands on a bench, wall, or sturdy box.',
            'Keep your body in one straight line from head to heel.',
            'Lower your chest toward the support with control.',
            'Press the floor away and finish with elbows nearly straight.',
          ],
          'form_cues': [
            'Brace your ribs and glutes so your lower back does not sag.',
            'Keep shoulders away from your ears as you lower.',
            'Touch the same point on the bench every rep.',
          ],
          'common_mistakes': [
            'Dropping the hips and turning it into a backbend.',
            'Letting elbows flare straight out at 90 degrees.',
          ],
          'beginner_tip':
              'Start higher than you think. A wall or kitchen counter makes it easy to learn clean pressing mechanics first.',
          'muscle_heatmap': [
            {'muscle': 'Chest', 'intensity': 4},
            {'muscle': 'Triceps', 'intensity': 3},
            {'muscle': 'Core', 'intensity': 2},
          ],
        },
        {
          'id': 'beginner_chest_2',
          'name': 'Knee Push-ups',
          'primary_muscle': 'Chest',
          'equipment': 'Bodyweight',
          'environment': 'Home',
          'difficulty': 'Beginner',
          'animation_key': 'push',
          'video_url': '',
          'instructions': [
            'Set up in a plank with knees on the floor.',
            'Hands slightly wider than shoulders.',
            'Lower chest between the hands while keeping the torso stiff.',
            'Press back up without shrugging.',
          ],
          'form_cues': [
            'Think chest forward, not head downward.',
            'Keep a straight line from knees through hips to shoulders.',
          ],
          'common_mistakes': [
            'Piking the hips up to make the rep easier.',
            'Bouncing off the floor at the bottom.',
          ],
          'beginner_tip':
              'If these still feel hard, shorten the range a little and build smooth reps before chasing depth.',
          'muscle_heatmap': [
            {'muscle': 'Chest', 'intensity': 4},
            {'muscle': 'Triceps', 'intensity': 3},
            {'muscle': 'Core', 'intensity': 2},
          ],
        },
        {
          'id': 'beginner_back_1',
          'name': 'Resistance Band Row',
          'primary_muscle': 'Back',
          'equipment': 'Resistance Band',
          'environment': 'Home',
          'difficulty': 'Beginner',
          'animation_key': 'row',
          'video_url': '',
          'instructions': [
            'Anchor the band at chest height.',
            'Step back until there is light tension.',
            'Pull elbows toward your ribs.',
            'Pause, squeeze your shoulder blades, then return slowly.',
          ],
          'form_cues': [
            'Lead with the elbows, not the wrists.',
            'Keep the chest tall instead of leaning back.',
          ],
          'common_mistakes': [
            'Shrugging shoulders up as you pull.',
            'Letting the band snap you forward on the return.',
          ],
          'beginner_tip':
              'This is one of the safest first pulling movements because you can make it lighter just by stepping closer to the anchor.',
          'muscle_heatmap': [
            {'muscle': 'Lats', 'intensity': 4},
            {'muscle': 'Rhomboids', 'intensity': 4},
            {'muscle': 'Biceps', 'intensity': 2},
          ],
        },
        {
          'id': 'beginner_back_2',
          'name': 'Chest-Supported Row',
          'primary_muscle': 'Back',
          'equipment': 'Dumbbell',
          'environment': 'Gym',
          'difficulty': 'Beginner',
          'animation_key': 'row',
          'video_url': '',
          'instructions': [
            'Set an incline bench and lie chest-down on it.',
            'Let dumbbells hang straight down.',
            'Row the weights toward your lower ribs.',
            'Lower slowly until elbows are straight again.',
          ],
          'form_cues': [
            'Keep your sternum glued to the bench.',
            'Pause for one beat when elbows are behind the torso.',
          ],
          'common_mistakes': [
            'Yanking the weights with momentum.',
            'Pulling too high and turning it into a shrug.',
          ],
          'beginner_tip':
              'This removes lower-back fatigue and makes it easier to feel the upper back doing the work.',
          'muscle_heatmap': [
            {'muscle': 'Mid Back', 'intensity': 5},
            {'muscle': 'Lats', 'intensity': 4},
            {'muscle': 'Biceps', 'intensity': 2},
          ],
        },
        {
          'id': 'beginner_back_3',
          'name': 'Single-Arm Dumbbell Row',
          'primary_muscle': 'Back',
          'equipment': 'Dumbbell',
          'environment': 'Home',
          'difficulty': 'Beginner',
          'animation_key': 'row',
          'video_url': '',
          'instructions': [
            'Place one hand and one knee on a bench or chair.',
            'Brace your torso flat to the floor.',
            'Pull the dumbbell toward your hip.',
            'Lower under control until the arm is long again.',
          ],
          'form_cues': [
            'Imagine scraping your elbow along your side.',
            'Keep the neck long and eyes down.',
          ],
          'common_mistakes': [
            'Twisting the torso to get the weight higher.',
            'Turning the pull into an upright row.',
          ],
          'beginner_tip':
              'Use a lighter bell than you expect and own the pause at the top first.',
          'muscle_heatmap': [
            {'muscle': 'Lats', 'intensity': 5},
            {'muscle': 'Rhomboids', 'intensity': 3},
            {'muscle': 'Biceps', 'intensity': 2},
          ],
        },
        {
          'id': 'beginner_shoulders_1',
          'name': 'Wall Slides',
          'primary_muscle': 'Shoulders',
          'equipment': 'Bodyweight',
          'environment': 'Home',
          'difficulty': 'Beginner',
          'animation_key': 'raise',
          'video_url': '',
          'instructions': [
            'Stand with your back and forearms against a wall.',
            'Set your ribs down and chin neutral.',
            'Slide your arms upward without losing wall contact.',
            'Return slowly to the starting position.',
          ],
          'form_cues': [
            'Keep your low back quiet and ribs stacked.',
            'Reach the elbows up, not just the hands.',
          ],
          'common_mistakes': [
            'Arching the lower back to fake shoulder range.',
            'Letting wrists peel off the wall immediately.',
          ],
          'beginner_tip':
              'Treat this as shoulder control practice, not a max-range stretch.',
          'muscle_heatmap': [
            {'muscle': 'Shoulders', 'intensity': 3},
            {'muscle': 'Upper Back', 'intensity': 3},
            {'muscle': 'Rotator Cuff', 'intensity': 4},
          ],
        },
        {
          'id': 'beginner_shoulders_2',
          'name': 'Seated Dumbbell Press',
          'primary_muscle': 'Shoulders',
          'equipment': 'Dumbbell',
          'environment': 'Gym',
          'difficulty': 'Beginner',
          'animation_key': 'press',
          'video_url': '',
          'instructions': [
            'Sit tall with feet planted.',
            'Start dumbbells just above shoulder level.',
            'Press overhead until arms are straight.',
            'Lower with control to the same start point.',
          ],
          'form_cues': [
            'Keep forearms vertical under the weights.',
            'Exhale as the bells pass your forehead.',
          ],
          'common_mistakes': [
            'Crashing the dumbbells together at the top.',
            'Leaning back hard and turning it into an incline press.',
          ],
          'beginner_tip':
              'The seated version teaches a cleaner press path before progressing to standing overhead work.',
          'muscle_heatmap': [
            {'muscle': 'Front Delt', 'intensity': 5},
            {'muscle': 'Triceps', 'intensity': 3},
            {'muscle': 'Upper Chest', 'intensity': 2},
          ],
        },
        {
          'id': 'beginner_legs_1',
          'name': 'Box Squat',
          'primary_muscle': 'Legs',
          'equipment': 'Bodyweight',
          'environment': 'Home',
          'difficulty': 'Beginner',
          'animation_key': 'squat',
          'video_url': '',
          'instructions': [
            'Stand in front of a box or chair.',
            'Reach hips back until you lightly sit down.',
            'Stay braced and drive through the feet to stand.',
            'Finish tall with hips fully extended.',
          ],
          'form_cues': [
            'Reach your hips back first before bending the knees.',
            'Keep the whole foot connected to the floor.',
          ],
          'common_mistakes': [
            'Plopping onto the box and losing tension.',
            'Driving knees inward on the way up.',
          ],
          'beginner_tip':
              'Use the box as a depth target so every rep looks the same and feels controlled.',
          'muscle_heatmap': [
            {'muscle': 'Quads', 'intensity': 4},
            {'muscle': 'Glutes', 'intensity': 4},
            {'muscle': 'Core', 'intensity': 2},
          ],
        },
        {
          'id': 'beginner_legs_2',
          'name': 'Goblet Squat',
          'primary_muscle': 'Legs',
          'equipment': 'Dumbbell',
          'environment': 'Gym',
          'difficulty': 'Beginner',
          'animation_key': 'squat',
          'video_url': '',
          'instructions': [
            'Hold one dumbbell at chest height.',
            'Sit down between your hips.',
            'Keep elbows pointed toward the floor.',
            'Stand up by pushing the floor away.',
          ],
          'form_cues': [
            'Let the weight act like a counterbalance and stay tall.',
            'Keep knees tracking over your middle toes.',
          ],
          'common_mistakes': [
            'Letting the dumbbell drift away from the chest.',
            'Cutting depth short because the torso folds over.',
          ],
          'beginner_tip':
              'This is often the best first loaded squat because the front load helps you learn posture.',
          'muscle_heatmap': [
            {'muscle': 'Quads', 'intensity': 5},
            {'muscle': 'Glutes', 'intensity': 4},
            {'muscle': 'Core', 'intensity': 3},
          ],
        },
        {
          'id': 'beginner_legs_3',
          'name': 'Step-Ups',
          'primary_muscle': 'Legs',
          'equipment': 'Bodyweight',
          'environment': 'Home',
          'difficulty': 'Beginner',
          'animation_key': 'lunge',
          'video_url': '',
          'instructions': [
            'Place one full foot on a box or step.',
            'Lean slightly forward and push through that foot.',
            'Stand tall on top before coming down slowly.',
            'Complete all reps on one side, then switch.',
          ],
          'form_cues': [
            'Use the working leg to stand instead of bouncing off the floor.',
            'Keep the knee tracking over the foot on the step.',
          ],
          'common_mistakes': [
            'Launching off the back leg to cheat the rep.',
            'Using a box so high that the pelvis twists.',
          ],
          'beginner_tip':
              'A low step is better than a high one. Own balance and control before adding height or weight.',
          'muscle_heatmap': [
            {'muscle': 'Quads', 'intensity': 4},
            {'muscle': 'Glutes', 'intensity': 4},
            {'muscle': 'Calves', 'intensity': 2},
          ],
        },
        {
          'id': 'beginner_legs_4',
          'name': 'Dumbbell Romanian Deadlift',
          'primary_muscle': 'Legs',
          'equipment': 'Dumbbell',
          'environment': 'Home',
          'difficulty': 'Beginner',
          'animation_key': 'bridge',
          'video_url': '',
          'instructions': [
            'Stand tall with dumbbells at your sides.',
            'Soften the knees and push the hips backward.',
            'Lower until you feel a hamstring stretch.',
            'Drive hips forward to stand tall again.',
          ],
          'form_cues': [
            'Keep the dumbbells close to your thighs the whole time.',
            'Think long spine and proud chest.',
          ],
          'common_mistakes': [
            'Turning it into a squat by bending the knees too much.',
            'Reaching the weights down by rounding the back.',
          ],
          'beginner_tip':
              'Film yourself from the side. The movement should look like a hip hinge, not a squat.',
          'muscle_heatmap': [
            {'muscle': 'Hamstrings', 'intensity': 5},
            {'muscle': 'Glutes', 'intensity': 4},
            {'muscle': 'Erectors', 'intensity': 3},
          ],
        },
        {
          'id': 'beginner_core_1',
          'name': 'Dead Bug',
          'primary_muscle': 'Core',
          'equipment': 'Bodyweight',
          'environment': 'Home',
          'difficulty': 'Beginner',
          'animation_key': 'core',
          'video_url': '',
          'instructions': [
            'Lie on your back with knees and hands up.',
            'Press the low back gently into the floor.',
            'Reach opposite arm and leg away slowly.',
            'Return and alternate sides.',
          ],
          'form_cues': [
            'Move slowly enough that the ribs stay down.',
            'Only reach as far as you can while keeping the back flat.',
          ],
          'common_mistakes': [
            'Letting the lower back pop off the floor.',
            'Rushing the limbs and losing control.',
          ],
          'beginner_tip':
              'This is one of the best first core drills for learning how to brace without neck strain.',
          'muscle_heatmap': [
            {'muscle': 'Core', 'intensity': 5},
            {'muscle': 'Hip Flexors', 'intensity': 2},
          ],
        },
        {
          'id': 'beginner_core_2',
          'name': 'Bird Dog',
          'primary_muscle': 'Core',
          'equipment': 'Bodyweight',
          'environment': 'Home',
          'difficulty': 'Beginner',
          'animation_key': 'core',
          'video_url': '',
          'instructions': [
            'Start on hands and knees.',
            'Reach opposite arm and leg long.',
            'Pause without rotating your hips.',
            'Return and switch sides.',
          ],
          'form_cues': [
            'Keep your belt line level as the leg reaches back.',
            'Reach long, not high, with the back leg.',
          ],
          'common_mistakes': [
            'Lifting the leg too high and arching the back.',
            'Rocking side to side instead of staying stable.',
          ],
          'beginner_tip':
              'Use a full exhale before each rep to lock the trunk in place.',
          'muscle_heatmap': [
            {'muscle': 'Core', 'intensity': 4},
            {'muscle': 'Glutes', 'intensity': 3},
            {'muscle': 'Shoulders', 'intensity': 2},
          ],
        },
        {
          'id': 'beginner_glutes_1',
          'name': 'Banded Glute Bridge',
          'primary_muscle': 'Glutes',
          'equipment': 'Resistance Band',
          'environment': 'Home',
          'difficulty': 'Beginner',
          'animation_key': 'bridge',
          'video_url': '',
          'instructions': [
            'Loop a mini band above the knees.',
            'Lie on your back with feet planted.',
            'Drive hips up while pressing knees outward.',
            'Pause and squeeze glutes, then lower slowly.',
          ],
          'form_cues': [
            'Keep the ribcage down as the hips rise.',
            'Press out into the band the entire rep.',
          ],
          'common_mistakes': [
            'Flaring the ribs and over-arching at the top.',
            'Letting knees cave inward against the band.',
          ],
          'beginner_tip':
              'This is a good first glute drill before heavy hip thrusts because it teaches both extension and knee control.',
          'muscle_heatmap': [
            {'muscle': 'Glutes', 'intensity': 5},
            {'muscle': 'Glute Med', 'intensity': 4},
            {'muscle': 'Hamstrings', 'intensity': 2},
          ],
        },
        {
          'id': 'beginner_cardio_1',
          'name': 'March in Place',
          'primary_muscle': 'Cardio',
          'equipment': 'Bodyweight',
          'environment': 'Home',
          'difficulty': 'Beginner',
          'animation_key': 'cardio',
          'video_url': '',
          'instructions': [
            'Stand tall and lift one knee at a time.',
            'Swing the opposite arm naturally.',
            'Keep ribs stacked over hips.',
            'Gradually increase pace while staying smooth.',
          ],
          'form_cues': [
            'Land softly through the midfoot.',
            'Keep the torso tall rather than leaning back.',
          ],
          'common_mistakes': [
            'Stomping the feet down and losing rhythm.',
            'Leaning backward to get knees higher.',
          ],
          'beginner_tip':
              'Use this as a low-impact cardio option or a warm-up before jogging, high knees, or jumping jacks.',
          'muscle_heatmap': [
            {'muscle': 'Hip Flexors', 'intensity': 3},
            {'muscle': 'Calves', 'intensity': 2},
            {'muscle': 'Heart', 'intensity': 4},
          ],
        },
      ]);

      return mock.where((e) {
        if (muscle != null && e['primary_muscle'] != muscle) return false;
        if (equipment != null && e['equipment'] != equipment) return false;
        if (environment != null && e['environment'] != environment) {
          return false;
        }
        return true;
      }).toList();
    }
  }

  static List<Map<String, dynamic>> _mergeExerciseCatalogs(
    List<Map<String, dynamic>> localCatalog,
    List<Map<String, dynamic>> remoteCatalog,
  ) {
    final merged = <String, Map<String, dynamic>>{};

    for (final exercise in localCatalog) {
      final key = (exercise['name'] ?? '').toString().trim().toLowerCase();
      if (key.isEmpty) continue;
      merged[key] = Map<String, dynamic>.from(exercise);
    }

    for (final exercise in remoteCatalog) {
      final key = (exercise['name'] ?? '').toString().trim().toLowerCase();
      if (key.isEmpty) continue;
      merged[key] = {
        ...(merged[key] ?? const <String, dynamic>{}),
        ...Map<String, dynamic>.from(exercise),
      };
    }

    final result = merged.values.toList(growable: false)
      ..sort(
        (a, b) => (a['name'] ?? '').toString().toLowerCase().compareTo(
          (b['name'] ?? '').toString().toLowerCase(),
        ),
      );
    return result;
  }

  /// Fetches available workout programs.
  static Future<List<Map<String, dynamic>>> getWorkoutPrograms() async {
    final res = await _retry(
      () => client
          .from('workout_programs')
          .select()
          .order('created_at', ascending: false),
    );
    return List<Map<String, dynamic>>.from(res);
  }

  /// Fetches sessions (days) within a specific program.
  static Future<List<Map<String, dynamic>>> getProgramSessions(
    String programId,
  ) async {
    final res = await _retry(
      () => client
          .from('workout_program_sessions')
          .select()
          .eq('program_id', programId)
          .order('day_number', ascending: true),
    );
    return List<Map<String, dynamic>>.from(res);
  }

  /// Fetches exercises prescribed for a specific program session.
  static Future<List<Map<String, dynamic>>> getProgramExercises(
    String sessionId,
  ) async {
    final res = await _retry(
      () => client
          .from('workout_program_exercises')
          .select('*, exercises(*)')
          .eq('session_id', sessionId)
          .order('order_index', ascending: true),
    );
    return List<Map<String, dynamic>>.from(res);
  }

  /// Enrolls a user in a multi-week workout program.
  static Future<void> enrollInProgram(String userId, String programId) async {
    await _retry(
      () => client.from('user_program_enrollments').upsert({
        'user_id': userId,
        'program_id': programId,
        'started_at': DateTime.now().toIso8601String(),
      }),
    );
  }

  /// Gets the user's active program enrollments.
  static Future<List<Map<String, dynamic>>> getUserEnrollments(
    String userId,
  ) async {
    final res = await _retry(
      () => client
          .from('user_program_enrollments')
          .select('*, workout_programs(*)')
          .eq('user_id', userId)
          .eq('is_completed', false),
    );
    return List<Map<String, dynamic>>.from(res);
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

  // ─── NEW: AI Coach Memory ────────────────────────────────────────────────────

  /// NEW: Get AI coach memory object for user
  static Future<Map<String, dynamic>> getAiCoachMemory(String userId) async {
    try {
      final res = await client
          .from('profiles')
          .select('ai_coach_memory')
          .eq('id', userId)
          .maybeSingle();
      return (res?['ai_coach_memory'] as Map<String, dynamic>?) ?? {};
    } catch (_) {
      return {};
    }
  }

  /// NEW: Save updated AI coach memory
  static Future<void> saveAiCoachMemory(
    String userId,
    Map<String, dynamic> memory,
  ) async {
    try {
      await client
          .from('profiles')
          .update({'ai_coach_memory': memory})
          .eq('id', userId);
    } catch (_) {}
  }

  /// NEW: Save a coach conversation session
  static Future<void> saveAiCoachSession({
    required String userId,
    required List<Map<String, dynamic>> messages,
    String? summary,
    Map<String, dynamic>? keyFacts,
  }) async {
    try {
      await client.from('ai_coach_sessions').insert({
        'user_id': userId,
        'messages': messages,
        'summary': summary,
        'key_facts': keyFacts ?? {},
      });
    } catch (_) {}
  }

  // ─── NEW: Mood Tracking ──────────────────────────────────────────────────────

  /// NEW: Save user mood for today
  static Future<void> saveMoodToday(String userId, int mood) async {
    try {
      await client.from('profiles').update({
        'today_mood': mood.clamp(1, 5),
        'mood_updated_at': DateTime.now().toIso8601String().split('T')[0],
      }).eq('id', userId);
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════════════
  // NEW: Activities — GPS-tracked sessions
  // ═══════════════════════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> createActivity(
    Map<String, dynamic> activity,
  ) async {
    final res = await _retry(
      () => client.from('activities').insert(activity).select().single(),
    );
    return Map<String, dynamic>.from(res as Map);
  }

  static Future<List<Map<String, dynamic>>> getActivities(
    String userId, {
    int limit = 20,
  }) async {
    final res = await _retry(
      () => client
          .from('activities')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit),
    );
    return (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<Map<String, dynamic>?> getActivityById(
    String activityId,
  ) async {
    try {
      final res = await _retry(
        () => client.from('activities').select().eq('id', activityId).single(),
      );
      return Map<String, dynamic>.from(res as Map);
    } catch (_) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // NEW: GPS Points
  // ═══════════════════════════════════════════════════════════════════════

  static Future<void> createGpsPoints(
    List<Map<String, dynamic>> points,
  ) async {
    if (points.isEmpty) return;
    // Insert in batches of 500
    for (var i = 0; i < points.length; i += 500) {
      final batch = points.sublist(
        i,
        i + 500 > points.length ? points.length : i + 500,
      );
      await _retry(() => client.from('gps_points').insert(batch));
    }
  }

  static Future<List<Map<String, dynamic>>> getGpsPoints(
    String activityId,
  ) async {
    final res = await _retry(
      () => client
          .from('gps_points')
          .select()
          .eq('activity_id', activityId)
          .order('recorded_at'),
    );
    return (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // NEW: Health Metrics
  // ═══════════════════════════════════════════════════════════════════════

  static Future<void> upsertHealthMetrics(
    Map<String, dynamic> metrics,
  ) async {
    await _retry(
      () => client.from('health_metrics').upsert(
        metrics,
        onConflict: 'user_id,recorded_at',
      ),
    );
  }

  static Future<List<Map<String, dynamic>>> getHealthMetricsSince(
    String userId,
    String sinceDate,
  ) async {
    final res = await _retry(
      () => client
          .from('health_metrics')
          .select()
          .eq('user_id', userId)
          .gte('recorded_at', sinceDate)
          .order('recorded_at', ascending: false),
    );
    return (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // NEW: Water Logs
  // ═══════════════════════════════════════════════════════════════════════

  static Future<void> logWater(String userId, int amountMl) async {
    await _retry(
      () => client.from('water_logs').insert({
        'user_id': userId,
        'amount_ml': amountMl,
      }),
    );
  }

  static Future<int> getTodayWater(String userId) async {
    final today = DateTime.now().toIso8601String().split('T').first;
    final res = await _retry(
      () => client
          .from('water_logs')
          .select('amount_ml')
          .eq('user_id', userId)
          .gte('logged_at', '${today}T00:00:00'),
    );
    final list = res as List;
    int total = 0;
    for (final r in list) {
      total += ((r as Map)['amount_ml'] as int?) ?? 0;
    }
    return total;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // NEW: Training Load
  // ═══════════════════════════════════════════════════════════════════════

  static Future<void> upsertTrainingLoad(
    Map<String, dynamic> load,
  ) async {
    await _retry(
      () => client.from('training_load').upsert(
        load,
        onConflict: 'user_id,week_start',
      ),
    );
  }

  static Future<List<Map<String, dynamic>>> getTrainingLoadHistory(
    String userId, {
    int weeks = 12,
  }) async {
    final since = DateTime.now()
        .subtract(Duration(days: weeks * 7))
        .toIso8601String()
        .split('T')
        .first;
    final res = await _retry(
      () => client
          .from('training_load')
          .select()
          .eq('user_id', userId)
          .gte('week_start', since)
          .order('week_start', ascending: false),
    );
    return (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}
