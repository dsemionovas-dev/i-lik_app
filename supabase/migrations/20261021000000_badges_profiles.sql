-- Išlik: ženkleliai (PRD 4 sk.) ir vartotojo profilis (vardas, avataras).
--
-- Ženklelių taisyklės (badges.rule) – tos pačios kaip programėlėje (assets/badges.json;
-- testas tikrina, kad sąrašai sutampa). Klientas jas įvertina iškart (ir be ryšio),
-- serveris – award_badges po kiekvieno progreso pokyčio, todėl ženkleliai išlieka
-- visuose įrenginiuose.

create table public.badges (
  id          text primary key,
  title       text not null,
  description text not null,
  icon        text not null,
  rule        jsonb not null check (rule ? 'type'),
  sort_order  int not null default 0
);

insert into public.badges (id, title, description, icon, rule, sort_order) values
  ('pirmoji-pamoka', 'Pirmasis žingsnis', 'Baik pirmą pamoką.', 'flag', '{"type": "lessons_completed", "count": 1}'::jsonb, 1),
  ('smalsuolis', 'Smalsuolis', 'Baik 5 pamokas.', 'explore', '{"type": "lessons_completed", "count": 5}'::jsonb, 2),
  ('patyres-zygeivis', 'Patyręs žygeivis', 'Baik 20 pamokų.', 'hiking', '{"type": "lessons_completed", "count": 20}'::jsonb, 3),
  ('be-klaidu', 'Be klaidų', 'Baik pamoką be nė vienos klaidos.', 'star', '{"type": "perfect_lessons", "count": 1}'::jsonb, 4),
  ('serija-3', 'Įsibėgėjimas', 'Mokykis 3 dienas iš eilės.', 'fire', '{"type": "streak_days", "days": 3}'::jsonb, 5),
  ('serija-7', '7 dienų serija', 'Mokykis 7 dienas iš eilės.', 'fire', '{"type": "streak_days", "days": 7}'::jsonb, 6),
  ('serija-30', 'Mėnuo be pertraukos', 'Mokykis 30 dienų iš eilės.', 'fire', '{"type": "streak_days", "days": 30}'::jsonb, 7),
  ('xp-100', 'Šimtukas', 'Surink 100 XP.', 'bolt', '{"type": "total_xp", "xp": 100}'::jsonb, 8),
  ('xp-1000', 'Tūkstantininkas', 'Surink 1000 XP.', 'bolt', '{"type": "total_xp", "xp": 1000}'::jsonb, 9),
  ('kompaso-meistras', 'Kompaso meistras', 'Baik visas skyriaus „Kompasas“ pamokas.', 'compass', '{"type": "unit_completed", "unitId": "nav-u02"}'::jsonb, 10),
  ('ugnies-meistras', 'Ugnies meistras', 'Baik visas skyriaus „Ugnis“ pamokas.', 'fire_master', '{"type": "unit_completed", "unitId": "wild-u02"}'::jsonb, 11);

create table public.user_badges (
  user_id   uuid not null references auth.users (id) on delete cascade,
  badge_id  text not null references public.badges (id) on delete cascade,
  earned_at timestamptz not null default now(),
  primary key (user_id, badge_id)
);

alter table public.badges      enable row level security;
alter table public.user_badges enable row level security;

create policy "badges are public" on public.badges for select to anon, authenticated using (true);
create policy "own badges are readable" on public.user_badges for select to authenticated using (user_id = auth.uid());
grant select on public.badges to anon, authenticated;
grant select on public.user_badges to authenticated;
-- Rašyti user_badges klientas negali – tik award_badges.

create function public.award_badges(p_user uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_completed int;
  v_perfect   int;
  v_xp        int;
  v_streak    int;
  v_awarded   int;
begin
  select count(*) filter (where status in ('completed', 'mastered')),
         count(*) filter (where stars = 3),
         coalesce(sum(xp_earned), 0)
    into v_completed, v_perfect, v_xp
    from user_lesson_progress
   where user_id = p_user;

  -- Ilgiausia serija: dienos iš eilės (Vilniaus laiku) su bent vienu bandymu.
  select coalesce(max(len), 0) into v_streak
    from (select count(*) as len
            from (select d, d - (row_number() over (order by d))::int as grp
                    from (select distinct (completed_at at time zone 'Europe/Vilnius')::date as d
                            from lesson_attempts
                           where user_id = p_user) days) runs
           group by grp) streaks;

  insert into user_badges (user_id, badge_id)
  select p_user, b.id
    from badges b
   where case b.rule ->> 'type'
           when 'lessons_completed' then v_completed >= (b.rule ->> 'count')::int
           when 'perfect_lessons'   then v_perfect   >= (b.rule ->> 'count')::int
           when 'total_xp'          then v_xp        >= (b.rule ->> 'xp')::int
           when 'streak_days'       then v_streak    >= (b.rule ->> 'days')::int
           when 'unit_completed'    then
             exists (select 1 from lessons l
                      where l.unit_id = b.rule ->> 'unitId' and l.status = 'approved')
             and not exists (
               select 1 from lessons l
                where l.unit_id = b.rule ->> 'unitId' and l.status = 'approved'
                  and not exists (select 1 from user_lesson_progress p
                                   where p.user_id = p_user and p.lesson_id = l.id
                                     and p.status in ('completed', 'mastered')))
           else false
         end
  on conflict (user_id, badge_id) do nothing;
  get diagnostics v_awarded = row_count;
  return v_awarded;
end;
$$;

create function public.user_lesson_progress_award_badges()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform award_badges(new.user_id);
  return new;
end;
$$;

create trigger user_lesson_progress_badges
  after insert or update on public.user_lesson_progress
  for each row execute function public.user_lesson_progress_award_badges();

revoke all on function public.award_badges(uuid) from public, anon, authenticated;

-- Profilis: viešas vardas (lygose) ir avataras iš nustatyto rinkinio.
create table public.profiles (
  user_id      uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  display_name text check (
    display_name is null or (
      char_length(display_name) between 3 and 24
      and display_name = btrim(display_name)
      and display_name !~ '\s{2,}'
      -- Jokių valdymo simbolių, el. pašto ar HTML (vardas matomas kitiems).
      and display_name !~ '[[:cntrl:]<>@/\\]'
    )
  ),
  avatar       text check (avatar is null or avatar in ('fox', 'bear', 'wolf', 'owl', 'deer', 'hedgehog', 'boar', 'eagle', 'beaver', 'stork')),
  updated_at   timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "own profile is readable"  on public.profiles for select to authenticated using (user_id = auth.uid());
create policy "own profile is insertable" on public.profiles for insert to authenticated with check (user_id = auth.uid());
create policy "own profile is updatable" on public.profiles for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
grant select, insert, update on public.profiles to authenticated;

-- Lygoje rodomas profilio vardas (jei pasirinktas), kitaip – sugeneruotas.
create function public.league_member_profile_name()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.display_name := coalesce(
    (select display_name from profiles where user_id = new.user_id),
    new.display_name);
  return new;
end;
$$;

create trigger league_members_profile_name
  before insert on public.league_members
  for each row execute function public.league_member_profile_name();

-- Pakeitus vardą – atnaujinamas ir šios savaitės lygoje.
create function public.profile_name_to_league()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.updated_at := now();
  update league_members
     set display_name = coalesce(new.display_name,
                                 'Žygeivis ' || upper(substr(md5(new.user_id::text), 1, 5)))
   where user_id = new.user_id and week_start = league_week_start();
  return new;
end;
$$;

create trigger profiles_name_to_league
  before insert or update on public.profiles
  for each row execute function public.profile_name_to_league();
