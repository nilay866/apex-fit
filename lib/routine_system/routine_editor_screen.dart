import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';
import '../services/supabase_service.dart';

class RoutineEditorScreen extends StatefulWidget {
  final Map<String, dynamic> routine;
  final VoidCallback onSaved;

  const RoutineEditorScreen({super.key, required this.routine, required this.onSaved});

  @override
  State<RoutineEditorScreen> createState() => _RoutineEditorScreenState();
}

class _RoutineEditorScreenState extends State<RoutineEditorScreen> {
  List<Map<String, dynamic>> _exercises = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final exercises = await SupabaseService.getRoutineExercises(widget.routine['id']);
      if (mounted) setState(() { _exercises = exercises; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _exercises = []; _loading = false; });
    }
  }

  Future<void> _addExercise() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1F),
        title: Text('Add Exercise', style: GoogleFonts.inter(color: ApexColors.t1, fontWeight: FontWeight.w800)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: ApexColors.t1),
          decoration: InputDecoration(
            hintText: 'e.g. Bench Press',
            hintStyle: TextStyle(color: ApexColors.t3),
            filled: true, fillColor: ApexColors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ApexColors.border)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: ApexColors.t3))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text('Add', style: TextStyle(color: ApexColors.accent, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;
    setState(() {
      _exercises.add({'exercise_name': name, 'sets': 3, 'reps': '8-12', 'rest_seconds': 90});
    });
    await _save();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await SupabaseService.saveRoutineExercises(widget.routine['id'], _exercises);
      widget.onSaved();
    } catch (_) {}
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ApexColors.bg,
      appBar: AppBar(
        backgroundColor: ApexColors.bg,
        elevation: 0,
        title: Text(widget.routine['name'] ?? 'Routine', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: ApexColors.t1)),
        iconTheme: const IconThemeData(color: ApexColors.t1),
        actions: [
          if (_saving)
            const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: ApexColors.accent, strokeWidth: 2)))
          else
            IconButton(icon: const Icon(Icons.check_rounded, color: ApexColors.accent), onPressed: _save),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: ApexColors.accent))
          : ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _exercises.removeAt(oldIndex);
                  _exercises.insert(newIndex, item);
                });
                _save();
              },
              itemCount: _exercises.length,
              itemBuilder: (ctx, i) {
                final ex = _exercises[i];
                return Container(
                  key: ValueKey(i),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: ApexColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ApexColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.drag_handle_rounded, color: ApexColors.t3),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ex['exercise_name'] ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: ApexColors.t1)),
                            const SizedBox(height: 4),
                            Row(children: [
                              _pill('${ex['sets']} sets', ApexColors.accent),
                              const SizedBox(width: 6),
                              _pill(ex['reps'] ?? '8-12', ApexColors.blue),
                              const SizedBox(width: 6),
                              _pill('${ex['rest_seconds']}s rest', ApexColors.t3),
                            ]),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: ApexColors.red, size: 20),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          setState(() => _exercises.removeAt(i));
                          _save();
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addExercise,
        backgroundColor: ApexColors.accent,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Add Exercise', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}
