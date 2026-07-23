-- KOMMILO 03-companies.sql — kuratierter Company Access (Workstream I)
-- Idempotent. Nach 02-projects.sql ausführen.
-- ADMIN-SNIPPET (nur Owner, SQL-Editor):
--   insert into public.company_domains(domain, company_name, approved)
--     values ('firma.de','Firma GmbH', true)
--     on conflict (domain) do update set approved = excluded.approved, company_name = excluded.company_name;

-- profiles.role: student (default) | company
alter table public.profiles add column if not exists role text not null default 'student'
  check (role in ('student','company'));
alter table public.profiles add column if not exists uni_email text;

-- ===== Kuratierte Allowlist (kein Self-Service) =====
create table if not exists public.company_domains (
  domain text primary key,
  company_name text not null,
  approved boolean not null default false,
  created_at timestamptz not null default now()
);
alter table public.company_domains enable row level security;
drop policy if exists company_domains_read on public.company_domains;
create policy company_domains_read on public.company_domains for select to authenticated using (approved);
-- Schreiben ausschließlich via SQL-Editor/Service-Role (Owner).

-- Seed: ~25 bekannte deutsche Tech-/Engineering-Arbeitgeber (approved). Erweiterung nur per Admin-Snippet.
insert into public.company_domains (domain, company_name, approved) values
 ('volkswagen.de','Volkswagen AG', true), ('siemens.com','Siemens AG', true),
 ('bosch.com','Robert Bosch GmbH', true), ('sap.com','SAP SE', true),
 ('airbus.com','Airbus', true), ('continental.com','Continental AG', true),
 ('zf.com','ZF Friedrichshafen AG', true), ('telekom.de','Deutsche Telekom AG', true),
 ('bmw.de','BMW Group', true), ('mercedes-benz.com','Mercedes-Benz Group AG', true),
 ('porsche.de','Porsche AG', true), ('audi.de','AUDI AG', true),
 ('infineon.com','Infineon Technologies AG', true), ('basf.com','BASF SE', true),
 ('bayer.com','Bayer AG', true), ('thyssenkrupp.com','thyssenkrupp AG', true),
 ('schaeffler.com','Schaeffler AG', true), ('mtu.de','MTU Aero Engines AG', true),
 ('dlr.de','Deutsches Zentrum für Luft- und Raumfahrt', true),
 ('salzgitter-ag.com','Salzgitter AG', true), ('miele.de','Miele & Cie. KG', true),
 ('sennheiser.com','Sennheiser', true), ('festo.com','Festo SE & Co. KG', true),
 ('kuka.com','KUKA AG', true), ('trumpf.com','TRUMPF SE + Co. KG', true)
on conflict (domain) do nothing;

-- ===== Rollenvergabe: NUR wenn Login-Domain approved ist (SECURITY DEFINER, kein Self-Service) =====
create or replace function public.claim_company_role() returns text
language plpgsql security definer set search_path = public as $$
declare mail text; dom text; comp text;
begin
  select email into mail from auth.users where id = auth.uid();
  if mail is null then return 'no-user'; end if;
  dom := lower(split_part(mail, '@', 2));
  select company_name into comp from public.company_domains where domain = dom and approved;
  if comp is null then return 'waitlist'; end if;                -- freundliche Warteliste im Client
  update public.profiles set role = 'company' where id = auth.uid();
  insert into public.profiles(id, role) select auth.uid(), 'company'
    where not exists (select 1 from public.profiles where id = auth.uid());
  return comp;
end $$;
revoke all on function public.claim_company_role() from public;
grant execute on function public.claim_company_role() to authenticated;

-- ===== Audit: jeder Company-Projektaufruf ist für den Studierenden sichtbar =====
create table if not exists public.company_views (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  company_user uuid not null references auth.users(id) on delete cascade,
  company_name text,
  viewed_at timestamptz not null default now()
);
create index if not exists company_views_project_idx on public.company_views(project_id);
alter table public.company_views enable row level security;
drop policy if exists cviews_insert on public.company_views;
drop policy if exists cviews_read_owner on public.company_views;
create policy cviews_insert on public.company_views for insert to authenticated
  with check (company_user = auth.uid()
    and (select role from public.profiles where id = auth.uid()) = 'company');
create policy cviews_read_owner on public.company_views for select to authenticated
  using (exists (select 1 from public.projects p where p.id = project_id and p.owner = auth.uid()));

-- Kontakt: Companies sehen die Uni-Mail NUR bei expliziter Freigabe (view statt Tabellenzugriff)
create or replace view public.company_project_contacts as
  select p.id as project_id,
         case when p.contact_release then pr.uni_email else null end as uni_email
  from public.projects p
  join public.profiles pr on pr.id = p.owner
  where p.visibility = 'companies_too';

-- ===== RLS-Testnotizen =====
-- 1) Login mit mail@volkswagen.de → select claim_company_role() ⇒ 'Volkswagen AG'; profiles.role='company'.
-- 2) Login mit mail@gmail.com → claim_company_role() ⇒ 'waitlist'; Rolle bleibt 'student'.
-- 3) Company: select projects ⇒ nur companies_too; insert company_views ✓ (nur als company).
-- 4) Student-Owner: select company_views zu eigenem Projekt ✓; zu fremdem ✗.
-- 5) company_project_contacts liefert uni_email NUR bei contact_release=true.
