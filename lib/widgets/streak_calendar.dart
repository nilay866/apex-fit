import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';
import 'apex_card.dart';

class StreakCalendar extends StatelessWidget {
  final List<Map<String, dynamic>> logs;
  final List<Map<String, dynamic>> photos;

  const StreakCalendar({super.key, required this.logs, required this.photos});

  @override
  Widget build(BuildContext context) {
    final workoutDates = <String>{};
    final intensityMap = <String, String>{};
    final photoDates = <String>{};

    for (final log in logs) {
      final date = (log['completed_at'] as String?)?.split('T')[0];
      if (date != null) {
        workoutDates.add(date);
        intensityMap[date] = (log['intensity'] as String?) ?? 'moderate';
      }
    }

    for (final photo in photos) {
      final date = (photo['taken_at'] as String?)?.split('T')[0];
      if (date != null) {
        photoDates.add(date);
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

      if (hasWorkout) {
        if (intensity == 'heavy') return ApexColors.orange.withAlpha(82);
        if (intensity == 'light') return ApexColors.accentSoft.withAlpha(200);
        return ApexColors.blue.withAlpha(82);
      }
      if (isToday) return ApexColors.t3.withAlpha(44);
      if (isSunday) return Colors.transparent;
      if (date.isBefore(today)) return ApexColors.surface;
      return Colors.transparent;
    }

    Color borderFor(DateTime date) {
      final key = _key(date);
      final isToday = _isSameDay(date, today);
      final isSunday = date.weekday == DateTime.sunday;
      final hasWorkout = workoutDates.contains(key);
      final intensity = intensityMap[key];

      if (hasWorkout) {
        if (intensity == 'heavy') return ApexColors.orange;
        if (intensity == 'light') return ApexColors.accentSoft;
        return ApexColors.blue;
      }
      if (isToday) return ApexColors.t3;
      if (isSunday || date.isAfter(today)) return ApexColors.border.withAlpha(60);
      return ApexColors.border.withAlpha(140);
    }

    Color textFor(DateTime date) {
      final key = _key(date);
      final hasWorkout = workoutDates.contains(key);
      if (hasWorkout) return ApexColors.bg;
      if (_isSameDay(date, today)) return ApexColors.t1;
      return ApexColors.t3;
    }

    final monthString = '${_monthName(today.month)} ${today.year}'.toUpperCase();
    
    return ApexCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TRAINING LOG',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        color: ApexColors.t3,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      monthString,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        color: ApexColors.t1,
                      ),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                alignment: WrapAlignment.end,
                children: [
                  _legend('Heavy', ApexColors.orange),
                  _legend('Mod', ApexColors.blue),
                  _legend('Light', ApexColors.accentSoft),
                  _legend('Photo', ApexColors.purple),
                ],
              ),
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
                  final isOutsideMonth = date.month != today.month;
                  return Expanded(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: fillFor(date),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderFor(date)),
                        ),
                        alignment: Alignment.center,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Text(
                              '${date.day}',
                              style: GoogleFonts.dmMono(
                                fontSize: 11,
                                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                                color: isOutsideMonth ? textFor(date).withAlpha(100) : textFor(date),
                              ),
                            ),
                            if (photoDates.contains(_key(date)))
                              Positioned(
                                bottom: 4,
                                child: Container(
                                  width: 3.5,
                                  height: 3.5,
                                  decoration: const BoxDecoration(
                                    color: ApexColors.purple,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
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

  static String _monthName(int m) {
    const names = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return names[m];
  }
}
