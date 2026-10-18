-- Išlik: pranešimai apie klaidas turinyje ar programėlėje (PRD: „Pranešk apie klaidą“).
-- Klientas tik įrašo; skaito ir tvarko komanda (Supabase Studio / service_role).

create table public.content_reports (
  -- Kliento UUID: pakartotinai išsiųstas pranešimas atmetamas (23505), ne dubliuojamas.
  id            uuid primary key,
  -- Ištrynus paskyrą (BDAR) pranešimas lieka, bet tampa anonimiškas.
  user_id       uuid default auth.uid() references auth.users (id) on delete set null,
  category      text not null check (category in ('content_error', 'unsafe_advice', 'app_bug', 'suggestion')),
  message       text not null check (char_length(btrim(message)) between 10 and 2000),
  lesson_id     text check (lesson_id is null or char_length(lesson_id) <= 100),
  item_id       text check (item_id is null or char_length(item_id) <= 100),
  guide_card_id text check (guide_card_id is null or char_length(guide_card_id) <= 100),
  app_version   text not null check (char_length(app_version) <= 50),
  platform      text not null check (char_length(platform) <= 30),
  created_at    timestamptz not null,
  received_at   timestamptz not null default now(),
  -- Komandai: new → triaged → fixed / rejected.
  status        text not null default 'new' check (status in ('new', 'triaged', 'fixed', 'rejected'))
);

create index content_reports_status_idx on public.content_reports (status, received_at desc);
create index content_reports_lesson_idx on public.content_reports (lesson_id) where lesson_id is not null;

alter table public.content_reports enable row level security;

-- Tik įrašyti ir tik savo vardu; pavojingi patarimai matomi pirmiausia (žr. vaizdą žemiau).
create policy "users can submit reports" on public.content_reports
  for insert to authenticated
  with check (user_id = auth.uid() and status = 'new');
grant insert on public.content_reports to authenticated;

-- Apsauga nuo šlamšto: daugiausia 10 pranešimų per valandą vienam vartotojui.
create function public.content_reports_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if (select count(*) from content_reports
       where user_id = new.user_id and received_at > now() - interval '1 hour') >= 10 then
    raise exception 'too many reports' using errcode = 'P0429';
  end if;
  return new;
end;
$$;

create trigger content_reports_rate_limit
  before insert on public.content_reports
  for each row execute function public.content_reports_rate_limit();

-- Komandos darbo sąrašas: pavojingi patarimai – pirmi.
create view public.content_reports_queue
with (security_invoker = true) as
select *
  from public.content_reports
 where status in ('new', 'triaged')
 order by (category = 'unsafe_advice') desc, received_at;

revoke all on public.content_reports_queue from anon, authenticated;
