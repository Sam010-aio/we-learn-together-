-- KOMMILO 03-companies.sql — kuratierter Company Access (Workstream I)
-- Idempotent. NACH 01-feed.sql und 02-projects.sql ausführen.
--
-- ADMIN-SNIPPET (nur Owner, im SQL-Editor) — neue Firma freischalten:
--   insert into public.company_domains(domain, company_name, approved)
--     values ('firma.de','Firma GmbH', true)
--     on conflict (domain) do update set approved = excluded.approved, company_name = excluded.company_name;

-- profiles.role/uni_email existieren bereits aus 01 (defensiv erneut, idempotent):
alter table public.profiles add column if not exists role text not null default 'student';
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

-- ===== Kontakt: Uni-Mail NUR bei Freigabe, NUR für Companies (RPC statt RLS-loser View) =====
-- Ersetzt die frühere View company_project_contacts (die als Owner lief und Mails leaken konnte).
drop view if exists public.company_project_contacts;
create or replace function public.company_get_contact(p_project uuid) returns text
language plpgsql security definer set search_path = public stable as $$
declare my_role text; rel boolean; mail text;
begin
  select role into my_role from public.profiles where id = auth.uid();
  if coalesce(my_role,'student') <> 'company' then return null; end if;     -- nur Companies
  select p.contact_release, pr.uni_email into rel, mail
    from public.projects p join public.profiles pr on pr.id = p.owner
    where p.id = p_project and p.visibility = 'companies_too';
  if not found or not coalesce(rel, false) then return null; end if;        -- nur bei Freigabe
  return mail;
end $$;
revoke all on function public.company_get_contact(uuid) from public;
grant execute on function public.company_get_contact(uuid) to authenticated;

-- ===== RLS-Testnotizen =====
-- 1) Login mit mail@volkswagen.de → select claim_company_role() ⇒ 'Volkswagen AG'; profiles.role='company'.
-- 2) Login mit mail@gmail.com/uni → claim_company_role() ⇒ 'waitlist'; Rolle bleibt 'student'.
-- 3) Company: select projects ⇒ nur companies_too; insert company_views ✓ (nur als company).
-- 4) Student-Owner: select company_views zu eigenem Projekt ✓; zu fremdem ✗.
-- 5) company_get_contact(pid): als Company + contact_release=true ⇒ Uni-Mail; sonst NULL.
--    Als Student ⇒ immer NULL (Rollen-Check).
