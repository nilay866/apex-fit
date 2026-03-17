import 'dart:convert';
import 'dart:async';
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
import '../repositories/workout_repository.dart';
import '../services/ai_service.dart';
import '../services/health_service.dart';
import '../services/supabase_service.dart';
import '../services/cache_service.dart';
import '../services/achievement_service.dart';
import '../widgets/achievement_badges.dart';
import '../services/nfi_service.dart';
import '../widgets/nfi_ring_widget.dart';
import '../widgets/mood_checkin_widget.dart';
import '../widgets/quick_action_fab.dart';
import 'workout_programs_screen.dart';

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
  List<Map<String, dynamic>> _enrollments = [];
  List<Achievement> _unlockedAchievements = [];

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
  Timer? _offlineSyncTimer;

  // NEW: NFI + Mood state
  NfiResult? _nfiResult;
  bool _nfiLoading = true;

  @override
  void initState() {
    super.initState();
    // Synchronous hydration from cache for sub-20ms TTI
    _logs =
        cache.get<List<Map<String, dynamic>>>(CacheService.keyHomeLogs) ?? [];
    _workouts =
        cache.get<List<Map<String, dynamic>>>(CacheService.keyHomeWorkouts) ??
        [];
    _waterLogs =
        cache.get<List<Map<String, dynamic>>>(CacheService.keyWaterLogs) ?? [];

    _waterNotifier = ValueNotifier<int>(_calculateTotalWater(_waterLogs));
    _stepsNotifier = ValueNotifier<int>(0);
    _energyNotifier = ValueNotifier<double>(0.0);
    _calorieNotifier = ValueNotifier<int>(0);

    // Phase 14: Background Sync Trigger
    unawaited(workoutRepository.syncOfflineQueue());
    _offlineSyncTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => unawaited(workoutRepository.syncOfflineQueue()),
    );

    _load();

    // NEW: Load NFI score
    _loadNfi();
  }

  int _calculateTotalWater(List<Map<String, dynamic>> logs) {
    return logs.fold(0, (sum, log) => sum + (log['amount_ml'] as int? ?? 0));
  }

  @override
  void dispose() {
    _offlineSyncTimer?.cancel();
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

    try {
      final userId = SupabaseService.requireUserId(
        action: 'load your dashboard',
      );
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      final results = await Future.wait([
        SupabaseService.getWorkoutLogs(userId, limit: 14),
        SupabaseService.getWorkouts(userId),
        SupabaseService.getNutritionLogs(
          userId,
          since: DateTime.parse('${todayStr}T00:00:00'),
        ),
        SupabaseService.getBodyWeightLogs(userId, limit: 3),
        SupabaseService.getProgressPhotos(userId),
        SupabaseService.getWaterLogs(
          userId,
          since: DateTime.parse('${todayStr}T00:00:00'),
        ),
        SupabaseService.getUserEnrollments(userId),
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
        _enrollments = results.length > 6
            ? List<Map<String, dynamic>>.from(results[6] as List)
            : [];
        _loading = false;

        // Calculate Achievements
        AchievementService.checkAchievements(_logs, _streak).then((
          achievements,
        ) {
          if (mounted) setState(() => _unlockedAchievements = achievements);
        });

        // Update notifiers without triggering full rebuild
        _waterNotifier.value = _calculateTotalWater(_waterLogs);
        _stepsNotifier.value = healthData['steps'] as int;
        _energyNotifier.value = healthData['energy'] as double;
        _calorieNotifier.value = _nutritionLogs.fold(
          0,
          (sum, l) => sum + (l['calories'] as int? ?? 0),
        );

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

  // NEW: Load NFI recovery score
  Future<void> _loadNfi() async {
    try {
      final uid = SupabaseService.currentUser?.id;
      if (uid == null) return;
      final result = await NfiService.computeToday(uid);
      if (mounted) {
        setState(() {
          _nfiResult = result;
          _nfiLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _nfiLoading = false);
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
      final bytes =
          await FlutterImageCompress.compressWithFile(
            file.path,
            quality: 60,
            minWidth: 800,
            minHeight: 800,
            format: CompressFormat.jpeg,
          ) ??
          await file.readAsBytes();

      final base64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      await SupabaseService.createProgressPhoto(
        SupabaseService.requireUserId(action: 'save a progress photo'),
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
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: ApexColors.t1,
              ),
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

  void _openLogMealSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ApexColors.surfaceStrong,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (sheetContext) => _LogMealSheet(onLogged: _load),
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
        SupabaseService.requireUserId(action: 'log water'),
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          ApexScreenHeader(
            eyebrow: 'Dashboard',
            title: firstName,
            subtitle:
                'Good $greet. Your overview moves with your training week.',
            trailing: _streak > 0 ? _streakBadge() : null,
          ),
          const SizedBox(height: 12),
          // NEW: NFI Recovery Ring
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: NfiRingWidget(result: _nfiResult, isLoading: _nfiLoading),
          ),
          
          // NEW: Quick Action FAB inline
          QuickActionFab(
            onStartWorkout: () => widget.onStartWorkout({}),
            onLogMeal: _openLogMealSheet,
            onAddWater: () => setState(() => _addWater = !_addWater),
          ),
          
          // NEW: Mood check-in
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: MoodCheckinWidget(
              initialMood: 3,
              onMoodChanged: (mood) {
                // Trigger NFI recompute with mood
                _loadNfi();
              },
            ),
          ),
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
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              ApexTag(text: widget.profile?['goal'] ?? 'Build Muscle'),
              if (latestBW != null)
                ApexTag(text: '${latestBW}kg', color: ApexColors.blue),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ValueListenableBuilder<int>(
                  valueListenable: _calorieNotifier,
                  builder: (context, val, _) {
                    return GestureDetector(
                      onTap: _openLogMealSheet,
                      child: _statCard(
                        'Calories',
                        val,
                        calGoal,
                        Icons.local_fire_department_rounded,
                        ApexColors.orange,
                        'kcal',
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
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
          const SizedBox(height: 12),
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
            const SizedBox(height: 12),
          ],
          _buildProgramsCard(),
          const SizedBox(height: 12),

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
                  const SizedBox(height: 12),
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
          const SizedBox(height: 12),
          _journeyGallery(journeyStages),
          if (_unlockedAchievements.isNotEmpty) ...[
            const SizedBox(height: 12),
            AchievementList(unlockedAchievements: _unlockedAchievements),
          ],
          const SizedBox(height: 12),
          RepaintBoundary(
            child: StreakCalendar(logs: _logs, photos: _photos),
          ),
          const SizedBox(height: 12),
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
                const SizedBox(height: 12),
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
          const SizedBox(height: 12),
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
          const SizedBox(height: 12),
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
    return SizedBox(
      height: 140,
      child: ApexCard(
      glow: true,
      glowColor: color,
      padding: const EdgeInsets.all(12),
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
                width: 38,
                height: 38,
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
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 7,
                  backgroundColor: ApexColors.cardAlt,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(pct * 100).round()}% of goal',
                style: const TextStyle(fontSize: 10, color: ApexColors.t3),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _waterCard(int total, int goal) {
    final pct = goal > 0 ? (total / goal).clamp(0.0, 1.0) : 0.0;
    return GestureDetector(
      onTap: () => setState(() => _addWater = true),
      child: SizedBox(
        height: 140,
        child: ApexCard(
          glow: true,
          glowColor: ApexColors.blue,
          padding: const EdgeInsets.all(12),
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
                    width: 38,
                    height: 38,
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
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 7,
                      backgroundColor: ApexColors.cardAlt,
                      valueColor: const AlwaysStoppedAnimation(ApexColors.blue),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to track',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: ApexColors.blue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
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
                      'Start and current photos in one responsive strip.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: ApexColors.t2,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _showAddPhotoSource,
                child: Container(
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
              ),
            ],
          ),
          const SizedBox(height: 12),
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
      onTap: photoData == null ? _showAddPhotoSource : () => _showPhotoDialog(photoData, dateLabel),
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
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(23),
              ),
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
        errorBuilder: (context, error, stackTrace) =>
            Container(color: ApexColors.cardAlt),
      );
    }
    return Image.network(
      data,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          Container(color: ApexColors.cardAlt),
    );
  }

  void _showPhotoDialog(String data, String dateLabel) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: InteractiveViewer(
                child: _buildPhoto(data),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  dateLabel,
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
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

  Widget _buildProgramsCard() {
    if (_enrollments.isEmpty) {
      return GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WorkoutProgramsScreen()),
        ),
        child: ApexCard(
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: ApexColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.auto_graph_rounded,
                  color: ApexColors.accent,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'structured programs'.toUpperCase(),
                      style: TextStyle(
                        color: ApexColors.t3,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Accelerate your results',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: ApexColors.t1,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: ApexColors.t3),
            ],
          ),
        ),
      );
    }

    final active = _enrollments.first;
    final program = active['workout_programs'];
    final day = active['current_day'] ?? 1;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const WorkoutProgramsScreen()),
      ),
      child: ApexCard(
        glow: true,
        glowColor: ApexColors.accent,
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
                      'ACTIVE PROGRAM',
                      style: TextStyle(
                        color: ApexColors.t3,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      program?['name'] ?? 'Training Program',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        color: ApexColors.t1,
                      ),
                    ),
                  ],
                ),
                ApexTag(text: 'DAY $day', color: ApexColors.accent),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: day / ((program?['duration_weeks'] ?? 4) * 7),
                minHeight: 6,
                backgroundColor: ApexColors.cardAlt,
                valueColor: const AlwaysStoppedAnimation(ApexColors.accent),
              ),
            ),
          ],
        ),
      ),
    );
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

