import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:apex_ai/constants/colors.dart';
import 'package:apex_ai/widgets/apex_card.dart';
import 'package:apex_ai/widgets/apex_button.dart';
import 'package:apex_ai/widgets/apex_screen_header.dart';
import 'package:apex_ai/services/ai_service.dart';
import 'package:apex_ai/services/supabase_service.dart';
import 'package:google_fonts/google_fonts.dart';

class AiInsightsScreen extends StatefulWidget {
  const AiInsightsScreen({super.key});
  @override
  State<AiInsightsScreen> createState() => _AiInsightsScreenState();
}

class _AiInsightsScreenState extends State<AiInsightsScreen> {
  String _weeklyInsight = '';
  String _nutritionInsight = '';
  String _strengthInsight = '';
  bool _loading = false;
  bool _generated = false;

  Future<void> _generate() async {
    setState(() => _loading = true);
    try {
      final uid = SupabaseService.currentUser?.id;
      if (uid == null) return;

      final logs = await SupabaseService.getWorkoutLogs(uid, limit: 7);
      final nLogs = await SupabaseService.getNutritionLogs(uid, limit: 20);

      final workoutSummary =
          'Workouts this week: ${logs.length}. Total volume: '
          '${logs.fold<int>(0, (a, l) => a + ((l['total_volume'] as num?)?.round() ?? 0))}kg.';
      final nutritionSummary = 'Meals logged this week: ${nLogs.length}.';

      final prompt = '''
You are a fitness AI coach generating a personalized weekly insights report.
Be specific, encouraging, and actionable. Keep each section to 2-3 sentences.

User data:
$workoutSummary
$nutritionSummary

Generate 3 sections:
1. WEEKLY_SUMMARY: Overall week assessment
2. STRENGTH_INSIGHT: Strength/workout specific feedback  
3. NUTRITION_INSIGHT: Nutrition feedback

Format: Return only JSON with keys weekly_summary, strength_insight, nutrition_insight. No markdown.''';

      final response = await AIService.generate(prompt);
      final clean = response
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      try {
        final Map<String, dynamic> data = Map<String, dynamic>.from(
          jsonDecode(clean) as Map,
        );
        if (mounted) {
          setState(() {
            _weeklyInsight =
                data['weekly_summary']?.toString() ?? '';
            _strengthInsight =
                data['strength_insight']?.toString() ?? '';
            _nutritionInsight =
                data['nutrition_insight']?.toString() ?? '';
            _generated = true;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _weeklyInsight = response;
            _generated = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('AI error: $e'),
              backgroundColor: ApexColors.red),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
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
        title: Text('AI Insights',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: ApexColors.t1)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          ApexScreenHeader(
            eyebrow: 'AI Coach',
            title: 'Weekly Report',
            subtitle:
                'Personalized insights based on your training data.',
          ),
          const SizedBox(height: 20),

          if (!_generated) ...[
            ApexCard(
              glow: true,
              child: Column(
                children: [
                  const Text('🤖', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 16),
                  Text(
                    'Generate your AI weekly report',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: ApexColors.t1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your AI coach will analyze your workouts, nutrition, '
                    'and recovery from this week and give personalized feedback.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13,
                        color: ApexColors.t2,
                        height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  ApexButton(
                    text: 'Generate Weekly Insights',
                    onPressed: _generate,
                    full: true,
                    loading: _loading,
                  ),
                ],
              ),
            ),
          ] else ...[
            _insightCard(
              '📊',
              'Weekly Summary',
              _weeklyInsight,
              ApexColors.accent,
            ),
            const SizedBox(height: 12),
            _insightCard(
              '💪',
              'Strength Analysis',
              _strengthInsight,
              ApexColors.blue,
            ),
            const SizedBox(height: 12),
            _insightCard(
              '🥗',
              'Nutrition Feedback',
              _nutritionInsight,
              ApexColors.orange,
            ),
            const SizedBox(height: 20),
            ApexButton(
              text: 'Regenerate',
              onPressed: _generate,
              tone: ApexButtonTone.outline,
              color: ApexColors.t2,
              full: true,
              loading: _loading,
            ),
          ],
        ],
      ),
    );
  }

  Widget _insightCard(
      String emoji, String title, String body, Color color) {
    return ApexCard(
      glow: true,
      glowColor: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: ApexColors.t1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: const TextStyle(
              fontSize: 14,
              color: ApexColors.t2,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
