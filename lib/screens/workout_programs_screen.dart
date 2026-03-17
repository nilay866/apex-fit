import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import '../constants/colors.dart';
import '../services/supabase_service.dart';

class WorkoutProgramsScreen extends StatefulWidget {
  const WorkoutProgramsScreen({super.key});

  @override
  State<WorkoutProgramsScreen> createState() => _WorkoutProgramsScreenState();
}

class _WorkoutProgramsScreenState extends State<WorkoutProgramsScreen> {
  List<Map<String, dynamic>> _programs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await SupabaseService.getWorkoutPrograms();
    if (mounted) {
      setState(() {
        _programs = res;
        _loading = false;
      });
    }
  }

  Future<void> _enroll(String programId) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    Haptics.vibrate(HapticsType.medium);
    await SupabaseService.enrollInProgram(userId, programId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Successfully enrolled in program!'),
          backgroundColor: ApexColors.accent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ApexColors.bg,
      appBar: AppBar(
        backgroundColor: ApexColors.bg,
        elevation: 0,
        title: Text(
          'Programs',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            color: ApexColors.t1,
          ),
        ),
        iconTheme: const IconThemeData(color: ApexColors.t1),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: ApexColors.accent),
            )
          : _programs.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _programs.length,
              itemBuilder: (ctx, i) {
                final p = _programs[i];
                return _buildProgramCard(p);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_graph,
            size: 64,
            color: ApexColors.t3.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No programs available yet.',
            style: TextStyle(color: ApexColors.t2, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back soon for AI-generated plans.',
            style: TextStyle(color: ApexColors.t3, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildProgramCard(Map<String, dynamic> p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: ApexColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ApexColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Area
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  ApexColors.accent.withValues(alpha: 0.8),
                  ApexColors.blue.withValues(alpha: 0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    p['difficulty']?.toUpperCase() ?? 'INTERMEDIATE',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  p['name'] ?? 'Training Program',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p['description'] ?? 'No description available.',
                  style: TextStyle(
                    color: ApexColors.t2,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _buildMetaInfo(
                      Icons.calendar_today,
                      '${p['duration_weeks'] ?? 4} Weeks',
                    ),
                    const SizedBox(width: 16),
                    _buildMetaInfo(
                      Icons.flash_on,
                      'Level: ${p['difficulty'] ?? 'All'}',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _enroll(p['id']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ApexColors.accent,
                      foregroundColor: ApexColors.bg,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'ENROLL IN PROGRAM',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaInfo(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: ApexColors.t3),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: ApexColors.t3,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
