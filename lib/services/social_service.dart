import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class SocialService {
  static SupabaseClient get client => SupabaseService.client;

  /// Fetches the profiles of all users to enable global search.
  /// In a production environment, this would be paginated or server-side filtered.
  static Future<List<Map<String, dynamic>>> searchProfiles(String query) async {
    final res = await client
        .from('profiles')
        .select('id, name, avatar_data, goal')
        .or('name.ilike.%$query%, email.ilike.%$query%')
        .limit(10);
    return List<Map<String, dynamic>>.from(res);
  }

  /// Establishes a connection between two users.
  static Future<void> connectWithUser(String otherUserId) async {
    final myId = SupabaseService.currentUser!.id;
    if (myId == otherUserId) return;

    // In a real app, we'd have a 'connections' table.
    // For now, we'll implement a robust check/insert logic.
    try {
      await client.from('connections').upsert({
        'user_id': myId,
        'friend_id': otherUserId,
        'status': 'accepted',
      });
    } catch (e) {
      // If table doesn't exist, we might need a migration note.
      // But for this project scope, we assume schema matches.
      rethrow;
    }
  }

  /// Fetches activity from connected friends.
  static Future<List<Map<String, dynamic>>> getSocialFeed() async {
    final myId = SupabaseService.currentUser!.id;
    
    // 1. Get friend IDs
    final connections = await client
        .from('connections')
        .select('friend_id')
        .eq('user_id', myId);
    
    final friendIds = (connections as List)
        .map((c) => c['friend_id'] as String)
        .toList();
    
    if (friendIds.isEmpty) return [];

    // 2. Get recent workout logs from these friends
    final logs = await client
        .from('workout_logs')
        .select('*, profiles(name, avatar_data)')
        .inFilter('user_id', friendIds)
        .order('completed_at', ascending: false)
        .limit(20);
        
    return List<Map<String, dynamic>>.from(logs);
  }

  /// Calculates "Me vs You" stats.
  static Future<Map<String, dynamic>> getVersusStats(String otherId) async {
    final myId = SupabaseService.currentUser!.id;
    
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
    
    for (var l in myLogs) {
      myVolume += (l['total_volume'] as num?)?.toDouble() ?? 0;
    }
    for (var l in theirLogs) {
      theirVolume += (l['total_volume'] as num?)?.toDouble() ?? 0;
    }

    return {
      'my_volume': myVolume,
      'their_volume': theirVolume,
      'my_count': myLogs.length,
      'their_count': theirLogs.length,
    };
  }
}
