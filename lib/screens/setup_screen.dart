import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';
import '../widgets/apex_card.dart';
import '../widgets/apex_button.dart';
import '../services/ai_service.dart';

class SetupScreen extends StatefulWidget {
  final Function({
    required String url,
    required String key,
    required String aiKey,
    String? rapidApiKey,
  }) onConnect;
  const SetupScreen({super.key, required this.onConnect});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _urlC = TextEditingController();
  final _keyC = TextEditingController();
  final _aiKeyC = TextEditingController();
  final _rapidC = TextEditingController();
  bool _showSql = false;
  bool _copied = false;
  String _err = '';
  bool _testingDb = false;
  Map<String, dynamic>? _dbResult;
  bool _testingAi = false;
  Map<String, dynamic>? _aiResult;

  static const _sql = '''-- APEX AI v3 — Run in Supabase SQL Editor
create table if not exists public.profiles (id uuid references auth.users on delete cascade primary key, name text, avatar_data text, weight_kg numeric, height_cm numeric, goal text default 'Build Muscle', calorie_goal int default 2000, water_goal_ml int default 2500, created_at timestamptz default now());
create table if not exists public.workouts (id uuid default gen_random_uuid() primary key, user_id uuid references auth.users on delete cascade, name text not null, type text default 'Gym', created_at timestamptz default now());
create table if not exists public.exercises (id uuid default gen_random_uuid() primary key, workout_id uuid references public.workouts on delete cascade, name text not null, sets int default 3, reps text default '8-12', target_weight numeric);
create table if not exists public.workout_logs (id uuid default gen_random_uuid() primary key, user_id uuid references auth.users on delete cascade, workout_name text, duration_min int, total_volume numeric default 0, intensity text default 'moderate', notes text, completed_at timestamptz default now());
create table if not exists public.set_logs (id uuid default gen_random_uuid() primary key, log_id uuid references public.workout_logs on delete cascade, exercise_name text, set_number int, reps_done int, weight_kg numeric, logged_at timestamptz default now());
create table if not exists public.nutrition_logs (id uuid default gen_random_uuid() primary key, user_id uuid references auth.users on delete cascade, meal_name text not null, quantity text, photo_data text, calories int default 0, protein_g numeric default 0, carbs_g numeric default 0, fat_g numeric default 0, logged_at timestamptz default now());
create table if not exists public.body_weight_logs (id uuid default gen_random_uuid() primary key, user_id uuid references auth.users on delete cascade, weight_kg numeric not null, logged_at timestamptz default now());
create table if not exists public.water_logs (id uuid default gen_random_uuid() primary key, user_id uuid references auth.users on delete cascade, amount_ml int not null, logged_at timestamptz default now());
create table if not exists public.progress_photos (id uuid default gen_random_uuid() primary key, user_id uuid references auth.users on delete cascade, photo_data text not null, caption text, taken_at timestamptz default now());
-- Backfill columns for older projects
alter table public.profiles add column if not exists name text;
alter table public.profiles add column if not exists avatar_data text;
alter table public.profiles add column if not exists weight_kg numeric;
alter table public.profiles add column if not exists height_cm numeric;
alter table public.profiles add column if not exists goal text default 'Build Muscle';
alter table public.profiles add column if not exists calorie_goal int default 2000;
alter table public.profiles add column if not exists water_goal_ml int default 2500;
alter table public.water_logs add column if not exists amount_ml int;
alter table public.water_logs add column if not exists logged_at timestamptz default now();
update public.profiles set calorie_goal = coalesce(calorie_goal, 2000), water_goal_ml = coalesce(water_goal_ml, 2500);
update public.water_logs set amount_ml = coalesce(amount_ml, 250) where amount_ml is null;
alter table public.water_logs alter column amount_ml set not null;
-- Enable RLS
alter table public.profiles enable row level security;
alter table public.workouts enable row level security;
alter table public.exercises enable row level security;
alter table public.workout_logs enable row level security;
alter table public.set_logs enable row level security;
alter table public.nutrition_logs enable row level security;
alter table public.body_weight_logs enable row level security;
alter table public.water_logs enable row level security;
alter table public.progress_photos enable row level security;
-- Policies
drop policy if exists "own_profile" on public.profiles; create policy "own_profile" on public.profiles for all using (auth.uid()=id) with check (auth.uid()=id);
drop policy if exists "own_workouts" on public.workouts; create policy "own_workouts" on public.workouts for all using (auth.uid()=user_id) with check (auth.uid()=user_id);
drop policy if exists "own_exercises" on public.exercises; create policy "own_exercises" on public.exercises for all using (auth.uid()=(select user_id from public.workouts where id=workout_id));
drop policy if exists "own_logs" on public.workout_logs; create policy "own_logs" on public.workout_logs for all using (auth.uid()=user_id) with check (auth.uid()=user_id);
drop policy if exists "own_set_logs" on public.set_logs; create policy "own_set_logs" on public.set_logs for all using (auth.uid()=(select user_id from public.workout_logs where id=log_id));
drop policy if exists "own_nutrition" on public.nutrition_logs; create policy "own_nutrition" on public.nutrition_logs for all using (auth.uid()=user_id) with check (auth.uid()=user_id);
drop policy if exists "own_weight" on public.body_weight_logs; create policy "own_weight" on public.body_weight_logs for all using (auth.uid()=user_id) with check (auth.uid()=user_id);
drop policy if exists "own_water" on public.water_logs; create policy "own_water" on public.water_logs for all using (auth.uid()=user_id) with check (auth.uid()=user_id);
drop policy if exists "own_photos" on public.progress_photos; create policy "own_photos" on public.progress_photos for all using (auth.uid()=user_id) with check (auth.uid()=user_id);
-- Trigger
create or replace function public.handle_new_user() returns trigger as \$\$ begin insert into public.profiles(id,name) values(new.id,new.raw_user_meta_data->>'name') on conflict(id) do nothing; return new; end; \$\$ language plpgsql security definer;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();''';

