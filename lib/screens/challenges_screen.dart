import 'package:flutter/material.dart';
import 'package:apex_ai/constants/colors.dart';
import 'package:apex_ai/widgets/apex_card.dart';
import 'package:apex_ai/widgets/apex_button.dart';
import 'package:apex_ai/widgets/empty_state_widget.dart';
import 'package:google_fonts/google_fonts.dart';

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  // Sample challenges — replace with Supabase fetch when table exists
  final List<Map<String, dynamic>> _activeChallenges = [
    {
      'title': '30-Day Strength Challenge',
      'description': 'Complete 20 strength workouts in 30 days',
      'participants': 1243,
      'daysLeft': 18,
      'progress': 0.6,
      'color': 0xFF00FFA0,
      'icon': '🏋️',
      'joined': true,
    },
    {
      'title': 'March Step Master',
      'description': 'Hit 10,000 steps every day this month',
      'participants': 3892,
      'daysLeft': 14,
      'progress': 0.43,
      'color': 0xFF3D9BFF,
      'icon': '🏃',
      'joined': false,
    },
    {
      'title': 'Protein King',
      'description': 'Hit your protein goal 25 days this month',
      'participants': 567,
      'daysLeft': 14,
      'progress': 0.0,
      'color': 0xFFFF6B2B,
      'icon': '🥩',
      'joined': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
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
        title: Text(
          'Challenges',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: ApexColors.t1,
          ),
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: ApexColors.accent,
          unselectedLabelColor: ApexColors.t3,
          indicatorColor: ApexColors.accent,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: 'Explore'),
            Tab(text: 'My Challenges'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // ALL CHALLENGES
          ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: _activeChallenges.length,
            itemBuilder: (_, i) => _challengeCard(_activeChallenges[i]),
          ),
          // MY CHALLENGES
          _activeChallenges.where((c) => c['joined'] == true).isEmpty
              ? const EmptyStateWidget(
                  icon: Icons.emoji_events_outlined,
                  title: 'No active challenges',
                  subtitle: 'Join a challenge from the Explore tab!',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: _activeChallenges
                      .where((c) => c['joined'] == true)
                      .length,
                  itemBuilder: (_, i) {
                    final joined = _activeChallenges
                        .where((c) => c['joined'] == true)
                        .toList();
                    return _challengeCard(joined[i], showProgress: true);
                  },
                ),
        ],
      ),
    );
  }

  Widget _challengeCard(
    Map<String, dynamic> c, {
    bool showProgress = false,
  }) {
    final color = Color(c['color'] as int);
    final joined = c['joined'] as bool? ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ApexCard(
        glow: joined,
        glowColor: color,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(c['icon'] as String,
                    style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c['title'] as String,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: ApexColors.t1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        c['description'] as String,
                        style: const TextStyle(
                            fontSize: 12, color: ApexColors.t2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _pill(
                  '${c['participants']} joined',
                  Icons.people_rounded,
                  ApexColors.t3,
                ),
                const SizedBox(width: 8),
                _pill(
                  '${c['daysLeft']} days left',
                  Icons.timer_rounded,
                  color,
                ),
                if (joined) ...[
                  const SizedBox(width: 8),
                  _pill('Joined ✓', Icons.check_circle_rounded, color),
                ],
              ],
            ),
            if (showProgress && joined) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Progress',
                      style: TextStyle(
                          fontSize: 11,
                          color: ApexColors.t3,
                          fontWeight: FontWeight.w600)),
                  Text(
                    '${((c['progress'] as double) * 100).round()}%',
                    style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: LinearProgressIndicator(
                  value: c['progress'] as double,
                  minHeight: 6,
                  backgroundColor: ApexColors.cardAlt,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ],
            if (!joined) ...[
              const SizedBox(height: 14),
              ApexButton(
                text: 'Join Challenge',
                onPressed: () {
                  setState(() => c['joined'] = true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Joined: ${c['title']}'),
                      backgroundColor: color,
                    ),
                  );
                },
                sm: true,
                full: true,
                color: color,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pill(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
