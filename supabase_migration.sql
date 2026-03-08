-- APEX AI schema sync
-- Safe to run multiple times in Supabase SQL Editor.

begin;

create extension if not exists pgcrypto;

-- Core tables
create table if not exists public.profiles (
  id uuid references auth.users on delete cascade primary key,
  name text,
  avatar_data text,
  weight_kg numeric,
  height_cm numeric,
  goal text default 'Build Muscle',
  calorie_goal int default 2000,
  water_goal_ml int default 2500,
  created_at timestamptz default now()
);

create table if not exists public.workouts (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users on delete cascade,
  name text not null,
  type text default 'Gym',
  created_at timestamptz default now()
);

create table if not exists public.exercises (
  id uuid default gen_random_uuid() primary key,
  workout_id uuid references public.workouts on delete cascade,
  name text not null,
  sets int default 3,
  reps text default '8-12',
  target_weight numeric
);

create table if not exists public.workout_logs (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users on delete cascade,
  workout_name text,
  duration_min int,
  total_volume numeric default 0,
  intensity text default 'moderate',
  notes text,
  completed_at timestamptz default now()
);

create table if not exists public.set_logs (
  id uuid default gen_random_uuid() primary key,
  log_id uuid references public.workout_logs on delete cascade,
  exercise_name text,
  set_number int,
  reps_done int,
  weight_kg numeric,
  logged_at timestamptz default now()
);

create table if not exists public.nutrition_logs (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users on delete cascade,
  meal_name text not null,
  quantity text,
  photo_data text,
  calories int default 0,
  protein_g numeric default 0,
  carbs_g numeric default 0,
  fat_g numeric default 0,
  logged_at timestamptz default now()
);

create table if not exists public.body_weight_logs (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users on delete cascade,
  weight_kg numeric not null,
  logged_at timestamptz default now()
);

create table if not exists public.water_logs (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users on delete cascade,
  amount_ml int not null,
  logged_at timestamptz default now()
);

create table if not exists public.progress_photos (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users on delete cascade,
  photo_data text not null,
  caption text,
  taken_at timestamptz default now()
);

-- Backfill columns for older projects
alter table public.profiles add column if not exists name text;
alter table public.profiles add column if not exists avatar_data text;
alter table public.profiles add column if not exists weight_kg numeric;
alter table public.profiles add column if not exists height_cm numeric;
alter table public.profiles add column if not exists goal text default 'Build Muscle';
alter table public.profiles add column if not exists calorie_goal int default 2000;
alter table public.profiles add column if not exists water_goal_ml int default 2500;
alter table public.profiles add column if not exists created_at timestamptz default now();

alter table public.workouts add column if not exists user_id uuid references auth.users on delete cascade;
alter table public.workouts add column if not exists name text;
alter table public.workouts add column if not exists type text default 'Gym';
alter table public.workouts add column if not exists created_at timestamptz default now();

alter table public.exercises add column if not exists workout_id uuid references public.workouts on delete cascade;
alter table public.exercises add column if not exists name text;
alter table public.exercises add column if not exists sets int default 3;
alter table public.exercises add column if not exists reps text default '8-12';
alter table public.exercises add column if not exists target_weight numeric;

alter table public.workout_logs add column if not exists user_id uuid references auth.users on delete cascade;
alter table public.workout_logs add column if not exists workout_name text;
alter table public.workout_logs add column if not exists duration_min int;
alter table public.workout_logs add column if not exists total_volume numeric default 0;
alter table public.workout_logs add column if not exists intensity text default 'moderate';
alter table public.workout_logs add column if not exists notes text;
alter table public.workout_logs add column if not exists completed_at timestamptz default now();

alter table public.set_logs add column if not exists log_id uuid references public.workout_logs on delete cascade;
alter table public.set_logs add column if not exists exercise_name text;
alter table public.set_logs add column if not exists set_number int;
alter table public.set_logs add column if not exists reps_done int;
alter table public.set_logs add column if not exists weight_kg numeric;
alter table public.set_logs add column if not exists logged_at timestamptz default now();

alter table public.nutrition_logs add column if not exists user_id uuid references auth.users on delete cascade;
alter table public.nutrition_logs add column if not exists meal_name text;
alter table public.nutrition_logs add column if not exists quantity text;
alter table public.nutrition_logs add column if not exists photo_data text;
alter table public.nutrition_logs add column if not exists calories int default 0;
alter table public.nutrition_logs add column if not exists protein_g numeric default 0;
alter table public.nutrition_logs add column if not exists carbs_g numeric default 0;
alter table public.nutrition_logs add column if not exists fat_g numeric default 0;
alter table public.nutrition_logs add column if not exists logged_at timestamptz default now();

alter table public.body_weight_logs add column if not exists user_id uuid references auth.users on delete cascade;
alter table public.body_weight_logs add column if not exists weight_kg numeric;
alter table public.body_weight_logs add column if not exists logged_at timestamptz default now();

