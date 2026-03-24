class Achievement {
  final String id;
  final String title;
  final String description;
  final String icon;
  final String color; // hex string

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'icon': icon,
    'color': color,
  };
}

class AchievementService {
  static final List<Achievement> availableAchievements = [
    Achievement(
      id: 'first_workout',
      title: 'First Step',
      description: 'Completed your first workout session.',
      icon: 'stars_rounded',
      color: '0xFF4FC3F7',
    ),
    Achievement(
      id: 'streak_7',
      title: 'Consistent',
      description: 'Hit a 7-day training streak.',
      icon: 'local_fire_department_rounded',
      color: '0xFFFF8C42',
    ),
    Achievement(
      id: 'volume_10k',
      title: 'Iron Enthusiast',
      description: 'Lifted a total volume of 10,000kg.',
      icon: 'fitness_center_rounded',
      color: '0xFFBB86FC',
    ),
    Achievement(
      id: 'distance_50km',
      title: 'Marathoner',
      description: 'Covered over 50km in total running distance.',
      icon: 'directions_run_rounded',
      color: '0xFF03DAC6',
    ),
    Achievement(
      id: 'month_warrior',
      title: 'Monthly Warrior',
      description: 'Completed 20 workouts in a single month.',
      icon: 'workspace_premium_rounded',
      color: '0xFFFFD700',
    ),
  ];

  static Future<List<Achievement>> checkAchievements(
    List<Map<String, dynamic>> logs,
    int streak,
  ) async {
    final unlocked = <Achievement>[];

    // 1. First Workout
    if (logs.isNotEmpty) {
      unlocked.add(
        availableAchievements.firstWhere((a) => a.id == 'first_workout'),
      );
    }

    // 2. 7-Day Streak
    if (streak >= 7) {
      unlocked.add(availableAchievements.firstWhere((a) => a.id == 'streak_7'));
    }

    // 3. 10k Volume
    double totalVol = 0;
    for (final log in logs) {
      totalVol += (log['total_volume'] as num?)?.toDouble() ?? 0;
    }
    if (totalVol >= 10000) {
      unlocked.add(
        availableAchievements.firstWhere((a) => a.id == 'volume_10k'),
      );
    }

    // 4. 50km Distance
    // Note: This requires filtering cardio logs. For now, we'll assume distance is stored in notes or meta if not in a separate field.
    // In a real app, we'd have a 'total_distance' field in workout_logs.
    // For this mock, let's look for cardio entries.
    double totalDist = 0;
    for (final log in logs) {
      if (log['workout_name']?.toString().toLowerCase().contains('run') ??
          false) {
        // Mock distance extraction if not in schema
        totalDist +=
            (log['duration_min'] as num? ?? 0) * 0.15; // Rough estimate: 9km/h
      }
    }
    if (totalDist >= 50) {
      unlocked.add(
        availableAchievements.firstWhere((a) => a.id == 'distance_50km'),
      );
    }

    // 5. 20 Workouts in a month
    final now = DateTime.now();
    final monthLogs = logs.where((log) {
      final date = DateTime.tryParse(log['completed_at'] ?? '');
      return date != null && date.year == now.year && date.month == now.month;
    }).length;
    if (monthLogs >= 20) {
      unlocked.add(
        availableAchievements.firstWhere((a) => a.id == 'month_warrior'),
      );
    }

    return unlocked;
  }
}
