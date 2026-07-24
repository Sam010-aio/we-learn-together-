-- KOMMILO 05-gender-policy.sql — Geschlechtspräferenz für Matches & Lerngruppen
-- Idempotent. Im Supabase-SQL-Editor ausführen. Groups/Matches liegen aktuell in localStorage
-- (wlt_db_v1); der Client spiegelt dieselben Felder + erzwingt die Eignung client-seitig. Diese
-- Migration setzt die Profil-Wahrheit (gender/pronouns) und die künftige Server-Eignungsfunktion.

-- ===== Profil = Quelle der Wahrheit (inklusive Taxonomie, nie „Andere“) =====
alter table public.profiles add column if not exists gender text
  check (gender is null or gender in ('female','male','nonbinary','prefer_not'));
alter table public.profiles add column if not exists pronouns text
  check (pronouns is null or char_length(pronouns) <= 20);

-- ===== Policy-Felder auf künftigen Server-Records (nur falls die Tabellen existieren) =====
do $$ begin
  if to_regclass('public.groups') is not null then
    alter table public.groups add column if not exists gender_policy text not null default 'mixed'
      check (gender_policy in ('mixed','women_only','men_only'));
    alter table public.groups add column if not exists nonbinary_welcome boolean not null default true;
    alter table public.groups add column if not exists reason_tag text;
  end if;
  if to_regclass('public.matches') is not null then
    alter table public.matches add column if not exists gender_policy text not null default 'mixed'
      check (gender_policy in ('mixed','women_only','men_only'));
    alter table public.matches add column if not exists nonbinary_welcome boolean not null default true;
    alter table public.matches add column if not exists reason_tag text;
  end if;
end $$;

-- ===== Server-Eignung — VOR jeder Credit-Buchung aufrufen (nie ein Credit bei Ausschluss) =====
-- Selbstauskunft: Komfort-/Vertrauens-Setting, KEINE Sicherheitsgrenze.
create or replace function public.can_join_room(p_policy text) returns boolean
language sql security definer set search_path = public stable as $$
  select case
    when p_policy = 'mixed'      then true
    when p_policy = 'women_only' then coalesce((select gender from public.profiles where id = auth.uid()),'') = 'female'
    when p_policy = 'men_only'   then coalesce((select gender from public.profiles where id = auth.uid()),'') = 'male'
    else false end $$;
revoke all on function public.can_join_room(text) from public;
grant execute on function public.can_join_room(text) to authenticated;

-- ===== RLS-Testnotizen =====
-- 1) profiles.gender='female': select can_join_room('women_only') ⇒ true; ='male' ⇒ false; 'mixed' ⇒ immer true.
-- 2) nonbinary/prefer_not: mixed ⇒ true; women_only/men_only ⇒ false (dürfen eigene Räume anlegen; fremde Binärräume gesperrt).
-- 3) gender NULL: women_only/men_only ⇒ false (Client fordert vorher zur Angabe auf).
