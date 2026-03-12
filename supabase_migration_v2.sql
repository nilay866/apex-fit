-- APEX FIT: EXERCISE INTELLIGENCE SYSTEM MIGRATION
-- This script implements the core intelligence layer for the fitness platform.

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. CORE EXERCISES
CREATE TABLE IF NOT EXISTS exercises (
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

-- 3. MUSCLE INTENSITY MAPPING (For Anatomical Heatmaps)
CREATE TABLE IF NOT EXISTS muscle_heatmap (
    exercise_id UUID REFERENCES exercises(id) ON DELETE CASCADE,
    muscle TEXT NOT NULL,
    intensity INT CHECK (intensity >= 1 AND intensity <= 5),
    PRIMARY KEY (exercise_id, muscle)
);

-- 4. WORKOUT PROGRAMS (Multi-Week Threads)
CREATE TABLE IF NOT EXISTS workout_programs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    description TEXT,
    difficulty TEXT,
    duration_weeks INT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. PROGRAM SESSIONS (Individual Days in a Program)
CREATE TABLE IF NOT EXISTS workout_program_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    program_id UUID REFERENCES workout_programs(id) ON DELETE CASCADE,
    day_number INT NOT NULL,
    title TEXT,
    UNIQUE (program_id, day_number)
);

-- 6. PROGRAM EXERCISES (Prescribed Work for a Session)
CREATE TABLE IF NOT EXISTS workout_program_exercises (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID REFERENCES workout_program_sessions(id) ON DELETE CASCADE,
    exercise_id UUID REFERENCES exercises(id),
    sets INT,
    reps_range TEXT,
    rest_seconds INT,
    order_index INT
);

-- 7. USER ENROLLMENTS (Tracking Progress in a Program)
CREATE TABLE IF NOT EXISTS user_program_enrollments (
    user_id UUID REFERENCES auth.users(id),
    program_id UUID REFERENCES workout_programs(id),
    started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    current_day INT DEFAULT 1,
    is_completed BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (user_id, program_id)
);
