-- Išlik: mokymo turinio lentelės (PRD 5 sk.).
-- Programėlė tik skaito; turinį rašo CMS / administratoriai su service_role raktu.

create table public.courses (
  id          text primary key check (id ~ '^[A-Za-z0-9_-]+$'),
  title       text not null,
  description text,
  sort_order  int  not null default 0,
  published   boolean not null default false,
  updated_at  timestamptz not null default now()
);

create table public.units (
  id          text primary key check (id ~ '^[A-Za-z0-9_-]+$'),
  course_id   text not null references public.courses (id) on delete cascade,
  title       text not null,
  description text,
  sort_order  int  not null default 0,
  published   boolean not null default false,
  updated_at  timestamptz not null default now()
);

create table public.lessons (
  id                text primary key check (id ~ '^[A-Za-z0-9_-]+$'),
  course_id         text not null references public.courses (id) on delete cascade,
  unit_id           text not null references public.units (id) on delete cascade,
  title             text not null,
  sort_order        int  not null default 0,
  -- Didinama kiekvieną kartą pakeitus `content`; programėlė pagal ją atnaujina kešą.
  version           int  not null default 1 check (version > 0),
  estimated_minutes int  not null default 5,
  -- Visa pamoka pagal assets/lessons/*.json schemą.
  content           jsonb not null,
  -- PRD: kiekviena pamoka su eksperto patvirtinimu.
  status            text not null default 'draft'
                    check (status in ('draft', 'in_review', 'approved', 'rejected')),
  updated_at        timestamptz not null default now(),
  constraint lessons_content_matches_row check (
    content ->> 'id' = id and (content ->> 'version')::int = version
  )
);

create index units_course_idx on public.units (course_id, sort_order);
create index lessons_unit_idx on public.lessons (unit_id, sort_order);

alter table public.courses enable row level security;
alter table public.units   enable row level security;
alter table public.lessons enable row level security;

-- Turinys viešas (PRD: „Gido“ medžiaga prieinama ir be prisijungimo), bet tik publikuotas.
create policy "published courses are readable" on public.courses
  for select to anon, authenticated using (published);

create policy "published units are readable" on public.units
  for select to anon, authenticated using (
    published and exists (select 1 from public.courses c where c.id = course_id and c.published)
  );

create policy "approved lessons are readable" on public.lessons
  for select to anon, authenticated using (
    status = 'approved'
    and exists (select 1 from public.units u where u.id = unit_id and u.published)
  );