  Future<void> _testDb() async {
    if (_urlC.text.isEmpty || _keyC.text.isEmpty) {
      setState(() => _err = 'Enter URL and key first.');
      return;
    }
    setState(() { _testingDb = true; _dbResult = null; _err = ''; });
    try {
      final url = _urlC.text.trim().replaceAll(RegExp(r'/$'), '');
      Uri.parse('$url/rest/v1/');
      setState(() => _dbResult = {'ok': true, 'msg': '✅ Supabase URL looks valid!'});
    } catch (e) {
      setState(() => _dbResult = {'ok': false, 'msg': '❌ Cannot reach Supabase. Check URL.'});
    } finally {
      setState(() => _testingDb = false);
    }
  }

  Future<void> _testAi() async {
    if (_aiKeyC.text.trim().isEmpty) {
      setState(() => _aiResult = {'ok': false, 'msg': 'Enter your Gemini API key first.'});
      return;
    }
    setState(() { _testingAi = true; _aiResult = null; });
    try {
      final ok = await AIService.testConnection();
      setState(() => _aiResult = ok
          ? {'ok': true, 'msg': '✅ Gemini AI working!'}
          : {'ok': false, 'msg': '❌ Invalid API key'});
    } catch (e) {
      setState(() => _aiResult = {'ok': false, 'msg': '❌ $e'});
    } finally {
      setState(() => _testingAi = false);
    }
  }

