import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';
import '../repositories/auth_repository.dart';
import '../widgets/apex_button.dart';
import '../repositories/workout_repository.dart';
import '../services/storage_service.dart';
import '../services/adaptive_logic.dart';
import '../services/plan_generator_service.dart';
import '../workout_engine/plate_calculator.dart';
import '../widgets/pr_celebration_overlay.dart';
import 'exercise_library_screen.dart';
import 'active_workout/widgets/rest_timer_banner.dart';
import 'active_workout/widgets/session_footer.dart';
import 'active_workout/widgets/workout_header.dart';
import 'active_workout/widgets/workout_set_row.dart';

class ActiveWorkoutScreen extends StatefulWidget {
  final Map<String, dynamic> workout;
  final VoidCallback onFinish;
  const ActiveWorkoutScreen({
    super.key,
    required this.workout,
    required this.onFinish,
  });

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  List<Map<String, dynamic>> _exercises = [];
  final Map<int, List<Map<String, dynamic>>> _logs = {};
  int _cur = 0;
  int _timer = 0;
  List<Map<String, dynamic>> _previousSets = [];
  final Map<int, String> _exNotes = {};
  final _exNoteC = TextEditingController();
  final _sessionNotesC = TextEditingController();
  int? _focusedEx;
  int? _focusedSet;
  int? _rest;
  String _notes = '';
  String _intensity = 'moderate';
  bool _saving = false;
  bool _showEnd = false;
  Timer? _rRef;
  Timer? _tRef;
  // String? _smartTip; // Removed unused smart tip code

  // NEW: PR celebration state
  bool _showPrCelebration = false;
  String? _prExerciseName;
  double _prWeight = 0;
  int _prReps = 0;
  bool _hadPr = false;

