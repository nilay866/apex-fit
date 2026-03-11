import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'constants/app_config.dart';
import 'constants/theme.dart';
import 'constants/colors.dart';
import 'services/supabase_service.dart';
import 'services/ai_service.dart';
import 'screens/auth_screen.dart';
import 'screens/main_shell.dart';
import 'widgets/apex_backdrop.dart';
import 'widgets/apex_orb_logo.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: ApexColors.bg,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
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
        if (AppConfig.hasGemini) Future.microtask(() => AIService.init(AppConfig.geminiApiKey)),
      ]);

      if (SupabaseService.currentUser != null) {
        setState(() => _state = AppState.home);
        // Decentralized fire-and-forget sync
        unawaited(SupabaseService.syncOfflineWorkouts());
      } else {
        setState(() => _state = AppState.auth);
      }
    } catch (e) {
      if (mounted) setState(() => _state = AppState.auth);
    }
  }

  void _onAuth() {
    setState(() => _state = AppState.home);
  }

  Future<void> _onSignOut() async {
    try {
      await SupabaseService.signOut();
    } catch (_) {}
    setState(() => _state = AppState.auth);
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
