import '../services/storage_service.dart';
import '../services/social_service.dart';
import '../services/supabase_service.dart';
import 'auth_repository.dart';

class WorkoutCompletionResult {
  final bool savedOffline;
  final Map<String, dynamic>? savedLog;

  const WorkoutCompletionResult({required this.savedOffline, this.savedLog});
}

class WorkoutCloneResult {
  final Map<String, dynamic> workout;
  final int clonedExerciseCount;

  const WorkoutCloneResult({
    required this.workout,
    required this.clonedExerciseCount,
  });
}

class WorkoutRepository {
  const WorkoutRepository();

  Future<List<Map<String, dynamic>>> getCurrentUserWorkouts() {
    return SupabaseService.getWorkouts(authRepository.requireUserId());
  }

  Future<List<Map<String, dynamic>>> getPreviousWorkoutStats(
    String workoutName,
  ) {
    return SupabaseService.getPreviousWorkoutStats(
      authRepository.requireUserId(),
      workoutName,
    );
  }

  Future<Map<String, dynamic>> createWorkout(String name, String type) {
    return SupabaseService.createWorkout(
      authRepository.requireUserId(),
      name,
      type,
    );
  }

  Future<List<Map<String, dynamic>>> getWorkoutPrograms() {
    return SupabaseService.getWorkoutPrograms();
  }

  Future<void> enrollInProgram(String programId) {
    return SupabaseService.enrollInProgram(
      authRepository.requireUserId(),
      programId,
    );
  }

  Future<WorkoutCloneResult> cloneWorkoutFromSocialPost(
    Map<String, dynamic> post,
  ) async {
    final baseName = post['workout_name']?.toString().trim();
    final clonedName =
        '${(baseName == null || baseName.isEmpty) ? 'Workout' : baseName} (Cloned)';
    final workout = await createWorkout(clonedName, _inferWorkoutType(post));

    final sourceLogId = post['id']?.toString();
    if (sourceLogId == null || sourceLogId.isEmpty) {
      return WorkoutCloneResult(workout: workout, clonedExerciseCount: 0);
    }

    final exercises = await SocialService.getWorkoutTemplateFromLog(
      sourceLogId,
    );
    if (exercises.isNotEmpty) {
      await SupabaseService.createExercises(
        exercises
            .map((exercise) => {...exercise, 'workout_id': workout['id']})
            .toList(),
      );
    }

    return WorkoutCloneResult(
      workout: workout,
      clonedExerciseCount: exercises.length,
    );
  }

  Future<WorkoutCompletionResult> completeWorkoutSession({
    required Map<String, dynamic> logPayload,
    required List<Map<String, dynamic>> sets,
  }) async {
    Map<String, dynamic>? createdLog;

    try {
      createdLog = await SupabaseService.createWorkoutLog(
        Map<String, dynamic>.from(logPayload),
      );

      if (sets.isNotEmpty) {
        final setsWithLogId = sets
            .map(
              (set) => {
                ...Map<String, dynamic>.from(set),
                'log_id': createdLog!['id'],
              },
            )
            .toList();
        try {
          await SupabaseService.createSetLogs(setsWithLogId);
        } catch (error) {
          await SupabaseService.deleteWorkoutLog(createdLog['id'] as String);
          rethrow;
        }
      }

      await StorageService.clearActiveWorkoutState();
      return WorkoutCompletionResult(savedOffline: false, savedLog: createdLog);
    } catch (_) {
      await StorageService.saveOfflineWorkout({
        ...Map<String, dynamic>.from(logPayload),
        'sets': sets.map((set) => Map<String, dynamic>.from(set)).toList(),
      });
      await StorageService.clearActiveWorkoutState();
      return const WorkoutCompletionResult(savedOffline: true);
    }
  }

  Future<void> syncOfflineQueue() {
    return SupabaseService.syncOfflineWorkouts();
  }
}

const workoutRepository = WorkoutRepository();

String _inferWorkoutType(Map<String, dynamic> post) {
  final fingerprint =
      '${post['type'] ?? ''} ${post['workout_name'] ?? ''} ${post['notes'] ?? ''}'
          .toLowerCase();
  if (fingerprint.contains('run') || fingerprint.contains('cardio')) {
    return 'Cardio';
  }
  if (fingerprint.contains('hiit') || fingerprint.contains('circuit')) {
    return 'HIIT';
  }
  if (fingerprint.contains('mobility')) {
    return 'Mobility';
  }
  return 'Gym';
}
