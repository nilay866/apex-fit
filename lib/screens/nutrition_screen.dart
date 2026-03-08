import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';
import '../constants/theme.dart';
import '../widgets/apex_card.dart';
import '../widgets/apex_button.dart';
import '../widgets/macro_bar.dart';
import '../widgets/apex_screen_header.dart';
import '../services/supabase_service.dart';
import '../services/ai_service.dart';

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});
  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;
  bool _showAdd = false;
  final _foodC = TextEditingController();
  final _qtyC = TextEditingController();
  final _calC = TextEditingController();
  final _protC = TextEditingController();
  final _carbsC = TextEditingController();
  final _fatC = TextEditingController();
  bool _aiLoading = false;
  String _aiErr = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final l = await SupabaseService.getNutritionLogs(SupabaseService.currentUser!.id, limit: 50);
      setState(() { _logs = l; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _aiLookup() async {
    if (_foodC.text.trim().isEmpty) { setState(() => _aiErr = 'Enter food name first.'); return; }
    setState(() { _aiLoading = true; _aiErr = ''; });
    try {
      final d = await AIService.lookupNutrition(_foodC.text.trim(), _qtyC.text.trim());
      setState(() {
        if (d['calories'] != null) _calC.text = '${(d['calories'] as num).round()}';
        if (d['protein_g'] != null) _protC.text = '${(d['protein_g'] as num).round()}';
        if (d['carbs_g'] != null) _carbsC.text = '${(d['carbs_g'] as num).round()}';
        if (d['fat_g'] != null) _fatC.text = '${(d['fat_g'] as num).round()}';
      });
    } catch (e) {
      setState(() => _aiErr = 'AI lookup failed: $e');
    }
    setState(() => _aiLoading = false);
  }

  Future<void> _saveMeal() async {
    if (_foodC.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await SupabaseService.createNutritionLog({
        'user_id': SupabaseService.currentUser!.id,
        'meal_name': _foodC.text.trim(),
        'quantity': _qtyC.text.trim().isNotEmpty ? _qtyC.text.trim() : null,
        'calories': int.tryParse(_calC.text) ?? 0,
        'protein_g': double.tryParse(_protC.text) ?? 0,
        'carbs_g': double.tryParse(_carbsC.text) ?? 0,
        'fat_g': double.tryParse(_fatC.text) ?? 0,
      });
      _foodC.clear(); _qtyC.clear(); _calC.clear(); _protC.clear(); _carbsC.clear(); _fatC.clear();
      setState(() { _showAdd = false; _aiErr = ''; });
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save meal. Please try again.')),
      );
    }
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final todayLogs = _logs.where((l) {
      final d = l['logged_at']?.toString().split('T')[0];
      return d == today;
    }).toList();
    final totCal = todayLogs.fold<int>(0, (a, l) => a + ((l['calories'] as int?) ?? 0));
    final totProt = todayLogs.fold<double>(0, (a, l) => a + ((l['protein_g'] as num?)?.toDouble() ?? 0));
    final totCarbs = todayLogs.fold<double>(0, (a, l) => a + ((l['carbs_g'] as num?)?.toDouble() ?? 0));
    final totFat = todayLogs.fold<double>(0, (a, l) => a + ((l['fat_g'] as num?)?.toDouble() ?? 0));

    return RefreshIndicator(
      onRefresh: _load,
      color: ApexColors.accent,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          ApexScreenHeader(
            eyebrow: 'Nutrition',
            title: 'Fuel',
            subtitle: "Today's intake, macros, and meal history.",
            trailing: ApexButton(
              text: _showAdd ? 'Close' : 'Log meal',
              onPressed: () => setState(() => _showAdd = !_showAdd),
              sm: true,
              icon: _showAdd ? Icons.close_rounded : Icons.add_rounded,
            ),
          ),
          const SizedBox(height: 14),
          ApexCard(
            glow: true,
            child: Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text("Today's macros", style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18, color: ApexColors.t1)),
                  RichText(text: TextSpan(children: [
                    TextSpan(text: '$totCal', style: ApexTheme.mono(size: 20, color: ApexColors.accent)),
                    TextSpan(text: ' kcal', style: ApexTheme.mono(size: 11, color: ApexColors.t3)),
                  ])),
                ]),
                const SizedBox(height: 12),
                MacroBar(label: 'Protein', value: totProt, goal: 160, color: ApexColors.blue),
                MacroBar(label: 'Carbs', value: totCarbs, goal: 250, color: ApexColors.orange),
                MacroBar(label: 'Fat', value: totFat, goal: 70, color: ApexColors.purple),
              ],
            ),
          ),
          if (_showAdd) ...[
            const SizedBox(height: 14),
            ApexCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Log a Meal', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, color: ApexColors.t1)),
                  const SizedBox(height: 11),
                  Row(children: [
                    Expanded(child: _field('Food Name', _foodC, 'e.g. Boiled eggs')),
                    const SizedBox(width: 8),
                    SizedBox(width: 90, child: _field('Quantity', _qtyC, '4 pcs')),
                  ]),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _aiLoading || _foodC.text.trim().isEmpty ? null : _aiLookup,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [ApexColors.purple.withAlpha(32), ApexColors.blue.withAlpha(32)]),
                        border: Border.all(color: ApexColors.purple.withAlpha(70)),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: _aiLoading
                            ? [SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2, color: ApexColors.purple)), const SizedBox(width: 7), Text('Looking up...', style: GoogleFonts.inter(color: ApexColors.purple, fontWeight: FontWeight.w700, fontSize: 12))]
                            : [const Icon(Icons.auto_awesome_rounded, size: 16, color: ApexColors.purple), const SizedBox(width: 7), Text('Auto-fill macros', style: GoogleFonts.inter(color: ApexColors.purple, fontWeight: FontWeight.w700, fontSize: 12))],
                      ),
                    ),
                  ),
                  if (_aiErr.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 9), child: Text(_aiErr, style: TextStyle(color: ApexColors.red, fontSize: 11))),
                  const SizedBox(height: 7),
                  Text('Or fill manually:', style: TextStyle(fontSize: 10, color: ApexColors.t3)),
                  const SizedBox(height: 7),
                  Row(children: [
                    Expanded(child: _field('Calories', _calC, '0', number: true)),
                    const SizedBox(width: 8),
                    Expanded(child: _field('Protein (g)', _protC, '0', number: true)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _field('Carbs (g)', _carbsC, '0', number: true)),
                    const SizedBox(width: 8),
                    Expanded(child: _field('Fat (g)', _fatC, '0', number: true)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: ApexButton(text: 'Cancel', onPressed: () => setState(() => _showAdd = false), outline: true, sm: true, full: true)),
                    const SizedBox(width: 8),
                    Expanded(child: ApexButton(text: 'Save Meal', onPressed: _saveMeal, sm: true, full: true, loading: _saving)),
                  ]),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text('Today (${todayLogs.length} meals)', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: ApexColors.t1)),
          const SizedBox(height: 9),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(18), child: CircularProgressIndicator(color: ApexColors.accent)))
          else if (todayLogs.isEmpty)
            ApexCard(child: Center(child: Text('No meals logged today.', style: TextStyle(color: ApexColors.t3, fontSize: 12))))
          else
            ...todayLogs.map((l) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: ApexCard(
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: ApexColors.orange.withAlpha(24),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.restaurant_rounded, size: 18, color: ApexColors.orange),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      RichText(text: TextSpan(children: [
                        TextSpan(text: l['meal_name'] ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: ApexColors.t1)),
                        if (l['quantity'] != null) TextSpan(text: ' · ${l['quantity']}', style: TextStyle(color: ApexColors.t3, fontSize: 11)),
                      ])),
                      Row(children: [
                        Text('${l['calories']}kcal', style: ApexTheme.mono(size: 10, color: ApexColors.accent)),
                        const SizedBox(width: 8),
                        Text('P:${(l['protein_g'] as num?)?.round() ?? 0}g', style: TextStyle(color: ApexColors.t3, fontSize: 10)),
                        const SizedBox(width: 4),
                        Text('C:${(l['carbs_g'] as num?)?.round() ?? 0}g', style: TextStyle(color: ApexColors.t3, fontSize: 10)),
                        const SizedBox(width: 4),
                        Text('F:${(l['fat_g'] as num?)?.round() ?? 0}g', style: TextStyle(color: ApexColors.t3, fontSize: 10)),
                      ]),
                    ])),
                  ],
                ),
              ),
            )),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController c, String hint, {bool number = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: GoogleFonts.inter(fontSize: 11, color: ApexColors.t2, fontWeight: FontWeight.w700, letterSpacing: 0.7)),
        const SizedBox(height: 4),
        TextField(controller: c, keyboardType: number ? TextInputType.number : TextInputType.text, style: GoogleFonts.inter(fontSize: 12, color: ApexColors.t1), decoration: InputDecoration(hintText: hint, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7))),
      ],
    );
  }

  @override
  void dispose() { _foodC.dispose(); _qtyC.dispose(); _calC.dispose(); _protC.dispose(); _carbsC.dispose(); _fatC.dispose(); super.dispose(); }
}
