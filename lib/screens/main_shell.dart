import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import '../constants/colors.dart';
import '../repositories/auth_repository.dart';
import '../repositories/profile_repository.dart';
import '../repositories/workout_repository.dart';
import '../widgets/apex_backdrop.dart';
import '../widgets/apex_orb_logo.dart';
import '../widgets/profile_modal.dart';
import 'active_workout_screen.dart';
import 'home_screen.dart';

import 'social_feed_screen.dart';
import 'reports_screen.dart';
import 'workout_screen.dart';
import 'circuit_player_screen.dart';
import 'cardio_map_screen.dart';

class MainShell extends StatefulWidget {
  final VoidCallback onSignOut;
  const MainShell({super.key, required this.onSignOut});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _activeWorkout;

  // GPS live run state — shared with CardioMapScreen via callbacks
  bool _runActive = false;
  bool _runPaused = false;
  double _runDistanceKm = 0;
  int _runElapsedSeconds = 0;
  double _runPaceMinPerKm = 0;
  Timer? _runTimer;

  static const _navItems = [
    {'icon': Icons.home_rounded, 'label': 'Home'},
    {'icon': Icons.fitness_center_rounded, 'label': 'Train'},
    {'icon': Icons.public_rounded, 'label': 'Social'},
    {'icon': Icons.bar_chart_rounded, 'label': 'Stats'},
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _syncOfflineData();
  }

  @override
  void dispose() {
    _runTimer?.cancel();
    super.dispose();
  }

