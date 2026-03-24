class ProgressForecastService {
  /// Given a list of {date, weight} data points, compute a linear regression
  /// and project forward [daysAhead] days.
  /// Returns a list of projected {date, projected_weight} maps.
  static List<Map<String, dynamic>> forecast({
    required List<Map<String, dynamic>> historicalData,
    int daysAhead = 60,
  }) {
    if (historicalData.length < 3) return [];

    try {
      // Parse data into (x=day_index, y=weight) pairs
      final baseDate = DateTime.tryParse(
        historicalData.first['date']?.toString() ?? '',
      );
      if (baseDate == null) return [];

      final points = <(double, double)>[];
      for (final d in historicalData) {
        final date = DateTime.tryParse(d['date']?.toString() ?? '');
        final weight = double.tryParse(d['weight']?.toString() ?? '');
        if (date != null && weight != null) {
          final x = date.difference(baseDate).inDays.toDouble();
          points.add((x, weight));
        }
      }

      if (points.length < 2) return [];

      // Linear regression
      final n = points.length.toDouble();
      final sumX = points.fold(0.0, (a, p) => a + p.$1);
      final sumY = points.fold(0.0, (a, p) => a + p.$2);
      final sumXY = points.fold(0.0, (a, p) => a + p.$1 * p.$2);
      final sumX2 = points.fold(0.0, (a, p) => a + p.$1 * p.$1);

      final denom = n * sumX2 - sumX * sumX;
      if (denom == 0) return [];

      final slope = (n * sumXY - sumX * sumY) / denom;
      final intercept = (sumY - slope * sumX) / n;

      // Generate projected points
      final lastX = points.last.$1;
      final projections = <Map<String, dynamic>>[];

      for (int i = 1; i <= daysAhead; i += 7) {
        final x = lastX + i;
        final projDate = baseDate.add(Duration(days: x.round()));
        final projWeight = intercept + slope * x;
        projections.add({
          'date': projDate.toIso8601String().split('T')[0],
          'projected_weight': projWeight.clamp(0, double.infinity),
          'is_projection': true,
        });
      }

      return projections;
    } catch (_) {
      return [];
    }
  }

  /// Returns a human-readable prediction string, e.g.
  /// "At your current rate, you'll hit 100kg by Aug 15"
  static String? buildPredictionLabel({
    required List<Map<String, dynamic>> historicalData,
    required double targetWeight,
  }) {
    try {
      final projections =
          forecast(historicalData: historicalData, daysAhead: 180);
      for (final p in projections) {
        final w = (p['projected_weight'] as double?) ?? 0;
        if (w >= targetWeight) {
          final date = DateTime.tryParse(p['date']?.toString() ?? '');
          if (date == null) return null;
          const months = [
            'Jan',
            'Feb',
            'Mar',
            'Apr',
            'May',
            'Jun',
            'Jul',
            'Aug',
            'Sep',
            'Oct',
            'Nov',
            'Dec',
          ];
          return 'At your current rate → ${targetWeight.round()}kg by '
              '${months[date.month - 1]} ${date.day}';
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
