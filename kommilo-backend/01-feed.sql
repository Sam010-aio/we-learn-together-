-- KOMMILO 01-feed.sql — Campus Feed (Workstream G)
-- Idempotent: kann mehrfach im Supabase SQL-Editor laufen. VOR dem Client-Deploy ausführen.

-- ===== Kill-Switch-Flags (Server = Wahrheit) =====
create table if not exists public.app_flags (
  key text primary key,
  enabled boolean not null default true,
  updated_at timestamptz not null default now()
);
insert into public.app_flags(key, enabled) values ('feed', true), ('projects', true), ('companies', true)
  on conflict (key) do nothing;
alter table public.app_flags enable row level security;
drop policy if exists app_flags_read on public.app_flags;
create policy app_flags_read on public.app_flags for select to authenticated using (true);
-- Schreiben nur via SQL-Editor/Service-Role (kein Policy-Insert/Update für Clients).

-- ===== Posts =====
create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  author uuid not null references auth.users(id) on delete cascade,
  type text not null check (type in ('text','image','video')),
  storage_path text,                                   -- media/feed/<uid>/... ; null bei type='text'
  caption text check (char_length(caption) <= 500),
  activity_tag text,
  created_at timestamptz not null default now(),
  constraint media_needs_path check (type = 'text' or storage_path is not null)
);
create index if not exists posts_created_idx on public.posts (created_at desc);
alter table public.posts enable row level security;
drop policy if exists posts_read   on public.posts;
drop policy if exists posts_insert on public.posts;
drop policy if exists posts_delete on public.posts;
create policy posts_read   on public.posts for select to authenticated using (true);
create policy posts_insert on public.posts for insert to authenticated with check (author = auth.uid());
create policy posts_delete on public.posts for delete to authenticated using (author = auth.uid());

-- ===== Likes =====
create table if not exists public.post_likes (
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);
alter table public.post_likes enable row level security;
drop policy if exists likes_read   on public.post_likes;
drop policy if exists likes_insert on public.post_likes;
drop policy if exists likes_delete on public.post_likes;
create policy likes_read   on public.post_likes for select to authenticated using (true);
create policy likes_insert on public.post_likes for insert to authenticated with check (user_id = auth.uid());
create policy likes_delete on public.post_likes for delete to authenticated using (user_id = auth.uid());

create or replace view public.post_like_counts as
  select post_id, count(*)::int as likes from public.post_likes group by post_id;

-- ===== Reports (≥3 ⇒ ausgeblendet bis Review) =====
create table if not exists public.post_reports (
  post_id uuid not null references public.posts(id) on delete cascade,
  reporter uuid not null references auth.users(id) on delete cascade,
  reason text check (char_length(reason) <= 200),
  created_at timestamptz not null default now(),
  primary key (post_id, reporter)
);
alter table public.post_reports enable row level security;
drop policy if exists reports_insert on public.post_reports;
drop policy if exists reports_read_own on public.post_reports;
create policy reports_insert on public.post_reports for insert to authenticated with check (reporter = auth.uid());
create policy reports_read_own on public.post_reports for select to authenticated using (reporter = auth.uid());

create or replace view public.feed_visible_posts as
  select p.* from public.posts p
  where (select count(*) from public.post_reports r where r.post_id = p.id) < 3;

-- ===== Storage: privater Bucket `media`; Upload nur in den eigenen <uid>-Prefix =====
insert into storage.buckets (id, name, public) values ('media','media', false)
  on conflict (id) do nothing;
drop policy if exists media_read   on storage.objects;
drop policy if exists media_insert on storage.objects;
drop policy if exists media_delete on storage.objects;
create policy media_read   on storage.objects for select to authenticated
  using (bucket_id = 'media');
create policy media_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'media'
    and (storage.foldername(name))[1] in ('feed','projects')
    and (storage.foldername(name))[2] = auth.uid()::text);
create policy media_delete on storage.objects for delete to authenticated
  using (bucket_id = 'media' and (storage.foldername(name))[2] = auth.uid()::text);

-- ===== RLS-Testnotizen (mit 2 Test-Usern A/B durchspielen) =====
-- 1) Als A: insert posts(author=A) ✓ ; insert posts(author=B) ✗ (RLS).
-- 2) Als B: select posts ✓ (lesen erlaubt); delete auf A-Post ✗.
-- 3) 3× report (A2, B, C) auf einen Post ⇒ er verschwindet aus feed_visible_posts.
-- 4) Storage: A kann nach feed/<A>/x.jpg hochladen ✓, nach feed/<B>/x.jpg ✗.
-- 5) GDPR: Client löscht zuerst storage-Objekt, dann posts-Zeile (Code-Kommentar in index.html).
