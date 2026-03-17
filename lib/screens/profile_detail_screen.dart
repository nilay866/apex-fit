import 'package:flutter/material.dart';
import 'package:apex_ai/constants/colors.dart';
import 'package:apex_ai/constants/theme.dart';
import 'package:apex_ai/widgets/apex_card.dart';
import 'package:apex_ai/services/supabase_service.dart';
import 'package:apex_ai/screens/settings_screen.dart';
import 'package:apex_ai/screens/achievements_screen.dart';
import 'package:apex_ai/screens/level_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileDetailScreen extends StatefulWidget {
  const ProfileDetailScreen({super.key});

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  int _totalWorkouts = 0;
  double _totalVolume = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final uid = SupabaseService.currentUser?.id;
      if (uid == null) return;
      final profile = await SupabaseService.getProfile(uid);
      final logs = await SupabaseService.getWorkoutLogs(uid, limit: 200);
      double vol = 0;
      for (final l in logs) {
        vol += (l['total_volume'] as num?)?.toDouble() ?? 0;
      }
      if (mounted) {
        setState(() {
          _profile = profile;
          _totalWorkouts = logs.length;
          _totalVolume = vol;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _profile?['name']?.toString() ?? 'Athlete';
    final bio = _profile?['bio']?.toString() ?? '';
    final avatarUrl = _profile?['avatar_url']?.toString();

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
        title: Text('Profile',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: ApexColors.t1)),
        actions: [
          IconButton(
            icon:
                const Icon(Icons.settings_rounded, color: ApexColors.t2),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: ApexColors.accent))
          : RefreshIndicator(
              onRefresh: _load,
              color: ApexColors.accent,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                children: [
                  const SizedBox(height: 12),

                  // Avatar + stats row
                  ApexCard(
                    child: Row(
                      children: [
                        // Avatar
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: ApexColors.accent.withAlpha(30),
                            border: Border.all(
                              color: ApexColors.accent.withAlpha(80),
                              width: 2,
                            ),
                          ),
                          child: avatarUrl != null
                              ? ClipOval(
                                  child: Image.network(
                                    avatarUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, e2, s2) =>
                                        const Icon(Icons.person_rounded,
                                            color: ApexColors.accent,
                                            size: 36),
                                  ),
                                )
                              : const Icon(Icons.person_rounded,
                                  color: ApexColors.accent, size: 36),
                        ),
                        const SizedBox(width: 20),
                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 20,
                                  color: ApexColors.t1,
                                ),
                              ),
                              if (bio.isNotEmpty)
                                Text(
                                  bio,
                                  style: const TextStyle(
                                      fontSize: 12, color: ApexColors.t2),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Stats row
                  ApexCard(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _statCol('Workouts', '$_totalWorkouts'),
                        _statCol(
                          'Volume',
                          _totalVolume > 1000
                              ? '${(_totalVolume / 1000).toStringAsFixed(1)}t'
                              : '${_totalVolume.round()}kg',
                        ),
                        _statCol('Streak',
                            '${_profile?['streak_current'] ?? 0}🔥'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Activity section placeholder
                  ApexCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Activity',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: ApexColors.t1,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'View your activity streak on the Stats tab.',
                          style: const TextStyle(
                            fontSize: 13,
                            color: ApexColors.t2,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Achievements preview
                  ApexCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Achievements',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: ApexColors.t1,
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const AchievementsScreen(),
                                ),
                              ),
                              child: Text(
                                'See all',
                                style: GoogleFonts.inter(
                                  color: ApexColors.accent,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tap "See all" to view your full achievement collection.',
                          style: TextStyle(
                              fontSize: 12, color: ApexColors.t3),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Level/XP card
                  ApexCard(
                    glow: true,
                    glowColor: ApexColors.purple,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Fitness Level',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: ApexColors.t1,
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const LevelScreen(),
                                ),
                              ),
                              child: Text(
                                'View XP',
                                style: GoogleFonts.inter(
                                  color: ApexColors.purple,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _xpBar(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _statCol(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: ApexTheme.mono(size: 18, color: ApexColors.t1),
        ),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 9,
            color: ApexColors.t3,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _xpBar() {
    final xp = (_profile?['xp_total'] as int?) ?? 0;
    final level = (xp / 500).floor() + 1;
    final xpInLevel = xp % 500;
    final pct = xpInLevel / 500;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Level $level',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w900,
                fontSize: 22,
                color: ApexColors.purple,
              ),
            ),
            Text(
              '$xpInLevel / 500 XP',
              style: ApexTheme.mono(size: 11, color: ApexColors.t3),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            backgroundColor: ApexColors.cardAlt,
            valueColor: const AlwaysStoppedAnimation(ApexColors.purple),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${500 - xpInLevel} XP to Level ${level + 1}',
          style: const TextStyle(fontSize: 11, color: ApexColors.t3),
        ),
      ],
    );
  }
}
