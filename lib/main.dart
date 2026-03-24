import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'constants/app_config.dart';
import 'constants/theme.dart';
import 'constants/colors.dart';
import 'repositories/auth_repository.dart';
import 'repositories/workout_repository.dart';
import 'services/supabase_service.dart';
import 'services/ai_service.dart';
import 'services/exercise_animation_service.dart';
import 'services/storage_service.dart';
import 'screens/auth_screen.dart';
import 'screens/main_shell.dart';
import 'widgets/apex_backdrop.dart';
import 'widgets/apex_orb_logo.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: ApexColors.bg,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const ApexAIApp());
}

class ApexAIApp extends StatefulWidget {
  const ApexAIApp({super.key});

  @override
  State<ApexAIApp> createState() => _ApexAIAppState();
}

enum AppState { loading, auth, home }

class _ApexAIAppState extends State<ApexAIApp> {
  AppState _state = AppState.loading;
  StreamSubscription<User?>? _authSubscription;
  bool _listeningToAuth = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      if (!AppConfig.hasSupabase) {
        throw Exception('AppConfig is missing Supabase settings.');
      }

      // Parallelize heavy initialization
      await Future.wait([
        SupabaseService.init(AppConfig.supabaseUrl, AppConfig.supabaseAnonKey),
        _initAI(),
        _initExerciseAnimations(),
      ]);

      _bindAuthState();

      final hasSession = authRepository.currentUser != null;
      if (mounted) {
        setState(() => _state = hasSession ? AppState.home : AppState.auth);
      }
      if (hasSession) {
        unawaited(workoutRepository.syncOfflineQueue());
      }
    } catch (e) {
      if (mounted) setState(() => _state = AppState.auth);
    }
  }

  void _bindAuthState() {
    if (_listeningToAuth) return;
    _listeningToAuth = true;
    _authSubscription = authRepository.sessionChanges().listen((user) {
      if (!mounted) return;

      final nextState = user == null ? AppState.auth : AppState.home;
      if (_state != nextState) {
        setState(() => _state = nextState);
      }

      if (user != null) {
        unawaited(workoutRepository.syncOfflineQueue());
      }
    });
  }

  Future<void> _initAI() async {
    final provider = await StorageService.loadAIProvider();
    if (provider == 'bedrock') {
      final aws = await StorageService.loadAWSConfig();
      if (aws != null) {
        AIService.useBedrock(modelId: aws['modelId']);
        return;
      }
    }

    // Default to Gemini
    if (AppConfig.hasGemini) {
      AIService.useGemini(AppConfig.geminiApiKey);
    }
  }

  Future<void> _initExerciseAnimations() async {
    final key = await StorageService.loadExerciseApiKey();
    ExerciseAnimationService.setApiKey(key);
  }

  void _onAuth() {
    setState(() => _state = AppState.home);
  }

  Future<void> _onSignOut() async {
    try {
      await authRepository.signOut();
    } catch (_) {}
    setState(() => _state = AppState.auth);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'APEX AI',
      debugShowCheckedModeBanner: false,
      theme: ApexTheme.dark,
      home: _buildScreen(),
    );
  }

  Widget _buildScreen() {
    switch (_state) {
      case AppState.loading:
        return Scaffold(
          backgroundColor: ApexColors.bg,
          body: ApexBackdrop(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const ApexOrbLogo(size: 82, label: 'APEX'),
                  const SizedBox(height: 18),
                  Text(
                    'APEX AI',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ApexColors.accentSoft,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Connecting to your training workspace',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        );
      case AppState.auth:
        return AuthScreen(onAuth: _onAuth);
      case AppState.home:
        return MainShell(onSignOut: _onSignOut);
    }
  }
}
