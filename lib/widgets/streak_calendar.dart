import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';
import 'apex_card.dart';

class StreakCalendar extends StatelessWidget {
  final List<Map<String, dynamic>> logs;

  const StreakCalendar({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    final workoutDates = <String>{};
    final intensityMap = <String, String>{};
    for (final log in logs) {
      final date = (log['completed_at'] as String?)?.split('T')[0];
      if (date != null) {
        workoutDates.add(date);
        intensityMap[date] = (log['intensity'] as String?) ?? 'moderate';
      }
    }

    final today = DateTime.now();
    var start = today.subtract(const Duration(days: 27));
    while (start.weekday != DateTime.sunday) {
      start = start.subtract(const Duration(days: 1));
    }

    final weeks = <List<DateTime>>[];
    var day = start;
    for (int week = 0; week < 5; week++) {
      final currentWeek = <DateTime>[];
      for (int index = 0; index < 7; index++) {
        currentWeek.add(day);
        day = day.add(const Duration(days: 1));
      }
      weeks.add(currentWeek);
    }

    Color fillFor(DateTime date) {
      final key = _key(date);
      final isToday = _isSameDay(date, today);
      final isSunday = date.weekday == DateTime.sunday;
      final hasWorkout = workoutDates.contains(key);
      final intensity = intensityMap[key];

      if (isSunday) return ApexColors.surface;
      if (hasWorkout) {
        if (intensity == 'heavy') return ApexColors.orange.withAlpha(58);
        if (intensity == 'light') return ApexColors.accentDim;
        return ApexColors.blue.withAlpha(54);
      }
      if (isToday) return ApexColors.accentDim;
      if (date.isBefore(today)) return ApexColors.surface;
      return Colors.transparent;
    }

    Color borderFor(DateTime date) {
      final key = _key(date);
      final isToday = _isSameDay(date, today);
      final isSunday = date.weekday == DateTime.sunday;
      final hasWorkout = workoutDates.contains(key);
      final intensity = intensityMap[key];

      if (isSunday) return ApexColors.border;
      if (hasWorkout) {
        if (intensity == 'heavy') return ApexColors.orange;
        if (intensity == 'light') return ApexColors.accentSoft;
        return ApexColors.blue;
      }
      if (isToday) return ApexColors.accentSoft;
      return ApexColors.border.withAlpha(140);
    }

    return ApexCard(
      floating: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Training calendar',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: ApexColors.t1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'A quick view of your last five training weeks.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: ApexColors.t2,
                      ),
                    ),
                  ],
                ),
              ),
              _legend('Heavy', ApexColors.orange),
              const SizedBox(width: 8),
              _legend('Moderate', ApexColors.blue),
              const SizedBox(width: 8),
              _legend('Light', ApexColors.accentSoft),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                .map(
                  (label) => Expanded(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: label == 'S' ? ApexColors.t3 : ApexColors.t2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 6),
          ...weeks.map(
            (week) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: week.map((date) {
                  final isToday = _isSameDay(date, today);
                  return Expanded(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: fillFor(date),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderFor(date)),
                          boxShadow: isToday
                              ? [
                                  BoxShadow(
                                    color: ApexColors.accentSoft.withAlpha(36),
                                    blurRadius: 12,
                                  ),
                                ]
                              : null,
                        ),
                        child: isToday
                            ? Center(
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: ApexColors.accent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              'Sundays stay clear for recovery.',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: ApexColors.t3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _key(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _legend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: ApexColors.t3,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
