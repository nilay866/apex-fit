import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';
import '../services/supabase_service.dart';
import 'routine_editor_screen.dart';

class RoutineLibraryScreen extends StatefulWidget {
  const RoutineLibraryScreen({super.key});

  @override
  State<RoutineLibraryScreen> createState() => _RoutineLibraryScreenState();
}

class _RoutineLibraryScreenState extends State<RoutineLibraryScreen> {
  List<Map<String, dynamic>> _routines = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await SupabaseService.getRoutines(SupabaseService.currentUser!.id);
      if (mounted) setState(() { _routines = res; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createNew() async {
    HapticFeedback.lightImpact();
    final name = await _showNameDialog();
    if (name == null || name.isEmpty) return;
    try {
      await SupabaseService.createRoutine(SupabaseService.currentUser!.id, name);
      _load();
    } catch (_) {}
  }

  Future<String?> _showNameDialog() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ApexColors.surface,
        title: Text('New Routine', style: GoogleFonts.inter(color: ApexColors.t1, fontWeight: FontWeight.w800)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: ApexColors.t1),
          decoration: InputDecoration(
            hintText: 'e.g. Push Day A',
            hintStyle: TextStyle(color: ApexColors.t3),
            filled: true, fillColor: ApexColors.bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ApexColors.border)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: ApexColors.t2))),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: ApexColors.accent.withAlpha(20),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text('Create', style: TextStyle(color: ApexColors.accent, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ApexColors.bg,
      appBar: AppBar(
        backgroundColor: ApexColors.bg,
        elevation: 0,
        title: Text('Routine Library', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: ApexColors.t1)),
        iconTheme: const IconThemeData(color: ApexColors.t1),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: ApexColors.accent),
            onPressed: _createNew,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: ApexColors.accent))
          : _routines.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.menu_book_rounded, size: 64, color: ApexColors.t3),
                      const SizedBox(height: 16),
                      Text('No routines yet', style: GoogleFonts.inter(color: ApexColors.t2, fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text('Tap + to create your first routine template', style: TextStyle(color: ApexColors.t3, fontSize: 13)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _routines.length,
                  itemBuilder: (ctx, i) {
                    final r = _routines[i];
                    final exercises = (r['routine_exercises'] as List?)?.length ?? 0;
                    return Dismissible(
                      key: Key(r['id'] ?? i.toString()),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(color: ApexColors.red.withAlpha(30), borderRadius: BorderRadius.circular(16)),
                        child: const Icon(Icons.delete_rounded, color: ApexColors.red),
                      ),
                      onDismissed: (_) async {
                        await SupabaseService.deleteRoutine(r['id']);
                        _load();
                      },
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => RoutineEditorScreen(routine: r, onSaved: _load)),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: ApexColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: ApexColors.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48, height: 48,
                                decoration: BoxDecoration(color: ApexColors.accent.withAlpha(20), borderRadius: BorderRadius.circular(12)),
                                child: const Icon(Icons.fitness_center_rounded, color: ApexColors.accent, size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(r['name'] ?? 'Untitled', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: ApexColors.t1, fontSize: 15)),
                                    const SizedBox(height: 2),
                                    Text('$exercises exercise${exercises == 1 ? '' : 's'}', style: TextStyle(color: ApexColors.t3, fontSize: 12)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: ApexColors.t3),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
