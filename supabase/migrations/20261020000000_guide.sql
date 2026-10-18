-- Išlik: gido atmintinės (PRD: nemokamai, be prisijungimo, veikia be interneto).
-- Programėlėje gidas įdiegtas (assets/guide/guide.json) ir visada atidaromas iš
-- įrenginio; ši lentelė – tik naujesnės versijos atsisiuntimui fone.

create table public.guide_books (
  locale     text primary key default 'lt-LT',
  version    int  not null check (version > 0),
  -- Visas gidas pagal assets/guide/guide.json schemą.
  content    jsonb not null,
  -- Kaip pamokos: tik eksperto patvirtintas turinys publikuojamas.
  published  boolean not null default false,
  updated_at timestamptz not null default now(),
  constraint guide_content_matches_row check (
    (content ->> 'version')::int = version
    and content ->> 'locale' = locale
    and jsonb_typeof(content -> 'cards') = 'array'
    and jsonb_array_length(content -> 'cards') > 0
  )
);

alter table public.guide_books enable row level security;

-- Viešai: ir neprisijungusiems (anon raktas).
create policy "published guide is public" on public.guide_books
  for select to anon, authenticated using (published);

grant select on public.guide_books to anon, authenticated;
