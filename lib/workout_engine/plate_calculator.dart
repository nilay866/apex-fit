import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';

/// Shows the plate calculator modal. Call this on long-press of a weight field.
Future<void> showPlateCalculator(BuildContext context, {double initialWeight = 0}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => PlateCalculatorSheet(initialWeight: initialWeight),
  );
}

class PlateCalculatorSheet extends StatefulWidget {
  final double initialWeight;
  const PlateCalculatorSheet({super.key, this.initialWeight = 60});

  @override
  State<PlateCalculatorSheet> createState() => _PlateCalculatorSheetState();
}

class _PlateCalculatorSheetState extends State<PlateCalculatorSheet> {
  // Standard plate sizes in kg
  static const _plates = [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25];
  // Bar weights
  static const _barOptions = [20.0, 15.0, 10.0, 7.5]; // Olympic, Women's, EZ, Hex
  static const _barLabels = ['Olympic (20kg)', "Women's (15kg)", 'EZ Bar (10kg)', 'Hex (7.5kg)'];

  double _targetWeight = 0;
  int _barIndex = 0;
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _targetWeight = widget.initialWeight;
    _ctrl.text = widget.initialWeight.toStringAsFixed(1);
    _ctrl.addListener(() {
      final v = double.tryParse(_ctrl.text);
      if (v != null && mounted) setState(() => _targetWeight = v);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double get _barWeight => _barOptions[_barIndex];

  /// Returns a map of plate -> count EACH SIDE
  Map<double, int> get _plateDistribution {
    final result = <double, int>{};
    double remaining = (_targetWeight - _barWeight) / 2;
    if (remaining <= 0) return result;
    for (final plate in _plates) {
      if (remaining >= plate) {
        final count = (remaining / plate).floor();
        result[plate] = count;
        remaining -= count * plate;
      }
    }
    return result;
  }

  Color _plateColor(double plate) {
    if (plate >= 25) return const Color(0xFFE53935); // Red
    if (plate >= 20) return const Color(0xFF1E88E5); // Blue
    if (plate >= 15) return const Color(0xFFFFB300); // Yellow
    if (plate >= 10) return const Color(0xFF43A047); // Green
    if (plate >= 5) return const Color(0xFFffffff); // White
    return const Color(0xFF9E9E9E); // Gray
  }

  @override
  Widget build(BuildContext context) {
    final distribution = _plateDistribution;
    final totalLoaded = distribution.entries.fold(0.0, (s, e) => s + e.key * e.value * 2) + _barWeight;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: ApexColors.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Text('Plate Calculator', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 22, color: ApexColors.t1)),
          const SizedBox(height: 20),

          // Bar selector
          Text('BAR', style: TextStyle(color: ApexColors.t3, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _barLabels.asMap().entries.map((e) {
                final sel = _barIndex == e.key;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _barIndex = e.key),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel ? ApexColors.accent : ApexColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sel ? ApexColors.accent : ApexColors.border),
                      ),
                      child: Text(e.value, style: TextStyle(color: sel ? Colors.white : ApexColors.t2, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          // Weight input
          Text('TARGET WEIGHT (KG)', style: TextStyle(color: ApexColors.t3, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          TextField(
            controller: _ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w700, color: ApexColors.t1),
            decoration: InputDecoration(
              suffix: Text('kg', style: TextStyle(color: ApexColors.t3, fontSize: 16)),
              filled: true,
              fillColor: ApexColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: ApexColors.border)),
            ),
          ),
          const SizedBox(height: 24),

          // Visual plate bar
          if (distribution.isNotEmpty) ...[
            Text('PLATES EACH SIDE', style: TextStyle(color: ApexColors.t3, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: distribution.entries.expand((e) {
                  return List.generate(e.value, (_) => Container(
                    margin: const EdgeInsets.only(right: 4),
                    width: 44, height: 56,
                    decoration: BoxDecoration(
                      color: _plateColor(e.key),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        e.key >= 1 ? '${e.key.toInt()}' : '${e.key}',
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                    ),
                  ));
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Result
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ApexColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ApexColors.borderStrong),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Bar', style: TextStyle(color: ApexColors.t3, fontSize: 11)),
                  Text('${_barWeight}kg', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: ApexColors.t2)),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Text('Plates (each side)', style: TextStyle(color: ApexColors.t3, fontSize: 11)),
                  Text(distribution.entries.map((e) => '${e.value}×${e.key}kg').join(' + '), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: ApexColors.t1)),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('Total', style: TextStyle(color: ApexColors.t3, fontSize: 11)),
                  Text('${totalLoaded.toStringAsFixed(1)}kg', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: ApexColors.accent)),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
