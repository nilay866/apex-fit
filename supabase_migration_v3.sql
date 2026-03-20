-- APEX AI Platform v3 — Schema Expansion
-- Safe to run multiple times. Run in Supabase SQL Editor.

begin;

-- Personal Records Table
create table if not exists public.personal_records (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users on delete cascade,
  exercise_name text not null,
  record_type text not null, -- 'max_weight', 'best_volume', 'best_1rm'
  weight numeric,
  reps int,
  estimated_1rm numeric,
  date timestamptz default now()
);

-- Exercise 1RM History
create table if not exists public.exercise_1rm (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users on delete cascade,
  exercise_name text not null,
  estimated_1rm numeric not null,
  weight numeric,
  reps int,
  date timestamptz default now()
);

-- Routine Templates
create table if not exists public.routine_templates (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users on delete cascade,
  name text not null,
  description text,
  folder text default 'General',
  is_public boolean default false,
  created_at timestamptz default now()
);

-- Routine Exercises
create table if not exists public.routine_exercises (
  id uuid default gen_random_uuid() primary key,
  routine_id uuid references public.routine_templates on delete cascade,
  exercise_name text not null,
  sets int default 3,
  reps text default '8-12',
  rest_seconds int default 90,
  sort_order int default 0
);

-- Workout Streaks
create table if not exists public.workout_streaks (
  user_id uuid references auth.users on delete cascade primary key,
  current_streak int default 0,
  longest_streak int default 0,
  last_workout_date date
);

-- Friends / Follow System
create table if not exists public.friends (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users on delete cascade,
  friend_id uuid references auth.users on delete cascade,
  status text default 'pending', -- 'pending', 'accepted'
  created_at timestamptz default now(),
  unique(user_id, friend_id)
);

-- Workout Posts (Social Feed)
create table if not exists public.workout_posts (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users on delete cascade,
  workout_log_id uuid references public.workout_logs on delete set null,
  caption text,
  likes int default 0,
  created_at timestamptz default now()
);

-- Indexes
create index if not exists idx_personal_records_user_exercise on public.personal_records (user_id, exercise_name);
create index if not exists idx_exercise_1rm_user_exercise on public.exercise_1rm (user_id, exercise_name, date desc);
create index if not exists idx_routine_templates_user on public.routine_templates (user_id);
create index if not exists idx_routine_exercises_routine on public.routine_exercises (routine_id, sort_order);
create index if not exists idx_workout_posts_created on public.workout_posts (created_at desc);
create index if not exists idx_friends_user on public.friends (user_id, status);

-- Enable RLS
alter table public.personal_records enable row level security;
alter table public.exercise_1rm enable row level security;
alter table public.routine_templates enable row level security;
alter table public.routine_exercises enable row level security;
alter table public.workout_streaks enable row level security;
alter table public.friends enable row level security;
alter table public.workout_posts enable row level security;

-- Policies
drop policy if exists "own_prs" on public.personal_records;
create policy "own_prs" on public.personal_records for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "own_1rm" on public.exercise_1rm;
create policy "own_1rm" on public.exercise_1rm for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "own_routines" on public.routine_templates;
create policy "own_routines" on public.routine_templates for all using (auth.uid() = user_id or is_public = true) with check (auth.uid() = user_id);

drop policy if exists "own_routine_exercises" on public.routine_exercises;
create policy "own_routine_exercises" on public.routine_exercises for all using (auth.uid() = (select user_id from public.routine_templates where id = routine_id)) with check (auth.uid() = (select user_id from public.routine_templates where id = routine_id));

drop policy if exists "own_streaks" on public.workout_streaks;
create policy "own_streaks" on public.workout_streaks for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "own_friends" on public.friends;
create policy "own_friends" on public.friends for all using (auth.uid() = user_id or auth.uid() = friend_id) with check (auth.uid() = user_id);

drop policy if exists "public_posts" on public.workout_posts;
create policy "public_posts" on public.workout_posts for select using (true);

drop policy if exists "own_posts" on public.workout_posts;
create policy "own_posts" on public.workout_posts for insert with check (auth.uid() = user_id);

drop policy if exists "delete_own_posts" on public.workout_posts;
create policy "delete_own_posts" on public.workout_posts for delete using (auth.uid() = user_id);

commit;
