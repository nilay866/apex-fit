import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import '../constants/colors.dart';
import '../services/exercise_animation_service.dart';
import '../services/supabase_service.dart';
import 'exercise_detail_screen.dart';

class ExerciseLibraryScreen extends StatefulWidget {
  final Function(Map<String, dynamic>)? onSelect;

  const ExerciseLibraryScreen({super.key, this.onSelect});

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  List<Map<String, dynamic>> _allExercises = [];
  List<Map<String, dynamic>> _exercises = [];
  bool _loading = true;

  // Filters
  String? _selectedMuscle;
  String? _selectedEnv;
  String? _selectedEquipment;
  String? _selectedDifficulty;
  String _searchQuery = '';

  final List<String> _muscles = [
    'Chest',
    'Back',
    'Legs',
    'Arms',
    'Shoulders',
    'Core',
    'Glutes',
    'Cardio',
  ];
  final List<String> _environments = ['Gym', 'Home'];
  final List<String> _difficulties = ['Beginner', 'Intermediate', 'Advanced'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    // Use the new Intelligence System method
    final res = await SupabaseService.getExercises(
      muscle: _selectedMuscle,
      environment: _selectedEnv,
      equipment: _selectedEquipment,
    );
    if (mounted) {
      setState(() {
        _allExercises = res;
        _exercises = _applyLocalFilters(res);
        _loading = false;
      });
    }
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

  void _onDifficultyTap(String difficulty) {
    Haptics.vibrate(HapticsType.selection);
    setState(() {
      _selectedDifficulty = _selectedDifficulty == difficulty
          ? null
          : difficulty;
      _exercises = _applyLocalFilters(_allExercises);
    });
  }

  List<Map<String, dynamic>> _applyLocalFilters(
    List<Map<String, dynamic>> source,
  ) {
    return source.where((exercise) {
      final name = (exercise['name'] ?? '').toString().toLowerCase();
      final difficulty = (exercise['difficulty'] ?? '').toString();

      if (_searchQuery.isNotEmpty &&
          !name.contains(_searchQuery.toLowerCase())) {
        return false;
      }
      if (_selectedDifficulty != null && difficulty != _selectedDifficulty) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ApexColors.bg,
      appBar: AppBar(
        backgroundColor: ApexColors.bg,
        elevation: 0,
        title: Text(
          'Exercise Library',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            color: ApexColors.t1,
          ),
        ),
        iconTheme: const IconThemeData(color: ApexColors.t1),
      ),
      body: Column(
        children: [
          // Search & Filter Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              style: const TextStyle(color: ApexColors.t1),
              decoration: InputDecoration(
                hintText: 'Search exercises...',
                hintStyle: TextStyle(color: ApexColors.t3),
                prefixIcon: const Icon(Icons.search, color: ApexColors.t3),
                filled: true,
                fillColor: ApexColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: ApexColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: ApexColors.border),
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim();
                  _exercises = _applyLocalFilters(_allExercises);
                });
              },
            ),
          ),

          // 3D Anatomical Body Selector Mock (Filter chips for now)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
            decoration: const BoxDecoration(color: ApexColors.bg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VISUAL ANATOMICAL FILTER',
                  style: TextStyle(
                    color: ApexColors.t2,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: sel
                                  ? ApexColors.accent
                                  : ApexColors.cardAlt,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: sel
                                    ? ApexColors.accent
                                    : ApexColors.border,
                              ),
                            ),
                            child: Text(
                              m,
                              style: TextStyle(
                                color: sel ? ApexColors.bg : ApexColors.t1,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'ENVIRONMENT',
                  style: TextStyle(
                    color: ApexColors.t2,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
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
                              child: Text(
                                e,
                                style: TextStyle(
                                  color: sel ? ApexColors.bg : ApexColors.t1,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                Text(
                  'DIFFICULTY',
                  style: TextStyle(
                    color: ApexColors.t2,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _difficulties.map((difficulty) {
                      final selected = _selectedDifficulty == difficulty;
                      final color = switch (difficulty) {
                        'Advanced' => ApexColors.red,
                        'Intermediate' => ApexColors.orange,
                        _ => ApexColors.accent,
                      };
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => _onDifficultyTap(difficulty),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: selected ? color : ApexColors.cardAlt,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: selected ? color : ApexColors.border,
                              ),
                            ),
                            child: Text(
                              difficulty,
                              style: TextStyle(
                                color: selected ? ApexColors.bg : ApexColors.t1,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: ApexColors.accent),
                  )
                : _exercises.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_off_rounded,
                                  size: 48, color: ApexColors.t3),
                              SizedBox(height: 12),
                              Text(
                                'No exercises found',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: ApexColors.t2,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Try adjusting your filters or search term.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 13, color: ApexColors.t3),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    itemCount: _exercises.length,
                    itemBuilder: (ctx, i) {
                      final ex = _exercises[i];
                      final hasBuiltInGuide =
                          (ex['animation_key'] as String?)?.isNotEmpty ==
                              true ||
                          ExerciseAnimationService.getBuiltInMotionKey(
                                ex['name']?.toString() ?? '',
                              ) !=
                              null;
                      return GestureDetector(
                        onTap: () {
                          Haptics.vibrate(HapticsType.light);
                          if (widget.onSelect != null) {
                            widget.onSelect!(ex);
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ExerciseDetailScreen(exercise: ex),
                              ),
                            );
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(
                            bottom: 8,
                            left: 16,
                            right: 16,
                          ),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: ApexColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: ApexColors.border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ex['name'] ?? '',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w800,
                                        color: ApexColors.t1,
                                        fontSize: 16,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 6,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.fitness_center,
                                              size: 12,
                                              color: ApexColors.t3,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              ex['equipment'] ?? 'Bodyweight',
                                              style: TextStyle(
                                                color: ApexColors.t3,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.accessibility_new,
                                              size: 12,
                                              color: ApexColors.t3,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              ex['primary_muscle'] ?? '',
                                              style: TextStyle(
                                                color: ApexColors.t3,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        if ((ex['difficulty'] ?? '')
                                            .toString()
                                            .isNotEmpty)
                                          _pill(
                                            ex['difficulty'].toString(),
                                            switch (ex['difficulty']) {
                                              'Advanced' => ApexColors.red,
                                              'Intermediate' =>
                                                ApexColors.orange,
                                              _ => ApexColors.accent,
                                            },
                                          ),
                                        if (hasBuiltInGuide)
                                          _pill(
                                            'Animated Guide',
                                            ApexColors.blue,
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Icon(
                                Icons.chevron_right,
                                color: ApexColors.t3,
                              ),
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

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
