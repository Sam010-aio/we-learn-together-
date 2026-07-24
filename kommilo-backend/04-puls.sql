-- KOMMILO 04-puls.sql — „Campus Puls" (lebendiges Reels/Posts-Erlebnis; baut auf 01-feed.sql auf)
-- Idempotent. NACH 01 → 02 → 03 im Supabase-SQL-Editor ausführen (VOR dem Client-Merge).

-- Neue Post-Felder: Client-generiertes Vorschaubild + Tags (Modul/Aktivität existiert, Ort neu).
alter table public.posts add column if not exists thumb_path text;   -- media/feed/<uid>/…_t.jpg (Canvas-Frame-Grab — das Mini-Fenster braucht damit NIE Video-Decode)
alter table public.posts add column if not exists module_tag text check (module_tag is null or char_length(module_tag) <= 60);
alter table public.posts add column if not exists place_tag  text check (place_tag  is null or char_length(place_tag)  <= 60);
-- activity_tag existiert bereits aus 01-feed.sql.

-- Kill-Switch NUR für die Puls-Oberflächen (Fenster/Theater/In-World); Posting bleibt unter 'feed'.
insert into public.app_flags(key, enabled) values ('puls', true) on conflict (key) do nothing;

-- View neu erzeugen, damit `p.*` die neuen Spalten mitliefert (Report-Schwelle ≥3 unverändert).
create or replace view public.feed_visible_posts with (security_invoker = true) as
  select p.* from public.posts p where public.post_report_count(p.id) < 3;

-- ===== Kommentare (kurz; Client moderiert via modCheck, Server begrenzt die Länge) =====
create table if not exists public.post_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  author uuid not null references auth.users(id) on delete cascade,
  text text not null check (char_length(text) between 1 and 300),
  created_at timestamptz not null default now()
);
create index if not exists post_comments_post_idx on public.post_comments(post_id, created_at);
alter table public.post_comments enable row level security;
drop policy if exists pcom_read   on public.post_comments;
drop policy if exists pcom_insert on public.post_comments;
drop policy if exists pcom_delete on public.post_comments;
create policy pcom_read   on public.post_comments for select to authenticated using (true);
create policy pcom_insert on public.post_comments for insert to authenticated with check (author = auth.uid());
create policy pcom_delete on public.post_comments for delete to authenticated using (author = auth.uid());

create or replace view public.post_comment_counts with (security_invoker = true) as
  select post_id, count(*)::int as comments from public.post_comments group by post_id;

-- ===== RLS-Testnotizen =====
-- 1) Als A: Kommentar auf sichtbaren Post ✓ (author=A); Kommentar als B löschen ✗, eigenen ✓.
-- 2) insert post_comments mit 301 Zeichen ⇒ Check-Fehler.
-- 3) update app_flags set enabled=false where key='puls' ⇒ Client blendet Mini-Fenster,
--    Theater und alle In-World-Puls-Flächen aus (Posting-Backend bleibt unter 'feed' steuerbar).
-- 4) Thumb-Upload media/feed/<uid>/…_t.jpg fällt unter dieselbe Prefix-Policy wie das Medium (01).
