import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/safe_haptics.dart';
import 'package:image_picker/image_picker.dart';
import '../services/supabase_service.dart';
import '../widgets/apex_button.dart';
import '../widgets/apex_orb_logo.dart';
import '../services/exercise_animation_service.dart';
import '../services/storage_service.dart';

@Deprecated('Use ProfileScreen instead.')
class ProfileModal extends StatelessWidget {
  final Map<String, dynamic>? profile;
  final VoidCallback onSignOut;
  final VoidCallback onSaved;

  const ProfileModal({
    super.key,
    this.profile,
    required this.onSignOut,
    required this.onSaved,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileScreen(
      profile: profile,
      onSignOut: onSignOut,
      onSaved: onSaved,
    );
  }
}

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? profile;
  final VoidCallback onSignOut;
  final VoidCallback onSaved;

  const ProfileScreen({
    super.key,
    this.profile,
    required this.onSignOut,
    required this.onSaved,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameC;
  late TextEditingController _weightC;
  late TextEditingController _heightC;
  late TextEditingController _calGoalC;
  late TextEditingController _waterGoalC;
  late String _goal;
  String? _avatarData;
  bool _loading = false;
  bool _saved = false;

  late String _aiProvider;
  late TextEditingController _awsModelC;
  late TextEditingController _exerciseApiKeyC;
  bool _showExerciseApiKey = false;

  static const _goals = [
    'Build Muscle',
    'Lose Fat',
    'Calisthenics Skills',
    'Strength & Power',
    'General Fitness',
  ];

  @override
  void initState() {
    super.initState();
    _nameC = TextEditingController(
      text: widget.profile?['name']?.toString() ?? '',
    );
    _weightC = TextEditingController(
      text: widget.profile?['weight_kg']?.toString() ?? '',
    );
    _heightC = TextEditingController(
      text: widget.profile?['height_cm']?.toString() ?? '',
    );
    _calGoalC = TextEditingController(
      text: (widget.profile?['calorie_goal'] ?? 2000).toString(),
    );
    _waterGoalC = TextEditingController(
      text: (widget.profile?['water_goal_ml'] ?? 2500).toString(),
    );
    _goal = widget.profile?['goal']?.toString() ?? 'Build Muscle';
    _avatarData = widget.profile?['avatar_data']?.toString();
    _aiProvider = 'bedrock';
    _awsModelC = TextEditingController(
      text: 'anthropic.claude-3-haiku-20240307-v1:0',
    );
    _exerciseApiKeyC = TextEditingController();

    _nameC.addListener(_handlePreviewChange);
    _weightC.addListener(_handlePreviewChange);
    _heightC.addListener(_handlePreviewChange);

    _initAI();
  }

  Future<void> _initAI() async {
    final provider = await StorageService.loadAIProvider();
    final aws = await StorageService.loadAWSConfig();
    final exerciseApiKey = await StorageService.loadExerciseApiKey();
    if (mounted) {
      setState(() {
        _aiProvider = provider;
        if (aws?['modelId'] != null) _awsModelC.text = aws!['modelId'];
        _exerciseApiKeyC.text = exerciseApiKey;
      });
    }
  }

  void _handlePreviewChange() => setState(() {});

  Future<void> _showAvatarOptions() async {
    SafeHaptics.vibrate(HapticsType.light);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ApexButton(
              text: 'Camera',
              icon: Icons.camera_alt_outlined,
              onPressed: () => _pickAvatar(ImageSource.camera, ctx),
              full: true,
            ),
            const SizedBox(height: 12),
            ApexButton(
              text: 'Gallery',
              icon: Icons.photo_library_outlined,
              onPressed: () => _pickAvatar(ImageSource.gallery, ctx),
              full: true,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAvatar(ImageSource source, BuildContext ctx) async {
    Navigator.pop(ctx);
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(
      () => _avatarData = 'data:image/jpeg;base64,${base64Encode(bytes)}',
    );
    await _save();
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      final data = {
        'name': _nameC.text,
        'goal': _goal,
        'calorie_goal': int.tryParse(_calGoalC.text) ?? 2000,
        'water_goal_ml': int.tryParse(_waterGoalC.text) ?? 2500,
        'avatar_data': _avatarData,
        'weight_kg': double.tryParse(_weightC.text),
        'height_cm': double.tryParse(_heightC.text),
      };
      await SupabaseService.updateProfile(
        SupabaseService.currentUser!.id,
        data,
      );
      await StorageService.saveAIProvider(_aiProvider);
      await StorageService.saveAWSConfig(
        accessKey: '',
        secretKey: '',
        region: 'us-east-1',
        modelId: _awsModelC.text,
      );
      await StorageService.saveExerciseApiKey(_exerciseApiKeyC.text);
      ExerciseAnimationService.setApiKey(_exerciseApiKeyC.text);
      setState(() => _saved = true);
      widget.onSaved();
    } catch (_) {}
    setState(() => _loading = false);
  }

  void _signOut() => widget.onSignOut();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ProfilePalette.base,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 12),
                  Text('Profile', style: _ProfileText.pageTitle),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Center(
                    child: ApexOrbLogo(
                      size: 116,
                      label: _nameC.text,
                      imageData: _avatarData,
                      onTap: _showAvatarOptions,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Personal Details', style: _ProfileText.sectionTitle),
                  const SizedBox(height: 12),
                  _surfacePanel(
                    child: Column(
                      children: [
                        _field('Name', _nameC, 'Name'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _field(
                                'Weight',
                                _weightC,
                                'kg',
                                number: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _field(
                                'Height',
                                _heightC,
                                'cm',
                                number: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Goals', style: _ProfileText.sectionTitle),
                  const SizedBox(height: 12),
                  _surfacePanel(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _goals
                          .map(
                            (g) => ChoiceChip(
                              label: Text(g),
                              selected: _goal == g,
                              onSelected: (s) => setState(() => _goal = g),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Exercise Animations', style: _ProfileText.sectionTitle),
                  const SizedBox(height: 12),
                  _surfacePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ExerciseDB RapidAPI Key',
                          style: _ProfileText.label,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _exerciseApiKeyC,
                          obscureText: !_showExerciseApiKey,
                          autocorrect: false,
                          enableSuggestions: false,
                          keyboardType: TextInputType.visiblePassword,
                          decoration: InputDecoration(
                            hintText: 'Paste your RapidAPI key',
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(
                                  () => _showExerciseApiKey =
                                      !_showExerciseApiKey,
                                );
                              },
                              icon: Icon(
                                _showExerciseApiKey
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Leave blank to keep the free static image fallback. Add your own key to unlock animated ExerciseDB demos.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ApexButton(
                    text: 'Sign out',
                    onPressed: _signOut,
                    tone: ApexButtonTone.soft,
                    color: Colors.red,
                    full: true,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: ApexButton(
                text: _saved ? 'Saved' : 'Save',
                onPressed: _save,
                full: true,
                loading: _loading,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _surfacePanel({required Widget child}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: child,
  );

  Widget _field(
    String label,
    TextEditingController c,
    String hint, {
    bool number = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: _ProfileText.label),
      TextField(
        controller: c,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(hintText: hint),
      ),
    ],
  );

  @override
  void dispose() {
    _nameC.dispose();
    _weightC.dispose();
    _heightC.dispose();
    _calGoalC.dispose();
    _waterGoalC.dispose();
    _awsModelC.dispose();
    _exerciseApiKeyC.dispose();
    super.dispose();
  }
}

class _ProfilePalette {
  static const Color base = Color(0xFFF7F7F4);
}

class _ProfileText {
  static final TextStyle pageTitle = GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );
  static final TextStyle sectionTitle = GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );
  static final TextStyle label = GoogleFonts.inter(
    fontSize: 12,
    color: Colors.grey,
  );
}
