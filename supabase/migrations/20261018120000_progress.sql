-- Išlik: vartotojo progresas (PRD 5 sk.: user_lesson_progress, xp_events).
--
-- Klientas siunčia ne būseną, o BANDYMUS (lesson_attempts) per RPC
-- record_lesson_attempt. Serveris:
--   * atmeta pakartotinį to paties bandymo siuntimą (idempotentiška pagal id),
--   * pats apskaičiuoja žvaigždutes iš tikslumo,
--   * sujungia su esamu progresu (XP sumuojamas, žvaigždutės / tikslumas – geriausi),
-- todėl offline eilė ir keli įrenginiai neperrašo vienas kito.

create table public.user_lesson_progress (
  user_id        uuid not null references auth.users (id) on delete cascade,
  lesson_id      text not null references public.lessons (id) on delete cascade,
  lesson_version int  not null,
  status         text not null default 'in_progress'
                 check (status in ('in_progress', 'completed', 'mastered')),
  stars          int  not null default 0 check (stars between 0 and 3),
  best_accuracy  numeric(4, 3) not null default 0 check (best_accuracy between 0 and 1),
  xp_earned      int  not null default 0 check (xp_earned >= 0),
  attempts       int  not null default 0 check (attempts >= 0),
  completed_at   timestamptz,
  updated_at     timestamptz not null default now(),
  primary key (user_id, lesson_id)
);

create table public.lesson_attempts (
  id             uuid primary key,
  user_id        uuid not null references auth.users (id) on delete cascade,
  lesson_id      text not null references public.lessons (id) on delete cascade,
  lesson_version int  not null,
  accuracy       numeric(4, 3) not null check (accuracy between 0 and 1),
  xp             int  not null check (xp between 0 and 500),
  completed_at   timestamptz not null,
  received_at    timestamptz not null default now()
);

create index lesson_attempts_user_idx on public.lesson_attempts (user_id, completed_at desc);

alter table public.user_lesson_progress enable row level security;
alter table public.lesson_attempts      enable row level security;

-- Skaityti – tik savo. Rašyti tiesiogiai negalima: tik per funkciją žemiau.
create policy "own progress is readable" on public.user_lesson_progress
  for select to authenticated using (user_id = auth.uid());

create policy "own attempts are readable" on public.lesson_attempts
  for select to authenticated using (user_id = auth.uid());

grant select on public.user_lesson_progress, public.lesson_attempts to authenticated;

create function public.record_lesson_attempt(
  p_attempt_id     uuid,
  p_lesson_id      text,
  p_lesson_version int,
  p_accuracy       numeric,
  p_xp             int,
  p_completed_at   timestamptz
) returns public.user_lesson_progress
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user   uuid := auth.uid();
  v_stars  int;
  v_new    boolean;
  v_result public.user_lesson_progress;
begin
  if v_user is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  if p_accuracy is null or p_accuracy < 0 or p_accuracy > 1 then
    raise exception 'accuracy out of range: %', p_accuracy using errcode = '22023';
  end if;
  if p_xp is null or p_xp < 0 or p_xp > 500 then
    raise exception 'xp out of range: %', p_xp using errcode = '22023';
  end if;
  -- Laikrodžio paklaidai leidžiame 1 d. į ateitį.
  if p_completed_at > now() + interval '1 day' then
    raise exception 'completed_at in the future' using errcode = '22023';
  end if;

  insert into public.lesson_attempts (id, user_id, lesson_id, lesson_version, accuracy, xp, completed_at)
  values (p_attempt_id, v_user, p_lesson_id, p_lesson_version, p_accuracy, p_xp, p_completed_at)
  on conflict (id) do nothing;
  v_new := found;

  if not v_new then
    -- Jau gautas (pakartotinis siuntimas) – nieko nekeičiam.
    select * into v_result from public.user_lesson_progress
    where user_id = v_user and lesson_id = p_lesson_id;
    return v_result;
  end if;

  -- Ta pati taisyklė kaip kliente (UserProgress.starsForAccuracy).
  v_stars := case
    when p_accuracy >= 1   then 3
    when p_accuracy >= 0.8 then 2
    when p_accuracy >= 0.6 then 1
    else 0
  end;

  insert into public.user_lesson_progress as p
    (user_id, lesson_id, lesson_version, status, stars, best_accuracy, xp_earned, attempts, completed_at, updated_at)
  values
    (v_user, p_lesson_id, p_lesson_version,
     case when v_stars > 0 then 'completed' else 'in_progress' end,
     v_stars, p_accuracy, p_xp, 1,
     case when v_stars > 0 then p_completed_at end,
     now())
  on conflict (user_id, lesson_id) do update set
    lesson_version = greatest(p.lesson_version, excluded.lesson_version),
    stars          = greatest(p.stars, excluded.stars),
    best_accuracy  = greatest(p.best_accuracy, excluded.best_accuracy),
    xp_earned      = p.xp_earned + excluded.xp_earned,
    attempts       = p.attempts + 1,
    status         = case
                       when p.status = 'mastered' then 'mastered'
                       when greatest(p.stars, excluded.stars) > 0 then 'completed'
                       else 'in_progress'
                     end,
    completed_at   = coalesce(p.completed_at, excluded.completed_at),
    updated_at     = now()
  returning * into v_result;

  return v_result;
end;
$$;

revoke all on function public.record_lesson_attempt(uuid, text, int, numeric, int, timestamptz) from public, anon;
grant execute on function public.record_lesson_attempt(uuid, text, int, numeric, int, timestamptz) to authenticated;