  @override
  void initState() {
    super.initState();
    _loadPrevious();
    _sessionNotesC.addListener(() {
      _notes = _sessionNotesC.text;
      _saveState();
    });

    final exList =
        (widget.workout['exercises'] as List?)?.cast<Map<String, dynamic>>() ??
        [];
    _exercises = exList;

    // Initialize default logs
    for (int i = 0; i < exList.length; i++) {
      final sets = (exList[i]['sets'] as int?) ?? 3;
      final repsStr = exList[i]['reps']?.toString().split('-')[0] ?? '8';
      final tw = exList[i]['target_weight']?.toString() ?? '';
      _logs[i] = List.generate(
        sets,
        (_) => {'reps': repsStr, 'weight': tw, 'done': false, 'type': 'normal'},
      );
    }

    _checkRecoveredState();

    _tRef = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _timer++);
        if (_timer % 10 == 0) _saveState(); // Auto-save every 10s
      }
    });
  }

  void _addExerciseFromLibrary() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExerciseLibraryScreen(
          onSelect: (ex) {
            setState(() {
              _exercises.add({
                'name': ex['name'],
                'target_weight': null,
              });
              _logs[_exercises.length - 1] = [
                {'reps': '10', 'weight': '', 'done': false, 'type': 'normal'},
              ];
              _cur = _exercises.length - 1;
            });
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  Future<void> _checkRecoveredState() async {
    try {
      final state = await StorageService.loadActiveWorkoutState();
      if (state != null && state['workout_name'] == widget.workout['name']) {
        // Simple heuristic: only recover if it's the same workout and within the last 2 hours
        final savedAt = state['savedAt'] as int? ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - savedAt < 1000 * 60 * 60 * 2) {
          if (mounted) {
            setState(() {
              _timer = state['timer'] as int? ?? 0;
              _cur = state['cur'] as int? ?? 0;
              state['logs']?.forEach((k, v) {
                _logs[int.parse(k.toString())] =
                    List<Map<String, dynamic>>.from(v as List);
              });
              state['exNotes']?.forEach((k, v) {
                _exNotes[int.parse(k.toString())] = v as String;
              });
              _notes = state['notes'] as String? ?? '';
              _intensity = state['intensity'] as String? ?? 'moderate';
            });
            _exNoteC.text = _exNotes[_cur] ?? '';
            _sessionNotesC.text = _notes;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Recovered previous session progress.'),
                backgroundColor: ApexColors.accent,
              ),
            );
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _saveState() async {
    if (_saving) return;
    try {
      final state = {
        'workout_name': widget.workout['name'],
        'timer': _timer,
        'cur': _cur,
        'logs': _logs.map((k, v) => MapEntry(k.toString(), v)),
        'exNotes': _exNotes.map((k, v) => MapEntry(k.toString(), v)),
        'notes': _notes,
        'intensity': _intensity,
        'savedAt': DateTime.now().millisecondsSinceEpoch,
      };
      await StorageService.saveActiveWorkoutState(state);
    } catch (_) {}
  }

  Future<void> _loadPrevious() async {
    try {
      final pSets = await workoutRepository.getPreviousWorkoutStats(
        widget.workout['name'] ?? '',
      );
      if (mounted) {
        setState(() {
          _previousSets = pSets;
          // After loading previous sets, apply AI recommendations to initial logs
          for (int i = 0; i < _exercises.length; i++) {
            final exName = _exercises[i]['name'];
            final exPSets = pSets
                .where((ps) => ps['exercise_name'] == exName)
                .toList();
            if (exPSets.isNotEmpty) {
              final rec = AdaptiveLogic.recommendNextSession(
                previousSets: exPSets,
                intensity: 'moderate', // Default assumption
              );
              if (rec.containsKey('weight')) {
                final recW = rec['weight'].toString();
                // Update only sets that haven't been touched yet
                for (var s in _logs[i]!) {
                  if (s['done'] == false &&
                      (s['weight'] == null ||
                          s['weight'] == '' ||
                          s['weight'] ==
                              _exercises[i]['target_weight']?.toString())) {
                    s['weight'] = recW;
                  }
                }
              }
            }
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tRef?.cancel();
    _rRef?.cancel();
    _exNoteC.dispose();
    _sessionNotesC.dispose();
    super.dispose();
  }

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  Map<String, dynamic>? _previousSetFor(String exerciseName, int setNumber) {
    for (final prevSet in _previousSets) {
      if (prevSet['exercise_name'] == exerciseName &&
          prevSet['set_number'] == setNumber) {
        return prevSet;
      }
    }
    return null;
  }

  int? _deltaPercentForSet(
    String exerciseName,
    int setNumber,
    Map<String, dynamic> setLog,
  ) {
    final previous = _previousSetFor(exerciseName, setNumber);
    if (previous == null || setLog['done'] != true) return null;

    final previousVolume =
        (num.tryParse(previous['reps_done']?.toString() ?? '') ?? 0) *
        (num.tryParse(previous['weight_kg']?.toString() ?? '') ?? 0);
    final currentVolume =
        (num.tryParse(setLog['reps']?.toString() ?? '') ?? 0) *
        (num.tryParse(setLog['weight']?.toString() ?? '') ?? 0);

    if (previousVolume <= 0 || currentVolume <= 0) return null;

    final percent = ((currentVolume - previousVolume) / previousVolume * 100)
        .round();
    return percent == 0 ? null : percent;
  }

  void _startRest() {
    setState(() => _rest = 60);
    _rRef?.cancel();

    _rRef = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        if (_rest != null && _rest! <= 1) {
          _rRef?.cancel();
          _rest = null;
        } else if (_rest != null) {
          _rest = _rest! - 1;
        }
      });
    });
  }

  void _toggleType(int ei, int si) {
    setState(() {
      final s = _logs[ei]![si];
      final cur = s['type'] as String? ?? 'normal';
      String n = 'normal';
      if (cur == 'normal') {
        n = 'warmup';
      } else if (cur == 'warmup') {
        n = 'drop';
      } else if (cur == 'drop') {
        n = 'failure';
      }
      s['type'] = n;
    });
    _saveState();
  }

  void _toggle(int ei, int si) {
    setState(() {
      final was = _logs[ei]![si]['done'] as bool;
      _logs[ei]![si]['done'] = !was;
      if (!was) {
        _logs[ei]![si]['completed_at'] = DateTime.now().toIso8601String();
      } else {
        _logs[ei]![si].remove('completed_at');
      }
    });
    final s = _logs[_cur]![si];
    if (!(s['done'] as bool? ?? false)) return;

    // Phase 15: AI Live Adjustment
    final targetReps = 8; // Default or from exercise meta
    final actualReps = int.tryParse(s['reps']?.toString() ?? '0') ?? 0;
    final suggest = AdaptiveLogic.getLiveAdjustmentSuggest(
      setNumber: si + 1,
      setType: s['type'] ?? 'normal',
      actualReps: actualReps,
      targetReps: targetReps,
    );
    if (suggest != null) {
      // Smart tip UI disabled in the current aesthetic
    }

    _saveState();
    if (s['type'] != 'drop') _startRest();

    // NEW: Detect PR on set completion (compare to previous best)
    if (s['done'] == true) {
      _checkForPR(_cur, si);
    }
  }

  // NEW: Check if a completed set is a PR
  void _checkForPR(int exerciseIndex, int setIndex) {
    try {
      final exName = _exercises[exerciseIndex]['name'];
      final setData = _logs[exerciseIndex]![setIndex];
      final currentWeight = double.tryParse(setData['weight']?.toString() ?? '0') ?? 0;
      final currentReps = int.tryParse(setData['reps']?.toString() ?? '0') ?? 0;
      if (currentWeight <= 0 || currentReps <= 0) return;

      // Check against previous sets
      for (final prevSet in _previousSets) {
        if (prevSet['exercise_name'] == exName) {
          final prevWeight = double.tryParse(prevSet['weight_kg']?.toString() ?? '0') ?? 0;
          if (currentWeight > prevWeight) {
            setState(() {
              _showPrCelebration = true;
              _prExerciseName = exName?.toString() ?? 'Exercise';
              _prWeight = currentWeight;
              _prReps = currentReps;
              _hadPr = true;
            });
            HapticFeedback.heavyImpact();
            return;
          }
        }
      }
    } catch (_) {}
  }

  void _upd(int ei, int si, String f, String v) {
    setState(() => _logs[ei]![si][f] = v);
    _saveState();
  }

  void _addSet(int ei) {
    setState(() {
      final last = _logs[ei]!.last;
      _logs[ei]!.add({
        'reps': '8',
        'weight': last['weight'] ?? '',
        'done': false,
        'type': 'normal',
      });
    });
    _saveState();
  }

  double get _totalVol => _logs.values
      .expand((e) => e)
      .where((s) => s['done'] == true)
      .fold(
        0.0,
        (a, s) =>
            a +
            ((double.tryParse(s['reps']?.toString() ?? '0') ?? 0) *
                (double.tryParse(s['weight']?.toString() ?? '0') ?? 0)),
      );

  int get _doneCount =>
      _logs.values.expand((e) => e).where((s) => s['done'] == true).length;
  int get _totalCount => _logs.values.expand((e) => e).length;

  Future<void> _finish() async {
    setState(() => _saving = true);

    String aggNotes = _notes;
    _exercises.asMap().forEach((ei, ex) {
      if ((_exNotes[ei] ?? '').trim().isNotEmpty) {
        aggNotes += '\n\n${ex['name']}: ${_exNotes[ei]}';
      }
    });
    aggNotes = aggNotes.trim();

    final payload = {
      'user_id': authRepository.requireUserId(),
      'workout_name': widget.workout['name'],
      'duration_min': (_timer / 60).round(),
      'total_volume': _totalVol,
      'intensity': _intensity,
      'notes': aggNotes.isNotEmpty ? aggNotes : null,
      'sets': <Map<String, dynamic>>[],
    };

    _exercises.asMap().forEach((ei, ex) {
      (_logs[ei] ?? []).asMap().forEach((si, s) {
        if (s['done'] == true) {
          (payload['sets'] as List).add({
            // log_id will be set during actual sync
            'exercise_name': ex['name'],
            'set_number': si + 1,
            'set_type': s['type'] ?? 'normal',
            'reps_done': int.tryParse(s['reps']?.toString() ?? '0') ?? 0,
            'weight_kg': double.tryParse(s['weight']?.toString() ?? '0') ?? 0,
            'completed_at': s['completed_at'],
          });
        }
      });
    });

    final sets = (payload['sets'] as List).cast<Map<String, dynamic>>();
    final logPayload = Map<String, dynamic>.from(payload)..remove('sets');

    try {
      final result = await workoutRepository.completeWorkoutSession(
        logPayload: logPayload,
        sets: sets,
      );
      if (mounted && result.savedOffline) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved offline. Will sync when connected.'),
            backgroundColor: ApexColors.blue,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save workout. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _saving = false);
      }
      return;
    }

    String? prMessage;
    for (var ei = 0; ei < _exercises.length; ei++) {
      if (prMessage != null) break;
      final exName = _exercises[ei]['name'];
      final prevSets = _previousSets
          .where((set) => set['exercise_name'] == exName)
          .toList();
      final currSets = _logs[ei] ?? [];

      double pVol = 0;
      for (var s in prevSets) {
        pVol +=
            (double.tryParse(s['reps_done']?.toString() ?? '0') ?? 0) *
            (double.tryParse(s['weight_kg']?.toString() ?? '0') ?? 0);
      }
      pVol = (pVol * 10).roundToDouble() / 10; // Precision normalize

      double cVol = 0;
      for (var s in currSets) {
        if (s['done'] == true) {
          cVol +=
              (double.tryParse(s['reps']?.toString() ?? '0') ?? 0) *
              (double.tryParse(s['weight']?.toString() ?? '0') ?? 0);
        }
      }
      cVol = (cVol * 10).roundToDouble() / 10; // Precision normalize

      if (cVol > 0 && pVol > 0 && cVol > pVol) {
        final pct = ((cVol - pVol) / pVol * 100).round();
        if (pct >= 5) prMessage = 'NEW PR!\n$exName\n+$pct% Volume';
      }
    }

    if (prMessage != null && mounted) {
      HapticFeedback.heavyImpact();
      await showDialog(
        context: context,
        barrierColor: Colors.black87,
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.workspace_premium_rounded,
                  size: 100,
                  color: ApexColors.yellow,
                ),
                const SizedBox(height: 24),
                Text(
                  prMessage!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w900,
                    fontSize: 32,
                    color: ApexColors.yellow,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 48),
                ApexButton(
                  text: 'Let\'s Go',
                  onPressed: () => Navigator.pop(ctx),
                  color: ApexColors.yellow,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (mounted) {
      setState(() => _saving = false);
    }

    // NEW: Generate AI workout summary (non-blocking)
    try {
      final summary = await PlanGeneratorService.generateWorkoutSummary(
        workoutName: widget.workout['name'] ?? 'Workout',
        durationMin: (_timer / 60).round(),
        totalVolume: _totalVol.round(),
        setsCompleted: _doneCount,
        hadPr: prMessage != null || _hadPr,
      );
      if (mounted && summary.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(summary),
            backgroundColor: ApexColors.accent,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } catch (_) {}

    widget.onFinish();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
    Scaffold(
      backgroundColor: ApexColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            ActiveWorkoutHeader(
              workoutName: widget.workout['name'] ?? '',
              doneCount: _doneCount,
              totalCount: _totalCount,
              totalVolume: _totalVol,
              elapsedLabel: _fmt(_timer),
            ),

            if (_rest != null)
              RestTimerBanner(
                formattedTime: _fmt(_rest!),
                onDecrease: () =>
                    setState(() => _rest = (_rest! - 5).clamp(1, 9999)),
                onIncrease: () => setState(() => _rest = _rest! + 15),
                onSkip: () {
                  _rRef?.cancel();
                  setState(() => _rest = null);
                },
              ),

            // Exercise tabs
            // Unified Exercises List
            Expanded(
              child: _exercises.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.fitness_center_rounded,
                              size: 48, color: ApexColors.t3),
                          const SizedBox(height: 16),
                          Text('No exercises yet',
                              style: GoogleFonts.inter(
                                  color: ApexColors.t2, fontSize: 16)),
                          const SizedBox(height: 24),
                          ApexButton(
                            text: 'Add Exercise',
                            onPressed: _addExerciseFromLibrary,
                          )
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 150),
                      itemCount: _exercises.length + 1,
                      itemBuilder: (ctx, ei) {
                        if (ei == _exercises.length) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                            child: ApexButton(
                              text: '+ Add Exercise',
                              outline: true,
                              onPressed: _addExerciseFromLibrary,
                            ),
                          );
                        }
                        return _buildExerciseBlock(ei, _exercises[ei]);
                      },
                    ),
            ),

            SessionFooter(
              showConfirmation: _showEnd,
              saving: _saving,
              elapsedLabel: _fmt(_timer),
              doneCount: _doneCount,
              totalVolume: _totalVol,
              intensity: _intensity,
              notesController: _sessionNotesC,
              onBeginFinish: () => setState(() => _showEnd = true),
              onCancelFinish: () => setState(() => _showEnd = false),
              onSave: _finish,
              onIntensityChanged: (value) => setState(() => _intensity = value),
            ),
          ],
        ),
      ),
    ),
    // NEW: PR Celebration overlay
    if (_showPrCelebration)
      Positioned.fill(
        child: PrCelebrationOverlay(
          exerciseName: _prExerciseName ?? 'Exercise',
          weightKg: _prWeight,
          reps: _prReps,
          onDismiss: () {
            if (mounted) setState(() => _showPrCelebration = false);
          },
        ),
      ),
    ], // Stack children
    ); // Stack
  }

  Widget _buildExerciseBlock(int ei, Map<String, dynamic> ex) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ApexColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                ex['name'] ?? '',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: ApexColors.t1,
                ),
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _exercises.removeAt(ei);
                    _logs.remove(ei);
                    // Re-index remaining logs
                    final newLogs = <int, List<Map<String, dynamic>>>{};
                    for (var i = 0; i < _exercises.length; i++) {
                      newLogs[i] = _logs[i >= ei ? i + 1 : i] ?? [];
                    }
                    _logs.clear();
                    _logs.addAll(newLogs);
                  });
                },
                child: const Icon(Icons.close_rounded,
                    color: ApexColors.t3, size: 20),
              ),
            ],
          ),
          Text(
            'Edit each set independently',
            style: TextStyle(color: ApexColors.t2, fontSize: 10),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 34,
                child: Text(
                  '#',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    color: ApexColors.t3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'REPS',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    color: ApexColors.t3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'KG',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    color: ApexColors.t3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(
                width: 40,
                child: Text(
                  '✓',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    color: ApexColors.t3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ...(_logs[ei] ?? []).asMap().entries.map((entry) {
            final si = entry.key;
            final s = entry.value;
            final prevSet = _previousSetFor(ex['name'], si + 1);
            final pReps = prevSet?['reps_done']?.toString() ?? '';
            final pWeight = prevSet?['weight_kg']?.toString() ?? '';
            return WorkoutSetRow(
              key: ValueKey('$ei-$si'),
              setNumber: si + 1,
              setData: s,
              previousReps: pReps,
              previousWeight: pWeight,
              deltaPercent: _deltaPercentForSet(
                ex['name'],
                si + 1,
                s,
              ),
              onToggleType: () => _toggleType(ei, si),
              onRepsChanged: (v) => _upd(ei, si, 'reps', v),
              onWeightChanged: (v) => _upd(ei, si, 'weight', v),
              onFieldTap: () => setState(() {
                _focusedEx = ei;
                _focusedSet = si;
              }),
              onWeightLongPress: () {
                HapticFeedback.mediumImpact();
                final currentWeight =
                    double.tryParse(s['weight']?.toString() ?? '0') ?? 0;
                showPlateCalculator(
                  context,
                  initialWeight: currentWeight > 0 ? currentWeight : 60,
                );
              },
              onToggleDone: () => _toggle(ei, si),
            );
          }),
          GestureDetector(
            onTap: () => _addSet(ei),
            child: Container(
              margin: const EdgeInsets.only(top: 9),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(
                  color: ApexColors.border,
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Center(
                child: Text(
                  'Add set',
                  style: TextStyle(
                    color: ApexColors.t2,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          if (_focusedEx == ei) ...[
            const SizedBox(height: 24),
            Text(
              'QUICK ADD (Set ${_focusedSet != null ? _focusedSet! + 1 : '-'})',
              style: TextStyle(
                color: ApexColors.t3,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [2.5, 5.0, 10.0, 15.0, 20.0, 25.0].map((v) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          if (_focusedSet != null) {
                            final setMap = _logs[ei]![_focusedSet!];
                            final currentW = double.tryParse(
                                  setMap['weight']?.toString() ?? '0',
                                ) ??
                                0;
                            String newW = (currentW + v).toString();
                            if (newW.endsWith('.0')) {
                              newW = newW.substring(0, newW.length - 2);
                            }
                            _upd(ei, _focusedSet!, 'weight', newW);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: ApexColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: ApexColors.border),
                          ),
                          child: Text(
                            '+$v',
                            style: TextStyle(
                              color: ApexColors.t1,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    )).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
