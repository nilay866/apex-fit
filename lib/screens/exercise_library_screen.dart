import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import '../constants/colors.dart';
import '../constants/theme.dart';
import '../services/supabase_service.dart';
import 'exercise_detail_screen.dart';

class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  List<Map<String, dynamic>> _exercises = [];
  bool _loading = true;

  // Filters
  String? _selectedMuscle;
  String? _selectedEnv;
  String? _selectedEquipment;

  final List<String> _muscles = ['Chest', 'Back', 'Legs', 'Arms', 'Shoulders', 'Core'];
  final List<String> _environments = ['Gym', 'Home'];
  final List<String> _equipments = ['Barbell', 'Dumbbell', 'Machine', 'Bodyweight', 'Cables'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await SupabaseService.getExerciseDictionary(
      muscleGroup: _selectedMuscle,
      environment: _selectedEnv,
      equipment: _selectedEquipment,
    );
    if (mounted) setState(() {
      _exercises = res;
      _loading = false;
    });
  }

  void _onMuscleTap(String muscle) {
    Haptics.vibrate(HapticsType.selection);
    setState(() {
      _selectedMuscle = _selectedMuscle == muscle ? null : muscle;
    });
    _load();
  }

  void _onEnvTap(String env) {
    Haptics.vibrate(HapticsType.selection);
    setState(() {
      _selectedEnv = _selectedEnv == env ? null : env;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ApexColors.bg,
      appBar: AppBar(
        backgroundColor: ApexColors.bg,
        elevation: 0,
        title: Text('Exercise Library', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: ApexColors.t1)),
        iconTheme: const IconThemeData(color: ApexColors.t1),
      ),
      body: Column(
        children: [
          // 3D Anatomical Body Selector Mock (Filter chips for now)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: const BoxDecoration(
              color: ApexColors.surface,
              border: Border(bottom: BorderSide(color: ApexColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('VISUAL ANATOMICAL FILTER', style: TextStyle(color: ApexColors.t2, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _muscles.map((m) {
                      final sel = _selectedMuscle == m;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => _onMuscleTap(m),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: sel ? ApexColors.accent : ApexColors.cardAlt,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: sel ? ApexColors.accent : ApexColors.border),
                            ),
                            child: Text(m, style: TextStyle(color: sel ? ApexColors.bg : ApexColors.t1, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),
                Text('ENVIRONMENT', style: TextStyle(color: ApexColors.t2, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                const SizedBox(height: 12),
                Row(
                  children: _environments.map((e) {
                    final sel = _selectedEnv == e;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: GestureDetector(
                          onTap: () => _onEnvTap(e),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: sel ? ApexColors.blue : ApexColors.cardAlt,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(e, style: TextStyle(color: sel ? ApexColors.bg : ApexColors.t1, fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: _loading
              ? const Center(child: CircularProgressIndicator(color: ApexColors.accent))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount: _exercises.length,
                  itemBuilder: (ctx, i) {
                    final ex = _exercises[i];
                    return GestureDetector(
                      onTap: () {
                        Haptics.vibrate(HapticsType.light);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => ExerciseDetailScreen(exercise: ex)));
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: ApexColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: ApexColors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(ex['name'] ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: ApexColors.t1, fontSize: 16)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.fitness_center, size: 12, color: ApexColors.t3),
                                    const SizedBox(width: 4),
                                    Text(ex['equipment'] ?? 'Bodyweight', style: TextStyle(color: ApexColors.t3, fontSize: 12)),
                                    const SizedBox(width: 12),
                                    Icon(Icons.accessibility_new, size: 12, color: ApexColors.t3),
                                    const SizedBox(width: 4),
                                    Text(ex['primary_muscle'] ?? '', style: TextStyle(color: ApexColors.t3, fontSize: 12)),
                                  ],
                                ),
                              ],
                            ),
                            const Icon(Icons.chevron_right, color: ApexColors.t3),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}