class _LogMealSheet extends StatefulWidget {
  final VoidCallback onLogged;
  const _LogMealSheet({required this.onLogged});

  @override
  State<_LogMealSheet> createState() => _LogMealSheetState();
}

class _LogMealSheetState extends State<_LogMealSheet> {
  final _foodController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();

  bool _loadingAI = false;
  bool _saving = false;

  @override
  void dispose() {
    _foodController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  Future<void> _lookupMacros() async {
    final food = _foodController.text.trim();
    if (food.isEmpty) return;

    setState(() => _loadingAI = true);
    try {
      final res = await AIService.lookupNutrition(food, '');
      if (mounted) {
        setState(() {
          if (res['calories'] != null) {
            _caloriesController.text = res['calories'].toString();
          }
          if (res['protein_g'] != null) {
            _proteinController.text = res['protein_g'].toString();
          }
          if (res['carbs_g'] != null) {
            _carbsController.text = res['carbs_g'].toString();
          }
          if (res['fat_g'] != null) _fatController.text = res['fat_g'].toString();
        });
      }
    } catch (_) {
      // Silent fail
    } finally {
      if (mounted) setState(() => _loadingAI = false);
    }
  }

  Future<void> _logMeal() async {
    if (_foodController.text.trim().isEmpty) return;

    setState(() => _saving = true);
    try {
      final userId = SupabaseService.requireUserId(action: 'log a meal');
      await SupabaseService.createNutritionLog({
        'user_id': userId,
        'meal_name': _foodController.text.trim(),
        'calories': int.tryParse(_caloriesController.text) ?? 0,
        'protein_g': double.tryParse(_proteinController.text) ?? 0,
        'carbs_g': double.tryParse(_carbsController.text) ?? 0,
        'fat_g': double.tryParse(_fatController.text) ?? 0,
      });

      widget.onLogged();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to log meal: $e'),
            backgroundColor: ApexColors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Log a Meal',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: ApexColors.t1,
                ),
              ),
              if (_loadingAI)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: ApexColors.accent,
                  ),
                )
              else
                IconButton(
                  onPressed: _lookupMacros,
                  icon: const Icon(
                    Icons.auto_awesome_rounded,
                    color: ApexColors.accent,
                    size: 20,
                  ),
                  tooltip: 'Auto-fill macros',
                ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(_foodController, 'Food Name'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  _caloriesController,
                  'Calories',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  _proteinController,
                  'Protein (g)',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  _carbsController,
                  'Carbs (g)',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  _fatController,
                  'Fat (g)',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ApexButton(
            text: 'Log Meal',
            loading: _saving,
            onPressed: _logMeal,
            full: true,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: ApexColors.t1),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: ApexColors.t3),
        filled: true,
        fillColor: ApexColors.surfaceStrong,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ApexColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ApexColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ApexColors.accent),
        ),
      ),
    );
  }
}
