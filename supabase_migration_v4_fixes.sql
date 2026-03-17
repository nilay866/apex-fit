-- APEX FIT v4: SCHEMA REPAIR & FIXES
-- Safe to run multiple times. Run this in the Supabase SQL Editor.

BEGIN;

-- =========================================================================
-- 1. RESOLVE THE 'exercises' TABLE NAMING CONFLICT
-- =========================================================================

-- The V2 schema incorrectly named the global catalog 'exercises', clashing with
-- the V1 user-specific workout logger table. We need to rename the global catalog
-- back to 'exercise_dictionary' (which the app code expects) and recreate the V1 table.

DO $$ 
BEGIN
  -- If the V2 global catalog "exercises" exists (identified by having 'primary_muscle')
  -- We rename it to 'exercise_dictionary'. PostgreSQL automatically updates FKs.
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'exercises' 
      AND column_name = 'primary_muscle'
  ) THEN
    ALTER TABLE public.exercises RENAME TO exercise_dictionary;
  END IF;
END $$;

-- Now recreate the V1 'exercises' table for user-specific custom workouts.
-- If it already exists natively (e.g. from V1), this won't break anything.
CREATE TABLE IF NOT EXISTS public.exercises (
  id uuid default gen_random_uuid() primary key,
  workout_id uuid references public.workouts on delete cascade,
  name text not null,
  sets int default 3,
  reps text default '8-12',
  target_weight numeric
);

-- Secure the reconstructed V1 exercises table
ALTER TABLE public.exercises ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "own_exercises" ON public.exercises;
CREATE POLICY "own_exercises" ON public.exercises FOR ALL USING (
  auth.uid() = (select user_id from public.workouts where id = workout_id)
) WITH CHECK (
  auth.uid() = (select user_id from public.workouts where id = workout_id)
);

-- =========================================================================
-- 2. FIX 'workout_streaks' PRIMARY KEY FOR HISTORICAL TRACKING
-- =========================================================================

-- In V3, user_id was the PK. To allow multiple streak rows (e.g., historical tracking),
-- we change the PK to an auto-generated UUID while keeping user_id as a foreign key.

DO $$
DECLARE
  con_name text;
BEGIN
  -- Check if `user_id` is the solitary Primary Key for workout_streaks
  SELECT constraint_name INTO con_name
  FROM information_schema.table_constraints
  WHERE table_schema = 'public'
    AND table_name = 'workout_streaks'
    AND constraint_type = 'PRIMARY KEY';

  IF con_name IS NOT NULL THEN
    -- Verify the PK is 'user_id' and not 'id'
    IF EXISTS (
      SELECT 1 FROM information_schema.key_column_usage
      WHERE constraint_name = con_name AND column_name = 'user_id'
    ) AND NOT EXISTS (
      SELECT 1 FROM information_schema.key_column_usage
      WHERE constraint_name = con_name AND column_name = 'id'
    ) THEN
      -- Drop the old PK constraint
      EXECUTE 'ALTER TABLE public.workout_streaks DROP CONSTRAINT ' || con_name;
      -- Add a new UUID primary key column
      ALTER TABLE public.workout_streaks ADD COLUMN id uuid DEFAULT gen_random_uuid() PRIMARY KEY;
    END IF;
  END IF;
END $$;

COMMIT;
