import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../services/supabase_service.dart';
import '../widgets/apex_backdrop.dart';
import '../widgets/apex_orb_logo.dart';
import '../widgets/profile_modal.dart';
import 'active_workout_screen.dart';
import 'ai_coach_screen.dart';
import 'home_screen.dart';
import 'nutrition_screen.dart';
import 'photos_screen.dart';
import 'reports_screen.dart';
import 'workout_screen.dart';

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
    {'icon': Icons.restaurant_menu_rounded, 'label': 'Fuel'},
    {'icon': Icons.photo_camera_back_rounded, 'label': 'Photos'},
    {'icon': Icons.bar_chart_rounded, 'label': 'Stats'},
    {'icon': Icons.auto_awesome_rounded, 'label': 'Coach'},
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadRecentLogs();
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
      _tab = 4;
    });
    _loadRecentLogs();
  }

  void _showProfile() {
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
                    const NutritionScreen(),
                    const PhotosScreen(),
                    const ReportsScreen(),
                    AiCoachScreen(profile: _profile, recentLogs: _recentLogs),
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
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Container(
          height: 76,
          decoration: BoxDecoration(
            color: ApexColors.surface.withAlpha(235),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: ApexColors.borderStrong),
            boxShadow: [
              BoxShadow(
                color: ApexColors.shadow.withAlpha(64),
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
                  onTap: () => setState(() => _tab = index),
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
