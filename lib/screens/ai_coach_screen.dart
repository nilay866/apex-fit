import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';
import '../services/ai_service.dart';
import '../services/plan_generator_service.dart';
import '../services/supabase_service.dart';
import '../services/coach_memory_service.dart';
import '../widgets/apex_orb_logo.dart';
import 'package:flutter/services.dart';
import 'ai_insights_screen.dart';

class AiCoachScreen extends StatefulWidget {
  final Map<String, dynamic>? profile;
  final List<Map<String, dynamic>> recentLogs;
  const AiCoachScreen({super.key, this.profile, required this.recentLogs});

  @override
  State<AiCoachScreen> createState() => _AiCoachScreenState();
}

class _AiCoachScreenState extends State<AiCoachScreen> {
  final List<Map<String, String>> _msgs = [
    {'role': 'assistant', 'content': "Your coach already knows your profile and recent training. Ask for plans, nutrition ideas, recovery adjustments, or form cues."}
  ];
  final _inputC = TextEditingController();
  final _scrollC = ScrollController();
  bool _thinking = false;

  // NEW: AI Coach Memory
  Map<String, dynamic> _coachMemory = {};

  static const _prompts = ['Best post-workout meal?', 'Build me a 5-day split', 'How to break plateau?', 'Am I overtraining?', 'Tips for fat loss?', 'Best exercises for back?'];

  void _scrollBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollC.hasClients) _scrollC.animateTo(_scrollC.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  @override
  void initState() {
    super.initState();
    // NEW: Load coach memory on init
    _loadCoachMemory();
  }

  Future<void> _send() async {
    if (_inputC.text.trim().isEmpty || _thinking) return;
    final userMsg = {'role': 'user', 'content': _inputC.text.trim()};
    setState(() { _msgs.add(userMsg); _thinking = true; });
    _inputC.clear();
    _scrollBottom();

    try {
      final recentLogDescs = widget.recentLogs.take(3).map((l) =>
        '${l['workout_name']}(${l['duration_min']}min,${((l['total_volume'] as num?)?.round() ?? 0)}kg,${l['intensity'] ?? 'moderate'})'
      ).toList();

      final reply = await AIService.chat(
        messages: _msgs,
        athleteName: widget.profile?['name'] ?? 'Athlete',
        goal: widget.profile?['goal'] ?? 'Build Muscle',
        weightKg: (widget.profile?['weight_kg'] as num?)?.toDouble(),
        heightCm: (widget.profile?['height_cm'] as num?)?.toDouble(),
        recentLogs: recentLogDescs,
        memoryContext: CoachMemoryService.buildMemoryContext(_coachMemory),
      );
      setState(() => _msgs.add({'role': 'assistant', 'content': reply.trim()}));
    } catch (e) {
      setState(() => _msgs.add({'role': 'assistant', 'content': '❌ $e'}));
    }
    setState(() => _thinking = false);
    _scrollBottom();

    // NEW: Save memory after conversation (non-blocking)
    if (_msgs.length >= 4) {
      _saveMemoryAfterConversation(_msgs);
    }
  }

  // NEW: Load coach memory from Supabase
  Future<void> _loadCoachMemory() async {
    try {
      final uid = SupabaseService.currentUser?.id;
      if (uid == null) return;
      final memory = await SupabaseService.getAiCoachMemory(uid);
      if (mounted) {
        setState(() {
          _coachMemory = memory;
        });
      }
    } catch (_) {}
  }

  // NEW: Extract and save memory after conversation
  Future<void> _saveMemoryAfterConversation(
    List<Map<String, String>> messages,
  ) async {
    try {
      final uid = SupabaseService.currentUser?.id;
      if (uid == null) return;
      final newFacts = await CoachMemoryService.extractKeyFacts(messages);
      if (newFacts.isNotEmpty) {
        final merged = CoachMemoryService.mergeMemory(_coachMemory, newFacts);
        await SupabaseService.saveAiCoachMemory(uid, merged);
        if (mounted) setState(() => _coachMemory = merged);
      }
    } catch (_) {}
  }

  bool _showPlanner = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: ApexColors.surface.withAlpha(220),
            border: Border(bottom: BorderSide(color: ApexColors.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const ApexOrbLogo(size: 54, label: 'AI', elevated: false),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Coach', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 20, color: ApexColors.t1)),
                      const SizedBox(height: 4),
                      Text('Context-aware training help for your current profile.', style: TextStyle(fontSize: 11, color: ApexColors.t2)),
                    ]),
                  ),
                  // NEW: AI Insights shortcut
                  IconButton(
                    key: const ValueKey('ai_insights_button'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AiInsightsScreen(),
                      ),
                    ),
                    icon: const Icon(
                      Icons.insights_rounded,
                      color: ApexColors.accent,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: ApexColors.accent.withAlpha(20),
                      padding: const EdgeInsets.all(10),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                height: 36,
                decoration: BoxDecoration(color: ApexColors.bg, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    _Tab('Chat', !_showPlanner, () => setState(() => _showPlanner = false)),
                    _Tab('Macrocycle Planner', _showPlanner, () => setState(() => _showPlanner = true)),
                  ],
                ),
              ),
            ],
          ),
        ),

        if (_showPlanner)
          Expanded(child: const _MacrocyclePlannerTab())
        else
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
            controller: _scrollC,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: _msgs.length + (_thinking ? 1 : 0),
            itemBuilder: (ctx, i) {
              if (i == _msgs.length) return _typingIndicator();
              final m = _msgs[i];
              final isUser = m['role'] == 'user';
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (!isUser) ...[
                      const ApexOrbLogo(size: 28, label: 'AI', elevated: false),
                      const SizedBox(width: 7),
                    ],
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                        decoration: BoxDecoration(
                          color: isUser ? ApexColors.accent : ApexColors.card,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(14),
                            topRight: const Radius.circular(14),
                            bottomLeft: Radius.circular(isUser ? 14 : 3),
                            bottomRight: Radius.circular(isUser ? 3 : 14),
                          ),
                          border: isUser ? null : Border.all(color: ApexColors.border),
                        ),
                        child: Text(m['content']!, style: TextStyle(color: isUser ? ApexColors.bg : ApexColors.t1, fontSize: 12, height: 1.6)),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        if (_msgs.length <= 1)
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: _prompts.map((p) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _inputC.text = p);
                  },
                    child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: ApexColors.surface, border: Border.all(color: ApexColors.border), borderRadius: BorderRadius.circular(18)),
                    child: Text(p, style: TextStyle(fontSize: 10, color: ApexColors.t2, fontWeight: FontWeight.w600)),
                  ),
                ),
              )).toList(),
            ),
          ),

        Container(
          padding: const EdgeInsets.fromLTRB(16, 9, 16, 12),
          decoration: BoxDecoration(color: ApexColors.surface.withAlpha(220), border: Border(top: BorderSide(color: ApexColors.border))),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputC,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _send(),
                  style: GoogleFonts.inter(fontSize: 12, color: ApexColors.t1),
                  decoration: InputDecoration(
                    hintText: 'Ask your AI coach...',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: ApexColors.border, width: 1.5)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _send,
                child: Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: _inputC.text.trim().isNotEmpty && !_thinking ? ApexColors.accent : ApexColors.border,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Center(
                    child: _thinking
                        ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: ApexColors.t3))
                        : const Icon(Icons.arrow_upward, color: ApexColors.ink, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  ),
],
);
}

  Widget _typingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const ApexOrbLogo(size: 28, label: 'AI', elevated: false),
          const SizedBox(width: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(color: ApexColors.card, border: Border.all(color: ApexColors.border), borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14), bottomRight: Radius.circular(14), bottomLeft: Radius.circular(3))),
            child: Row(children: List.generate(3, (i) => _Dot(delay: i * 200))),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() { _inputC.dispose(); _scrollC.dispose(); super.dispose(); }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});
  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
    Future.delayed(Duration(milliseconds: widget.delay), () { if (mounted) _c.forward(from: 0); });
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        width: 5, height: 5,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(color: ApexColors.t2.withAlpha((_c.value * 255).round()), shape: BoxShape.circle),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String text;
  final bool active;
  final VoidCallback onTap;
  const _Tab(this.text, this.active, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: active ? ApexColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: active ? [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))] : null,
          ),
          child: Center(
            child: Text(text, style: GoogleFonts.inter(fontSize: 12, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? ApexColors.t1 : ApexColors.t3)),
          ),
        ),
      ),
    );
  }
}