  Future<void> _syncOfflineData() async {
    try {
      await workoutRepository.syncOfflineQueue();
    } catch (_) {}
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await profileRepository.getCurrentProfile();
      if (mounted) setState(() => _profile = profile);
    } catch (_) {}
  }

  void _startWorkout(Map<String, dynamic> workout) {
    setState(() => _activeWorkout = workout);
  }

  void _finishWorkout() {
    _runTimer?.cancel();
    setState(() {
      _activeWorkout = null;
      _runActive = false;
      _runPaused = false;
      _runDistanceKm = 0;
      _runElapsedSeconds = 0;
      _runPaceMinPerKm = 0;
      _tab = 0;
    });
  }

  // Called by CardioMapScreen when GPS state changes
  void _onRunStateUpdate({
    required bool active,
    required bool paused,
    required double distanceKm,
    required int elapsedSeconds,
    required double paceMinPerKm,
  }) {
    if (!mounted) return;
    setState(() {
      _runActive = active;
      _runPaused = paused;
      _runDistanceKm = distanceKm;
      _runElapsedSeconds = elapsedSeconds;
      _runPaceMinPerKm = paceMinPerKm;
    });
  }

  void _showProfile() {
    Haptics.vibrate(HapticsType.light);
    Navigator.of(context)
        .push<void>(
          PageRouteBuilder<void>(
            transitionDuration: const Duration(milliseconds: 280),
            reverseTransitionDuration: const Duration(milliseconds: 220),
            pageBuilder: (context, animation, secondaryAnimation) =>
                ProfileScreen(
                  profile: _profile,
                  onSignOut: widget.onSignOut,
                  onSaved: _loadProfile,
                ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  final curved = CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                    reverseCurve: Curves.easeInCubic,
                  );
                  return FadeTransition(
                    opacity: curved,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.06),
                        end: Offset.zero,
                      ).animate(curved),
                      child: child,
                    ),
                  );
                },
          ),
        )
        .then((_) {
          if (mounted) _loadProfile();
        });
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _fmtTime(int secs) =>
      '${(secs ~/ 3600).toString().padLeft(2, '0')}:'
      '${((secs % 3600) ~/ 60).toString().padLeft(2, '0')}:'
      '${(secs % 60).toString().padLeft(2, '0')}';

  String _fmtPace(double paceMinPerKm) {
    if (paceMinPerKm <= 0 || paceMinPerKm > 60) return '--:--';
    final m = paceMinPerKm.floor();
    final s = ((paceMinPerKm - m) * 60).floor();
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // ── Active workout full-screen modes ────────────────────────────────────
    if (_activeWorkout != null) {
      final t = _activeWorkout!['type']?.toString().toLowerCase() ?? '';
      if (t == 'hiit' || t == 'circuit') {
        return CircuitPlayerScreen(
          workout: _activeWorkout!,
          onFinish: _finishWorkout,
        );
      } else if (t == 'cardio' || t == 'run') {
        return _cardioWithLiveBar();
      }
      return ActiveWorkoutScreen(
        workout: _activeWorkout!,
        onFinish: _finishWorkout,
      );
    }

    final profileLabel =
        (_profile?['name'] ?? authRepository.currentUser?.email ?? 'A')
            .toString();

    return Scaffold(
      backgroundColor: ApexColors.bg,
      body: ApexBackdrop(
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: IndexedStack(
                  index: _tab,
                  children: [
                    HomeScreen(
                      profile: _profile,
                      onStartWorkout: _startWorkout,
                    ),
                    WorkoutScreen(onStartWorkout: _startWorkout),
                    const SocialFeedScreen(),
                    const ReportsScreen(),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                right: 16,
                child: ApexOrbLogo(
                  size: 52,
                  label: profileLabel,
                  imageData: _profile?['avatar_data']?.toString(),
                  onTap: _showProfile,
                  badgeIcon: Icons.edit_outlined,
                  variant: ApexOrbVariant.light,
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: _buildNavBar(),
      ),
    );
  }

  // ── Cardio map + live top banner ─────────────────────────────────────────
  Widget _cardioWithLiveBar() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full-screen map
          CardioMapScreen(
            workout: _activeWorkout!,
            onFinish: _finishWorkout,
            onStateUpdate: _onRunStateUpdate,
          ),

          // ── Live GPS banner at top (always visible) ──────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _RunLiveBanner(
              active: _runActive,
              paused: _runPaused,
              distanceKm: _runDistanceKm,
              elapsedSeconds: _runElapsedSeconds,
              paceMinPerKm: _runPaceMinPerKm,
              formattedTime: _fmtTime(_runElapsedSeconds),
              formattedPace: _fmtPace(_runPaceMinPerKm),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom nav bar ───────────────────────────────────────────────────────
  Widget _buildNavBar() {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: ApexColors.surface.withAlpha(235),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: ApexColors.borderStrong),
        boxShadow: [
          BoxShadow(
            color: ApexColors.shadow.withAlpha(54),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: List.generate(_navItems.length, (index) {
          final item = _navItems[index];
          final active = _tab == index;
          final color = active ? ApexColors.accent : ApexColors.t3;

          return Expanded(
            child: GestureDetector(
              key: ValueKey('nav_${(item['label'] as String).toLowerCase()}'),
              onTap: () {
                if (_tab != index) {
                  Haptics.vibrate(HapticsType.selection);
                  setState(() => _tab = index);
                }
              },
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: active ? ApexColors.accentDim : Colors.transparent,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item['icon'] as IconData, size: 20, color: color),
                    const SizedBox(height: 5),
                    Text(
                      item['label'] as String,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: color,
                        letterSpacing: 0.7,
                        fontWeight: active
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 5),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: active ? 18 : 6,
                      height: 3,
                      decoration: BoxDecoration(
                        color: active ? ApexColors.accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Live Run Banner Widget ─────────────────────────────────────────────────

class _RunLiveBanner extends StatelessWidget {
  final bool active;
  final bool paused;
  final double distanceKm;
  final int elapsedSeconds;
  final double paceMinPerKm;
  final String formattedTime;
  final String formattedPace;

  const _RunLiveBanner({
    required this.active,
    required this.paused,
    required this.distanceKm,
    required this.elapsedSeconds,
    required this.paceMinPerKm,
    required this.formattedTime,
    required this.formattedPace,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(16, topPad + 6, 16, 10),
      decoration: BoxDecoration(
        color: const Color(0xF2000000),
        border: Border(
          bottom: BorderSide(color: ApexColors.accent.withAlpha(80), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Status indicator
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: paused
                  ? ApexColors.orange
                  : (active ? ApexColors.accent : Colors.white38),
              shape: BoxShape.circle,
              boxShadow: active && !paused
                  ? [
                      BoxShadow(
                        color: ApexColors.accent.withAlpha(120),
                        blurRadius: 6,
                      ),
                    ]
                  : null,
            ),
          ),

          // Time
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'TIME',
                style: TextStyle(
                  color: ApexColors.t3,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              Text(
                formattedTime,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),

          const SizedBox(width: 20),
          _vertDivider(),
          const SizedBox(width: 20),

          // Distance
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'KM',
                style: TextStyle(
                  color: ApexColors.t3,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              Text(
                distanceKm.toStringAsFixed(2),
                style: GoogleFonts.inter(
                  color: ApexColors.accent,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(width: 20),
          _vertDivider(),
          const SizedBox(width: 20),

          // Pace
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'PACE /KM',
                style: TextStyle(
                  color: ApexColors.t3,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              Text(
                formattedPace,
                style: GoogleFonts.inter(
                  color: const Color(0xFF64B5F6),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),

          const Spacer(),

          // Status chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: paused
                  ? ApexColors.orange.withAlpha(30)
                  : (active ? ApexColors.accent.withAlpha(30) : Colors.white10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: paused
                    ? ApexColors.orange.withAlpha(80)
                    : (active
                          ? ApexColors.accent.withAlpha(80)
                          : Colors.white24),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  paused
                      ? Icons.pause_rounded
                      : (active
                            ? Icons.directions_run_rounded
                            : Icons.play_arrow_rounded),
                  color: paused
                      ? ApexColors.orange
                      : (active ? ApexColors.accent : Colors.white38),
                  size: 14,
                ),
                const SizedBox(width: 5),
                Text(
                  paused ? 'PAUSED' : (active ? 'RUNNING' : 'READY'),
                  style: TextStyle(
                    color: paused
                        ? ApexColors.orange
                        : (active ? ApexColors.accent : Colors.white38),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _vertDivider() =>
      Container(width: 1, height: 32, color: Colors.white12);
}
