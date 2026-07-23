-- KOMMILO 02-projects.sql — Studierenden-Projektportfolio (Workstream H)
-- Idempotent. Nach 01-feed.sql ausführen (nutzt Bucket `media` + app_flags).

create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  owner uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 80),
  summary text check (char_length(summary) <= 280),
  description text check (char_length(description) <= 5000),   -- Markdown
  tags text[] default '{}' check (coalesce(array_length(tags,1),0) <= 8),
  links jsonb default '[]'::jsonb,
  cover_path text,                                             -- media/projects/<uid>/...
  status text not null default 'idea' check (status in ('idea','in_progress','done')),
  visibility text not null default 'private' check (visibility in ('public_students','companies_too','private')),
  contact_release boolean not null default false,              -- default AUS: Uni-Mail für Companies erst nach Freigabe
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint links_shape check (
    jsonb_typeof(links) = 'array' and jsonb_array_length(links) <= 5
  )
);
create index if not exists projects_owner_idx on public.projects(owner);
create index if not exists projects_vis_idx on public.projects(visibility);

-- https-Zwang für alle Link-URLs (server-seitig, nicht nur Client)
create or replace function public.projects_links_https() returns trigger
language plpgsql as $$
declare l jsonb;
begin
  for l in select * from jsonb_array_elements(coalesce(new.links,'[]'::jsonb)) loop
    if coalesce(l->>'url','') !~* '^https://' then
      raise exception 'project links must be https';
    end if;
  end loop;
  new.updated_at := now();
  return new;
end $$;
drop trigger if exists projects_links_https_t on public.projects;
create trigger projects_links_https_t before insert or update on public.projects
  for each row execute function public.projects_links_https();

alter table public.projects enable row level security;
drop policy if exists projects_owner_all   on public.projects;
drop policy if exists projects_read_students on public.projects;
drop policy if exists projects_read_companies on public.projects;
create policy projects_owner_all on public.projects
  for all to authenticated using (owner = auth.uid()) with check (owner = auth.uid());
-- Studierende lesen public_students + companies_too:
create policy projects_read_students on public.projects
  for select to authenticated
  using (visibility in ('public_students','companies_too')
         and coalesce((select role from public.profiles where id = auth.uid()),'student') = 'student');
-- Companies lesen NUR companies_too:
create policy projects_read_companies on public.projects
  for select to authenticated
  using (visibility = 'companies_too'
         and (select role from public.profiles where id = auth.uid()) = 'company');

-- ===== RLS-Testnotizen =====
-- 1) Student A: eigenes private-Projekt lesbar ✓; Student B sieht es ✗.
-- 2) B sieht A-Projekte mit public_students/companies_too ✓.
-- 3) Company C (Rolle via 03) sieht NUR companies_too ✓, public_students ✗, private ✗.
-- 4) insert mit http://-Link ⇒ Exception 'project links must be https'.
