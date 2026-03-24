import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  Set<String> _joinedIds = {};

  // Challenges data — will be replaced by Supabase fetch once the
  // `challenges` table is added to the schema.
  static const List<Map<String, dynamic>> _challengeList = [
    {
      'id': 'strength_30',
      'title': '30-Day Strength Challenge',
      'description': 'Complete 20 strength workouts in 30 days',
      'participants': 1243,
      'daysLeft': 18,
      'progress': 0.6,
      'colorKey': 'green',
      'icon': '🏋️',
    },
    {
      'id': 'steps_march',
      'title': 'March Step Master',
      'description': 'Hit 10,000 steps every day this month',
      'participants': 3892,
      'daysLeft': 14,
      'progress': 0.43,
      'colorKey': 'blue',
      'icon': '🏃',
    },
    {
      'id': 'protein_king',
      'title': 'Protein King',
      'description': 'Hit your protein goal 25 days this month',
      'participants': 567,
      'daysLeft': 14,
      'progress': 0.0,
      'colorKey': 'orange',
      'icon': '🥩',
    },
  ];

  Color _colorForKey(String key) {
    switch (key) {
      case 'green':
        return ApexColors.green;
      case 'blue':
        return ApexColors.blue;
      case 'orange':
        return ApexColors.orange;
      default:
        return ApexColors.accent;
    }
  }

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadJoined();
  }

  Future<void> _loadJoined() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final joined = prefs.getStringList('apex_joined_challenges') ?? [];
      if (mounted) setState(() => _joinedIds = joined.toSet());
    } catch (_) {}
  }

  Future<void> _joinChallenge(Map<String, dynamic> c) async {
    final id = c['id'] as String;
    setState(() => _joinedIds.add(id));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('apex_joined_challenges', _joinedIds.toList());
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Joined: ${c['title']}'),
          backgroundColor: _colorForKey(c['colorKey'] as String),
        ),
      );
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final joined = _challengeList
        .where((c) => _joinedIds.contains(c['id'] as String))
        .toList();

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
            itemCount: _challengeList.length,
            itemBuilder: (_, i) => _challengeCard(_challengeList[i]),
          ),
          // MY CHALLENGES
          joined.isEmpty
              ? const EmptyStateWidget(
                  icon: Icons.emoji_events_outlined,
                  title: 'No active challenges',
                  subtitle: 'Join a challenge from the Explore tab!',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: joined.length,
                  itemBuilder: (_, i) =>
                      _challengeCard(joined[i], showProgress: true),
                ),
        ],
      ),
    );
  }

  Widget _challengeCard(
    Map<String, dynamic> c, {
    bool showProgress = false,
  }) {
    final color = _colorForKey(c['colorKey'] as String);
    final joined = _joinedIds.contains(c['id'] as String);

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
                  _pill('Joined', Icons.check_circle_rounded, color),
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
                onPressed: () => _joinChallenge(c),
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
