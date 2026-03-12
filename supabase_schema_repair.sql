-- APEX FIT: SCHEMA REPAIR & FORCE SYNC
-- Run this if you get "column does not exist" errors.
-- WARNING: This will drop existing exercise and program data to ensure a fresh, normalized schema.

-- 1. DROP EXISTING TO RESOLVE CONFLICTS
DROP TABLE IF EXISTS user_program_enrollments CASCADE;
DROP TABLE IF EXISTS workout_program_exercises CASCADE;
DROP TABLE IF EXISTS workout_program_sessions CASCADE;
DROP TABLE IF EXISTS workout_programs CASCADE;
DROP TABLE IF EXISTS muscle_heatmap CASCADE;
DROP TABLE IF EXISTS exercises CASCADE;

-- 2. RECREATE NORMALIZED SCHEMA
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE exercises (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    category TEXT CHECK (category IN ('strength', 'cardio', 'circuit')),
    primary_muscle TEXT,
    secondary_muscle TEXT,
    equipment TEXT,
    difficulty TEXT CHECK (difficulty IN ('beginner', 'intermediate', 'advanced')),
    taxonomy_folder TEXT,
    environment TEXT,
    video_url TEXT,
    instructions JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE muscle_heatmap (
    exercise_id UUID REFERENCES exercises(id) ON DELETE CASCADE,
    muscle TEXT NOT NULL,
    intensity INT CHECK (intensity >= 1 AND intensity <= 5),
    PRIMARY KEY (exercise_id, muscle)
);

CREATE TABLE workout_programs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    description TEXT,
    difficulty TEXT,
    duration_weeks INT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE workout_program_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    program_id UUID REFERENCES workout_programs(id) ON DELETE CASCADE,
    day_number INT NOT NULL,
    title TEXT,
    UNIQUE (program_id, day_number)
);

CREATE TABLE workout_program_exercises (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID REFERENCES workout_program_sessions(id) ON DELETE CASCADE,
    exercise_id UUID REFERENCES exercises(id),
    sets INT,
    reps_range TEXT,
    rest_seconds INT,
    order_index INT
);

CREATE TABLE user_program_enrollments (
    user_id UUID REFERENCES auth.users(id),
    program_id UUID REFERENCES workout_programs(id),
    started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    current_day INT DEFAULT 1,
    is_completed BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (user_id, program_id)
);
