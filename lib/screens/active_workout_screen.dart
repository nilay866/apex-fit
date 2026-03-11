import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';
import '../constants/theme.dart';
import '../widgets/apex_button.dart';
import '../services/supabase_service.dart';
import '../services/storage_service.dart';
import '../widgets/apex_orb_logo.dart';
import 'package:flutter/services.dart';
import '../widgets/apex_orb_logo.dart';

class ActiveWorkoutScreen extends StatefulWidget {
  final Map<String, dynamic> workout;
  final VoidCallback onFinish;
  const ActiveWorkoutScreen({super.key, required this.workout, required this.onFinish});

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  List<Map<String, dynamic>> _exercises = [];
  final Map<int, List<Map<String, dynamic>>> _logs = {};
  int _cur = 0;
  int _timer = 0;
  List<Map<String, dynamic>> _previousSets = [];
  Map<int, String> _exNotes = {};
  final _exNoteC = TextEditingController();
  int? _focusedEx;
  int? _focusedSet;
  int? _rest;
  String _notes = '';
  String _intensity = 'moderate';
  bool _saving = false;
  bool _showEnd = false;
  Timer? _tRef;
  Timer? _rRef;
  
  String? _activityId;

  @override
  void initState() {
    super.initState();
    _loadPrevious();
    final exList = (widget.workout['exercises'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    _exercises = exList;
    for (int i = 0; i < exList.length; i++) {
      final sets = (exList[i]['sets'] as int?) ?? 3;
      final repsStr = exList[i]['reps']?.toString().split('-')[0] ?? '8';
      final tw = exList[i]['target_weight']?.toString() ?? '';
      _logs[i] = List.generate(sets, (_) => {'reps': repsStr, 'weight': tw, 'done': false, 'type': 'normal'});
    }
    _tRef = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _timer++));
  }

  Future<void> _loadPrevious() async {
    try {
      final pSets = await SupabaseService.getPreviousWorkoutStats(
        SupabaseService.currentUser!.id,
        widget.workout['name'] ?? '',
      );
      if (mounted) setState(() => _previousSets = pSets);
    } catch (_) {}
  }

  @override
  void dispose() {
    _tRef?.cancel();
    _rRef?.cancel();
    _exNoteC.dispose();
    super.dispose();
  }

