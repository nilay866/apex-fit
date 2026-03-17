-- ═══════════════════════════════════════════════════
-- APEX AI — Migration V5: New Features (Additive Only)
-- All changes are safe for existing data (nullable columns)
-- ═══════════════════════════════════════════════════

-- 1. AI Coach Memory on profiles
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS ai_coach_memory JSONB DEFAULT '{}';

-- 2. Mood tracking on profiles  
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS today_mood INT DEFAULT 3;
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS mood_updated_at DATE;

-- 3. AI summary on workout_logs
ALTER TABLE workout_logs
  ADD COLUMN IF NOT EXISTS ai_summary TEXT;

-- 4. AI Coach Sessions table
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

ALTER TABLE ai_coach_sessions ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'ai_coach_sessions'
    AND policyname = 'Users own their coach sessions'
  ) THEN
    CREATE POLICY "Users own their coach sessions"
      ON ai_coach_sessions FOR ALL
      USING (auth.uid() = user_id);
  END IF;
END $$;
