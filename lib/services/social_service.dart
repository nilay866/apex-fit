import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class SocialService {
  static SupabaseClient get client => SupabaseService.client;

  static String _requireUserId({String action = 'continue'}) {
    return SupabaseService.requireUserId(action: action);
  }

  /// Fetches the profiles of all users to enable global search.
  /// In a production environment, this would be paginated or server-side filtered.
  static Future<List<Map<String, dynamic>>> searchProfiles(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return [];

    // SEC-FIX: Escape LIKE wildcards from user input to prevent filter bypass
    final escaped = normalized.replaceAll('%', r'\%').replaceAll('_', r'\_');
    final myId = SupabaseService.currentUser?.id;

    try {
      final res = await client
          .from('profiles')
          .select('id, name, avatar_data, goal')
          .or('name.ilike.%$escaped%, email.ilike.%$escaped%')
          .limit(10);
      return _dedupeProfiles(List<Map<String, dynamic>>.from(res), myId);
    } catch (_) {
      final res = await client
          .from('profiles')
          .select('id, name, avatar_data, goal')
          .ilike('name', '%$escaped%')
          .limit(10);
      return _dedupeProfiles(List<Map<String, dynamic>>.from(res), myId);
    }
  }

  /// Establishes a connection between two users.
  static Future<void> connectWithUser(String otherUserId) async {
    final myId = _requireUserId(action: 'connect with other athletes');
    if (myId == otherUserId) return;

    await client.from('connections').upsert([
      {'user_id': myId, 'friend_id': otherUserId, 'status': 'accepted'},
      {'user_id': otherUserId, 'friend_id': myId, 'status': 'accepted'},
    ], onConflict: 'user_id,friend_id');
  }

  /// Fetches activity from connected friends.
  static Future<List<Map<String, dynamic>>> getSocialFeed() async {
    final myId = _requireUserId(action: 'load your social feed');
    return getSocialFeedPage(userId: myId, offset: 0, limit: 20);
  }

  static Future<List<Map<String, dynamic>>> getSocialFeedPage({
    required String userId,
    required int offset,
    required int limit,
  }) async {
    try {
      late final List<dynamic> connections;
      try {
        connections = await client
            .from('connections')
            .select('user_id, friend_id, status')
            .or('user_id.eq.$userId,friend_id.eq.$userId')
            .eq('status', 'accepted');
      } catch (_) {
        connections = await client
            .from('connections')
            .select('user_id, friend_id')
            .or('user_id.eq.$userId,friend_id.eq.$userId');
      }

      final friendIds = <String>{};
      for (final raw in connections) {
        final connection = Map<String, dynamic>.from(raw as Map);
        final userA = connection['user_id']?.toString();
        final userB = connection['friend_id']?.toString();
        if (userA == null || userB == null) continue;

        if (userA == userId && userB.isNotEmpty) {
          friendIds.add(userB);
        } else if (userB == userId && userA.isNotEmpty) {
          friendIds.add(userA);
        }
      }

      if (friendIds.isEmpty) return [];

      final logs = await client
          .from('workout_logs')
          .select('*, profiles(name, avatar_data)')
          .inFilter('user_id', friendIds.toList())
          .order('completed_at', ascending: false)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(logs);
    } catch (_) {
      return [];
    }
  }

  /// Calculates "Me vs You" stats.
  static Future<Map<String, dynamic>> getVersusStats(String otherId) async {
    final myId = _requireUserId(action: 'compare workout stats');

    final myLogs = await client
        .from('workout_logs')
        .select('total_volume, duration_min')
        .eq('user_id', myId);

    final theirLogs = await client
        .from('workout_logs')
        .select('total_volume, duration_min')
        .eq('user_id', otherId);

    double myVolume = 0;
    double theirVolume = 0;

    for (final log in myLogs) {
      myVolume += (log['total_volume'] as num?)?.toDouble() ?? 0;
    }
    for (final log in theirLogs) {
      theirVolume += (log['total_volume'] as num?)?.toDouble() ?? 0;
    }

    return {
      'my_volume': myVolume,
      'their_volume': theirVolume,
      'my_count': myLogs.length,
      'their_count': theirLogs.length,
    };
  }

  static Future<List<Map<String, dynamic>>> getWorkoutTemplateFromLog(
    String logId,
  ) async {
    try {
      final rows = await client
          .from('set_logs')
          .select('exercise_name, reps_done, weight_kg, set_number')
          .eq('log_id', logId)
          .order('set_number', ascending: true);

      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final raw in rows as List) {
        final row = Map<String, dynamic>.from(raw as Map);
        final name = row['exercise_name']?.toString().trim() ?? '';
        if (name.isEmpty) continue;
        grouped.putIfAbsent(name, () => []).add(row);
      }

      return grouped.entries
          .map((entry) {
            final sets = entry.value;
            num? reps;
            num? weight;

            for (final set in sets) {
              final nextReps = num.tryParse(set['reps_done']?.toString() ?? '');
              final nextWeight = num.tryParse(
                set['weight_kg']?.toString() ?? '',
              );
              if (nextReps != null && nextReps > 0) {
                reps = nextReps;
              }
              if (nextWeight != null && nextWeight > 0) {
                weight = nextWeight;
              }
            }

            return {
              'name': entry.key,
              'sets': sets.length,
              'reps': reps != null ? reps.round().toString() : '10',
              'target_weight': weight?.toDouble(),
            };
          })
          .toList(growable: false);
    } catch (_) {
      return [];
    }
  }

  static List<Map<String, dynamic>> _dedupeProfiles(
    List<Map<String, dynamic>> profiles,
    String? myId,
  ) {
    final deduped = <String, Map<String, dynamic>>{};
    for (final profile in profiles) {
      final id = profile['id']?.toString();
      if (id == null || id.isEmpty || id == myId) continue;
      deduped[id] = profile;
    }
    return deduped.values.toList(growable: false);
  }
}