alter table public.water_logs add column if not exists user_id uuid references auth.users on delete cascade;
alter table public.water_logs add column if not exists amount_ml int;
alter table public.water_logs add column if not exists logged_at timestamptz default now();

alter table public.progress_photos add column if not exists user_id uuid references auth.users on delete cascade;
alter table public.progress_photos add column if not exists photo_data text;
alter table public.progress_photos add column if not exists caption text;
alter table public.progress_photos add column if not exists taken_at timestamptz default now();

-- Defaults
alter table public.profiles alter column goal set default 'Build Muscle';
alter table public.profiles alter column calorie_goal set default 2000;
alter table public.profiles alter column water_goal_ml set default 2500;
alter table public.workouts alter column type set default 'Gym';
alter table public.exercises alter column sets set default 3;
alter table public.exercises alter column reps set default '8-12';
alter table public.workout_logs alter column total_volume set default 0;
alter table public.workout_logs alter column intensity set default 'moderate';
alter table public.nutrition_logs alter column calories set default 0;
alter table public.nutrition_logs alter column protein_g set default 0;
alter table public.nutrition_logs alter column carbs_g set default 0;
alter table public.nutrition_logs alter column fat_g set default 0;

-- Backfill nulls where the app expects values
update public.profiles
set goal = coalesce(goal, 'Build Muscle'),
    calorie_goal = coalesce(calorie_goal, 2000),
    water_goal_ml = coalesce(water_goal_ml, 2500);

update public.workouts
set type = coalesce(type, 'Gym');

update public.exercises
set sets = coalesce(sets, 3),
    reps = coalesce(reps, '8-12');

update public.workout_logs
set total_volume = coalesce(total_volume, 0),
    intensity = coalesce(intensity, 'moderate');

update public.nutrition_logs
set calories = coalesce(calories, 0),
    protein_g = coalesce(protein_g, 0),
    carbs_g = coalesce(carbs_g, 0),
    fat_g = coalesce(fat_g, 0);

update public.water_logs
set amount_ml = coalesce(amount_ml, 250)
where amount_ml is null;

-- Safe not-null enforcement for fields the app relies on
alter table public.water_logs alter column amount_ml set not null;

-- Indexes
create index if not exists idx_workouts_user_id on public.workouts (user_id);
create index if not exists idx_workout_logs_user_id_completed_at on public.workout_logs (user_id, completed_at desc);
create index if not exists idx_nutrition_logs_user_id_logged_at on public.nutrition_logs (user_id, logged_at desc);
create index if not exists idx_body_weight_logs_user_id_logged_at on public.body_weight_logs (user_id, logged_at desc);
create index if not exists idx_water_logs_user_id_logged_at on public.water_logs (user_id, logged_at desc);
create index if not exists idx_progress_photos_user_id_taken_at on public.progress_photos (user_id, taken_at desc);

-- Enable RLS
alter table public.profiles enable row level security;
alter table public.workouts enable row level security;
alter table public.exercises enable row level security;
alter table public.workout_logs enable row level security;
alter table public.set_logs enable row level security;
alter table public.nutrition_logs enable row level security;
alter table public.body_weight_logs enable row level security;
alter table public.water_logs enable row level security;
alter table public.progress_photos enable row level security;

-- Policies
drop policy if exists "own_profile" on public.profiles;
create policy "own_profile"
on public.profiles
for all
using (auth.uid() = id)
with check (auth.uid() = id);

drop policy if exists "own_workouts" on public.workouts;
create policy "own_workouts"
on public.workouts
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "own_exercises" on public.exercises;
create policy "own_exercises"
on public.exercises
for all
using (auth.uid() = (select user_id from public.workouts where id = workout_id))
with check (auth.uid() = (select user_id from public.workouts where id = workout_id));

drop policy if exists "own_logs" on public.workout_logs;
create policy "own_logs"
on public.workout_logs
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "own_set_logs" on public.set_logs;
create policy "own_set_logs"
on public.set_logs
for all
using (auth.uid() = (select user_id from public.workout_logs where id = log_id))
with check (auth.uid() = (select user_id from public.workout_logs where id = log_id));

drop policy if exists "own_nutrition" on public.nutrition_logs;
create policy "own_nutrition"
on public.nutrition_logs
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "own_weight" on public.body_weight_logs;
create policy "own_weight"
on public.body_weight_logs
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "own_water" on public.water_logs;
create policy "own_water"
on public.water_logs
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "own_photos" on public.progress_photos;
create policy "own_photos"
on public.progress_photos
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

-- Signup trigger
create or replace function public.handle_new_user()
returns trigger
as $$
begin
  insert into public.profiles (id, name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', new.email)
  )
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- Backfill profiles for users created before the trigger existed
insert into public.profiles (id, name)
select
  u.id,
  coalesce(u.raw_user_meta_data->>'name', u.email)
from auth.users u
on conflict (id) do nothing;

commit;
