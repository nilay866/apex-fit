import 'package:flutter/material.dart';
import 'package:apex_ai/constants/colors.dart';
import 'package:apex_ai/services/achievement_service.dart';
import 'package:apex_ai/services/supabase_service.dart';
import 'package:apex_ai/widgets/achievement_badges.dart';
import 'package:google_fonts/google_fonts.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  List<Achievement> _unlocked = [];
  List<Achievement> _locked = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final uid = SupabaseService.currentUser?.id;
      if (uid == null) return;
      final logs = await SupabaseService.getWorkoutLogs(uid, limit: 500);
      final profile = await SupabaseService.getProfile(uid);
      final streak = (profile?['streak_current'] as int?) ?? 0;
      final unlocked =
          await AchievementService.checkAchievements(logs, streak);
      final unlockedIds = unlocked.map((a) => a.id).toSet();
      final all = AchievementService.availableAchievements;
      if (mounted) {
        setState(() {
          _unlocked = unlocked;
          _locked =
              all.where((a) => !unlockedIds.contains(a.id)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = SupabaseService.describeError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ApexColors.bg,
      appBar: AppBar(
        backgroundColor: ApexColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: ApexColors.t1, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Achievements',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: ApexColors.t1)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: ApexColors.accent))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: ApexColors.red, size: 40),
                        const SizedBox(height: 12),
                        Text(
                          'Failed to load achievements',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: ApexColors.t1),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 12, color: ApexColors.t3),
                        ),
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh_rounded,
                              color: ApexColors.accent),
                          label: const Text('Retry',
                              style:
                                  TextStyle(color: ApexColors.accent)),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                // Summary
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ApexColors.accent.withAlpha(15),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: ApexColors.accent.withAlpha(60)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statCol(
                          '${_unlocked.length}', 'Unlocked', ApexColors.accent),
                      _statCol('${_locked.length}', 'Locked', ApexColors.t3),
                      _statCol(
                        '${(_unlocked.length * 100 / (_unlocked.length + _locked.length).clamp(1, 999)).round()}%',
                        'Complete',
                        ApexColors.yellow,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Unlocked section
                if (_unlocked.isNotEmpty) ...[
                  _sectionHeader('UNLOCKED', ApexColors.accent),
                  const SizedBox(height: 12),
                  _achievementGrid(_unlocked, unlocked: true),
                  const SizedBox(height: 24),
                ],

                // Locked section
                if (_locked.isNotEmpty) ...[
                  _sectionHeader('LOCKED', ApexColors.t3),
                  const SizedBox(height: 12),
                  _achievementGrid(_locked, unlocked: false),
                ],

                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ApexColors.cardAlt,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ApexColors.borderStrong),
                  ),
                  child: const Text(
                    'View your full activity streak on the Stats tab.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13, color: ApexColors.t2, height: 1.5),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _achievementGrid(List<Achievement> achievements,
      {required bool unlocked}) {
    return Wrap(
      spacing: 12,
      runSpacing: 16,
      children: achievements
          .map((a) => SizedBox(
                width: (MediaQuery.of(context).size.width - 56) / 3,
                child: AchievementBadge(
                  achievement: a,
                  unlocked: unlocked,
                ),
              ))
          .toList(),
    );
  }

  Widget _statCol(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            color: color,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title, Color color) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 10,
        color: color,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}
