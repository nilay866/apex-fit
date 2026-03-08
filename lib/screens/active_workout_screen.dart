import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';
import '../constants/theme.dart';
import '../widgets/apex_button.dart';
import '../services/supabase_service.dart';

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
  int? _rest;
  String _notes = '';
  String _intensity = 'moderate';
  bool _saving = false;
  bool _showEnd = false;
  Timer? _tRef;
  Timer? _rRef;

  @override
  void initState() {
    super.initState();
    final exList = (widget.workout['exercises'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    _exercises = exList;
    for (int i = 0; i < exList.length; i++) {
      final sets = (exList[i]['sets'] as int?) ?? 3;
      final repsStr = exList[i]['reps']?.toString().split('-')[0] ?? '8';
      final tw = exList[i]['target_weight']?.toString() ?? '';
      _logs[i] = List.generate(sets, (_) => {'reps': repsStr, 'weight': tw, 'done': false});
    }
    _tRef = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _timer++));
  }

  @override
  void dispose() {
    _tRef?.cancel();
    _rRef?.cancel();
    super.dispose();
  }

  String _fmt(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  void _startRest() {
    setState(() => _rest = 60);
    _rRef?.cancel();
    _rRef = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        if (_rest != null && _rest! <= 1) {
          _rest = null;
          _rRef?.cancel();
        } else if (_rest != null) {
          _rest = _rest! - 1;
        }
      });
    });
  }

  void _toggle(int ei, int si) {
    setState(() {
      final was = _logs[ei]![si]['done'] as bool;
      _logs[ei]![si]['done'] = !was;
    });
    if (!(_logs[_cur]![si]['done'] as bool? ?? false)) return;
    _startRest();
  }

  void _upd(int ei, int si, String f, String v) {
    setState(() => _logs[ei]![si][f] = v);
  }

  void _addSet(int ei) {
    setState(() {
      final last = _logs[ei]!.last;
      _logs[ei]!.add({'reps': '8', 'weight': last['weight'] ?? '', 'done': false});
    });
  }

  int get _totalVol => _logs.values.expand((e) => e).where((s) => s['done'] == true)
      .fold(0, (a, s) => a + ((int.tryParse(s['reps']?.toString() ?? '0') ?? 0) * (double.tryParse(s['weight']?.toString() ?? '0')?.round() ?? 0)));

  int get _doneCount => _logs.values.expand((e) => e).where((s) => s['done'] == true).length;
  int get _totalCount => _logs.values.expand((e) => e).length;

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      final log = await SupabaseService.createWorkoutLog({
        'user_id': SupabaseService.currentUser!.id,
        'workout_name': widget.workout['name'],
        'duration_min': (_timer / 60).round(),
        'total_volume': _totalVol,
        'intensity': _intensity,
        'notes': _notes.isNotEmpty ? _notes : null,
      });
      final sets = <Map<String, dynamic>>[];
      _exercises.asMap().forEach((ei, ex) {
        (_logs[ei] ?? []).asMap().forEach((si, s) {
          if (s['done'] == true) {
            sets.add({
              'log_id': log['id'],
              'exercise_name': ex['name'],
              'set_number': si + 1,
              'reps_done': int.tryParse(s['reps']?.toString() ?? '0') ?? 0,
              'weight_kg': double.tryParse(s['weight']?.toString() ?? '0') ?? 0,
            });
          }
        });
      });
      await SupabaseService.createSetLogs(sets);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save workout. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      // Still finish even if save fails
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
                        Text(widget.workout['name'] ?? '', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800, fontSize: 16, color: ApexColors.t1)),
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
                    Text('Rest timer', style: TextStyle(color: ApexColors.blue, fontWeight: FontWeight.w700, fontSize: 11)),
                    Text(_fmt(_rest!), style: ApexTheme.mono(size: 20, color: ApexColors.blue)),
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
                        onTap: () => setState(() => _cur = i),
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
                        Text(ex['name'] ?? '', style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.w800, color: ApexColors.t1)),
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
                                  child: Container(
                                    width: 26, height: 26,
                                    decoration: BoxDecoration(color: done ? ApexColors.accent : ApexColors.surface, shape: BoxShape.circle),
                                    child: Center(child: Text(done ? '✓' : '${si + 1}', style: TextStyle(color: done ? ApexColors.bg : ApexColors.t3, fontWeight: FontWeight.w800, fontSize: 11))),
                                  ),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: TextEditingController(text: s['reps']?.toString() ?? ''),
                                    onChanged: (v) => _upd(_cur, si, 'reps', v),
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: ApexTheme.mono(size: 16),
                                    decoration: InputDecoration(
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
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: ApexTheme.mono(size: 16),
                                    decoration: InputDecoration(
                                      hintText: '0',
                                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                      filled: true, fillColor: ApexColors.surface,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: BorderSide(color: ApexColors.border)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
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
                    Text('Save this session?', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800, fontSize: 12, color: ApexColors.t1)),
                    Text('${_fmt(_timer)} · $_doneCount sets · ${_totalVol}kg', style: TextStyle(color: ApexColors.t2, fontSize: 10)),
                    const SizedBox(height: 9),
                    Text('INTENSITY', style: GoogleFonts.spaceGrotesk(fontSize: 10, color: ApexColors.t2, fontWeight: FontWeight.w700)),
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
                      style: GoogleFonts.spaceGrotesk(fontSize: 13, color: ApexColors.t1),
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
