-- Išlik: savaitės lygos (PRD 4 sk.): 10 lygų, iki 30 žmonių grupės,
-- savaitė pirmadienis–sekmadienis (Europe/Vilnius), top 7 kyla, apatiniai 5 krenta.
--
-- * Į savaitės grupę patenkama uždirbus pirmą XP tą savaitę (tuščių grupių nėra).
-- * XP į lygą ateina per trigerį ant lesson_attempts – pakartotinai atsiųstas
--   bandymas (record_lesson_attempt jį ignoruoja) XP nedubliuoja.
-- * Savaitę uždaro close_league_week: per pg_cron arba tingiai – pirmo kreipinio
--   naujoje savaitėje metu. Funkcija idempotentiška.
-- * Klientas lentelių tiesiogiai neskaito – tik savo grupę per get_my_league().

create table public.leagues (
  tier int primary key check (tier between 1 and 10),
  name text not null
);

insert into public.leagues (tier, name) values
  (1, 'Pradinukas'), (2, 'Stovyklautojas'), (3, 'Žygeivis'), (4, 'Pėdsekys'),
  (5, 'Orientuotojas'), (6, 'Skautas'), (7, 'Tyrinėtojas'), (8, 'Gelbėtojas'),
  (9, 'Instruktorius'), (10, 'Rangeris');

-- Uždarytos savaitės (idempotentiškumui).
create table public.league_weeks (
  week_start date primary key,
  closed_at  timestamptz
);

create table public.league_groups (
  id         bigint generated always as identity primary key,
  week_start date not null,
  tier       int  not null references public.leagues (tier),
  created_at timestamptz not null default now()
);

create index league_groups_week_tier_idx on public.league_groups (week_start, tier);

create table public.league_members (
  week_start    date   not null,
  user_id       uuid   not null references auth.users (id) on delete cascade,
  group_id      bigint not null references public.league_groups (id) on delete cascade,
  tier          int    not null references public.leagues (tier),
  -- Viešai rodomas vardas; el. paštas niekada neatskleidžiamas.
  display_name  text   not null,
  weekly_xp     int    not null default 0 check (weekly_xp >= 0),
  -- Lygiems XP aukščiau tas, kas juos surinko anksčiau.
  xp_updated_at timestamptz not null default now(),
  final_rank    int,
  outcome       text check (outcome in ('promoted', 'stayed', 'demoted')),
  primary key (week_start, user_id)
);

create index league_members_group_idx on public.league_members (group_id);

-- Dabartinė vartotojo lyga (kitai savaitei).
create table public.league_standings (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  tier       int  not null default 1 references public.leagues (tier),
  updated_at timestamptz not null default now()
);

alter table public.leagues          enable row level security;
alter table public.league_weeks     enable row level security;
alter table public.league_groups    enable row level security;
alter table public.league_members   enable row level security;
alter table public.league_standings enable row level security;

create policy "league names are public" on public.leagues for select to anon, authenticated using (true);
grant select on public.leagues to anon, authenticated;
-- Kitoms lentelėms politikų nėra: prieiga tik per funkcijas žemiau.

create function public.league_week_start(ts timestamptz default now())
returns date language sql stable as $$
  select date_trunc('week', ts at time zone 'Europe/Vilnius')::date
$$;

-- Taisyklės vienoje vietoje (klientas jas gauna iš get_my_league).
create function public.league_outcome(p_rank int, p_size int, p_tier int)
returns text language sql immutable as $$
  select case
    when p_rank <= 7 and p_tier < 10 then 'promoted'
    -- Apatiniai 5, bet mažoje grupėje kilimo zona turi pirmenybę.
    when p_rank > greatest(7, p_size - 5) and p_tier > 1 then 'demoted'
    else 'stayed'
  end
$$;

create function public.close_league_week(p_week date)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int;
begin
  if p_week + 7 > league_week_start() then
    raise exception 'week % has not ended', p_week using errcode = '22023';
  end if;

  -- Vienu metu savaitę uždaro tik vienas.
  perform pg_advisory_xact_lock(hashtext('close_league_week'), (p_week - date '2000-01-03'));
  if exists (select 1 from league_weeks where week_start = p_week and closed_at is not null) then
    return 0;
  end if;

  with ranked as (
    select m.user_id,
           m.tier,
           row_number() over w as rank,
           count(*) over (partition by m.group_id) as size
    from league_members m
    where m.week_start = p_week
    window w as (partition by m.group_id order by m.weekly_xp desc, m.xp_updated_at, m.user_id)
  )
  update league_members m
     set final_rank = r.rank,
         outcome    = league_outcome(r.rank::int, r.size::int, r.tier)
    from ranked r
   where m.week_start = p_week and m.user_id = r.user_id;
  get diagnostics v_count = row_count;

  insert into league_standings (user_id, tier, updated_at)
  select user_id,
         case outcome when 'promoted' then tier + 1 when 'demoted' then tier - 1 else tier end,
         now()
    from league_members
   where week_start = p_week
  on conflict (user_id) do update set tier = excluded.tier, updated_at = excluded.updated_at;

  insert into league_weeks (week_start, closed_at) values (p_week, now())
  on conflict (week_start) do update set closed_at = excluded.closed_at;
  return v_count;
