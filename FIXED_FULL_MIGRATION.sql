-- ═══════════════════════════════════════════════════════════════
-- APEX FIT: FULL CONSOLIDATED MIGRATION (V1 - V6)
-- Cleaned, Fixed, and Safe to Run Multiple Times.
-- ═══════════════════════════════════════════════════════════════

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ==========================================
-- 0. PRE-FLIGHT REPAIR (Resolve Naming Conflicts)
-- ==========================================

DO $$ 
BEGIN
  -- If "exercises" table has "primary_muscle", it's the old global catalog.
  -- Rename it so we can use "exercises" for user-specific data.
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'exercises' 
      AND column_name = 'primary_muscle'
  ) THEN
    ALTER TABLE public.exercises RENAME TO exercise_dictionary;
  END IF;
END $$;

-- ==========================================
-- 1. CORE TABLES (V1)
-- ==========================================

CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
  name TEXT,
  avatar_data TEXT,
  weight_kg NUMERIC,
  height_cm NUMERIC,
  goal TEXT DEFAULT 'Build Muscle',
  calorie_goal INT DEFAULT 2000,
  water_goal_ml INT DEFAULT 2500,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.workouts (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users ON DELETE CASCADE,
  name TEXT NOT NULL,
  type TEXT DEFAULT 'Gym',
  created_at TIMESTAMPTZ DEFAULT now()
);

-- This is the table the app uses for logging workout data
CREATE TABLE IF NOT EXISTS public.exercises (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  workout_id UUID REFERENCES public.workouts ON DELETE CASCADE,
  name TEXT NOT NULL,
  sets INT DEFAULT 3,
  reps TEXT DEFAULT '8-12',
  target_weight NUMERIC
);

CREATE TABLE IF NOT EXISTS public.workout_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users ON DELETE CASCADE,
  workout_name TEXT,
  duration_min INT,
  total_volume NUMERIC DEFAULT 0,
  intensity TEXT DEFAULT 'moderate',
  notes TEXT,
  completed_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.set_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  log_id UUID REFERENCES public.workout_logs ON DELETE CASCADE,
  exercise_name TEXT,
  set_number INT,
  reps_done INT,
  weight_kg NUMERIC,
  logged_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.nutrition_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users ON DELETE CASCADE,
  meal_name TEXT NOT NULL,
  quantity TEXT,
  photo_data TEXT,
  calories INT DEFAULT 0,
  protein_g NUMERIC DEFAULT 0,
  carbs_g NUMERIC DEFAULT 0,
  fat_g NUMERIC DEFAULT 0,
  logged_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.body_weight_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users ON DELETE CASCADE,
  weight_kg NUMERIC NOT NULL,
  logged_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.water_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users ON DELETE CASCADE,
  amount_ml INT NOT NULL,
  logged_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.progress_photos (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users ON DELETE CASCADE,
  photo_data TEXT NOT NULL,
  caption TEXT,
  taken_at TIMESTAMPTZ DEFAULT now()
);

-- ==========================================
-- 2. SCHEMA EXPANSION (V3)
-- ==========================================

