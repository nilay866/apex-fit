import 'package:flutter/material.dart';
import 'package:apex_ai/constants/colors.dart';
import 'package:apex_ai/services/supabase_service.dart';
import 'package:apex_ai/repositories/auth_repository.dart';
import 'package:apex_ai/widgets/empty_state_widget.dart';
import 'package:apex_ai/widgets/error_state_widget.dart';
import 'package:google_fonts/google_fonts.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});
  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Map<String, dynamic>> _globalEntries = [];
  List<Map<String, dynamic>> _friendEntries = [];
  bool _loading = true;
  String? _error;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _currentUserId = authRepository.userId;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Fetch top 50 profiles by XP
      final globalRaw = await SupabaseService.client
          .from('profiles')
          .select('id, name, avatar_data, xp_total')
          .order('xp_total', ascending: false)
          .limit(50);

      // Fetch streaks for those users
      final ids = (globalRaw as List)
          .map((e) => e['id'] as String?)
          .whereType<String>()
          .toList();

      Map<String, int> streakMap = {};
      if (ids.isNotEmpty) {
        try {
          final streakRaw = await SupabaseService.client
              .from('workout_streaks')
              .select('user_id, current_streak')
              .inFilter('user_id', ids);
          for (final s in streakRaw as List) {
            streakMap[s['user_id'] as String] = (s['current_streak'] as int?) ?? 0;
          }
        } catch (_) {}
      }

      final global = (globalRaw as List).asMap().entries.map((entry) {
        final i = entry.key;
        final e = entry.value as Map<String, dynamic>;
        final uid = e['id'] as String?;
        return {
          'rank': i + 1,
          'id': uid ?? '',
          'name': (e['name'] as String?) ?? 'Athlete',
          'xp': (e['xp_total'] as int?) ?? 0,
          'streak': streakMap[uid ?? ''] ?? 0,
          'isMe': uid == _currentUserId,
        };
      }).toList();

      // Friends tab: filter to entries where user is a friend
      List<Map<String, dynamic>> friends = [];
      try {
        final friendRows = await SupabaseService.client
            .from('friends')
            .select('friend_id')
            .eq('user_id', _currentUserId ?? '');
        final friendIds = (friendRows as List)
            .map((f) => f['friend_id'] as String?)
            .whereType<String>()
            .toSet();
        friends = global
            .where((e) =>
                e['isMe'] == true || friendIds.contains(e['id'] as String))
            .toList();
        // Re-rank friends list
        for (var i = 0; i < friends.length; i++) {
          friends[i] = {...friends[i], 'rank': i + 1};
        }
      } catch (_) {
        friends = global.where((e) => e['isMe'] == true).toList();
      }

      if (mounted) {
        setState(() {
          _globalEntries = global;
          _friendEntries = friends;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = SupabaseService.describeError(e);
          _loading = false;
        });
      }
    }
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: ApexColors.t2, size: 20),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: ApexColors.yellow,
          unselectedLabelColor: ApexColors.t3,
          indicatorColor: ApexColors.yellow,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [Tab(text: 'Global'), Tab(text: 'Friends')],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorStateWidget(
                  message: _error!,
                  onRetry: _load,
                )
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _leaderList(_globalEntries),
                    _leaderList(_friendEntries, emptyTitle: 'No friends yet'),
                  ],
                ),
    );
  }

  Widget _leaderList(
    List<Map<String, dynamic>> entries, {
    String emptyTitle = 'No data yet',
  }) {
    if (entries.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.emoji_events_outlined,
        title: emptyTitle,
        subtitle: 'Complete workouts to earn XP and climb the ranks.',
      );
    }
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
                      color: rank <= 3 ? ApexColors.yellow : ApexColors.t3,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Avatar
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isMe
                        ? ApexColors.accent.withAlpha(20)
                        : ApexColors.surface,
                    border: Border.all(color: ApexColors.borderStrong),
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    color: isMe ? ApexColors.accent : ApexColors.t3,
                    size: 18,
                  ),
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
                          color: isMe ? ApexColors.accent : ApexColors.t1,
                        ),
                      ),
                      if ((e['streak'] as int) > 0)
                        Text(
                          '${e['streak']} day streak',
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
