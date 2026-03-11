import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import '../constants/colors.dart';
import '../widgets/apex_card.dart';
import '../widgets/apex_button.dart';
import '../widgets/apex_screen_header.dart';
import '../services/supabase_service.dart';

class SocialFeedScreen extends StatefulWidget {
  const SocialFeedScreen({super.key});

  @override
  State<SocialFeedScreen> createState() => _SocialFeedScreenState();
}

class _SocialFeedScreenState extends State<SocialFeedScreen> {
  bool _cloning = false;

  final List<Map<String, dynamic>> _mockFeed = [
    {
      'id': '1',
      'user_name': 'Alex C.',
      'user_avatar': 'https://i.pravatar.cc/150?u=alex',
      'title': 'Chest & Triceps Destroyer',
      'duration': '65m',
      'volume': '8,400kg',
      'time_ago': '2h ago',
      'badges': ['NEW PR: Bench Press 105kg'],
      'exercises': ['Bench Press', 'Incline Dumbbell Press', 'Tricep Pushdown', 'Overhead Extension']
    },
    {
      'id': '2',
      'user_name': 'Sarah W.',
      'user_avatar': 'https://i.pravatar.cc/150?u=sarah',
      'title': 'Leg Day (Hypertrophy)',
      'duration': '80m',
      'volume': '12,200kg',
      'time_ago': '5h ago',
      'badges': [],
      'exercises': ['Barbell Squat', 'Leg Press', 'Romanian Deadlift', 'Calf Raises']
    },
    {
      'id': '3',
      'user_name': 'David M.',
      'user_avatar': 'https://i.pravatar.cc/150?u=david',
      'title': 'HIIT Cardio Circuit',
      'duration': '30m',
      'volume': '0kg',
      'time_ago': '1d ago',
      'badges': ['Consistency Streak: 14 Days'],
      'exercises': ['Burpees', 'Mountain Climbers', 'Jump Squats', 'Plank']
    }
  ];

  Future<void> _cloneRoutine(Map<String, dynamic> post) async {
    Haptics.vibrate(HapticsType.medium);
    setState(() => _cloning = true);
    
    try {
      // Mock network delay
      await Future.delayed(const Duration(milliseconds: 800));
      
      final wName = '${post['title']} (Cloned)';
      final wType = 'hypertrophy';
      
      final savedWorkout = await SupabaseService.createWorkout(
        SupabaseService.currentUser!.id,
        wName,
        wType,
      );
      
      final clonedExercises = (post['exercises'] as List).map((ex) {
        return {
          'workout_id': savedWorkout['id'],
          'name': ex.toString(),
          'target_weight': 0,
          'reps': '10',
          'sets': 3,
        };
      }).toList();
      
      await SupabaseService.createExercises(clonedExercises);
      
      if (mounted) {
        Haptics.vibrate(HapticsType.success);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${post['title']} cloned to your routines!'),
            backgroundColor: ApexColors.accent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Haptics.vibrate(HapticsType.error);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to clone routine.'), backgroundColor: ApexColors.red),
        );
      }
    }
    
    if (mounted) setState(() => _cloning = false);
  }

  void _showVersus(Map<String, dynamic> post) {
    Haptics.vibrate(HapticsType.selection);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: ApexColors.surfaceStrong,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: ApexColors.borderStrong),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: ApexColors.border, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 24),
            Text('Versus Analytics', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 22, color: ApexColors.t1)),
            const SizedBox(height: 4),
            Text('Comparing your stats with ${post['user_name']}', style: TextStyle(color: ApexColors.t2, fontSize: 13)),
            const SizedBox(height: 32),
            _buildVersusStat('Total Volume (Last 30d)', '45,200kg', '62,100kg', false, post['user_name']),
            const SizedBox(height: 16),
            _buildVersusStat('Workouts Logged', '16', '14', true, post['user_name']),
            const SizedBox(height: 16),
            _buildVersusStat('Avg Session', '45m', '55m', false, post['user_name']),
            const SizedBox(height: 32),
            ApexButton(text: 'Close', onPressed: () => Navigator.pop(ctx), outline: true, full: true),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildVersusStat(String label, String myStat, String theirStat, bool iWin, String theirName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: ApexColors.t2, fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: iWin ? ApexColors.accent.withAlpha(40) : ApexColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: iWin ? ApexColors.accent : ApexColors.border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('You', style: TextStyle(color: ApexColors.t3, fontSize: 10)),
                    const SizedBox(height: 4),
                    Text(myStat, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: iWin ? ApexColors.accent : ApexColors.t1)),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('VS', style: TextStyle(color: ApexColors.t3, fontSize: 12, fontWeight: FontWeight.w900)),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: !iWin ? ApexColors.orange.withAlpha(30) : ApexColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: !iWin ? ApexColors.orange : ApexColors.border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(theirName, style: TextStyle(color: ApexColors.t3, fontSize: 10)),
                    const SizedBox(height: 4),
                    Text(theirStat, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: !iWin ? ApexColors.orange : ApexColors.t1)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          ApexScreenHeader(
            eyebrow: 'Community',
            title: 'Social Feed',
            subtitle: 'Real-time activity and routine syndication from your circles.',
          ),
          const SizedBox(height: 16),
          ..._mockFeed.map((post) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ApexCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundImage: NetworkImage(post['user_avatar']),
                          backgroundColor: ApexColors.surfaceStrong,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(post['user_name'], style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: ApexColors.t1)),
                              Text(post['time_ago'], style: TextStyle(fontSize: 10, color: ApexColors.t3)),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _showVersus(post),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: ApexColors.surfaceStrong, borderRadius: BorderRadius.circular(8), border: Border.all(color: ApexColors.border)),
                            child: Row(
                              children: [
                                const Icon(Icons.stacked_bar_chart_rounded, size: 12, color: ApexColors.t2),
                                const SizedBox(width: 6),
                                Text('Versus', style: TextStyle(color: ApexColors.t2, fontSize: 10, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(post['title'], style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18, color: ApexColors.t1)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 12, color: ApexColors.t2),
                        const SizedBox(width: 4),
                        Text(post['duration'], style: TextStyle(fontSize: 12, color: ApexColors.t2, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 12),
                        const Icon(Icons.fitness_center_outlined, size: 12, color: ApexColors.t2),
                        const SizedBox(width: 4),
                        Text(post['volume'], style: TextStyle(fontSize: 12, color: ApexColors.t2, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if ((post['badges'] as List).isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        children: (post['badges'] as List).map<Widget>((b) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: ApexColors.yellow.withAlpha(30), borderRadius: BorderRadius.circular(4)),
                          child: Text(b, style: TextStyle(color: ApexColors.yellow, fontSize: 9, fontWeight: FontWeight.w900)),
                        )).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: ApexColors.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: ApexColors.border)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ROUTINE SUMMARY', style: TextStyle(fontSize: 9, color: ApexColors.t3, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          Text((post['exercises'] as List).join(' • '), style: const TextStyle(fontSize: 11, color: ApexColors.t2, height: 1.4)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ApexButton(
                      text: 'Clone Routine',
                      icon: Icons.content_copy_rounded,
                      onPressed: () => _cloneRoutine(post),
                      loading: _cloning,
                      full: true,
                      sm: true,
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