end;
$$;

-- Uždaro praėjusią savaitę, jei to dar nepadarė cron (pirmas kreipinys naujoje savaitėje).
create function public.ensure_previous_league_week_closed()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_prev date := league_week_start() - 7;
begin
  if exists (select 1 from league_members where week_start = v_prev)
     and not exists (select 1 from league_weeks where week_start = v_prev and closed_at is not null) then
    perform close_league_week(v_prev);
  end if;
end;
$$;

create function public.add_league_xp(p_user uuid, p_xp int)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_week  date := league_week_start();
  v_tier  int;
  v_group bigint;
begin
  if p_xp is null or p_xp <= 0 then
    return;
  end if;

  update league_members
     set weekly_xp = weekly_xp + p_xp, xp_updated_at = now()
   where week_start = v_week and user_id = p_user;
  if found then
    return;
  end if;

  -- Pirmas XP šią savaitę: lyga priklauso nuo praėjusios savaitės rezultato.
  perform ensure_previous_league_week_closed();
  insert into league_standings (user_id) values (p_user) on conflict (user_id) do nothing;
  select tier into v_tier from league_standings where user_id = p_user;

  -- Grupių pildymas nuosekliai kiekvienai (savaitė, lyga) – kad nebūtų 31 nario.
  perform pg_advisory_xact_lock(hashtext('league_join'), (v_week - date '2000-01-03') * 16 + v_tier);
  select g.id into v_group
    from league_groups g
   where g.week_start = v_week and g.tier = v_tier
     and (select count(*) from league_members m where m.group_id = g.id) < 30
   order by g.id
   limit 1;
  if v_group is null then
    insert into league_groups (week_start, tier) values (v_week, v_tier) returning id into v_group;
  end if;

  insert into league_members (week_start, user_id, group_id, tier, display_name, weekly_xp)
  values (v_week, p_user, v_group, v_tier,
          -- Maišos pradžia – tolygiai pasiskirstę vardai (UUID pradžia gali kartotis).
          'Žygeivis ' || upper(substr(md5(p_user::text), 1, 5)), p_xp)
  on conflict (week_start, user_id) do update
    set weekly_xp = league_members.weekly_xp + excluded.weekly_xp, xp_updated_at = now();
end;
$$;

create function public.lesson_attempt_to_league()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform add_league_xp(new.user_id, new.xp);
  return new;
end;
$$;

create trigger lesson_attempts_league_xp
  after insert on public.lesson_attempts
  for each row execute function public.lesson_attempt_to_league();

-- Mano šios savaitės lyga + praėjusios savaitės rezultatas.
create function public.get_my_league()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user  uuid := auth.uid();
  v_week  date := league_week_start();
  v_me    league_members;
  v_tier  int;
  v_last  league_members;
begin
  if v_user is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  perform ensure_previous_league_week_closed();

  select * into v_me from league_members where week_start = v_week and user_id = v_user;
  select tier into v_tier from league_standings where user_id = v_user;
  v_tier := coalesce(v_me.tier, v_tier, 1);
  select * into v_last from league_members
   where week_start = v_week - 7 and user_id = v_user and outcome is not null;

  return jsonb_build_object(
    'week_start', v_week,
    'week_end', ((v_week + 7)::timestamp at time zone 'Europe/Vilnius'),
    'tier', v_tier,
    'tier_name', (select name from leagues where tier = v_tier),
    'max_tier', 10,
    'group_size', 30,
    'promote_count', 7,
    'demote_count', 5,
    'joined', v_me.user_id is not null,
    'members', coalesce((
      select jsonb_agg(jsonb_build_object(
               'rank', rank, 'display_name', display_name, 'weekly_xp', weekly_xp, 'is_me', user_id = v_user)
             order by rank)
        from (select m.*, row_number() over (order by m.weekly_xp desc, m.xp_updated_at, m.user_id) as rank
                from league_members m
               where m.group_id = v_me.group_id) ranked
    ), '[]'::jsonb),
    'last_week', case when v_last.user_id is null then null else jsonb_build_object(
      'tier', v_last.tier,
      'tier_name', (select name from leagues where tier = v_last.tier),
      'final_rank', v_last.final_rank,
      'outcome', v_last.outcome
    ) end
  );
end;
$$;

revoke all on function public.close_league_week(date) from public, anon, authenticated;
revoke all on function public.ensure_previous_league_week_closed() from public, anon, authenticated;
revoke all on function public.add_league_xp(uuid, int) from public, anon, authenticated;
revoke all on function public.get_my_league() from public, anon;
grant execute on function public.get_my_league() to authenticated;

-- pg_cron (Dashboard → Integrations → Cron) – nebūtina, bet sumažina pirmo kreipinio darbą:
--   select cron.schedule('close-league-week', '1 0 * * 1',
--     $$ select public.close_league_week(public.league_week_start() - 7) $$);
-- Pastaba: cron dirba UTC – 00:01 UTC pirmadienį Vilniuje jau 02:01/03:01, savaitė pasibaigusi.
