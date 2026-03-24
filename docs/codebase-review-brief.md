# APEX AI Codebase Review Brief

## What this repo is

`gym/` is a Flutter mobile app called `APEX AI`. It is a fitness coaching app with:

- Supabase auth and app data
- AI-backed workout and nutrition generation
- workout logging and active workout flows
- cardio / run tracking with maps
- Apple Health integration
- social feed, reports, progress photos, and profile management

The backend in this repo is lightweight:

- Supabase SQL migrations at the repo root and in `supabase/`
- one Supabase Edge Function at `supabase/functions/bedrock-proxy/index.ts`

## Main runtime entry points

- `lib/main.dart`
  - boots Flutter
  - initializes Supabase
  - initializes AI provider selection
  - initializes ExerciseDB animation key loading
  - routes to auth or the main shell
- `lib/screens/main_shell.dart`
  - main authenticated app container
  - bottom navigation
  - launches Home / Train / Social / Fuel / Stats
  - routes active workouts into full-screen flows
- `lib/services/supabase_service.dart`
  - main data access layer
  - auth, profiles, workouts, routines, exercise dictionary, logging, sync helpers
- `lib/services/ai_service.dart`
  - abstraction over AI providers
  - currently supports Gemini and AWS Bedrock
- `supabase/functions/bedrock-proxy/index.ts`
  - signs and forwards Bedrock requests from Supabase Edge Functions

## High-level structure

```text
lib/
  analytics_engine/      strength analytics
  constants/             app config, colors, theme
  routine_system/        routine editor and library
  screens/               main product screens
  services/              Supabase, AI, cache, health, social, animations
  widgets/               design system and reusable widgets
  workout_engine/        workout calculation helpers

supabase/
  functions/bedrock-proxy/

ios/
android/
```

## Important feature areas

### App shell and navigation

- `lib/screens/main_shell.dart`
- `lib/screens/home_screen.dart`
- `lib/screens/workout_screen.dart`
- `lib/screens/active_workout_screen.dart`
- `lib/screens/reports_screen.dart`
- `lib/screens/social_feed_screen.dart`
- `lib/screens/nutrition_screen.dart`

### Workout and exercise systems

- `lib/screens/exercise_library_screen.dart`
- `lib/screens/exercise_detail_screen.dart`
- `lib/screens/workout_programs_screen.dart`
- `lib/routine_system/routine_editor_screen.dart`
- `lib/routine_system/routine_library_screen.dart`
- `lib/workout_engine/plate_calculator.dart`

### AI and personalization

- `lib/services/ai_service.dart`
- `lib/services/ai/ai_provider.dart`
- `lib/services/ai/gemini_provider.dart`
- `lib/services/ai/bedrock_provider.dart`
- `lib/services/plan_generator_service.dart`
- `supabase/functions/bedrock-proxy/index.ts`

### Health, cardio, and media

- `lib/services/health_service.dart`
- `lib/screens/cardio_map_screen.dart`
- `lib/screens/circuit_player_screen.dart`
- `lib/widgets/profile_modal.dart`
- `lib/services/exercise_animation_service.dart`

## Tech stack

- Flutter / Dart
- Supabase
- shared_preferences for local persistence
- Google Maps Flutter
- geolocator
- Health / HealthKit
- Gemini SDK
- AWS Bedrock through a Supabase Edge Function proxy

## Current configuration behavior

- `lib/constants/app_config.dart` contains app config values and API-related defaults.
- AI provider selection is stored locally with `StorageService`.
- Exercise animations use `ExerciseAnimationService`.
  - with a RapidAPI ExerciseDB key: animated GIFs
  - without a key: static `wger.de` fallback images

## Review priorities

Ask the reviewing AI to focus on:

1. Architecture and state management consistency
2. Data integrity across Supabase reads/writes
3. Offline sync behavior and failure recovery
4. Auth/session restore correctness
5. iOS/Android platform integration risks
6. AI provider abstraction and prompt/JSON parsing robustness
7. Security concerns
   - hardcoded config or secrets
   - client-side API exposure
   - trust boundaries between app and backend
8. Code quality in screens that have grown large
9. Migration compatibility between current Dart code and Supabase SQL schema

## Current repo state

The worktree is dirty. Important because a reviewer should look at both modified and untracked files.

Modified files include:

- `ios/Podfile`
- `ios/Podfile.lock`
- `ios/Runner.xcodeproj/project.pbxproj`
- `lib/main.dart`
- `lib/screens/active_workout_screen.dart`
- `lib/screens/cardio_map_screen.dart`
- `lib/screens/exercise_detail_screen.dart`
- `lib/screens/exercise_library_screen.dart`
- `lib/screens/home_screen.dart`
- `lib/screens/main_shell.dart`
- `lib/screens/setup_screen.dart`
- `lib/screens/social_feed_screen.dart`
- `lib/screens/workout_screen.dart`
- `lib/services/ai_service.dart`
- `lib/services/storage_service.dart`
- `lib/services/supabase_service.dart`
- `lib/widgets/profile_modal.dart`
- `pubspec.yaml`
- `pubspec.lock`

Untracked files/directories include:

- `lib/analytics_engine/`
- `lib/routine_system/`
- `lib/screens/workout_programs_screen.dart`
- `lib/services/achievement_service.dart`
- `lib/services/adaptive_logic.dart`
- `lib/services/ai/`
- `lib/services/exercise_animation_service.dart`
- `lib/widgets/achievement_badges.dart`
- `lib/workout_engine/`
- `supabase/`
- several SQL migration files at repo root

## Important local-only note

There is local iOS build context that is not fully represented by repo files alone:

- `ios/Podfile` was adjusted to remove global `use_frameworks!`
- a local patch was applied in the developer machine's pub cache to the `health` plugin Objective-C shim so it can import its generated Swift header without framework mode

If another AI is reviewing only the git-tracked repo, it will not see the pub-cache patch.

## Paste-ready prompt for another AI

```text
Review this Flutter codebase as a senior mobile engineer. Focus on bugs, regressions, platform integration risk, Supabase schema mismatches, offline sync correctness, AI provider abstraction, and security issues. Prioritize findings over summary.

Project summary:
- Flutter app named APEX AI
- Fitness coaching product with auth, workout generation, workout logging, reports, nutrition, social feed, cardio tracking, and Apple Health integration
- Supabase is the main backend
- AI abstraction supports Gemini and AWS Bedrock
- Bedrock access is proxied via a Supabase Edge Function in supabase/functions/bedrock-proxy/index.ts
- Exercise animations are provided by ExerciseDB via RapidAPI when a key exists, otherwise it falls back to wger static images

Start with these files:
- lib/main.dart
- lib/screens/main_shell.dart
- lib/services/supabase_service.dart
- lib/services/ai_service.dart
- lib/widgets/profile_modal.dart
- lib/screens/active_workout_screen.dart
- lib/screens/workout_screen.dart
- lib/screens/reports_screen.dart
- lib/services/exercise_animation_service.dart
- supabase/functions/bedrock-proxy/index.ts

Extra context:
- The worktree is dirty with many modified and untracked files, including new analytics, routine-system, achievement, adaptive logic, AI provider, and exercise animation modules
- iOS build behavior also depends on a local pub-cache patch to the health plugin that is not committed in the repo

Return:
1. Findings ordered by severity
2. File references for each finding
3. Open questions / assumptions
4. A short architecture-risk summary only after findings
```
