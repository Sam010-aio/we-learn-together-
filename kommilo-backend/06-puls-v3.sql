-- KOMMILO 06-puls-v3.sql — Campus Puls v3 (Reels + Posts, Read-Time-Scope aus Autorprofilen)
-- Idempotent. NACH 01–05 ausführen. Baut additiv auf der bestehenden posts-Tabelle auf.

-- ===== posts: kind (reel|post), media_type, text (getrennt von caption) =====
alter table public.posts add column if not exists kind text not null default 'reel'
  check (kind in ('reel','post'));
alter table public.posts add column if not exists media_type text
  check (media_type is null or media_type in ('none','image','video'));
alter table public.posts add column if not exists "text" text
  check ("text" is null or char_length("text") <= 300);
-- Bestehende Zeilen sinnvoll einordnen (type war 'text'|'image'|'video' aus 01):
update public.posts set media_type = case when type='video' then 'video' when type='image' then 'image' else 'none' end
  where media_type is null;
update public.posts set kind = case when type='video' then 'reel' else 'post' end
  where kind is null;

-- ===== profiles: Scope-Felder für den Read-Time-Join (Autoren taggen NIE selbst) =====
alter table public.profiles add column if not exists university text;
alter table public.profiles add column if not exists program text;
alter table public.profiles add column if not exists modules text[];

-- View mit neuen Spalten neu erzeugen (Report-Schwelle ≥3 unverändert; post_report_count aus 04)
create or replace view public.feed_visible_posts with (security_invoker = true) as
  select p.* from public.posts p where public.post_report_count(p.id) < 3;

-- ===== Read-RPC: Scope serverseitig aus dem Autorprofil ableiten =====
-- p_scope ∈ 'uni'|'program'|'module'|'all' ; p_kind ∈ 'reel'|'post'|NULL(beides).
create or replace function public.feed(p_scope text, p_kind text) returns setof public.posts
language sql security definer set search_path = public stable as $$
  with me as (select university, program, modules from public.profiles where id = auth.uid())
  select p.*
    from public.posts p
    join public.profiles a on a.id = p.author
   where (p_kind is null or p.kind = p_kind)
     and public.post_report_count(p.id) < 3
     and (
          coalesce(p_scope,'uni') = 'all'
       or (p_scope = 'uni'     and a.university is not null and a.university = (select university from me))
       or (p_scope = 'program' and a.program   is not null and a.program   = (select program   from me))
       or (p_scope = 'module'  and a.modules is not null and (select modules from me) is not null and a.modules && (select modules from me))
     )
   order by p.created_at desc
   limit 60 $$;
revoke all on function public.feed(text,text) from public;
grant execute on function public.feed(text,text) to authenticated;

-- ===== RLS-Testnotizen =====
-- 1) A(uni=TUBS,program='Informatik',modules={Mathe 2}) postet reel+post; B(uni=TUBS) sieht sie unter scope='uni';
--    C(anderer Uni) sieht sie NUR unter scope='all'.
-- 2) scope='program' zeigt nur Autoren mit identischem program; scope='module' nur bei Modul-Überschneidung (&&).
-- 3) feed(NULL,'reel') liefert nur Reels; feed('all','post') nur Posts.
-- 4) 3× report auf einen Post ⇒ fällt aus feed() UND feed_visible_posts (post_report_count>=3).
-- 5) Autoren OHNE profiles.university/program/modules erscheinen nur unter scope='all' (Client upsertet diese beim Login/Profil-Speichern).
