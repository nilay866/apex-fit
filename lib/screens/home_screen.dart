import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/colors.dart';
import '../constants/theme.dart';
import '../widgets/apex_card.dart';
import '../widgets/apex_button.dart';
import '../widgets/apex_tag.dart';
import '../widgets/apex_screen_header.dart';
import '../widgets/apex_trend_chart.dart';
import '../widgets/streak_calendar.dart';
import '../services/ai_service.dart';
import '../services/health_service.dart';
import '../services/supabase_service.dart';
import '../services/cache_service.dart';

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic>? profile;
  final Function(Map<String, dynamic>) onStartWorkout;

  const HomeScreen({super.key, this.profile, required this.onStartWorkout});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _logs = [];
  List<Map<String, dynamic>> _workouts = [];
  List<Map<String, dynamic>> _nutritionLogs = [];
  List<Map<String, dynamic>> _waterLogs = [];
  List<Map<String, dynamic>> _bwLogs = [];
  List<Map<String, dynamic>> _photos = [];

  // Statistical Notifiers for surgical UI updates
  late final ValueNotifier<int> _waterNotifier;
  late final ValueNotifier<int> _stepsNotifier;
  late final ValueNotifier<double> _energyNotifier;
  late final ValueNotifier<int> _calorieNotifier;

  bool _loading = false;
  String _suggestion = '';
  bool _loadingSug = false;
  bool _addWater = false;
  String _waterAmt = '250';
  bool _savingWater = false;
  String? _waterError;

  @override
  void initState() {
    super.initState();
    // Synchronous hydration from cache for sub-20ms TTI
    _logs = cache.get<List<Map<String, dynamic>>>(CacheService.keyHomeLogs) ?? [];
    _workouts = cache.get<List<Map<String, dynamic>>>(CacheService.keyHomeWorkouts) ?? [];
    _waterLogs = cache.get<List<Map<String, dynamic>>>(CacheService.keyWaterLogs) ?? [];
    
    _waterNotifier = ValueNotifier<int>(_calculateTotalWater(_waterLogs));
    _stepsNotifier = ValueNotifier<int>(0);
    _energyNotifier = ValueNotifier<double>(0.0);
    _calorieNotifier = ValueNotifier<int>(0);

    _load();
  }

  int _calculateTotalWater(List<Map<String, dynamic>> logs) {
    return logs.fold(0, (sum, log) => sum + (log['amount_ml'] as int? ?? 0));
  }

  @override
  void dispose() {
    _waterNotifier.dispose();
    _stepsNotifier.dispose();
    _energyNotifier.dispose();
    _calorieNotifier.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    // If we have cached data, we don't show the skeleton loader
    if (_logs.isEmpty && _workouts.isEmpty) {
      setState(() => _loading = true);
    }

    final userId = SupabaseService.currentUser!.id;
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    
    try {
      final results = await Future.wait([
        SupabaseService.getWorkoutLogs(userId, limit: 14),
        SupabaseService.getWorkouts(userId),
        SupabaseService.getNutritionLogs(userId, since: DateTime.parse('${todayStr}T00:00:00')),
        SupabaseService.getBodyWeightLogs(userId, limit: 3),
        SupabaseService.getProgressPhotos(userId),
        SupabaseService.getWaterLogs(userId, since: DateTime.parse('${todayStr}T00:00:00')),
      ]);
      
      final healthData = await HealthService.fetchDailySummary();

      if (!mounted) return;

      // Atomic state update and cache persistence
      setState(() {
        _logs = results[0];
        _workouts = results[1];
        _nutritionLogs = results[2];
        _bwLogs = results[3];
        _photos = results[4];
        _waterLogs = results[5];
        _loading = false;
        
        // Update notifiers without triggering full rebuild
        _waterNotifier.value = _calculateTotalWater(_waterLogs);
        _stepsNotifier.value = healthData['steps'] as int;
        _energyNotifier.value = healthData['energy'] as double;
        _calorieNotifier.value = _nutritionLogs.fold(0, (sum, l) => sum + (l['calories'] as int? ?? 0));
        
        // Sync to Holographic Cache
        cache.setList(CacheService.keyHomeLogs, _logs);
        cache.setList(CacheService.keyHomeWorkouts, _workouts);
        cache.setList(CacheService.keyWaterLogs, _waterLogs);
      });
      
      _loadSuggestion();
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadSuggestion() async {
    setState(() => _loadingSug = true);
    final recentNames = _logs
        .take(3)
        .map((l) => l['workout_name']?.toString() ?? '')
        .toList();
    final dayOfWeek = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ][DateTime.now().weekday - 1];
    final goal = widget.profile?['goal'] ?? 'Build Muscle';
    try {
      final s = await AIService.getDailySuggestion(
        goal: goal,
        recentWorkouts: recentNames,
        dayOfWeek: dayOfWeek,
      );
      if (mounted) {
        setState(() {
          _suggestion = s;
          _loadingSug = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _suggestion = 'Focus on compound lifts today.';
          _loadingSug = false;
        });
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      maxWidth: 1200,
      imageQuality: 70,
    );
    if (file == null) return;

    setState(() => _loading = true);

    try {
      final bytes = await FlutterImageCompress.compressWithFile(
        file.path,
        quality: 60,
        minWidth: 800,
        minHeight: 800,
        format: CompressFormat.jpeg,
      ) ?? await file.readAsBytes();
      
      final base64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      await SupabaseService.createProgressPhoto(
        SupabaseService.currentUser!.id,
        base64,
        null, // Optional caption could be added later
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Progress photo added to your journey!'),
            backgroundColor: ApexColors.accent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: ${SupabaseService.describeError(e)}'),
            backgroundColor: ApexColors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      setState(() => _loading = false);
    }
  }

  void _showAddPhotoSource() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: ApexColors.surfaceStrong,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Capture Progress',
              style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18, color: ApexColors.t1),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ApexButton(
                    text: 'Camera',
                    icon: Icons.camera_alt_outlined,
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _pickImage(ImageSource.camera);
                    },
                    tone: ApexButtonTone.outline,
                    full: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ApexButton(
                    text: 'Gallery',
                    icon: Icons.photo_library_outlined,
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _pickImage(ImageSource.gallery);
                    },
                    tone: ApexButtonTone.outline,
                    full: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _logWater() async {
    final ml = int.tryParse(_waterAmt);
    if (ml == null || ml <= 0) return;
    setState(() {
      _savingWater = true;
      _addWater = false;
    });
    try {
      final log = await SupabaseService.createWaterLog(
        SupabaseService.currentUser!.id,
        ml,
      );
      if (!mounted) return;

      // Surgical update via notifier instead of full screen rebuild
      _waterLogs = [..._waterLogs, log];
      _waterNotifier.value = _calculateTotalWater(_waterLogs);
      cache.setList(CacheService.keyWaterLogs, _waterLogs);
      
      setState(() {
        _waterAmt = '250';
        _waterError = null;
      });
    } catch (e) {
      final message = SupabaseService.describeError(e);
      if (!mounted) return;
      setState(() => _waterError = message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: ApexColors.red),
      );
    }
    if (mounted) {
      setState(() => _savingWater = false);
    }
  }

  int get _streak {
    final dates = _logs
        .map((l) => (l['completed_at'] as String?)?.split('T')[0])
        .whereType<String>()
        .toSet();
    int s = 0;
    final now = DateTime.now();
    for (int i = 0; i < 60; i++) {
      final d = now.subtract(Duration(days: i));
      if (d.weekday == DateTime.sunday) continue;
      final ds =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      if (dates.contains(ds)) {
        s++;
      } else if (i > 0) {
        break;
      }
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final calGoal = (widget.profile?['calorie_goal'] as int?) ?? 2000;
    final waterGoal = (widget.profile?['water_goal_ml'] as int?) ?? 2500;
    final latestBW = _bwLogs.isNotEmpty ? _bwLogs[0]['weight_kg'] : null;
    final hour = DateTime.now().hour;
    final greet = hour < 12
        ? 'Morning'
        : hour < 17
        ? 'Afternoon'
        : 'Evening';
    final firstName =
        (widget.profile?['name'] ??
                SupabaseService.currentUser?.email ??
                'Athlete')
            .toString()
            .split(' ')[0];
    final suggestedWorkout = _workouts.isNotEmpty ? _workouts.first : null;
    final weeklyVolume = _buildDailyValues(
      _logs,
      7,
      'completed_at',
      (l) => (l['total_volume'] as num?)?.toDouble() ?? 0,
    );
    final journeyStages = _buildJourneyStages();

    return RefreshIndicator(
      onRefresh: _load,
      color: ApexColors.accent,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          ApexScreenHeader(
            eyebrow: 'Dashboard',
            title: firstName,
            subtitle:
                'Good $greet. Your overview moves with your training week.',
            trailing: _streak > 0 ? _streakBadge() : null,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FutureBuilder<bool>(
              future: HealthService.isSyncEnabled(),
              builder: (context, snapshot) {
                final enabled = snapshot.data ?? false;
                if (enabled) {
                  return ApexTag(
                    text: 'Health sync active',
                    color: ApexColors.t2,
                  );
                }
                return InkWell(
                  onTap: () async {
                    final granted = await HealthService.requestPermissions();
                    if (granted) _load();
                  },
                  borderRadius: BorderRadius.circular(99),
                  child: ApexTag(
                    text: 'Tap to sync steps & energy',
                    color: ApexColors.accent,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              ApexTag(text: widget.profile?['goal'] ?? 'Build Muscle'),
              if (latestBW != null)
                ApexTag(text: '${latestBW}kg', color: ApexColors.blue),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ValueListenableBuilder<int>(
                  valueListenable: _calorieNotifier,
                  builder: (context, val, _) {
                    return _statCard(
                      'Calories',
                      val,
                      calGoal,
                      Icons.local_fire_department_rounded,
                      ApexColors.orange,
                      'kcal',
                    );
                  },
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: ValueListenableBuilder<int>(
                  valueListenable: _waterNotifier,
                  builder: (context, val, _) {
                    return _waterCard(val, waterGoal);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_addWater) _buildWaterInput(),
          if (_waterError != null) ...[
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
            const SizedBox(height: 14),
          ],
          ApexCard(
            glow: true,
            glowColor: ApexColors.purple,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [ApexColors.purple, ApexColors.blue],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: ApexColors.ink,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'COACH NOTE',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: ApexColors.t3,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _loadingSug
                              ? Row(
                                  children: [
                                    const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: ApexColors.purple,
                                      ),
                                    ),
                                    const SizedBox(width: 7),
                                    Text(
                                      'Thinking through your next move...',
                                      style: GoogleFonts.inter(
                                        color: ApexColors.t2,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  _suggestion.isNotEmpty
                                      ? _suggestion
                                      : 'Ready to train!',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: ApexColors.t1,
                                    height: 1.6,
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (suggestedWorkout != null) ...[
                  const SizedBox(height: 14),
                  ApexButton(
                    text: 'Start ${suggestedWorkout['name']}',
                    icon: Icons.play_arrow_rounded,
                    onPressed: () => widget.onStartWorkout(suggestedWorkout),
                    full: true,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          _journeyGallery(journeyStages),
          const SizedBox(height: 14),
          RepaintBoundary(
            child: StreakCalendar(logs: _logs, photos: _photos),
          ),
          const SizedBox(height: 14),
          ApexCard(
            glow: true,
            glowColor: ApexColors.blue,
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
                          '7-day momentum',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: ApexColors.t1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Animated bar view of your recent training volume.',
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
                          '${weeklyVolume.fold<double>(0, (a, b) => a + b).round()}kg',
                          style: ApexTheme.mono(
                            size: 18,
                            color: ApexColors.blue,
                          ),
                        ),
                        Text(
                          'last 7 days',
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
                RepaintBoundary(
                  child: ApexTrendChart(
                    values: weeklyVolume,
                    labels: _buildDayLabels(7),
                    color: ApexColors.blue,
                    height: 166,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              _miniStat(
                Icons.stacked_bar_chart_rounded,
                _loading ? '—' : '${_logs.length}',
                'Sessions',
                ApexColors.accentSoft,
              ),
              _miniStat(
                Icons.show_chart_rounded,
                _loading
                    ? '—'
                    : '${_logs.fold<int>(0, (a, l) => a + ((l['total_volume'] as num?)?.round() ?? 0))}kg',
                'Volume',
                ApexColors.blue,
              ),
              _miniStat(
                Icons.schedule_rounded,
                _loading
                    ? '—'
                    : '${_logs.fold<int>(0, (a, l) => a + ((l['duration_min'] as int?) ?? 0))}m',
                'Time',
                ApexColors.purple,
              ),
              ValueListenableBuilder<int>(
                valueListenable: _stepsNotifier,
                builder: (context, val, _) {
                  return _miniStat(
                    Icons.directions_run_rounded,
                    _loading ? '—' : '$val',
                    'Steps',
                    ApexColors.accent,
                  );
                },
              ),
              ValueListenableBuilder<double>(
                valueListenable: _energyNotifier,
                builder: (context, val, _) {
                  return _miniStat(
                    Icons.bolt_rounded,
                    _loading ? '—' : '${val.round()}',
                    'Energy',
                    ApexColors.orange,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Recent sessions',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: ApexColors.t1,
            ),
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: CircularProgressIndicator(color: ApexColors.accent),
              ),
            )
          else if (_logs.isEmpty)
            ApexCard(
              child: Center(
                child: Text(
                  'No sessions yet. Start your first workout!',
                  style: const TextStyle(color: ApexColors.t3, fontSize: 12),
                ),
              ),
            )
          else
            ..._logs.take(4).map(_sessionCard),
        ],
      ),
    );
  }

  Widget _streakBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ApexColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ApexColors.orange.withAlpha(110)),
        boxShadow: [
          BoxShadow(
            color: ApexColors.orange.withAlpha(20),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.local_fire_department_rounded,
                size: 16,
                color: ApexColors.orange,
              ),
              const SizedBox(width: 6),
              Text(
                '$_streak',
                style: ApexTheme.mono(size: 16, color: ApexColors.t1),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'DAY STREAK',
            style: GoogleFonts.inter(
              fontSize: 8,
              color: ApexColors.t2,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(
    String label,
    int val,
    int goal,
    IconData icon,
    Color color,
    String unit,
  ) {
    final pct = goal > 0 ? (val / goal).clamp(0.0, 1.0) : 0.0;
    return ApexCard(
      glow: true,
      glowColor: color,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: ApexColors.t3,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: _loading ? '—' : '$val',
                            style: ApexTheme.mono(size: 22, color: color),
                          ),
                          TextSpan(
                            text: '/$goal $unit',
                            style: ApexTheme.mono(
                              size: 9,
                              color: ApexColors.t3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withAlpha(18),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withAlpha(60)),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 7,
                  backgroundColor: ApexColors.cardAlt,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${(pct * 100).round()}% of goal',
                style: const TextStyle(fontSize: 10, color: ApexColors.t3),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _waterCard(int total, int goal) {
    final pct = goal > 0 ? (total / goal).clamp(0.0, 1.0) : 0.0;
    return GestureDetector(
      onTap: () => setState(() => _addWater = true),
      child: ApexCard(
        glow: true,
        glowColor: ApexColors.blue,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'HYDRATION',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: ApexColors.t3,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: _loading
                                  ? '—'
                                  : (total / 1000).toStringAsFixed(1),
                              style: ApexTheme.mono(
                                size: 22,
                                color: ApexColors.blue,
                              ),
                            ),
                            TextSpan(
                              text: '/${(goal / 1000).toStringAsFixed(1)}L',
                              style: ApexTheme.mono(
                                size: 9,
                                color: ApexColors.t3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: ApexColors.blue.withAlpha(18),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ApexColors.blue.withAlpha(60)),
                  ),
                  child: const Icon(
                    Icons.water_drop_rounded,
                    size: 20,
                    color: ApexColors.blue,
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 7,
                    backgroundColor: ApexColors.cardAlt,
                    valueColor: const AlwaysStoppedAnimation(ApexColors.blue),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tap to track',
                  style: GoogleFonts.inter(fontSize: 10, color: ApexColors.blue, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaterInput() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ApexCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Log water intake',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: ApexColors.t1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose a quick amount and add it to today.',
              style: GoogleFonts.inter(fontSize: 12, color: ApexColors.t2),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['150', '250', '330', '500', '750', '1000']
                  .map(
                    (ml) => GestureDetector(
                      onTap: () => setState(() => _waterAmt = ml),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _waterAmt == ml
                              ? ApexColors.blue.withAlpha(18)
                              : ApexColors.cardAlt,
                          border: Border.all(
                            color: _waterAmt == ml
                                ? ApexColors.blue
                                : ApexColors.borderStrong,
                            width: 1.2,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '$ml ml',
                          style: TextStyle(
                            color: _waterAmt == ml
                                ? ApexColors.blue
                                : ApexColors.t2,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ApexButton(
                    text: 'Cancel',
                    onPressed: () => setState(() => _addWater = false),
                    tone: ApexButtonTone.outline,
                    sm: true,
                    full: true,
                    color: ApexColors.t2,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ApexButton(
                    text: 'Save intake',
                    onPressed: _logWater,
                    sm: true,
                    full: true,
                    color: ApexColors.blue,
                    loading: _savingWater,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _journeyGallery(List<_JourneyPhotoStage> stages) {
    final hasAny = stages.any((stage) => stage.photo != null);

    return ApexCard(
      glow: true,
      glowColor: ApexColors.pink,
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
                      'Journey frames',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: ApexColors.t1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Start, midpoint, and current photos in one responsive strip.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: ApexColors.t2,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: ApexColors.pink.withAlpha(16),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ApexColors.pink.withAlpha(56)),
                ),
                child: const Icon(
                  Icons.photo_library_rounded,
                  color: ApexColors.pink,
                  size: 19,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!hasAny)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: ApexColors.cardAlt.withAlpha(210),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: ApexColors.borderStrong),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.add_a_photo_outlined,
                    size: 30,
                    color: ApexColors.t3,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Add progress photos to unlock your start, midpoint, and current comparison here.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: ApexColors.t2,
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: stages.map((stage) {
                  return Padding(
                    padding: EdgeInsets.only(
                      right: stage == stages.last ? 0 : 10,
                    ),
                    child: _journeyStageCard(stage),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _journeyStageCard(_JourneyPhotoStage stage) {
    final photoData = stage.photo?['photo_data']?.toString();
    final dateLabel = _formatLongDate(stage.photo?['taken_at']?.toString());

    return InkWell(
      onTap: _showAddPhotoSource,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 152,
        decoration: BoxDecoration(
          color: ApexColors.surfaceStrong,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: ApexColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(23)),
              child: SizedBox(
                height: 172,
                width: double.infinity,
                child: photoData == null
                    ? DecoratedBox(
                        decoration: BoxDecoration(
                          color: stage.color.withAlpha(12),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                color: stage.color,
                                size: 26,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Add photo',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: ApexColors.t2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _buildPhoto(photoData),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stage.label.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: ApexColors.t3,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    stage.dayLabel,
                    style: ApexTheme.mono(size: 16, color: stage.color),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    photoData == null ? 'Capture this milestone.' : dateLabel,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: ApexColors.t2,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoto(String data) {
    if (data.startsWith('data:')) {
      final base64Str = data.split(',').last;
      return Image.memory(
        base64Decode(base64Str),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(color: ApexColors.cardAlt),
      );
    }
    return Image.network(
      data,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(color: ApexColors.cardAlt),
    );
  }

  Widget _miniStat(IconData icon, String value, String label, Color color) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 60) / 3,
      child: ApexCard(
        padding: const EdgeInsets.all(11),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 6),
            Text(value, style: ApexTheme.mono(size: 15, color: color)),
            Text(
              label.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 9,
                color: ApexColors.t3,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sessionCard(Map<String, dynamic> l) {
    final intensity = l['intensity'] ?? 'moderate';
    final ic =
        {
          'light': ApexColors.accentSoft,
          'moderate': ApexColors.blue,
          'heavy': ApexColors.orange,
        }[intensity] ??
        ApexColors.blue;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: ApexCard(
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: ic.withAlpha(18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.fitness_center_rounded, size: 18, color: ic),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l['workout_name'] ?? 'Workout',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: ApexColors.t1,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${_formatDate(l['completed_at'])} · ${l['duration_min'] ?? 0}min · ${((l['total_volume'] as num?)?.round() ?? 0)}kg',
                    style: const TextStyle(color: ApexColors.t3, fontSize: 10),
                  ),
                ],
              ),
            ),
            ApexTag(text: intensity.toString().toUpperCase(), color: ic),
          ],
        ),
      ),
    );
  }

  List<double> _buildDailyValues(
    List<Map<String, dynamic>> logs,
    int days,
    String dateField,
    double Function(Map<String, dynamic>) valFn,
  ) {
    final map = <String, double>{};
    for (int i = days - 1; i >= 0; i--) {
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

  List<String> _buildDayLabels(int days) {
    return List.generate(days, (index) {
      final d = DateTime.now().subtract(Duration(days: days - index - 1));
      return ['S', 'M', 'T', 'W', 'T', 'F', 'S'][d.weekday % 7];
    });
  }

  List<_JourneyPhotoStage> _buildJourneyStages() {
    final stages = <_JourneyPhotoStage>[];
    if (_photos.isEmpty) {
      return const [
        _JourneyPhotoStage(
          label: 'Start',
          dayLabel: 'Day 1',
          color: ApexColors.orange,
        ),
        _JourneyPhotoStage(
          label: 'Midpoint',
          dayLabel: 'Halfway',
          color: ApexColors.blue,
        ),
        _JourneyPhotoStage(
          label: 'Current',
          dayLabel: 'Today',
          color: ApexColors.accentSoft,
        ),
      ];
    }

    final ordered = [..._photos]
      ..sort((a, b) {
        final aDate = _photoDate(a) ?? DateTime.now();
        final bDate = _photoDate(b) ?? DateTime.now();
        return aDate.compareTo(bDate);
      });

    final start = ordered.first;
    final current = ordered.last;
    final startDate = _photoDate(start) ?? DateTime.now();
    final currentDate = _photoDate(current) ?? DateTime.now();
    final totalDays = currentDate.difference(startDate).inDays.abs();

    Map<String, dynamic>? mid;
    if (ordered.length >= 3) {
      final midpoint = startDate.add(Duration(days: (totalDays / 2).round()));
      mid = ordered.reduce((best, candidate) {
        final bestDiff = (_photoDate(best) ?? midpoint)
            .difference(midpoint)
            .inDays
            .abs();
        final candidateDiff = (_photoDate(candidate) ?? midpoint)
            .difference(midpoint)
            .inDays
            .abs();
        return candidateDiff < bestDiff ? candidate : best;
      });
      if (mid['id'] == start['id'] || mid['id'] == current['id']) {
        mid = ordered[ordered.length ~/ 2];
      }
    }

    stages.add(
      _JourneyPhotoStage(
        label: 'Start',
        dayLabel: 'Day 1',
        color: ApexColors.orange,
        photo: start,
      ),
    );
    stages.add(
      _JourneyPhotoStage(
        label: 'Midpoint',
        dayLabel: mid == null
            ? 'Add more'
            : 'Day ${((_photoDate(mid) ?? startDate).difference(startDate).inDays) + 1}',
        color: ApexColors.blue,
        photo: mid,
      ),
    );
    stages.add(
      _JourneyPhotoStage(
        label: 'Current',
        dayLabel: totalDays > 0 ? 'Day ${totalDays + 1}' : 'Today',
        color: ApexColors.accentSoft,
        photo: current,
      ),
    );
    return stages;
  }

  DateTime? _photoDate(Map<String, dynamic>? photo) {
    if (photo == null) return null;
    final raw = photo['taken_at']?.toString();
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final d = DateTime.parse(iso);
      return '${d.day}/${d.month}';
    } catch (_) {
      return '';
    }
  }

  String _formatLongDate(String? iso) {
    if (iso == null) return 'Waiting for this milestone';
    try {
      final d = DateTime.parse(iso);
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
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    } catch (_) {
      return 'Saved photo';
    }
  }
}

class _JourneyPhotoStage {
  final String label;
  final String dayLabel;
  final Color color;
  final Map<String, dynamic>? photo;

  const _JourneyPhotoStage({
    required this.label,
    required this.dayLabel,
    required this.color,
    this.photo,
  });
}