class _MacrocyclePlannerTab extends StatefulWidget {
  const _MacrocyclePlannerTab();
  @override
  State<_MacrocyclePlannerTab> createState() => _MacrocyclePlannerTabState();
}

class _MacrocyclePlannerTabState extends State<_MacrocyclePlannerTab> {
  bool _loading = false;
  Map<String, dynamic>? _macrocycle;

  Future<void> _generate() async {
    HapticFeedback.mediumImpact();
    setState(() => _loading = true);
    try {
      final profile = SupabaseService.currentUser == null 
          ? <String, dynamic>{} 
          : (await SupabaseService.getProfile(SupabaseService.currentUser!.id)) ?? <String, dynamic>{};
      
      final plan = await PlanGeneratorService.generateMacrocycle(profile);
      if (mounted) {
        setState(() {
          _macrocycle = plan;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_macrocycle == null) return _buildEmptyState();
    return _buildMacrocycleView();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(shape: BoxShape.circle, color: ApexColors.accent.withAlpha(20)),
              child: const Icon(Icons.auto_awesome, size: 64, color: ApexColors.accent),
            ),
            const SizedBox(height: 24),
            Text('AI Program Architect', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: ApexColors.t1)),
            const SizedBox(height: 12),
            Text(
              'Generate a hyper-targeted 4-week macrocycle based on your goals, age, and fitness level using advanced kinesiology rules.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ApexColors.t2, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: _loading ? null : _generate,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(color: _loading ? ApexColors.card : ApexColors.blue, borderRadius: BorderRadius.circular(16)),
                child: Center(
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: ApexColors.blue, strokeWidth: 2))
                      : Text('Generate Macrocycle', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: ApexColors.bg)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacrocycleView() {
    final weeks = _macrocycle!.keys.where((k) => k.startsWith('week')).toList()..sort();
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: weeks.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Text('Your 4-Week Block', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: ApexColors.t1)),
          );
        }
        
        final wKey = weeks[i - 1];
        final wData = _macrocycle![wKey] as Map<String, dynamic>;
        final focus = wData['focus'] ?? 'General Prep';
        final days = wData['days'] as List<dynamic>? ?? [];

        return Container(
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: ApexColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: ApexColors.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${wKey.toUpperCase().replaceAll('_', ' ')}: $focus', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: ApexColors.accent)),
              const SizedBox(height: 16),
              ...days.map((day) {
                final d = day as Map<String, dynamic>;
                final intensity = d['intensity'] ?? 'Low';
                final color = intensity == 'High' ? ApexColors.red : (intensity == 'Medium' || intensity == 'Med' ? ApexColors.yellow : ApexColors.blue);
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 8, height: 8,
                        margin: const EdgeInsets.only(top: 6, right: 12),
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d['title'] ?? 'Rest', style: TextStyle(color: ApexColors.t1, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(d['description'] ?? '', style: TextStyle(color: ApexColors.t3, fontSize: 12, height: 1.4)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
