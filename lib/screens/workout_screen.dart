import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';
import '../constants/theme.dart';
import '../widgets/apex_button.dart';
import '../widgets/apex_card.dart';
import '../widgets/apex_screen_header.dart';
import '../widgets/apex_tag.dart';
import '../services/supabase_service.dart';

class WorkoutScreen extends StatefulWidget {
  final Function(Map<String, dynamic>) onStartWorkout;
  const WorkoutScreen({super.key, required this.onStartWorkout});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  List<Map<String, dynamic>> _workouts = [];
  bool _loading = true;

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
      final w = await SupabaseService.getWorkouts(SupabaseService.currentUser!.id);
      setState(() {
        _workouts = w;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _showCreateModal() async {
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
    await SupabaseService.deleteWorkout(id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      color: ApexColors.accent,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          ApexScreenHeader(
            eyebrow: 'Training',
            title: 'Workouts',
            subtitle: '${_workouts.length} saved workout plans ready to start.',
            trailing: ApexButton(
              text: 'New',
              onPressed: _showCreateModal,
              sm: true,
              icon: Icons.add_rounded,
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
                  const Icon(Icons.fitness_center_rounded, size: 42, color: ApexColors.accentSoft),
                  const SizedBox(height: 12),
                  Text(
                    'No workouts yet',
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w800,
                      color: ApexColors.t1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create your first workout with exercises, sets, and reps.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      color: ApexColors.t2,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ApexButton(
                    text: 'New workout',
                    onPressed: _showCreateModal,
                    sm: true,
                    icon: Icons.add_rounded,
                  ),
                ],
              ),
            )
          else
            ..._workouts.map((w) {
              final exercises = (w['exercises'] as List?)?.cast<Map<String, dynamic>>() ?? [];
              final color = _typeColors[w['type']] ?? ApexColors.blue;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ApexCard(
                  onTap: () => _showDetail(w),
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
                                  style: GoogleFonts.spaceGrotesk(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: ApexColors.t1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${exercises.length} exercises',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 12,
                                    color: ApexColors.t2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              _iconBtn(Icons.visibility_outlined, ApexColors.purple, () => _showDetail(w)),
                              const SizedBox(width: 6),
                              _iconBtn(Icons.play_arrow_rounded, ApexColors.accent, () => widget.onStartWorkout(w), fill: true),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: color.withAlpha(14),
                                    border: Border.all(color: color.withAlpha(44)),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '${e['name']} · ${e['sets']} sets',
                                    style: GoogleFonts.spaceGrotesk(
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
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap, {bool fill = false}) {
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
    final exercises = (workout['exercises'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    showModalBottomSheet(
      context: context,
      backgroundColor: ApexColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
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
              style: GoogleFonts.spaceGrotesk(
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
            const SizedBox(height: 12),
            ...exercises.asMap().entries.map((entry) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: ApexColors.cardAlt,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.value['name'] ?? '',
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: ApexColors.t1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${entry.value['sets']} sets · ${entry.value['reps']} reps${entry.value['target_weight'] != null ? ' · ${entry.value['target_weight']}kg' : ''}',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 11,
                            color: ApexColors.t2,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '#${entry.key + 1}',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        color: ApexColors.t3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
            ApexButton(
              text: 'Start workout',
              icon: Icons.play_arrow_rounded,
              onPressed: () {
                Navigator.pop(ctx);
                widget.onStartWorkout(workout);
              },
              full: true,
            ),
            const SizedBox(height: 8),
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
      setState(() => _err = 'Workout name required.');
      return;
    }

    final valid = _exercises.where((exercise) => exercise.name.text.trim().isNotEmpty).toList();
    if (valid.isEmpty) {
      setState(() => _err = 'Add at least 1 exercise.');
      return;
    }

    setState(() {
      _loading = true;
      _err = '';
    });
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
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _err = 'Error: $e');
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
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
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: ApexColors.t1,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'WORKOUT NAME',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                color: ApexColors.t2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _nameC,
              style: GoogleFonts.spaceGrotesk(fontSize: 13, color: ApexColors.t1),
              decoration: const InputDecoration(hintText: 'Upper Body Strength'),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'EXERCISES',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    color: ApexColors.t2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _exercises.add(_ExerciseDraft())),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: ApexColors.accentDim,
                      border: Border.all(color: ApexColors.borderStrong),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '+ Exercise',
                      style: GoogleFonts.spaceGrotesk(
                        color: ApexColors.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ..._exercises.asMap().entries.map((entry) {
              final index = entry.key;
              final exercise = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ApexColors.card,
                  border: Border.all(color: ApexColors.borderStrong),
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
                            style: GoogleFonts.spaceGrotesk(fontSize: 13, color: ApexColors.t1),
                            decoration: InputDecoration(
                              hintText: 'Exercise name',
                              filled: true,
                              fillColor: ApexColors.cardAlt,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
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
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: ApexColors.red.withAlpha(14),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.close_rounded, color: ApexColors.red, size: 18),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'SETS',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        color: ApexColors.t3,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _stepBtn(Icons.remove_rounded, () {
                          if (exercise.sets > 1) {
                            setState(() => exercise.sets--);
                          }
                        }),
                        Container(
                          width: 68,
                          alignment: Alignment.center,
                          child: Text(
                            '${exercise.sets}',
                            style: ApexTheme.mono(size: 18, color: ApexColors.t1),
                          ),
                        ),
                        _stepBtn(Icons.add_rounded, () {
                          setState(() => exercise.sets++);
                        }),
                        const SizedBox(width: 12),
                        Text(
                          'Use + to add extra sets',
                          style: GoogleFonts.spaceGrotesk(fontSize: 11, color: ApexColors.t2),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'REPS',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        color: ApexColors.t3,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _ExerciseDraft.repOptions.map((rep) {
                        final selected = exercise.reps.text == rep;
                        return GestureDetector(
                          onTap: () {
                            setState(() => exercise.reps.text = rep);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: selected ? ApexColors.accent : ApexColors.cardAlt,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: selected ? ApexColors.accent : ApexColors.borderStrong,
                              ),
                            ),
                            child: Text(
                              rep,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: selected ? ApexColors.ink : ApexColors.t2,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: exercise.reps,
                            keyboardType: TextInputType.text,
                            style: GoogleFonts.spaceGrotesk(fontSize: 13, color: ApexColors.t1),
                            decoration: const InputDecoration(
                              hintText: 'Custom reps or range, e.g. 8-12',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 96,
                          child: TextField(
                            controller: exercise.weight,
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.spaceGrotesk(fontSize: 13, color: ApexColors.t1),
                            decoration: const InputDecoration(hintText: 'Load kg'),
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
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_err, style: const TextStyle(color: ApexColors.red, fontSize: 11)),
              ),
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
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: ApexColors.cardAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ApexColors.borderStrong),
        ),
        child: Icon(icon, color: ApexColors.t1, size: 18),
      ),
    );
  }
}

class _ExerciseDraft {
  static const repOptions = ['5', '8', '10', '12', '15', 'AMRAP'];

  final TextEditingController name;
  final TextEditingController reps;
  final TextEditingController weight;
  int sets;

  _ExerciseDraft({
    String initialName = '',
    String initialReps = '10',
    String initialWeight = '',
  })  : name = TextEditingController(text: initialName),
        sets = 3,
        reps = TextEditingController(text: initialReps),
        weight = TextEditingController(text: initialWeight);

  void dispose() {
    name.dispose();
    reps.dispose();
    weight.dispose();
  }
}