    widget.onConnect(
      url: _urlC.text.trim().replaceAll(RegExp(r'/$'), ''),
      key: _keyC.text.trim(),
      aiKey: _aiKeyC.text.trim(),
      rapidApiKey: _rapidC.text.trim().isNotEmpty ? _rapidC.text.trim() : null,
    );
  }

  @override
  void dispose() {
    _urlC.dispose();
    _keyC.dispose();
    _aiKeyC.dispose();
    _rapidC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ApexColors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(color: ApexColors.accent, borderRadius: BorderRadius.circular(13)),
                      child: const Center(child: Text('⚡', style: TextStyle(fontSize: 23))),
                    ),
                    const SizedBox(width: 10),
                    Text('APEX AI', style: GoogleFonts.inter(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: 2, color: ApexColors.t1)),
                  ],
                ),
                const SizedBox(height: 6),
                Text('AI-Powered Fitness Coach', style: GoogleFonts.inter(fontSize: 12, color: ApexColors.t2)),
                const SizedBox(height: 24),
                ApexCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _step(1, 'Create free Supabase project', [
                        GestureDetector(
                          onTap: () {},
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: ApexColors.surface,
                              border: Border.all(color: ApexColors.border, style: BorderStyle.solid),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(child: Text('→ supabase.com (free)', style: TextStyle(color: ApexColors.blue, fontSize: 12))),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text('⚠️ Free projects pause after 1 week — Resume at supabase.com if needed',
                            style: GoogleFonts.inter(fontSize: 10, color: ApexColors.yellow, height: 1.5)),
                      ]),
                      _step(2, 'Run SQL schema', [
                        GestureDetector(
                          onTap: () => setState(() => _showSql = !_showSql),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: ApexColors.surface, border: Border.all(color: ApexColors.border), borderRadius: BorderRadius.circular(8)),
                            child: Row(children: [
                              Text(_showSql ? '▾' : '▸', style: TextStyle(color: ApexColors.t2, fontSize: 11)),
                              const SizedBox(width: 6),
                              Expanded(child: Text('Show SQL → paste into Supabase SQL Editor → Run', style: TextStyle(color: ApexColors.t2, fontSize: 11))),
                            ]),
                          ),
                        ),
                        if (_showSql) ...[
                          const SizedBox(height: 7),
                          Stack(
                            children: [
                              Container(
                                constraints: const BoxConstraints(maxHeight: 140),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: ApexColors.surface, border: Border.all(color: ApexColors.border), borderRadius: BorderRadius.circular(8)),
                                child: SingleChildScrollView(
                                  child: Text(_sql, style: GoogleFonts.dmMono(fontSize: 9.5, color: ApexColors.t2, height: 1.5)),
                                ),
                              ),
                              Positioned(
                                top: 7, right: 7,
                                child: GestureDetector(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: _sql));
                                    setState(() => _copied = true);
                                    Future.delayed(const Duration(seconds: 2), () {
                                      if (mounted) setState(() => _copied = false);
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                                    decoration: BoxDecoration(color: _copied ? ApexColors.accent : ApexColors.card, border: Border.all(color: ApexColors.border), borderRadius: BorderRadius.circular(6)),
                                    child: Text(_copied ? '✓' : 'Copy', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _copied ? ApexColors.bg : ApexColors.t2)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ]),
                      _step(3, 'Supabase credentials (Settings → API)', [
                        _buildField('Project URL', _urlC, 'https://xxxxxxxx.supabase.co'),
                        const SizedBox(height: 9),
                        _buildField('Anon/Public Key', _keyC, 'eyJhbGci...', mono: true),
                        const SizedBox(height: 9),
                        _buildTestButton('🔍 Test Supabase Connection', _testingDb, _testDb, ApexColors.blue),
                        if (_dbResult != null) _resultBox(_dbResult!),
                      ]),
                      _step(4, 'Gemini API key (Free — google aistudio)', [
                        GestureDetector(
                          onTap: () {},
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(color: ApexColors.surface, border: Border.all(color: ApexColors.border), borderRadius: BorderRadius.circular(8)),
                            child: Center(child: Text('→ aistudio.google.com — 100% free', style: TextStyle(color: ApexColors.accent, fontSize: 11))),
                          ),
                        ),
                        const SizedBox(height: 7),
                        _buildField('Gemini Key', _aiKeyC, 'AIzaSy...', mono: true),
                        const SizedBox(height: 9),
                        _buildTestButton('🤖 Test Gemini AI', _testingAi, _testAi, ApexColors.purple),
                        if (_aiResult != null) _resultBox(_aiResult!),
                      ]),
                      if (_err.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(color: ApexColors.red.withAlpha(20), borderRadius: BorderRadius.circular(7)),
                          child: Text(_err, style: TextStyle(color: ApexColors.red, fontSize: 11)),
                        ),
                      ApexButton(text: 'Launch App ⚡', onPressed: _launch, full: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _step(int n, String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24, height: 24,
                decoration: const BoxDecoration(color: ApexColors.accent, shape: BoxShape.circle),
                child: Center(child: Text('$n', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: ApexColors.bg))),
              ),
              const SizedBox(width: 9),
              Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: ApexColors.t1)),
            ],
          ),
          const SizedBox(height: 11),
          ...children,
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, String hint, {bool mono = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: GoogleFonts.inter(fontSize: 11, color: ApexColors.t2, fontWeight: FontWeight.w700, letterSpacing: 0.7)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          style: (mono ? GoogleFonts.dmMono : GoogleFonts.inter)(fontSize: 13, color: ApexColors.t1),
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }

  Widget _buildTestButton(String text, bool loading, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(border: Border.all(color: color, width: 1.5), borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading) ...[
              SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: color)),
              const SizedBox(width: 7),
              Text('Testing...', style: GoogleFonts.inter(color: color, fontWeight: FontWeight.w700, fontSize: 11)),
            ] else
              Text(text, style: GoogleFonts.inter(color: color, fontWeight: FontWeight.w700, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _resultBox(Map<String, dynamic> result) {
    final ok = result['ok'] as bool;
    final color = ok ? ApexColors.accent : ApexColors.red;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        border: Border.all(color: color.withAlpha(64)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(result['msg'] as String, style: TextStyle(color: color, fontSize: 11, height: 1.5)),
    );
  }
}
