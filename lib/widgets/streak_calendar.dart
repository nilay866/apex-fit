import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';
import 'apex_card.dart';

class StreakCalendar extends StatefulWidget {
  final List<Map<String, dynamic>> logs;
  final List<Map<String, dynamic>> photos;
  final List<Map<String, dynamic>> nutritionLogs;
  final List<Map<String, dynamic>> waterLogs;
  final List<Map<String, dynamic>> weightLogs;

  const StreakCalendar({
    super.key,
    required this.logs,
    required this.photos,
    required this.nutritionLogs,
    required this.waterLogs,
    required this.weightLogs,
  });

  @override
  State<StreakCalendar> createState() => _StreakCalendarState();
}

class _StreakCalendarState extends State<StreakCalendar> {
  late DateTime _focusedMonth;

  @override
  void initState() {
    super.initState();
    _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  }

  void _prevMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
    });
  }

  void _showDayDetails(DateTime date) {
    final key = _key(date);
    final dayLogs = widget.logs.where((l) => (l['completed_at'] as String?)?.startsWith(key) ?? false).toList();
    final dayPhotos = widget.photos.where((p) => (p['taken_at'] as String?)?.startsWith(key) ?? false).toList();
    final dayNutrition = widget.nutritionLogs.where((l) => (l['logged_at'] as String?)?.startsWith(key) ?? false).toList();
    final dayWater = widget.waterLogs.where((l) => (l['logged_at'] as String?)?.startsWith(key) ?? false).toList();
    final dayWeight = widget.weightLogs.where((l) => (l['logged_at'] as String?)?.startsWith(key) ?? false).toList();

    final totalWater = dayWater.fold<int>(0, (sum, l) => sum + (l['amount_ml'] as int? ?? 0));
    final totalCals = dayNutrition.fold<int>(0, (sum, l) => sum + (l['calories'] as int? ?? 0));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ApexColors.surfaceStrong,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ListView(
            controller: scrollController,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: ApexColors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '${date.day} ${_monthName(date.month)} ${date.year}',
                style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: ApexColors.t1),
              ),
              const SizedBox(height: 24),
              
              if (dayLogs.isEmpty && dayPhotos.isEmpty && dayNutrition.isEmpty && totalWater == 0 && dayWeight.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: Text('No activity recorded for this day.', style: TextStyle(color: ApexColors.t3, fontSize: 13))),
                ),

              // Summary Stats Row
              Row(
                children: [
                  if (totalCals > 0) _summaryItem(Icons.restaurant_rounded, '$totalCals', 'kcal', ApexColors.accent),
                  if (totalWater > 0) _summaryItem(Icons.water_drop_rounded, '$totalWater', 'ml', ApexColors.blue),
                  if (dayWeight.isNotEmpty) _summaryItem(Icons.monitor_weight_rounded, '${dayWeight.last['weight_kg']}', 'kg', ApexColors.purple),
                ],
              ),
              if (totalCals > 0 || totalWater > 0 || dayWeight.isNotEmpty) const SizedBox(height: 24),

              if (dayLogs.isNotEmpty) ...[
                _sectionHeader('WORKOUTS'),
                ...dayLogs.map((l) => _dataItem(
                  Icons.fitness_center_rounded, 
                  l['workout_name'] ?? 'Workout', 
                  '${l['duration_min']}m · ${l['total_volume']}kg',
                  ApexColors.accent
                )),
                const SizedBox(height: 20),
              ],

              if (dayNutrition.isNotEmpty) ...[
                _sectionHeader('MEALS'),
                ...dayNutrition.map((l) => _dataItem(
                  Icons.restaurant_rounded, 
                  l['name'] ?? 'Meal', 
                  '${l['calories']} kcal',
                  ApexColors.accentSoft
                )),
                const SizedBox(height: 20),
              ],

              if (dayPhotos.isNotEmpty) ...[
                _sectionHeader('PROGRESS PHOTOS'),
                SizedBox(
                  height: 160,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: dayPhotos.length,
                    itemBuilder: (ctx, i) {
                      try {
                        final data = dayPhotos[i]['photo_data']?.toString() ?? dayPhotos[i]['path']?.toString() ?? '';
                        if (data.isEmpty) return const SizedBox.shrink();
                        String base64Str = data.contains(',') ? data.split(',')[1] : data;
                        return Container(
                          width: 120,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: ApexColors.border.withAlpha(40)),
                            image: DecorationImage(
                              image: MemoryImage(base64Decode(base64Str)),
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      } catch (e) {
                        return Container(
                          width: 120,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: ApexColors.surface,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(Icons.broken_image_rounded, color: ApexColors.t3),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: ApexColors.t3, letterSpacing: 1.2)),
    );
  }

  Widget _dataItem(IconData icon, String title, String sub, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ApexColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ApexColors.border.withAlpha(40)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withAlpha(15), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: ApexColors.t1, fontSize: 14)),
                const SizedBox(height: 2),
                Text(sub, style: GoogleFonts.inter(color: ApexColors.t3, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(IconData icon, String val, String unit, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withAlpha(10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withAlpha(40)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(val, style: GoogleFonts.dmMono(fontWeight: FontWeight.w800, fontSize: 16, color: ApexColors.t1)),
            Text(unit, style: GoogleFonts.inter(fontSize: 10, color: ApexColors.t3, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workoutDates = <String>{};
    final intensityMap = <String, String>{};
    final photoDates = <String>{};

    for (final log in widget.logs) {
      final date = (log['completed_at'] as String?)?.split('T')[0];
      if (date != null) {
        workoutDates.add(date);
        intensityMap[date] = (log['intensity'] as String?) ?? 'moderate';
      }
    }

    for (final photo in widget.photos) {
      final date = (photo['taken_at'] as String?)?.split('T')[0];
      if (date != null) {
        photoDates.add(date);
      }
    }

    final today = DateTime.now();
    
    // Month View logic starting from 1st
    final firstOfMonth = _focusedMonth;
    var start = firstOfMonth.subtract(Duration(days: firstOfMonth.weekday % 7));
    
    final weeks = <List<DateTime>>[];
    var day = start;
    // Show 6 weeks to ensure all months fit
    for (int week = 0; week < 6; week++) {
      final currentWeek = <DateTime>[];
      for (int index = 0; index < 7; index++) {
        currentWeek.add(day);
        day = day.add(const Duration(days: 1));
      }
      weeks.add(currentWeek);
      // Stop if we've reached the next month and finished the week
      if (day.month != firstOfMonth.month && day.weekday == DateTime.sunday) break;
    }

    Color fillFor(DateTime date) {
      final key = _key(date);
      final isToday = _isSameDay(date, today);
      final hasWorkout = workoutDates.contains(key);
      final intensity = intensityMap[key];

      if (hasWorkout) {
        if (intensity == 'heavy') return ApexColors.orange.withAlpha(82);
        if (intensity == 'light') return ApexColors.accentSoft.withAlpha(200);
        return ApexColors.blue.withAlpha(82);
      }
      if (isToday) return ApexColors.t3.withAlpha(44);
      return Colors.transparent;
    }

    Color borderFor(DateTime date) {
      final key = _key(date);
      final isToday = _isSameDay(date, today);
      final hasWorkout = workoutDates.contains(key);
      final intensity = intensityMap[key];

      if (hasWorkout) {
        if (intensity == 'heavy') return ApexColors.orange;
        if (intensity == 'light') return ApexColors.accentSoft;
        return ApexColors.blue;
      }
      if (isToday) return ApexColors.t3;
      return ApexColors.border.withAlpha(60);
    }

    Color textFor(DateTime date) {
      final key = _key(date);
      final hasWorkout = workoutDates.contains(key);
      if (hasWorkout) return ApexColors.bg;
      if (_isSameDay(date, today)) return ApexColors.t1;
      return ApexColors.t3;
    }

    final monthString = '${_monthName(_focusedMonth.month)} ${_focusedMonth.year}'.toUpperCase();
    
    return ApexCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
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
                      fontSize: 18,
                      color: ApexColors.t1,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: _prevMonth,
                    icon: const Icon(Icons.chevron_left_rounded, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: ApexColors.t3,
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: _nextMonth,
                    icon: const Icon(Icons.chevron_right_rounded, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: ApexColors.t3,
                  ),
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
                  final isOutsideMonth = date.month != _focusedMonth.month;
                  return Expanded(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: GestureDetector(
                        onTap: () => _showDayDetails(date),
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

  String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _monthName(int m) => [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December'
      ][m - 1];
}
