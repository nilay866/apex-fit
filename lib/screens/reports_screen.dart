import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';
import '../constants/theme.dart';
import '../widgets/apex_button.dart';
import '../widgets/apex_card.dart';
import '../widgets/apex_screen_header.dart';
import '../widgets/apex_trend_chart.dart';
import '../widgets/macro_bar.dart';
import '../widgets/heatmaps_painter.dart';
import '../services/supabase_service.dart';
import '../services/plan_generator_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _period = 'week';
  List<Map<String, dynamic>> _wLogs = [];
  List<Map<String, dynamic>> _nLogs = [];
  List<Map<String, dynamic>> _bwLogs = [];
  List<Map<String, dynamic>> _waterLogs = [];
  bool _loading = true;
  final _bwC = TextEditingController();
  bool _savingBw = false;
  String? _waterError;
  bool _show1RM = false;

  @override
  void initState() {
    super.initState();
    _load();
    _bwC.addListener(() {
      if (mounted) setState(() {});
    });
  }

  int get _days =>
      {'day': 1, 'week': 7, 'month': 30, 'year': 365}[_period] ?? 7;

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final userId = SupabaseService.requireUserId(action: 'load your reports');
      final since = DateTime.now().subtract(Duration(days: _days));
      final waterFuture = SupabaseService.getWaterLogs(userId, since: since);
      final results = await Future.wait([
        SupabaseService.getWorkoutLogsSince(userId, since),
        SupabaseService.getNutritionLogs(userId, since: since),
        SupabaseService.getBodyWeightLogs(userId),
      ]);
      List<Map<String, dynamic>> waterLogs = [];
      String? waterError;
      try {
        waterLogs = await waterFuture;
      } catch (e) {
        waterError = SupabaseService.describeError(e);
      }
      if (!mounted) return;
      setState(() {
        _wLogs = results[0];
        _nLogs = results[1];
        _bwLogs = results[2];
        _waterLogs = waterLogs;
        _waterError = waterError;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _logBw() async {
    final w = double.tryParse(_bwC.text);
    if (w == null) return;
    setState(() => _savingBw = true);

    try {
      final userId = SupabaseService.requireUserId(action: 'log body weight');
      await SupabaseService.createBodyWeightLog(userId, w);
      final bw = await SupabaseService.getBodyWeightLogs(userId);
      if (mounted) {
        setState(() {
          _bwLogs = bw;
        });
        _bwC.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(SupabaseService.describeError(e)),
            backgroundColor: ApexColors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _savingBw = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalVol = _wLogs.fold<int>(
      0,
      (a, l) => a + ((l['total_volume'] as num?)?.round() ?? 0),
    );
    final totalCal = _nLogs.fold<int>(
      0,
      (a, l) => a + ((l['calories'] as int?) ?? 0),
    );
    final mealDays = _nLogs
        .map((l) => l['logged_at']?.toString().split('T')[0])
        .whereType<String>()
        .toSet()
        .length;
    final avgCal = mealDays > 0 ? (totalCal / mealDays).round() : 0;
    final avgWater = _waterLogs.isNotEmpty
        ? (_waterLogs.fold<int>(
                    0,
                    (a, w) => a + ((w['amount_ml'] as int?) ?? 0),
                  ) /
                  (_waterLogs
                      .map((w) => w['logged_at']?.toString().split('T')[0])
                      .toSet()
                      .length
                      .clamp(1, 999)))
              .round()
        : 0;

    final workoutValues = _buildDailyValues(_wLogs, 'completed_at', (_) => 1);
    final mealValues = _buildDailyValues(_nLogs, 'logged_at', (_) => 1);
    final calorieValues = _buildDailyValues(
      _nLogs,
      'logged_at',
      (l) => (l['calories'] as num?)?.toDouble() ?? 0,
    );
    final waterValues = _buildDailyValues(
      _waterLogs,
      'logged_at',
      (l) => (l['amount_ml'] as num?)?.toDouble() ?? 0,
    );
    final labels = _buildLabels();
    final bwValues = _bwLogs
        .take(10)
        .toList()
        .reversed
        .map((entry) => (entry['weight_kg'] as num).toDouble())
        .toList();
    final achievements = _buildAchievements(
      workouts: _wLogs.length,
      totalVolume: totalVol,
      mealDays: mealDays,
      avgWater: avgWater,
      weighIns: _bwLogs.length,
    );

    return RefreshIndicator(
      onRefresh: _load,
      color: ApexColors.accent,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          ApexScreenHeader(
            eyebrow: 'Stats',
            title: 'Reports',
            subtitle:
                'Achievements, graphs, and daily signals that feel more like a game board.',
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _show1RM = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: !_show1RM ? ApexColors.accent : ApexColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ApexColors.border),
                    ),
                    child: Center(
                      child: Text(
                        'Dashboard',
                        style: TextStyle(
                          color: !_show1RM ? ApexColors.bg : ApexColors.t2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _show1RM = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _show1RM ? ApexColors.purple : ApexColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ApexColors.border),
                    ),
                    child: Center(
                      child: Text(
                        '1RM Extrapolation',
                        style: TextStyle(
                          color: _show1RM ? ApexColors.bg : ApexColors.t2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(36),
                child: CircularProgressIndicator(color: ApexColors.accent),
              ),
            )
          else if (_show1RM)
            _build1RMDashboard()
          else ...[
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: ApexColors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: ApexColors.borderStrong),
                boxShadow: [
                  BoxShadow(
                    color: ApexColors.shadow.withAlpha(22),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _periodTab('day', 'Today'),
                  _periodTab('week', 'Week'),
                  _periodTab('month', 'Month'),
                  _periodTab('year', 'Year'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(height: 24),
            ApexCard(
              glow: true,
              glowColor: ApexColors.accent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Habit Dashboard',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: ApexColors.t1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Daily unified radial tracking goals.',
                    style: TextStyle(fontSize: 12, color: ApexColors.t2),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildRing(
                        'Water\n${(avgWater / 1000).toStringAsFixed(1)}L',
                        (avgWater / 3000).clamp(0.0, 1.0),
                        ApexColors.cyan,
                      ),
                      _buildRing(
                        'Protein\n${_avgMacro('protein_g')}g',
                        (_avgMacro('protein_g') / 160).clamp(0.0, 1.0),
                        ApexColors.blue,
                      ),
                      _buildRing(
                        'Workouts\n${_wLogs.length}',
                        (_wLogs.length / (_days / 2)).clamp(0.0, 1.0),
                        ApexColors.accentSoft,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildHeatmapCard(),
            const SizedBox(height: 12),
            _buildContributionGraph(),
            const SizedBox(height: 12),
            _achievementHub(achievements),
            const SizedBox(height: 12),
            _graphCard(
              title: 'Workout graph',
              subtitle: 'Daily training hits across the selected period.',
              value: '${_wLogs.length} sessions',
              valueColor: ApexColors.accentSoft,
              chart: ApexTrendChart(
                values: workoutValues,
                labels: labels,
                color: ApexColors.accentSoft,
                height: 178,
              ),
            ),
            const SizedBox(height: 12),
            ApexCard(
              glow: true,
              glowColor: ApexColors.orange,
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
                            'Meals and calories',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: ApexColors.t1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Meal bars with calorie lines attached below for quick reading.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: ApexColors.t2,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${_nLogs.length} meals',
                            style: ApexTheme.mono(
                              size: 16,
                              color: ApexColors.orange,
                            ),
                          ),
                          Text(
                            '$avgCal avg kcal/day',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: ApexColors.t3,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Meals',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: ApexColors.t3,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ApexTrendChart(
                    values: mealValues,
                    labels: labels,
                    color: ApexColors.orange,
                    height: 130,
                    compact: true,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Calories line',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: ApexColors.t3,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ApexLineTrendChart(
                    values: calorieValues,
                    color: ApexColors.red,
                    height: 120,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _graphCard(
              title: 'Water graph',
              subtitle: 'Hydration trend by day.',
              value: '${(avgWater / 1000).toStringAsFixed(1)}L avg/day',
              valueColor: ApexColors.cyan,
              chart: ApexTrendChart(
                values: waterValues,
                labels: labels,
                color: ApexColors.cyan,
                height: 172,
              ),
            ),
            if (_waterError != null) ...[
              const SizedBox(height: 10),
              ApexCard(
                child: Text(
                  _waterError!,
                  style: const TextStyle(
                    color: ApexColors.red,
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            ApexCard(
              glow: true,
              glowColor: ApexColors.purple,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Body weight graph',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                color: ApexColors.t1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Smooth line for weight movement with quick logging.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: ApexColors.t2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 68,
                            child: TextField(
                              key: const ValueKey('body_weight_input'),
                              controller: _bwC,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: ApexTheme.mono(size: 11),
                              decoration: const InputDecoration(
                                hintText: 'kg',
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          ApexButton(
                            key: const ValueKey('body_weight_log_button'),
                            text: 'Log',
                            onPressed: _logBw,
                            sm: true,
                            loading: _savingBw,
                            disabled: _bwC.text.isEmpty,
                            color: ApexColors.purple,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (bwValues.length < 2)
                    Center(
                      child: Text(
                        'Log 2+ weigh-ins to see the graph',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: ApexColors.t3,
                        ),
                      ),
                    )
                  else ...[
                    ApexLineTrendChart(
                      values: bwValues,
                      color: ApexColors.purple,
                      height: 132,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _bwStat(
                          'Start',
                          '${_bwLogs.last['weight_kg']}kg',
                          ApexColors.t2,
                        ),
                        const SizedBox(width: 14),
                        _bwStat(
                          'Latest',
                          '${_bwLogs.first['weight_kg']}kg',
                          ApexColors.purple,
                        ),
                        const SizedBox(width: 14),
                        _bwStat(
                          'Δ',
                          '${((_bwLogs.first['weight_kg'] as num) - (_bwLogs.last['weight_kg'] as num)).toStringAsFixed(1)}kg',
                          (_bwLogs.first['weight_kg'] as num) <
                                  (_bwLogs.last['weight_kg'] as num)
                              ? ApexColors.accentSoft
                              : ApexColors.orange,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_nLogs.isNotEmpty)
              ApexCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Macro board',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: ApexColors.t1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    MacroBar(
                      label: 'Protein',
                      value: _avgMacro('protein_g'),
                      goal: 160,
                      color: ApexColors.blue,
                    ),
                    MacroBar(
                      label: 'Carbs',
                      value: _avgMacro('carbs_g'),
                      goal: 250,
                      color: ApexColors.orange,
                    ),
                    MacroBar(
                      label: 'Fat',
                      value: _avgMacro('fat_g'),
                      goal: 70,
                      color: ApexColors.purple,
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _achievementHub(List<_Achievement> achievements) {
    return ApexCard(
      glow: true,
      glowColor: ApexColors.yellow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _AchievementBeacon(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Achievement board',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: ApexColors.t1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      achievements.isEmpty
                          ? 'No trophies unlocked in this window yet. Keep stacking workouts and meals.'
                          : '${achievements.length} unlocked for this period. Your completed goals surface here like a game dashboard.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: ApexColors.t2,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (achievements.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ApexColors.cardAlt,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: ApexColors.borderStrong),
              ),
              child: Text(
                'Try hitting 4 workouts, 5 meal-tracking days, 2.2L average hydration, or multiple weigh-ins to unlock your first trophy.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: ApexColors.t2,
                  height: 1.55,
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: achievements.map((achievement) {
                  return Padding(
                    padding: EdgeInsets.only(
                      right: achievement == achievements.last ? 0 : 10,
                    ),
                    child: Container(
                      width: 188,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white,
                            achievement.color.withAlpha(18),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: achievement.color.withAlpha(76),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: achievement.color.withAlpha(18),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: achievement.color.withAlpha(18),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              achievement.icon,
                              color: achievement.color,
                              size: 20,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            achievement.title,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: ApexColors.t1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            achievement.detail,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: ApexColors.t2,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _graphCard({
    required String title,
    required String subtitle,
    required String value,
    required Color valueColor,
    required Widget chart,
  }) {
    return ApexCard(
      glow: true,
      glowColor: valueColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: ApexColors.t1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: ApexColors.t2,
                      ),
                    ),
                  ],
                ),
              ),
              Text(value, style: ApexTheme.mono(size: 16, color: valueColor)),
            ],
          ),
          const SizedBox(height: 14),
          chart,
        ],
      ),
    );
  }

  List<double> _buildDailyValues(
    List<Map<String, dynamic>> logs,
    String dateField,
    double Function(Map<String, dynamic>) valFn,
  ) {
    final map = <String, double>{};
    for (int i = _days - 1; i >= 0; i--) {
      final d = DateTime.now().subtract(Duration(days: i));
      map['${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}'] =
          0;
    }
    for (final l in logs) {
      final d = (l[dateField] as String?)?.split('T')[0];
      if (d != null && map.containsKey(d)) {
        map[d] = (map[d] ?? 0) + valFn(l);
      }
    }
    return map.values.toList();
  }

  List<String> _buildLabels() {
    return List.generate(_days, (index) {
      final d = DateTime.now().subtract(Duration(days: _days - index - 1));
      if (_days <= 7) {
        return ['S', 'M', 'T', 'W', 'T', 'F', 'S'][d.weekday % 7];
      }
      if (_days <= 30) {
        return index % 5 == 0 ? '${d.day}' : '';
      }
      return d.day == 1 ? _monthShort(d.month) : '';
    });
  }

  List<_Achievement> _buildAchievements({
    required int workouts,
    required int totalVolume,
    required int mealDays,
    required int avgWater,
    required int weighIns,
  }) {
    final achievements = <_Achievement>[];
    if (workouts >= 4) {
      achievements.add(
        const _Achievement(
          title: 'Consistency Combo',
          detail: '4 or more workouts locked in during this window.',
          icon: Icons.bolt_rounded,
          color: ApexColors.accentSoft,
        ),
      );
    }
    if (totalVolume >= 5000) {
      achievements.add(
        const _Achievement(
          title: 'Volume Hunter',
          detail: 'You crossed 5000kg of total training volume.',
          icon: Icons.fitness_center_rounded,
          color: ApexColors.blue,
        ),
      );
    }
    if (mealDays >= math.min(5, _days)) {
      achievements.add(
        const _Achievement(
          title: 'Meal Lock',
          detail: 'Nutrition logging stayed active across enough days.',
          icon: Icons.restaurant_rounded,
          color: ApexColors.orange,
        ),
      );
    }
    if (avgWater >= 2200) {
      achievements.add(
        const _Achievement(
          title: 'Hydration Flow',
          detail: 'Average water intake stayed above 2.2L.',
          icon: Icons.water_drop_rounded,
          color: ApexColors.cyan,
        ),
      );
    }
    if (weighIns >= 3) {
      achievements.add(
        const _Achievement(
          title: 'Scale Keeper',
          detail: 'Multiple weigh-ins mean the body trend is now reliable.',
          icon: Icons.monitor_weight_rounded,
          color: ApexColors.purple,
        ),
      );
    }
    return achievements;
  }

  double _avgMacro(String field) {
    final days = _nLogs
        .map((l) => l['logged_at']?.toString().split('T')[0])
        .toSet()
        .length
        .clamp(1, 999);
    return _nLogs.fold<double>(
          0,
          (a, l) => a + ((l[field] as num?)?.toDouble() ?? 0),
        ) /
        days;
  }

  String _monthShort(int month) {
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
    return months[month - 1];
  }

  Widget _periodTab(String id, String label) {
    final selected = _period == id;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _period = id);
          _load();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? ApexColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? ApexColors.ink : ApexColors.t2,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }

  Widget _bwStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(fontSize: 9, color: ApexColors.t3),
        ),
        const SizedBox(height: 1),
        Text(value, style: ApexTheme.mono(size: 14, color: color)),
      ],
    );
  }

  Widget _build1RMDashboard() {
    final Map<String, double> top1RM = {};
    final Map<String, List<double>> history1RM = {};

    // Parse sequentially chronologically (reversed from wLogs which is newest first)
    for (final w in _wLogs.reversed) {
      final exs = (w['exercises'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      for (final ex in exs) {
        final name = ex['name']?.toString() ?? 'Unknown';
        final sets = (ex['sets'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        double sessionMax = 0;
        for (final s in sets) {
          if (s['done'] == true) {
            final weight = double.tryParse(s['weight'].toString()) ?? 0.0;
            final reps = int.tryParse(s['reps'].toString()) ?? 0;
            if (weight > 0 && reps > 0) {
              final rm = SmartCoach.estimate1RM(weight, reps);
              if (!top1RM.containsKey(name) || rm > top1RM[name]!) {
                top1RM[name] = rm;
              }
              if (rm > sessionMax) sessionMax = rm;
            }
          }
        }
        if (sessionMax > 0) {
          history1RM.putIfAbsent(name, () => []).add(sessionMax);
        }
      }
    }

    if (top1RM.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
          child: Column(
            children: [
              const Icon(
                Icons.calculate,
                size: 64,
                color: ApexColors.accentSoft,
              ),
              const SizedBox(height: 16),
              Text(
                'No 1RM Data',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: ApexColors.t1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Log at least one completed set with weight and reps to generate extrapolation tables.',
                textAlign: TextAlign.center,
                style: TextStyle(color: ApexColors.t2, height: 1.5),
              ),
            ],
          ),
        ),
      );
    }

    final entries = top1RM.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: entries.map((e) {
        final name = e.key;
        final rm = e.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: ApexCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: ApexColors.t1,
                        ),
                      ),
                    ),
                    Text(
                      '${rm.round()} kg',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: ApexColors.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Estimated 1 Rep Max',
                  style: TextStyle(fontSize: 12, color: ApexColors.t3),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [100, 95, 90, 85, 80, 75, 70, 65, 60, 55, 50].map((
                    pct,
                  ) {
                    final w = SmartCoach.prescribedWeight(rm, pct / 100);
                    final isTop = pct >= 90;
                    return Container(
                      width: 72,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: ApexColors.bg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isTop
                              ? ApexColors.red.withAlpha(50)
                              : ApexColors.border,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$pct%',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: isTop ? ApexColors.red : ApexColors.t3,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${w.round()}',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: ApexColors.t1,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                if (history1RM.containsKey(name) &&
                    history1RM[name]!.length > 1) ...[
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '1RM Progression trajectory',
                        style: TextStyle(
                          fontSize: 12,
                          color: ApexColors.t2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${history1RM[name]!.length} sessions',
                        style: TextStyle(fontSize: 10, color: ApexColors.t3),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ApexLineTrendChart(
                    values: history1RM[name]!,
                    color: ApexColors.accentSoft,
                    height: 100,
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRing(String label, double progress, Color color) {
    return Column(
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: 1.0,
                strokeWidth: 8,
                color: color.withAlpha(25),
              ),
              CircularProgressIndicator(
                value: progress,
                strokeWidth: 8,
                color: color,
                strokeCap: StrokeCap.round,
              ),
              Center(
                child: Text(
                  '${(progress * 100).round()}%',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: ApexColors.t1,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: ApexColors.t2,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildHeatmapCard() {
    final Map<String, double> intensities = {
      'Head': 0,
      'Shoulders': 0,
      'Chest': 0,
      'Core': 0,
      'Arms': 0,
      'Legs': 0,
    };
    for (var w in _wLogs) {
      final n = w['name'].toString().toLowerCase();
      if (n.contains('push') || n.contains('chest')) {
        intensities['Chest'] = (intensities['Chest']! + 0.2).clamp(0.0, 1.0);
      }
      if (n.contains('pull') || n.contains('back')) {
        intensities['Arms'] = (intensities['Arms']! + 0.2).clamp(0.0, 1.0);
      }
      if (n.contains('leg') || n.contains('squat')) {
        intensities['Legs'] = (intensities['Legs']! + 0.3).clamp(0.0, 1.0);
      }
      if (n.contains('core') || n.contains('abs') || n.contains('hiit')) {
        intensities['Core'] = (intensities['Core']! + 0.25).clamp(0.0, 1.0);
      }
      if (n.contains('shoulder')) {
        intensities['Shoulders'] = (intensities['Shoulders']! + 0.3).clamp(
          0.0,
          1.0,
        );
      }
    }

    return ApexCard(
      glow: true,
      glowColor: ApexColors.red,
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
                    'Volume Heatmap',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: ApexColors.t1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '3D anatomical distribution',
                    style: TextStyle(fontSize: 12, color: ApexColors.t2),
                  ),
                ],
              ),
              const Icon(Icons.accessibility_new_rounded, color: ApexColors.t3),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: SizedBox(
              width: 140,
              height: 200,
              child: CustomPaint(
                painter: AnatomyHeatmapPainter(intensity: intensities),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildContributionGraph() {
    final now = DateTime.now();
    final days = List.generate(84, (i) => now.subtract(Duration(days: 83 - i)));

    final Set<String> activeDates = _wLogs.map((w) {
      final iso = w['completed_at']?.toString();
      if (iso == null) return '';
      return iso.split('T')[0];
    }).toSet();

    return ApexCard(
      glow: true,
      glowColor: ApexColors.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Contribution Heatmap',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: ApexColors.t1,
                ),
              ),
              Text(
                '${activeDates.length} days active',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: ApexColors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Consistency over the last 12 weeks',
            style: TextStyle(fontSize: 12, color: ApexColors.t2),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 110,
            child: GridView.builder(
              reverse: false,
              padding: EdgeInsets.zero,
              scrollDirection: Axis.horizontal,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemCount: days.length,
              itemBuilder: (ctx, i) {
                final d = days[i];
                final ds =
                    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                final active = activeDates.contains(ds);
                return Container(
                  decoration: BoxDecoration(
                    color: active ? ApexColors.accent : ApexColors.surface,
                    borderRadius: BorderRadius.circular(3),
                    border: active
                        ? null
                        : Border.all(color: ApexColors.border),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _bwC.dispose();
    super.dispose();
  }
}

class _Achievement {
  final String title;
  final String detail;
  final IconData icon;
  final Color color;

  const _Achievement({
    required this.title,
    required this.detail,
    required this.icon,
    required this.color,
  });
}

class _AchievementBeacon extends StatefulWidget {
  const _AchievementBeacon();

  @override
  State<_AchievementBeacon> createState() => _AchievementBeaconState();
}

class _AchievementBeaconState extends State<_AchievementBeacon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final scale = 0.96 + (_controller.value * 0.1);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [ApexColors.yellow, ApexColors.orange],
              ),
              boxShadow: [
                BoxShadow(
                  color: ApexColors.yellow.withAlpha(
                    36 + (_controller.value * 32).round(),
                  ),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: ApexColors.ink,
              size: 30,
            ),
          ),
        );
      },
    );
  }
}
