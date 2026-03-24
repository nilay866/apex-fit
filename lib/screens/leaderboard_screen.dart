import 'package:flutter/material.dart';
import 'package:apex_ai/constants/colors.dart';
import 'package:google_fonts/google_fonts.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});
  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

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
        title: Text('Leaderboard',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: ApexColors.t1)),
        bottom: TabBar(
          controller: _tabs,
          labelColor: ApexColors.yellow,
          unselectedLabelColor: ApexColors.t3,
          indicatorColor: ApexColors.yellow,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [Tab(text: 'Global'), Tab(text: 'Friends')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _leaderList(isGlobal: true),
          _leaderList(isGlobal: false),
        ],
      ),
    );
  }

  Widget _leaderList({required bool isGlobal}) {
    // Sample data — replace with real Supabase fetch
    final entries = List.generate(
      20,
      (i) => {
        'rank': i + 1,
        'name': ['Alex M.', 'Sam R.', 'Jordan K.', 'Chris P.', 'You'][i % 5],
        'xp': 5000 - (i * 180),
        'streak': 30 - i,
        'isMe': i == 4,
      },
    );

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: entries.length,
      itemBuilder: (_, i) {
        final e = entries[i];
        final isMe = e['isMe'] as bool;
        final rank = e['rank'] as int;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isMe
                  ? ApexColors.accent.withAlpha(15)
                  : ApexColors.cardAlt,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isMe
                    ? ApexColors.accent.withAlpha(60)
                    : ApexColors.borderStrong,
              ),
            ),
            child: Row(
              children: [
                // Rank
                SizedBox(
                  width: 36,
                  child: Text(
                    rank <= 3
                        ? ['🥇', '🥈', '🥉'][rank - 1]
                        : '#$rank',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w900,
                      fontSize: rank <= 3 ? 20 : 14,
                      color:
                          rank <= 3 ? ApexColors.yellow : ApexColors.t3,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Avatar placeholder
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ApexColors.accent.withAlpha(20),
                  ),
                  child: const Icon(Icons.person_rounded,
                      color: ApexColors.accent, size: 18),
                ),
                const SizedBox(width: 12),
                // Name + streak
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${e['name']}${isMe ? ' (You)' : ''}',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color:
                              isMe ? ApexColors.accent : ApexColors.t1,
                        ),
                      ),
                      Text(
                        '🔥 ${e['streak']} day streak',
                        style: const TextStyle(
                            fontSize: 11, color: ApexColors.t3),
                      ),
                    ],
                  ),
                ),
                // XP
                Text(
                  '${e['xp']} XP',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: isMe ? ApexColors.accent : ApexColors.t2,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
