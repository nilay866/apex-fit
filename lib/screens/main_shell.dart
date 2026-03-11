import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import '../constants/colors.dart';
import '../services/supabase_service.dart';
import '../widgets/apex_backdrop.dart';
import '../widgets/apex_orb_logo.dart';
import '../widgets/profile_modal.dart';
import 'active_workout_screen.dart';
import 'home_screen.dart';
import 'nutrition_screen.dart';
import 'social_feed_screen.dart';
import 'photos_screen.dart';
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
  List<Map<String, dynamic>> _recentLogs = [];

  static const _navItems = [
    {'icon': Icons.home_rounded, 'label': 'Home'},
    {'icon': Icons.fitness_center_rounded, 'label': 'Train'},
    {'icon': Icons.public_rounded, 'label': 'Social'},
    {'icon': Icons.restaurant_menu_rounded, 'label': 'Fuel'},
    {'icon': Icons.photo_camera_back_rounded, 'label': 'Photos'},
    {'icon': Icons.bar_chart_rounded, 'label': 'Stats'},
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadRecentLogs();
    _syncOfflineData();
  }

  Future<void> _syncOfflineData() async {
    // Fire and forget sync
    SupabaseService.syncOfflineWorkouts().then((_) {
      if (mounted) _loadRecentLogs(); // Refresh logs if sync succeeded
    });
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await SupabaseService.getProfile(SupabaseService.currentUser!.id);
      if (mounted) {
        setState(() => _profile = profile);
      }
    } catch (_) {}
  }

  Future<void> _loadRecentLogs() async {
    try {
      final logs = await SupabaseService.getWorkoutLogs(
        SupabaseService.currentUser!.id,
        limit: 5,
      );
      if (mounted) {
        setState(() => _recentLogs = logs);
      }
    } catch (_) {}
  }

  void _startWorkout(Map<String, dynamic> workout) {
    setState(() => _activeWorkout = workout);
  }

  void _finishWorkout() {
    setState(() {
      _activeWorkout = null;
      _tab = 4; // Switch to Stats after workout
    });
    _loadRecentLogs();
  }

  void _showProfile() {
    Haptics.vibrate(HapticsType.light);
    Navigator.of(context)
        .push<void>(
          PageRouteBuilder<void>(
            transitionDuration: const Duration(milliseconds: 280),
            reverseTransitionDuration: const Duration(milliseconds: 220),
            pageBuilder: (context, animation, secondaryAnimation) => ProfileScreen(
              profile: _profile,
              onSignOut: widget.onSignOut,
              onSaved: _loadProfile,
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
          if (mounted) {
            _loadProfile();
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    if (_activeWorkout != null) {
      final t = _activeWorkout!['type']?.toString().toLowerCase() ?? '';
      if (t == 'hiit' || t == 'circuit') {
        return CircuitPlayerScreen(workout: _activeWorkout!, onFinish: _finishWorkout);
      } else if (t == 'cardio' || t == 'run') {
        return CardioMapScreen(workout: _activeWorkout!, onFinish: _finishWorkout);
      }
      return ActiveWorkoutScreen(workout: _activeWorkout!, onFinish: _finishWorkout);
    }

    final profileLabel = (_profile?['name'] ?? SupabaseService.currentUser?.email ?? 'A').toString();

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
                    HomeScreen(profile: _profile, onStartWorkout: _startWorkout),
                    WorkoutScreen(onStartWorkout: _startWorkout),
                    const SocialFeedScreen(),
                    const NutritionScreen(),
                    const PhotosScreen(),
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
        child: Container(
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
                                fontWeight: active ? FontWeight.bold : FontWeight.normal,
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
        ),
      ),
    );
  }
}
