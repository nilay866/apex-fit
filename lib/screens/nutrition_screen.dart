import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/safe_haptics.dart';
import '../constants/colors.dart';
import '../constants/theme.dart';
import '../widgets/apex_card.dart';
import '../widgets/apex_button.dart';
import '../widgets/macro_bar.dart';
import '../widgets/apex_screen_header.dart';
import '../services/supabase_service.dart';
import '../services/ai_service.dart';
import '../services/nutrition_targets_service.dart';

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});
  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;

  final _foodC = TextEditingController();
  final _qtyC = TextEditingController();
  final _calC = TextEditingController();
  final _protC = TextEditingController();
  final _carbsC = TextEditingController();
  final _fatC = TextEditingController();
  bool _aiLoading = false;
  String _aiErr = '';
  bool _saving = false;

  // NEW: Dynamic nutrition targets
  NutritionTargets? _dynamicTargets;

  @override
  void initState() {
    super.initState();
    _load();
    // NEW: Load dynamic nutrition targets
    _loadDynamicTargets();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final userId = SupabaseService.requireUserId(
        action: 'load your nutrition log',
      );
      final l = await SupabaseService.getNutritionLogs(userId, limit: 50);
      if (mounted) {
        setState(() {
          _logs = l;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // NEW: Load dynamic nutrition targets based on training day
  Future<void> _loadDynamicTargets() async {
    try {
      final uid = SupabaseService.currentUser?.id;
      if (uid == null) return;
      final profile = await SupabaseService.getProfile(uid) ?? {};
      final targets =
          await NutritionTargetsService.computeForToday(uid, profile);
      if (mounted) setState(() => _dynamicTargets = targets);
    } catch (_) {}
  }

  Future<void> _saveMeal() async {
    if (_foodC.text.trim().isEmpty) {
      SafeHaptics.vibrate(HapticsType.error);
      return;
    }

    SafeHaptics.vibrate(HapticsType.medium);
    setState(() => _saving = true);

    // Clear keyboards
    FocusScope.of(context).unfocus();

    try {
      final userId = SupabaseService.requireUserId(action: 'save a meal');
      await SupabaseService.createNutritionLog({
        'user_id': userId,
        'meal_name': _foodC.text.trim(),
        'quantity': _qtyC.text.trim().isNotEmpty ? _qtyC.text.trim() : null,
        'calories': int.tryParse(_calC.text) ?? 0,
        'protein_g': double.tryParse(_protC.text) ?? 0,
        'carbs_g': double.tryParse(_carbsC.text) ?? 0,
        'fat_g': double.tryParse(_fatC.text) ?? 0,
      });
      _foodC.clear();
      _qtyC.clear();
      _calC.clear();
      _protC.clear();
      _carbsC.clear();
      _fatC.clear();

      SafeHaptics.vibrate(HapticsType.success);
      if (mounted) {
        setState(() {
          _aiErr = '';
        });
        _load();
      }
    } catch (e) {
      SafeHaptics.vibrate(HapticsType.error);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save meal. Please try again.'),
          backgroundColor: ApexColors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    if (mounted) setState(() => _saving = false);
  }

  void _showAddModal() {
    SafeHaptics.vibrate(HapticsType.light);
    setState(() {
      _aiErr = '';
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GestureDetector(
        onTap: () => FocusScope.of(ctx).unfocus(),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: ApexColors.surfaceStrong,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: ApexColors.border),
              boxShadow: [
                BoxShadow(
                  color: ApexColors.shadow.withAlpha(50),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
                    const SizedBox(height: 18),
                    Text(
                      'Log a Meal',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: ApexColors.t1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            'Food Name',
                            _foodC,
                            'e.g. Boiled eggs',
                            fieldKey: 'meal_food_field',
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 90,
                          child: _field(
                            'Quantity',
                            _qtyC,
                            '4 pcs',
                            fieldKey: 'meal_quantity_field',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    StatefulBuilder(
                      builder: (context, setModalState) {
                        return GestureDetector(
                          onTap: () {
                            if (_aiLoading || _foodC.text.trim().isEmpty) {
                              return;
                            }

                            // Run lookup logic and update modal state manually alongside outer state
                            SafeHaptics.vibrate(HapticsType.light);
                            setModalState(() {
                              _aiLoading = true;
                              _aiErr = '';
                            });
                            setState(() {
                              _aiLoading = true;
                              _aiErr = '';
                            });

                            AIService.lookupNutrition(
                                  _foodC.text.trim(),
                                  _qtyC.text.trim(),
                                )
                                .then((d) {
                                  if (mounted) {
                                    setModalState(() {
                                      if (d['calories'] != null) {
                                        _calC.text =
                                            '${(d['calories'] as num).round()}';
                                      }
                                      if (d['protein_g'] != null) {
                                        _protC.text =
                                            '${(d['protein_g'] as num).round()}';
                                      }
                                      if (d['carbs_g'] != null) {
                                        _carbsC.text =
                                            '${(d['carbs_g'] as num).round()}';
                                      }
                                      if (d['fat_g'] != null) {
                                        _fatC.text =
                                            '${(d['fat_g'] as num).round()}';
                                      }
                                      _aiLoading = false;
                                    });
                                    setState(() {
                                      _aiLoading = false;
                                    });
                                    SafeHaptics.vibrate(HapticsType.success);
                                  }
                                })
                                .catchError((e) {
                                  SafeHaptics.vibrate(HapticsType.error);
                                  if (mounted) {
                                    setModalState(() {
                                      _aiErr = 'AI lookup failed: $e';
                                      _aiLoading = false;
                                    });
                                    setState(() {
                                      _aiErr = 'AI lookup failed: $e';
                                      _aiLoading = false;
                                    });
                                  }
                                });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: (_aiLoading || _foodC.text.trim().isEmpty)
                                  ? ApexColors.cardAlt
                                  : ApexColors.purple.withAlpha(20),
                              border: Border.all(
                                color:
                                    (_aiLoading || _foodC.text.trim().isEmpty)
                                    ? ApexColors.borderStrong
                                    : ApexColors.purple.withAlpha(60),
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: _aiLoading
                                  ? [
                                      SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: ApexColors.purple,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Looking up...',
                                        style: GoogleFonts.inter(
                                          color: ApexColors.purple,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ]
                                  : [
                                      Icon(
                                        Icons.auto_awesome_rounded,
                                        size: 18,
                                        color: (_foodC.text.trim().isEmpty)
                                            ? ApexColors.t3
                                            : ApexColors.purple,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Auto-fill macros',
                                        style: GoogleFonts.inter(
                                          color: (_foodC.text.trim().isEmpty)
                                              ? ApexColors.t3
                                              : ApexColors.purple,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                            ),
                          ),
                        );
                      },
                    ),
                    if (_aiErr.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 9),
                        child: Text(
                          _aiErr,
                          style: TextStyle(color: ApexColors.red, fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      'NUTRITION INFO',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: ApexColors.t3,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            'Calories',
                            _calC,
                            '0',
                            number: true,
                            fieldKey: 'meal_calories_field',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _field(
                            'Protein (g)',
                            _protC,
                            '0',
                            number: true,
                            fieldKey: 'meal_protein_field',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            'Carbs (g)',
                            _carbsC,
                            '0',
                            number: true,
                            fieldKey: 'meal_carbs_field',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _field(
                            'Fat (g)',
                            _fatC,
                            '0',
                            number: true,
                            fieldKey: 'meal_fat_field',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    StatefulBuilder(
                      builder: (context, setModalState) {
                        return Row(
                          children: [
                            Expanded(
                              child: ApexButton(
                                text: 'Cancel',
                                onPressed: () {
                                  SafeHaptics.vibrate(HapticsType.light);
                                  Navigator.pop(ctx);
                                },
                                tone: ApexButtonTone.outline,
                                color: ApexColors.t1,
                                full: true,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ApexButton(
                                key: const ValueKey('save_meal_button'),
                                text: 'Save Meal',
                                onPressed: () {
                                  _saveMeal().then((_) {
                                    if (!ctx.mounted) return;
                                    Navigator.pop(ctx);
                                  });
                                },
                                full: true,
                                loading: _saving,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final todayLogs = _logs.where((l) {
      final d = l['logged_at']?.toString().split('T')[0];
      return d == today;
    }).toList();
    final totCal = todayLogs.fold<int>(
      0,
      (a, l) => a + ((l['calories'] as int?) ?? 0),
    );
    final totProt = todayLogs.fold<double>(
      0,
      (a, l) => a + ((l['protein_g'] as num?)?.toDouble() ?? 0),
    );
    final totCarbs = todayLogs.fold<double>(
      0,
      (a, l) => a + ((l['carbs_g'] as num?)?.toDouble() ?? 0),
    );
    final totFat = todayLogs.fold<double>(
      0,
      (a, l) => a + ((l['fat_g'] as num?)?.toDouble() ?? 0),
    );

    return Scaffold(
      backgroundColor: Colors.transparent, // Shell sets BG
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: FloatingActionButton.extended(
          onPressed: _showAddModal,
          elevation: 12,
          backgroundColor: ApexColors.red,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: Text(
            'Add Food',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: RefreshIndicator(
        onRefresh: _load,
        color: ApexColors.accent,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            ApexScreenHeader(
              eyebrow: 'Nutrition',
              title: 'Fuel',
              subtitle: "Today's intake, macros, and meal history.",
            ),
            const SizedBox(height: 14),
            // NEW: Training day / rest day target banner
            if (_dynamicTargets != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: (_dynamicTargets!.isTrainingDay
                            ? ApexColors.accentSoft
                            : ApexColors.blue)
                        .withAlpha(18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (_dynamicTargets!.isTrainingDay
                              ? ApexColors.accentSoft
                              : ApexColors.blue)
                          .withAlpha(60),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _dynamicTargets!.isTrainingDay
                            ? Icons.fitness_center_rounded
                            : Icons.self_improvement_rounded,
                        size: 16,
                        color: _dynamicTargets!.isTrainingDay
                            ? ApexColors.accentSoft
                            : ApexColors.blue,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _dynamicTargets!.isTrainingDay
                              ? 'Training day — targets boosted (+300 kcal)'
                              : 'Rest day — reduced carbs for recomposition',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _dynamicTargets!.isTrainingDay
                                ? ApexColors.accentSoft
                                : ApexColors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ApexCard(
              glow: true,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Today's macros",
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: ApexColors.t1,
                        ),
                      ),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '$totCal',
                              style: ApexTheme.mono(
                                size: 20,
                                color: ApexColors.accent,
                              ),
                            ),
                            TextSpan(
                              text: ' kcal',
                              style: ApexTheme.mono(
                                size: 11,
                                color: ApexColors.t3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  MacroBar(
                    label: 'PROTEIN',
                    value: totProt,
                    goal: 160,
                    color: ApexColors.blue,
                  ),
                  const SizedBox(height: 16),
                  MacroBar(
                    label: 'CARBS',
                    value: totCarbs,
                    goal: 250,
                    color: ApexColors.orange,
                  ),
                  const SizedBox(height: 16),
                  MacroBar(
                    label: 'FAT',
                    value: totFat,
                    goal: 70,
                    color: ApexColors.purple,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Today (${todayLogs.length} meals)',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                color: ApexColors.t1,
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: CircularProgressIndicator(color: ApexColors.accent),
                ),
              )
            else if (todayLogs.isEmpty)
              ApexCard(
                padding: const EdgeInsets.all(36),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.fastfood_outlined,
                        size: 42,
                        color: ApexColors.cardAlt,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No meals logged today.',
                        style: TextStyle(color: ApexColors.t2, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...todayLogs.map(
                (l) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ApexCard(
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: ApexColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: ApexColors.border),
                          ),
                          child: const Icon(
                            Icons.fastfood_rounded,
                            size: 20,
                            color: ApexColors.t2,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: l['meal_name'] ?? '',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: ApexColors.t1,
                                      ),
                                    ),
                                    if (l['quantity'] != null)
                                      TextSpan(
                                        text: ' · ${l['quantity']}',
                                        style: TextStyle(
                                          color: ApexColors.t3,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    '${l['calories']} kcal',
                                    style: ApexTheme.mono(
                                      size: 11,
                                      color: ApexColors.orange,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'P:${(l['protein_g'] as num?)?.round() ?? 0}g',
                                    style: TextStyle(
                                      color: ApexColors.t3,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'C:${(l['carbs_g'] as num?)?.round() ?? 0}g',
                                    style: TextStyle(
                                      color: ApexColors.t3,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'F:${(l['fat_g'] as num?)?.round() ?? 0}g',
                                    style: TextStyle(
                                      color: ApexColors.t3,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 60), // Add padding for bottom
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController c,
    String hint, {
    bool number = false,
    String? fieldKey,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 10,
            color: ApexColors.t2,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          key: fieldKey == null ? null : ValueKey(fieldKey),
          controller: c,
          keyboardType: number ? TextInputType.number : TextInputType.text,
          style: GoogleFonts.inter(fontSize: 13, color: ApexColors.t1),
          decoration: InputDecoration(
            hintText: hint,
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
      ],
    );
  }

  @override
  void dispose() {
    _foodC.dispose();
    _qtyC.dispose();
    _calC.dispose();
    _protC.dispose();
    _carbsC.dispose();
    _fatC.dispose();
    super.dispose();
  }
}
