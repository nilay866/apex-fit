-- ═══════════════════════════════════════════════════════════════
-- APEX AI — Migration V6: Activities, GPS, Health Metrics
-- Run in Supabase SQL Editor
-- ═══════════════════════════════════════════════════════════════

-- Activities table (GPS-tracked sessions: run, walk, cycle, hike)
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

-- GPS breadcrumb trail
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

-- Health metrics daily persistence
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

-- Training load tracking (weekly aggregates)
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

-- Water intake tracking
CREATE TABLE IF NOT EXISTS water_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  amount_ml INTEGER NOT NULL DEFAULT 250,
  logged_at TIMESTAMPTZ DEFAULT now()
);

-- RLS Policies
ALTER TABLE activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE gps_points ENABLE ROW LEVEL SECURITY;
ALTER TABLE health_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE training_load ENABLE ROW LEVEL SECURITY;
ALTER TABLE water_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY activities_user ON activities FOR ALL USING (auth.uid() = user_id);
CREATE POLICY gps_points_user ON gps_points FOR ALL
  USING (activity_id IN (SELECT id FROM activities WHERE user_id = auth.uid()));
CREATE POLICY health_metrics_user ON health_metrics FOR ALL USING (auth.uid() = user_id);
CREATE POLICY training_load_user ON training_load FOR ALL USING (auth.uid() = user_id);
CREATE POLICY water_logs_user ON water_logs FOR ALL USING (auth.uid() = user_id);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_activities_user ON activities(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_activities_type ON activities(user_id, type);
CREATE INDEX IF NOT EXISTS idx_gps_points_activity ON gps_points(activity_id, recorded_at);
CREATE INDEX IF NOT EXISTS idx_health_metrics_user ON health_metrics(user_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_training_load_user ON training_load(user_id, week_start DESC);
CREATE INDEX IF NOT EXISTS idx_water_logs_user ON water_logs(user_id, logged_at DESC);

-- Add nullable columns to existing profiles for extended tracking
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS vo2_max DOUBLE PRECISION;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS ftp_watts INTEGER;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS max_hr INTEGER;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS resting_hr_baseline INTEGER;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS daily_step_goal INTEGER DEFAULT 10000;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS daily_water_goal_ml INTEGER DEFAULT 2500;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS daily_calorie_goal INTEGER;