CREATE TABLE IF NOT EXISTS public.personal_records (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users ON DELETE CASCADE,
  exercise_name TEXT NOT NULL,
  record_type TEXT NOT NULL, -- 'max_weight', 'best_volume', 'best_1rm'
  weight NUMERIC,
  reps INT,
  estimated_1rm NUMERIC,
  date TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.exercise_1rm (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users ON DELETE CASCADE,
  exercise_name TEXT NOT NULL,
  estimated_1rm NUMERIC NOT NULL,
  weight NUMERIC,
  reps INT,
  date TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.routine_templates (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  folder TEXT DEFAULT 'General',
  is_public BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.routine_exercises (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  routine_id UUID REFERENCES public.routine_templates ON DELETE CASCADE,
  exercise_name TEXT NOT NULL,
  sets INT DEFAULT 3,
  reps TEXT DEFAULT '8-12',
  rest_seconds INT DEFAULT 90,
  sort_order INT DEFAULT 0
);

CREATE TABLE IF NOT EXISTS public.workout_streaks (
  user_id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
  current_streak INT DEFAULT 0,
  longest_streak INT DEFAULT 0,
  last_workout_date DATE
);

CREATE TABLE IF NOT EXISTS public.friends (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users ON DELETE CASCADE,
  friend_id UUID REFERENCES auth.users ON DELETE CASCADE,
  status TEXT DEFAULT 'pending', -- 'pending', 'accepted'
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, friend_id)
);

CREATE TABLE IF NOT EXISTS public.workout_posts (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users ON DELETE CASCADE,
  workout_log_id UUID REFERENCES public.workout_logs ON DELETE SET NULL,
  caption TEXT,
  likes INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ==========================================
-- 3. MODERN FEATURES (V5 & V6)
-- ==========================================

CREATE TABLE IF NOT EXISTS ai_coach_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  started_at TIMESTAMPTZ DEFAULT NOW(),
  messages JSONB DEFAULT '[]',
  summary TEXT,
  key_facts JSONB DEFAULT '{}',
  provider_used TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS activities (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  type TEXT NOT NULL DEFAULT 'run',
  distance_km DOUBLE PRECISION DEFAULT 0,
  duration_seconds INTEGER DEFAULT 0,
  calories DOUBLE PRECISION DEFAULT 0,
  elevation_gain DOUBLE PRECISION DEFAULT 0,
  elevation_loss DOUBLE PRECISION DEFAULT 0,
  avg_pace DOUBLE PRECISION DEFAULT 0,
  avg_speed DOUBLE PRECISION DEFAULT 0,
  max_speed DOUBLE PRECISION DEFAULT 0,
  avg_heart_rate INTEGER,
  max_heart_rate INTEGER,
  avg_cadence INTEGER,
  splits JSONB DEFAULT '[]',
  weather JSONB,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS gps_points (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  activity_id UUID REFERENCES activities(id) ON DELETE CASCADE NOT NULL,
  lat DOUBLE PRECISION NOT NULL,
  lng DOUBLE PRECISION NOT NULL,
  elevation DOUBLE PRECISION,
  speed DOUBLE PRECISION,
  heart_rate INTEGER,
  cadence INTEGER,
  recorded_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS health_metrics (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  heart_rate INTEGER,
  resting_hr INTEGER,
  steps INTEGER DEFAULT 0,
  sleep_hours DOUBLE PRECISION,
  hrv_ms DOUBLE PRECISION,
  spo2 DOUBLE PRECISION,
  active_calories DOUBLE PRECISION DEFAULT 0,
  floors_climbed INTEGER DEFAULT 0,
  weight_kg DOUBLE PRECISION,
  body_fat_pct DOUBLE PRECISION,
  stress_level INTEGER,
  recorded_at DATE DEFAULT CURRENT_DATE,
  UNIQUE(user_id, recorded_at)
);

CREATE TABLE IF NOT EXISTS training_load (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  week_start DATE NOT NULL,
  total_volume DOUBLE PRECISION DEFAULT 0,
  total_duration_min INTEGER DEFAULT 0,
  total_distance_km DOUBLE PRECISION DEFAULT 0,
  total_calories DOUBLE PRECISION DEFAULT 0,
  session_count INTEGER DEFAULT 0,
  training_stress DOUBLE PRECISION DEFAULT 0,
  fitness_score DOUBLE PRECISION DEFAULT 0,
  fatigue_score DOUBLE PRECISION DEFAULT 0,
  form_score DOUBLE PRECISION DEFAULT 0,
  UNIQUE(user_id, week_start)
);

-- ==========================================
-- 4. COLUMN PATCHES & REPAIR
-- ==========================================

-- Backfill profile columns
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS name TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS avatar_data TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS weight_kg NUMERIC;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS height_cm NUMERIC;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS goal TEXT DEFAULT 'Build Muscle';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS calorie_goal INT DEFAULT 2000;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS water_goal_ml INT DEFAULT 2500;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS ai_coach_memory JSONB DEFAULT '{}';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS today_mood INT DEFAULT 3;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS mood_updated_at DATE;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS vo2_max DOUBLE PRECISION;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS ftp_watts INTEGER;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS max_hr INTEGER;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS resting_hr_baseline INTEGER;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS daily_step_goal INTEGER DEFAULT 10000;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS daily_water_goal_ml INTEGER DEFAULT 2500;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS daily_calorie_goal INTEGER;

-- Backfill exercise columns
ALTER TABLE public.exercises ADD COLUMN IF NOT EXISTS sets INT DEFAULT 3;
ALTER TABLE public.exercises ADD COLUMN IF NOT EXISTS reps TEXT DEFAULT '8-12';
ALTER TABLE public.exercises ADD COLUMN IF NOT EXISTS target_weight NUMERIC;

-- Backfill log columns
ALTER TABLE public.workout_logs ADD COLUMN IF NOT EXISTS ai_summary TEXT;

-- Fix workout_streaks primary key (Migration V4)
DO $$
DECLARE
  con_name text;
BEGIN
  SELECT constraint_name INTO con_name
  FROM information_schema.table_constraints
  WHERE table_schema = 'public' AND table_name = 'workout_streaks' AND constraint_type = 'PRIMARY KEY';
  IF con_name IS NOT NULL THEN
    IF EXISTS (
      SELECT 1 FROM information_schema.key_column_usage
      WHERE constraint_name = con_name AND column_name = 'user_id'
    ) AND NOT EXISTS (
      SELECT 1 FROM information_schema.key_column_usage
      WHERE constraint_name = con_name AND column_name = 'id'
    ) THEN
      EXECUTE 'ALTER TABLE public.workout_streaks DROP CONSTRAINT ' || con_name;
      ALTER TABLE public.workout_streaks ADD COLUMN id uuid DEFAULT gen_random_uuid() PRIMARY KEY;
    END IF;
  END IF;
END $$;

-- ==========================================
-- 5. RLS & POLICIES (FIXED SYNTAX)
-- ==========================================

-- Policy creation helper
DO $$
BEGIN
  -- Enable RLS
  ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
  ALTER TABLE public.workouts ENABLE ROW LEVEL SECURITY;
  ALTER TABLE public.exercises ENABLE ROW LEVEL SECURITY;
  ALTER TABLE public.workout_logs ENABLE ROW LEVEL SECURITY;
  ALTER TABLE public.set_logs ENABLE ROW LEVEL SECURITY;
  ALTER TABLE public.nutrition_logs ENABLE ROW LEVEL SECURITY;
  ALTER TABLE public.body_weight_logs ENABLE ROW LEVEL SECURITY;
  ALTER TABLE public.water_logs ENABLE ROW LEVEL SECURITY;
  ALTER TABLE public.progress_photos ENABLE ROW LEVEL SECURITY;
  ALTER TABLE public.personal_records ENABLE ROW LEVEL SECURITY;
  ALTER TABLE public.exercise_1rm ENABLE ROW LEVEL SECURITY;
  ALTER TABLE public.routine_templates ENABLE ROW LEVEL SECURITY;
  ALTER TABLE public.routine_exercises ENABLE ROW LEVEL SECURITY;
  ALTER TABLE public.friends ENABLE ROW LEVEL SECURITY;
  ALTER TABLE public.workout_posts ENABLE ROW LEVEL SECURITY;
  ALTER TABLE ai_coach_sessions ENABLE ROW LEVEL SECURITY;
  ALTER TABLE activities ENABLE ROW LEVEL SECURITY;
  ALTER TABLE gps_points ENABLE ROW LEVEL SECURITY;
  ALTER TABLE health_metrics ENABLE ROW LEVEL SECURITY;
  ALTER TABLE training_load ENABLE ROW LEVEL SECURITY;

  -- Profiles
  DROP POLICY IF EXISTS "own_profile" ON public.profiles;
  CREATE POLICY "own_profile" ON public.profiles FOR ALL USING (auth.uid() = id);

  -- Workouts
  DROP POLICY IF EXISTS "own_workouts" ON public.workouts;
  CREATE POLICY "own_workouts" ON public.workouts FOR ALL USING (auth.uid() = user_id);

  -- Exercises
  DROP POLICY IF EXISTS "own_exercises" ON public.exercises;
  CREATE POLICY "own_exercises" ON public.exercises FOR ALL USING (auth.uid() = (SELECT user_id FROM public.workouts WHERE id = workout_id));

  -- Logs
  DROP POLICY IF EXISTS "own_logs" ON public.workout_logs;
  CREATE POLICY "own_logs" ON public.workout_logs FOR ALL USING (auth.uid() = user_id);

  DROP POLICY IF EXISTS "own_set_logs" ON public.set_logs;
  CREATE POLICY "own_set_logs" ON public.set_logs FOR ALL USING (auth.uid() = (SELECT user_id FROM public.workout_logs WHERE id = log_id));

  -- PRs & Stats
  DROP POLICY IF EXISTS "own_prs" ON public.personal_records;
  CREATE POLICY "own_prs" ON public.personal_records FOR ALL USING (auth.uid() = user_id);

  DROP POLICY IF EXISTS "own_1rm" ON public.exercise_1rm;
  CREATE POLICY "own_1rm" ON public.exercise_1rm FOR ALL USING (auth.uid() = user_id);

  -- Routines
  DROP POLICY IF EXISTS "own_routines" ON public.routine_templates;
  CREATE POLICY "own_routines" ON public.routine_templates FOR ALL USING (auth.uid() = user_id OR is_public = true);

  -- Activities
  DROP POLICY IF EXISTS activities_user ON activities;
  CREATE POLICY activities_user ON activities FOR ALL USING (auth.uid() = user_id);

  DROP POLICY IF EXISTS gps_points_user ON gps_points;
  CREATE POLICY gps_points_user ON gps_points FOR ALL USING (activity_id IN (SELECT id FROM activities WHERE user_id = auth.uid()));

  -- Others
  DROP POLICY IF EXISTS "own_nutrition" ON public.nutrition_logs;
  CREATE POLICY "own_nutrition" ON public.nutrition_logs FOR ALL USING (auth.uid() = user_id);

  DROP POLICY IF EXISTS "own_water" ON public.water_logs;
  CREATE POLICY "own_water" ON public.water_logs FOR ALL USING (auth.uid() = user_id);
END $$;

-- ==========================================
-- 6. TRIGGERS & FINAL SETUP
-- ==========================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, name)
  VALUES (new.id, COALESCE(new.raw_user_meta_data->>'name', new.email))
  ON CONFLICT (id) DO NOTHING;
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

COMMIT;
