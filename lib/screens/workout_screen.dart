import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import '../constants/colors.dart';
import '../constants/theme.dart';
import '../widgets/apex_button.dart';
import '../widgets/apex_card.dart';
import '../widgets/apex_screen_header.dart';
import '../widgets/apex_tag.dart';
import '../services/supabase_service.dart';
import 'exercise_library_screen.dart';

class WorkoutScreen extends StatefulWidget {
  final Function(Map<String, dynamic>) onStartWorkout;
  const WorkoutScreen({super.key, required this.onStartWorkout});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  List<Map<String, dynamic>> _workouts = [];
  bool _loading = true;
  String _folder = 'All';
  final List<String> _folders = ['All', 'Hypertrophy', 'Strength', 'Cardio', 'HIIT', 'Mobility'];

  static const _typeColors = {
    'Gym': ApexColors.blue,
    'Calisthenics': ApexColors.accentSoft,
    'HIIT': ApexColors.orange,
    'Mobility': ApexColors.purple,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final w = await SupabaseService.getWorkouts(
        SupabaseService.currentUser!.id,
      );
      if (mounted) {
        setState(() {
          _workouts = w;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showCreateModal() async {
    HapticFeedback.lightImpact();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ApexColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => _CreateWorkoutSheet(onSaved: _load),
    );
  }

  Future<void> _deleteWorkout(String id) async {
    HapticFeedback.mediumImpact();
    await SupabaseService.deleteWorkout(id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Background handled by main shell
      body: RefreshIndicator(
        onRefresh: _load,
        color: ApexColors.accent,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            ApexScreenHeader(
              eyebrow: 'Training',
              title: 'Workouts',
              subtitle:
                  '${_workouts.length} saved workout plans ready to start.',
              trailing: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ExerciseLibraryScreen()));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: ApexColors.cardAlt, borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.menu_book_rounded, color: ApexColors.accent, size: 16),
                      const SizedBox(width: 6),
                      Text('Library', style: GoogleFonts.inter(color: ApexColors.t1, fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(36),
                  child: CircularProgressIndicator(color: ApexColors.accent),
                ),
              )
            else if (_workouts.isEmpty)
              Center(
                child: Column(
                  children: [
                    const SizedBox(height: 36),
                    const Icon(
                      Icons.fitness_center_rounded,
                      size: 42,
                      color: ApexColors.accentSoft,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No workouts yet',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        color: ApexColors.t1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create your first workout with exercises, sets, and reps.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: ApexColors.t2,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              )
            else ...[
              SizedBox(
                height: 38,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _folders.length,
                  itemBuilder: (context, i) {
                    final f = _folders[i];
                    final sel = f == _folder;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _folder = f);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(color: sel ? ApexColors.accent : ApexColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: sel ? ApexColors.accent : ApexColors.border)),
                        child: Center(
                          child: Row(
                            children: [
                              Icon(sel ? Icons.folder_open : Icons.folder, size: 14, color: sel ? ApexColors.bg : ApexColors.t3),
                              const SizedBox(width: 6),
                              Text(f, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: sel ? ApexColors.bg : ApexColors.t2)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              ..._workouts.where((w) {
                if (_folder == 'All') return true;
                final t = w['type']?.toString().toLowerCase() ?? '';
                if (_folder == 'Hypertrophy' || _folder == 'Strength') return t == 'gym' || t == 'calisthenics';
                if (_folder == 'Cardio') return t == 'cardio' || t == 'run';
                if (_folder == 'HIIT') return t == 'hiit' || t == 'circuit';
                if (_folder == 'Mobility') return t == 'mobility';
                return true;
              }).map((w) {
                final exercises =
                    (w['exercises'] as List?)?.cast<Map<String, dynamic>>() ??
                    [];
                final color = _typeColors[w['type']] ?? ApexColors.blue;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ApexCard(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _showDetail(w);
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    w['name'] ?? '',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: ApexColors.t1,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${exercises.length} exercises',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: ApexColors.t2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                _iconBtn(
                                  Icons.visibility_outlined,
                                  ApexColors.purple,
                                  () {
                                    HapticFeedback.selectionClick();
                                    _showDetail(w);
                                  },
                                ),
                                const SizedBox(width: 6),
                                _iconBtn(
                                  Icons.play_arrow_rounded,
                                  ApexColors.accent,
                                  () {
                                    HapticFeedback.heavyImpact();
                                    widget.onStartWorkout(w);
                                  },
                                  fill: true,
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (exercises.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: exercises
                                .take(4)
                                .map(
                                  (e) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withAlpha(14),
                                      border: Border.all(
                                        color: color.withAlpha(44),
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '${e['name']} · ${e['sets']} sets',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: ApexColors.t2,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
          ],
        ],
      ),
    ),
    floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 20, right: 8),
        child: FloatingActionButton(
          onPressed: _showCreateModal,
          backgroundColor: ApexColors.t1,
          foregroundColor: ApexColors.bg,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.add_rounded, size: 28),
        ),
      ),
    );
  }

  Widget _iconBtn(
    IconData icon,
    Color color,
    VoidCallback onTap, {
    bool fill = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: fill ? 13 : 10, vertical: 8),
        decoration: BoxDecoration(
          color: fill ? color : color.withAlpha(18),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 16, color: fill ? ApexColors.ink : color),
      ),
    );
  }

  void _showDetail(Map<String, dynamic> workout) {
    final exercises =
        (workout['exercises'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    showModalBottomSheet(
      context: context,
      backgroundColor: ApexColors.surfaceStrong,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ApexColors.borderStrong,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                workout['name'] ?? '',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: ApexColors.t1,
                ),
              ),
              const SizedBox(height: 8),
              if ((workout['type'] ?? '').toString().isNotEmpty)
                ApexTag(
                  text: workout['type'] ?? 'Gym',
                  color: _typeColors[workout['type']] ?? ApexColors.blue,
                ),
              const SizedBox(height: 16),
              ...exercises.asMap().entries.map((entry) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: ApexColors.surface,
                    border: Border.all(color: ApexColors.border),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.value['name'] ?? '',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: ApexColors.t1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${entry.value['sets']} sets · ${entry.value['reps']} reps${entry.value['target_weight'] != null ? ' · ${entry.value['target_weight']}kg' : ''}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: ApexColors.t2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '#${entry.key + 1}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: ApexColors.t3,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 20),
              ApexButton(
                text: 'Start workout',
                icon: Icons.play_arrow_rounded,
                onPressed: () {
                  HapticFeedback.heavyImpact();
                  Navigator.pop(ctx);
                  widget.onStartWorkout(workout);
                },
                full: true,
              ),
              const SizedBox(height: 10),
              ApexButton(
                text: 'Delete',
                onPressed: () {
                  Navigator.pop(ctx);
                  _deleteWorkout(workout['id']);
                },
                tone: ApexButtonTone.outline,
                full: true,
                sm: true,
                color: ApexColors.red,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateWorkoutSheet extends StatefulWidget {
  final VoidCallback onSaved;
  const _CreateWorkoutSheet({required this.onSaved});

  @override
  State<_CreateWorkoutSheet> createState() => _CreateWorkoutSheetState();
}

class _CreateWorkoutSheetState extends State<_CreateWorkoutSheet> {
  final _nameC = TextEditingController();
  final List<_ExerciseDraft> _exercises = [_ExerciseDraft()];
  bool _loading = false;
  String _err = '';

  @override
  void dispose() {
    _nameC.dispose();
    for (final exercise in _exercises) {
      exercise.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameC.text.trim().isEmpty) {
      HapticFeedback.vibrate();
      setState(() => _err = 'Workout name required.');
      return;
    }

    final valid = _exercises
        .where((exercise) => exercise.name.text.trim().isNotEmpty)
        .toList();
    if (valid.isEmpty) {
      HapticFeedback.vibrate();
      setState(() => _err = 'Add at least 1 exercise.');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _loading = true;
      _err = '';
    });

    // Clear keyboard focus before saving
    FocusScope.of(context).unfocus();

    try {
      final workout = await SupabaseService.createWorkout(
        SupabaseService.currentUser!.id,
        _nameC.text.trim(),
        'Gym',
      );
      await SupabaseService.createExercises(
        valid
            .map(
              (exercise) => {
                'workout_id': workout['id'],
                'name': exercise.name.text.trim(),
                'sets': exercise.sets,
                'reps': exercise.reps.text.trim().isNotEmpty
                    ? exercise.reps.text.trim()
                    : '10',
                'target_weight': exercise.weight.text.trim().isNotEmpty
                    ? double.tryParse(exercise.weight.text.trim())
                    : null,
              },
            )
            .toList(),
      );

      HapticFeedback.heavyImpact();
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      HapticFeedback.vibrate();
      setState(() => _err = 'Error: $e');
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ApexColors.borderStrong,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'New workout',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: ApexColors.t1,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'WORKOUT NAME',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: ApexColors.t2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nameC,
                style: GoogleFonts.inter(fontSize: 13, color: ApexColors.t1),
                decoration: InputDecoration(
                  hintText: 'Upper Body Strength',
                  hintStyle: TextStyle(color: ApexColors.t3),
                  filled: true,
                  fillColor: ApexColors.cardAlt,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'EXERCISES',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: ApexColors.t2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _exercises.add(_ExerciseDraft()));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: ApexColors.surface,
                        border: Border.all(color: ApexColors.borderStrong),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '+ Exercise',
                        style: GoogleFonts.inter(
                          color: ApexColors.t1,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ..._exercises.asMap().entries.map((entry) {
                final index = entry.key;
                final exercise = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ApexColors.surfaceStrong,
                    border: Border.all(color: ApexColors.border),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: exercise.name,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: ApexColors.t1,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Exercise name',
                                hintStyle: TextStyle(color: ApexColors.t3),
                                filled: true,
                                fillColor: ApexColors.cardAlt,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              if (_exercises.length == 1) {
                                exercise.name.clear();
                                exercise.reps.text = '10';
                                exercise.weight.clear();
                                exercise.sets = 3;
                              } else {
                                final removed = _exercises.removeAt(index);
                                removed.dispose();
                              }
                              setState(() {});
                            },
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: ApexColors.red.withAlpha(20),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: ApexColors.red,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'SETS & REPS',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: ApexColors.t3,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Simplified Grid Layout for Sets, Reps, Weight
                      Row(
                        children: [
                          _counterWidget(
                            label: 'Sets',
                            value: '\${exercise.sets}',
                            onDec: () {
                              if (exercise.sets > 1) {
                                HapticFeedback.selectionClick();
                                setState(() => exercise.sets--);
                              }
                            },
                            onInc: () {
                              HapticFeedback.selectionClick();
                              setState(() => exercise.sets++);
                            },
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: exercise.reps,
                              keyboardType: TextInputType.text,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: ApexColors.t1,
                              ),
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                hintText: 'Reps (8-12)',
                                hintStyle: TextStyle(
                                  color: ApexColors.t3,
                                  fontSize: 11,
                                ),
                                filled: true,
                                fillColor: ApexColors.cardAlt,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: exercise.weight,
                              keyboardType: TextInputType.number,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: ApexColors.t1,
                              ),
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                hintText: 'kg',
                                hintStyle: TextStyle(
                                  color: ApexColors.t3,
                                  fontSize: 11,
                                ),
                                filled: true,
                                fillColor: ApexColors.cardAlt,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
              if (_err.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12, top: 4),
                  child: Text(
                    _err,
                    style: const TextStyle(color: ApexColors.red, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 8),
              ApexButton(
                text: 'Save workout',
                onPressed: _save,
                full: true,
                loading: _loading,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _counterWidget({
    required String label,
    required String value,
    required VoidCallback onDec,
    required VoidCallback onInc,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: ApexColors.cardAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepBtn(Icons.remove_rounded, onDec),
          Container(
            width: 32,
            alignment: Alignment.center,
            child: Text(
              value.replaceAll('\$', ''),
              style: ApexTheme.mono(size: 15, color: ApexColors.t1),
            ),
          ),
          _stepBtn(Icons.add_rounded, onInc),
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: ApexColors.surfaceStrong,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ApexColors.borderStrong.withAlpha(50)),
        ),
        child: Icon(icon, color: ApexColors.t2, size: 16),
      ),
    );
  }
}

class _ExerciseDraft {
  final TextEditingController name;
  final TextEditingController reps;
  final TextEditingController weight;
  int sets;

  _ExerciseDraft({
    String initialName = '',
    String initialReps = '10',
    String initialWeight = '',
  }) : name = TextEditingController(text: initialName),
       sets = 3,
       reps = TextEditingController(text: initialReps),
       weight = TextEditingController(text: initialWeight);

  void dispose() {
    name.dispose();
    reps.dispose();
    weight.dispose();
  }
}
