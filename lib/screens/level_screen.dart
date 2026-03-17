import 'package:flutter/material.dart';
import 'package:apex_ai/constants/colors.dart';
import 'package:apex_ai/constants/theme.dart';
import 'package:apex_ai/widgets/apex_card.dart';
import 'package:apex_ai/services/supabase_service.dart';
import 'package:google_fonts/google_fonts.dart';

class LevelScreen extends StatefulWidget {
  const LevelScreen({super.key});
  @override
  State<LevelScreen> createState() => _LevelScreenState();
}

class _LevelScreenState extends State<LevelScreen> {
  int _xp = 0;
  bool _loading = true;

  static const _xpRewards = [
    {'action': 'Complete a workout', 'xp': 50},
    {'action': 'Hit a PR', 'xp': 100},
    {'action': 'Log all meals', 'xp': 30},
    {'action': 'Maintain streak', 'xp': 20},
    {'action': 'Complete a challenge', 'xp': 200},
    {'action': 'Log water goal', 'xp': 10},
    {'action': 'AI coach conversation', 'xp': 15},
    {'action': '7-day streak milestone', 'xp': 150},
  ];

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
      if (mounted) {
        setState(() {
          _xp = (profile?['xp_total'] as int?) ?? 0;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _level => (_xp / 500).floor() + 1;
  int get _xpInLevel => _xp % 500;
  double get _pct => _xpInLevel / 500;

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
        title: Text('Level & XP',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: ApexColors.t1)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: ApexColors.accent))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                // Level card
                ApexCard(
                  glow: true,
                  glowColor: ApexColors.purple,
                  child: Column(
                    children: [
                      Text(
                        'Level $_level',
                        style: GoogleFonts.inter(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: ApexColors.purple,
                          letterSpacing: -2,
                        ),
                      ),
                      Text(
                        _levelTitle(_level),
                        style: const TextStyle(
                            fontSize: 14,
                            color: ApexColors.t2,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 24),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: LinearProgressIndicator(
                          value: _pct,
                          minHeight: 12,
                          backgroundColor: ApexColors.cardAlt,
                          valueColor: const AlwaysStoppedAnimation(
                              ApexColors.purple),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('$_xpInLevel / 500 XP',
                              style: ApexTheme.mono(
                                  size: 11, color: ApexColors.t3)),
                          Text(
                              '${500 - _xpInLevel} to Level ${_level + 1}',
                              style: const TextStyle(
                                  fontSize: 11, color: ApexColors.t3)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Total: $_xp XP',
                        style: ApexTheme.mono(
                            size: 13, color: ApexColors.purple),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'HOW TO EARN XP',
                  style: TextStyle(
                    fontSize: 10,
                    color: ApexColors.t3,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                ApexCard(
                  child: Column(
                    children: _xpRewards.asMap().entries.map((e) {
                      final isLast = e.key == _xpRewards.length - 1;
                      return Column(
                        children: [
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  e.value['action'] as String,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: ApexColors.t1,
                                      fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  '+${e.value['xp']} XP',
                                  style: ApexTheme.mono(
                                      size: 12, color: ApexColors.yellow),
                                ),
                              ],
                            ),
                          ),
                          if (!isLast)
                            const Divider(
                                color: ApexColors.border, height: 1),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
    );
  }

  String _levelTitle(int level) {
    if (level >= 20) return 'Elite Athlete 🏆';
    if (level >= 15) return 'Advanced Lifter 💪';
    if (level >= 10) return 'Consistent Trainer ⚡';
    if (level >= 5) return 'Building Momentum 🔥';
    return 'Getting Started 🌱';
  }
}