  String _fmt(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

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
      if (cur == 'normal') n = 'warmup';
      else if (cur == 'warmup') n = 'drop';
      else if (cur == 'drop') n = 'failure';
      s['type'] = n;
    });
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
    if (s['type'] != 'drop') _startRest();
  }

  void _upd(int ei, int si, String f, String v) {
    setState(() => _logs[ei]![si][f] = v);
  }

  void _addSet(int ei) {
    setState(() {
      final last = _logs[ei]!.last;
      _logs[ei]!.add({'reps': '8', 'weight': last['weight'] ?? '', 'done': false, 'type': 'normal'});
    });
  }

  int get _totalVol => _logs.values.expand((e) => e).where((s) => s['done'] == true)
      .fold(0, (a, s) => a + ((int.tryParse(s['reps']?.toString() ?? '0') ?? 0) * (double.tryParse(s['weight']?.toString() ?? '0')?.round() ?? 0)));

  int get _doneCount => _logs.values.expand((e) => e).where((s) => s['done'] == true).length;
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
      'user_id': SupabaseService.currentUser!.id,
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

    try {
      final logPayload = Map<String, dynamic>.from(payload)..remove('sets');
      final log = await SupabaseService.createWorkoutLog(logPayload);
      
      final sets = (payload['sets'] as List).cast<Map<String, dynamic>>();
      for (var s in sets) {
        s['log_id'] = log['id'];
      }
      await SupabaseService.createSetLogs(sets);
    } catch (e) {
      try {
        await StorageService.saveOfflineWorkout(payload);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved offline. Will sync when connected.'), backgroundColor: ApexColors.blue));
      } catch (innerE) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save workout. Please try again.'), backgroundColor: Colors.red));
      }
    }

    String? prMessage;
    for (var ei = 0; ei < _exercises.length; ei++) {
      if (prMessage != null) break;
      final exName = _exercises[ei]['name'];
      final prevSets = _previousSets[exName] as List<dynamic>? ?? [];
      final currSets = _logs[ei] ?? [];
      
      int pVol = 0;
      for (var s in prevSets) pVol += (int.tryParse(s['reps']?.toString() ?? '0') ?? 0) * (double.tryParse(s['weight']?.toString() ?? '0')?.round() ?? 0);
      
      int cVol = 0;
      for (var s in currSets) {
        if (s['done'] == true) cVol += (int.tryParse(s['reps']?.toString() ?? '0') ?? 0) * (double.tryParse(s['weight']?.toString() ?? '0')?.round() ?? 0);
      }

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
                const Icon(Icons.workspace_premium_rounded, size: 100, color: ApexColors.yellow),
                const SizedBox(height: 24),
                Text(prMessage!, textAlign: TextAlign.center, style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 32, color: ApexColors.yellow, height: 1.2)),
                const SizedBox(height: 48),
                ApexButton(text: 'Let\'s Go', onPressed: () => Navigator.pop(ctx), color: ApexColors.yellow),
              ],
            ),
          ),
        ),
      );
    }

    widget.onFinish();
  }

  @override
  Widget build(BuildContext context) {
    final ex = _cur < _exercises.length ? _exercises[_cur] : null;
    return Scaffold(
      backgroundColor: ApexColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: ApexColors.surface, border: Border(bottom: BorderSide(color: ApexColors.border))),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(widget.workout['name'] ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: ApexColors.t1)),
                        Text('$_doneCount/$_totalCount sets · ${_totalVol}kg', style: TextStyle(color: ApexColors.t2, fontSize: 10)),
                      ]),
                      Text(_fmt(_timer), style: ApexTheme.mono(size: 24, color: ApexColors.accent)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: _totalCount > 0 ? _doneCount / _totalCount : 0,
                      minHeight: 3,
                      backgroundColor: ApexColors.border,
                      valueColor: const AlwaysStoppedAnimation(ApexColors.accent),
                    ),
                  ),
                ],
              ),
            ),

            // Rest timer
            if (_rest != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: ApexColors.blue.withAlpha(24), border: Border(bottom: BorderSide(color: ApexColors.blue, width: 2))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Rest timer', style: TextStyle(color: ApexColors.blue, fontWeight: FontWeight.w700, fontSize: 11)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => setState(() => _rest = (_rest! - 5).clamp(1, 9999)),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: ApexColors.blue.withAlpha(40), borderRadius: BorderRadius.circular(4)),
                                child: Text('-5s', style: TextStyle(color: ApexColors.blue, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => setState(() => _rest = _rest! + 15),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: ApexColors.blue.withAlpha(40), borderRadius: BorderRadius.circular(4)),
                                child: Text('+15s', style: TextStyle(color: ApexColors.blue, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Text(_fmt(_rest!), style: ApexTheme.mono(size: 24, color: ApexColors.blue)),
                    GestureDetector(
                      onTap: () { _rRef?.cancel(); setState(() => _rest = null); },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(color: ApexColors.blue.withAlpha(40), borderRadius: BorderRadius.circular(6)),
                        child: Text('Skip', style: TextStyle(color: ApexColors.blue, fontWeight: FontWeight.w700, fontSize: 10)),
                      ),
                    ),
                  ],
                ),
              ),

            // Exercise tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  ..._exercises.asMap().entries.map((entry) {
                    final i = entry.key;
                    final e = entry.value;
                    final d = (_logs[i] ?? []).where((s) => s['done'] == true).length;
                    final t = (_logs[i] ?? []).length;
                    final all = d == t && t > 0;
                    return Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _cur = i;
                            _exNoteC.text = _exNotes[i] ?? '';
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                          decoration: BoxDecoration(
                            color: _cur == i ? ApexColors.card : Colors.transparent,
                            border: Border.all(color: _cur == i ? ApexColors.border : Colors.transparent),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                          ),
                          child: Text('${all ? '✓ ' : ''}${e['name']}', style: TextStyle(color: all ? ApexColors.accent : (_cur == i ? ApexColors.t1 : ApexColors.t3), fontWeight: FontWeight.w700, fontSize: 10)),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            Divider(color: ApexColors.border, height: 1),

            // Set logging
            Expanded(
              child: ex == null
                  ? const SizedBox()
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(ex['name'] ?? '', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: ApexColors.t1)),
                        Text('Edit each set independently', style: TextStyle(color: ApexColors.t2, fontSize: 10)),
                        const SizedBox(height: 12),
                        // Header
                        Row(children: [
                          SizedBox(width: 34, child: Text('#', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, color: ApexColors.t3, fontWeight: FontWeight.w700))),
                          Expanded(child: Text('REPS', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, color: ApexColors.t3, fontWeight: FontWeight.w700))),
                          Expanded(child: Text('KG', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, color: ApexColors.t3, fontWeight: FontWeight.w700))),
                          const SizedBox(width: 40, child: Text('✓', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, color: ApexColors.t3, fontWeight: FontWeight.w700))),
                        ]),
                        const SizedBox(height: 5),
                        ...(_logs[_cur] ?? []).asMap().entries.map((entry) {
                          final si = entry.key;
                          final s = entry.value;
                          final done = s['done'] == true;
                          
                          final prevSet = _previousSets.where((ps) => 
                            ps['exercise_name'] == ex['name'] && ps['set_number'] == (si + 1)
                          ).firstOrNull;
                          final pReps = prevSet?['reps_done']?.toString() ?? '0';
                          final pWeight = prevSet?['weight_kg']?.toString() ?? '0';

                          String tLabel = '${si + 1}';
                          final tVal = s['type'] as String? ?? 'normal';
                          if (tVal == 'warmup') tLabel = 'W';
                          else if (tVal == 'drop') tLabel = 'D';
                          else if (tVal == 'failure') tLabel = 'F';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 7),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: done ? ApexColors.accentDim : ApexColors.card,
                              border: Border.all(color: done ? ApexColors.accent.withAlpha(64) : ApexColors.border),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 34,
                                  child: GestureDetector(
                                    onTap: () => _toggleType(_cur, si),
                                    child: Container(
                                      width: 26, height: 26,
                                      decoration: BoxDecoration(color: done ? ApexColors.accent : ApexColors.surface, shape: BoxShape.circle),
                                      child: Center(child: Text(done ? '✓' : tLabel, style: TextStyle(color: done ? ApexColors.bg : (tVal != 'normal' ? ApexColors.accent : ApexColors.t3), fontWeight: FontWeight.w800, fontSize: 11))),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: TextEditingController(text: s['reps']?.toString() ?? ''),
                                    onChanged: (v) => _upd(_cur, si, 'reps', v),
                                    onTap: () => setState(() { _focusedEx = _cur; _focusedSet = si; }),
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: ApexTheme.mono(size: 16),
                                    decoration: InputDecoration(
                                      hintText: pReps,
                                      hintStyle: ApexTheme.mono(size: 16, color: ApexColors.t3.withOpacity(0.4)),
                                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                      filled: true, fillColor: ApexColors.surface,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: BorderSide(color: ApexColors.border)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: TextField(
                                    controller: TextEditingController(text: s['weight']?.toString() ?? ''),
                                    onChanged: (v) => _upd(_cur, si, 'weight', v),
                                    onTap: () => setState(() { _focusedEx = _cur; _focusedSet = si; }),
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: ApexTheme.mono(size: 16),
                                    decoration: InputDecoration(
                                      hintText: pWeight,
                                      hintStyle: ApexTheme.mono(size: 16, color: ApexColors.t3.withOpacity(0.4)),
                                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                      filled: true, fillColor: ApexColors.surface,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: BorderSide(color: ApexColors.border)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                if (done) ...[
                                  Builder(builder: (ctx) {
                                    final p = _previousSets.where((ps) => ps['exercise_name'] == ex['name'] && ps['set_number'] == (si + 1)).firstOrNull;
                                    if (p == null) return const SizedBox.shrink();
                                    
                                    final pV = (num.tryParse(p['reps_done']?.toString() ?? '') ?? 0) * (num.tryParse(p['weight_kg']?.toString() ?? '') ?? 0);
                                    final cV = (num.tryParse(s['reps']?.toString() ?? '') ?? 0) * (num.tryParse(s['weight']?.toString() ?? '') ?? 0);
                                    if (pV <= 0 || cV <= 0) return const SizedBox.shrink();
                                    
                                    final pct = ((cV - pV) / pV * 100).round();
                                    if (pct == 0) return const SizedBox.shrink();
                                    
                                    final isUp = pct > 0;
                                    final color = isUp ? ApexColors.accent : ApexColors.red;
                                    return Container(
                                      margin: const EdgeInsets.only(right: 6),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                      decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withAlpha(60))),
                                      child: Text(
                                        '${isUp ? '↑' : '↓'}${pct.abs()}%',
                                        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800),
                                      ),
                                    );
                                  }),
                                ],
                                GestureDetector(
                                  onTap: () => _toggle(_cur, si),
                                  child: Container(
                                    width: 36, height: 36,
                                    decoration: BoxDecoration(
                                      color: done ? ApexColors.accent : ApexColors.surface,
                                      border: Border.all(color: done ? ApexColors.accent : ApexColors.border, width: 1.5),
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    child: Center(child: Text(done ? '✓' : '○', style: TextStyle(color: done ? ApexColors.bg : ApexColors.t2, fontSize: 14))),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        GestureDetector(
                          onTap: () => _addSet(_cur),
                          child: Container(
                            margin: const EdgeInsets.only(top: 9),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(border: Border.all(color: ApexColors.border, style: BorderStyle.solid), borderRadius: BorderRadius.circular(9)),
                            child: Center(child: Text('Add set', style: TextStyle(color: ApexColors.t2, fontSize: 11, fontWeight: FontWeight.w700))),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text('QUICK ADD (Set ${_focusedSet != null ? _focusedSet! + 1 : '-'})', style: TextStyle(color: ApexColors.t3, fontSize: 10, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [2.5, 5.0, 10.0, 15.0, 20.0, 25.0].map((v) => 
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: GestureDetector(
                                  onTap: () {
                                    if (_focusedEx != null && _focusedSet != null) {
                                      final setMap = _logs[_focusedEx]![_focusedSet!];
                                      final currentW = double.tryParse(setMap['weight']?.toString() ?? '0') ?? 0;
                                      String newW = (currentW + v).toString();
                                      if (newW.endsWith('.0')) newW = newW.substring(0, newW.length - 2);
                                      _upd(_focusedEx!, _focusedSet!, 'weight', newW);
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(color: ApexColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: ApexColors.border)),
                                    child: Text('+$v', style: TextStyle(color: ApexColors.t1, fontWeight: FontWeight.w700, fontSize: 14)),
                                  ),
                                ),
                              ),
                            ).toList(),
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _exNoteC,
                          onChanged: (v) => _exNotes[_cur] = v,
                          maxLines: 2,
                          style: GoogleFonts.inter(fontSize: 12, color: ApexColors.t1),
                          decoration: InputDecoration(
                            hintText: 'Notes for ${ex['name']}...',
                            hintStyle: TextStyle(color: ApexColors.t3, fontSize: 12),
                            filled: true, fillColor: ApexColors.surface,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ApexColors.border)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ApexColors.blue)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(children: [
                          if (_cur > 0) Expanded(child: ApexButton(text: 'Previous', icon: Icons.arrow_back_rounded, onPressed: () => setState(() => _cur--), outline: true, sm: true, full: true)),
                          if (_cur > 0 && _cur < _exercises.length - 1) const SizedBox(width: 8),
                          if (_cur < _exercises.length - 1) Expanded(child: ApexButton(text: 'Next', icon: Icons.arrow_forward_rounded, onPressed: () => setState(() => _cur++), sm: true, full: true)),
                        ]),
                      ],
                    ),
            ),

            // Bottom bar
            if (!_showEnd)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: ApexColors.surface, border: Border(top: BorderSide(color: ApexColors.border))),
                child: ApexButton(text: 'Finish workout', icon: Icons.flag_rounded, onPressed: () => setState(() => _showEnd = true), full: true),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: ApexColors.card, border: Border(top: BorderSide(color: ApexColors.border))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Save this session?', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 12, color: ApexColors.t1)),
                    Text('${_fmt(_timer)} · $_doneCount sets · ${_totalVol}kg', style: TextStyle(color: ApexColors.t2, fontSize: 10)),
                    const SizedBox(height: 9),
                    Text('INTENSITY', style: GoogleFonts.inter(fontSize: 10, color: ApexColors.t2, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Row(children: [
                      ['light', 'Light', ApexColors.accentSoft],
                      ['moderate', 'Moderate', ApexColors.blue],
                      ['heavy', 'Heavy', ApexColors.orange],
                    ].map((i) => Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _intensity = i[0] as String),
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            color: _intensity == i[0] ? (i[2] as Color).withAlpha(32) : ApexColors.surface,
                            border: Border.all(color: _intensity == i[0] ? i[2] as Color : ApexColors.border, width: 1.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(i[1] as String, textAlign: TextAlign.center, style: TextStyle(color: _intensity == i[0] ? i[2] as Color : ApexColors.t2, fontSize: 10, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    )).toList()),
                    const SizedBox(height: 9),
                    TextField(
                      onChanged: (v) => _notes = v,
                      style: GoogleFonts.inter(fontSize: 13, color: ApexColors.t1),
                      decoration: const InputDecoration(hintText: 'Session notes'),
                    ),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: ApexButton(text: 'Back', onPressed: () => setState(() => _showEnd = false), outline: true, sm: true, full: true)),
                      const SizedBox(width: 8),
                      Expanded(child: ApexButton(text: 'Save and exit', icon: Icons.check_rounded, onPressed: _finish, full: true, loading: _saving)),
                    ]),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
