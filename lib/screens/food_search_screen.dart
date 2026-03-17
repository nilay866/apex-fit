import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';
import '../widgets/apex_card.dart';
import '../widgets/apex_button.dart';
import '../services/ai_service.dart';

/// AI-powered food search with macro estimation
class FoodSearchScreen extends StatefulWidget {
  const FoodSearchScreen({super.key});
  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen> {
  final _searchC = TextEditingController();
  bool _loading = false;
  List<Map<String, dynamic>> _results = [];

  Future<void> _search() async {
    final q = _searchC.text.trim();
    if (q.isEmpty) return;
    setState(() => _loading = true);

    try {
      final prompt = '''
You are a nutrition database. For the food "$q", estimate macros per standard serving.
Return ONLY valid JSON array, no markdown:
[{"food_name":"<name>","serving":"<serving size>","calories":<kcal>,"protein_g":<g>,"carbs_g":<g>,"fat_g":<g>,"fiber_g":<g>}]
If multiple items match, return up to 5 results.''';

      final response = await AIService.generate(prompt);
      final clean =
          response.replaceAll('```json', '').replaceAll('```', '').trim();

      try {
        final List<dynamic> parsed = jsonDecode(clean) as List;
        if (mounted) {
          setState(() {
            _results = parsed
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
          });
        }
      } catch (_) {
        // Try to parse as single object
        try {
          final Map<String, dynamic> single =
              Map<String, dynamic>.from(jsonDecode(clean) as Map);
          if (mounted) setState(() => _results = [single]);
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not parse food data'),
                backgroundColor: ApexColors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search failed: $e'),
            backgroundColor: ApexColors.red,
          ),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ApexColors.bg,
      appBar: AppBar(
        backgroundColor: ApexColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: ApexColors.t1, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Search Food',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: ApexColors.t1)),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchC,
                    style: const TextStyle(color: ApexColors.t1),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      hintText: 'Search any food...',
                      hintStyle: const TextStyle(color: ApexColors.t3),
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: ApexColors.t3),
                      filled: true,
                      fillColor: ApexColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ApexButton(
                  text: 'Search',
                  onPressed: _search,
                  sm: true,
                  loading: _loading,
                ),
              ],
            ),
          ),

          // Results
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text(
                      _loading
                          ? 'Searching...'
                          : 'Search for a food to see nutrition info',
                      style: const TextStyle(
                          color: ApexColors.t3, fontSize: 13),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: _results.length,
                    separatorBuilder: (_, i2) =>
                        const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final food = _results[i];
                      return GestureDetector(
                        onTap: () => Navigator.pop(context, food),
                        child: ApexCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      food['food_name']?.toString() ??
                                          'Unknown',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: ApexColors.t1,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${food['calories'] ?? 0} kcal',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      color: ApexColors.accent,
                                    ),
                                  ),
                                ],
                              ),
                              if (food['serving'] != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  food['serving'].toString(),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: ApexColors.t3,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _macro(
                                    'Protein',
                                    '${food['protein_g'] ?? 0}g',
                                    ApexColors.blue,
                                  ),
                                  _macro(
                                    'Carbs',
                                    '${food['carbs_g'] ?? 0}g',
                                    ApexColors.orange,
                                  ),
                                  _macro(
                                    'Fat',
                                    '${food['fat_g'] ?? 0}g',
                                    ApexColors.yellow,
                                  ),
                                  _macro(
                                    'Fiber',
                                    '${food['fiber_g'] ?? 0}g',
                                    ApexColors.t3,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  'Tap to add →',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: ApexColors.accent,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _macro(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 9, color: color.withAlpha(150)),
        ),
      ],
    );
  }
}
