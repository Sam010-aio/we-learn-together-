# FEATURES — Spezifikation Feed (G), Projekt-Portfolio (H), Company Access (I)

Verbindliche Spec VOR dem Code (Master-Brief G). Deutsch fürs Produkt, englischer Code.
Backend = Supabase (bestehendes Projekt, OTP-Auth, `profiles`-Tabelle vorhanden).
Migrationen: `kommilo-backend/01-feed.sql`, `02-projects.sql`, `03-companies.sql` —
**vom Owner im Supabase SQL-Editor in dieser Reihenfolge VOR dem Merge auszuführen.**

## Grundprinzipien (aus Best-Practice-Recherche verdichtet)
1. **Server ist die Wahrheit**: Jede Sichtbarkeit wird durch RLS erzwungen — die UI filtert nur
   zusätzlich. Kein Client-Trick kann private Daten lesen.
2. **Uni-angemessen statt TikTok-Klon**: kein Endlos-Algorithmus, keine Follower-Grafen,
   chronologischer Campus-Feed mit klaren Limits (Video ≤ 60 s/50 MB, Bild ≤ 10 MB) und
   Moderation ab dem ersten Zeichen (`modCheck` client- + Report-Pipeline serverseitig).
3. **Kill-Switch zuerst**: `app_flags` (Server) schaltet Feed/Projekte/Companies global ab;
   Client liest die Flags beim Boot (Fallback: an, wenn Server nicht erreichbar — Flags sind
   eine Abschalt-Sicherung, keine Freischaltung sensibler Daten; RLS schützt unabhängig).
4. **Datensparsamkeit**: Companies sehen NUR Projekte mit `visibility='companies_too'`,
   niemals Feed-Medien, Chats oder E-Mails; Kontakt nur nach expliziter Freigabe pro Projekt.
5. **Auditierbarkeit**: Jeder Company-Blick auf ein Projekt landet in `company_views` und ist
   für den Studierenden einsehbar; Sichtbarkeit jederzeit widerrufbar.

## G — Campus Feed
- **Tabellen**: `posts` (id, author→auth.users, type text|image|video, storage_path, caption ≤500,
  activity_tag, created_at), `post_likes` (unique post/user), `post_reports` (unique post/reporter).
- **Storage**: Bucket `media` (privat). Pfad-Konvention `feed/<uid>/<uuid>.<ext>`; Anzeige über
  kurzlebige signed URLs (60 min). Upload nur eigener Pfad (Policy prüft `<uid>`-Prefix).
- **Sichtbarkeit**: Lesen = alle Authentifizierten; Insert = Autor; Delete = Autor (GDPR:
  Client löscht erst das Storage-Objekt, dann die Zeile; Reihenfolge dokumentiert im Code).
- **Report-Pipeline**: ≥ 3 Reports ⇒ Post verschwindet aus `feed_visible_posts` (View) bis zur
  Review — kein Client-Ermessen. Eigene Blockliste (`DB.user.blockedUsers`) filtert zusätzlich.
- **Likes**: Insert/Delete auf `post_likes`; Zählung über View `post_like_counts`.
- **UI v1**: Sidebar „Campus Feed": vertikale Karten (Autor-Alias, Zeit, Medium, Caption ≤500
  durch `modCheck`, Like ♥ + Zahl, Melden, eigenes Löschen), Upload mit Fortschritt +
  Client-Validierung (Typ/Größe, Kompressionshinweis). Videos: stumm-Autoplay im Karten-Player,
  Tap = Ton. **v1.1 (dokumentiert, nicht in diesem PR): swipebarer Vollbild-Reels-Player.**
- **Ohne Login/Netz**: Sektion zeigt Gate bzw. Offline-Hinweis; keine Fake-Daten.

## H — Projekt-Portfolio („Projekte & Ideen" im Profil)
- **Tabelle**: `projects` (owner→auth.users, title ≤80, summary ≤280, description ≤5000 (Markdown),
  tags text[≤8], links jsonb [{label,url}] max 5 **nur https**, cover_path (Bucket `media`,
  `projects/<uid>/…`), status idea|in_progress|done, visibility public_students|companies_too|private,
  contact_release bool default false, created/updated).
- **RLS**: Owner schreibt; Lesen: private→Owner, public_students→alle auth. Studierenden,
  companies_too→Studierende UND Companies. Serverseitig erzwungen.
- **UI**: Profil-Abschnitt „Projekte & Ideen": Karten-Grid → Detail; Anlegen/Bearbeiten als
  Wizard (alle Texte durch `modCheck`, Links https-Zwang client- UND serverseitig via CHECK);
  Badge „Von Unternehmen sichtbar" bei companies_too; „Kontaktfreigabe"-Toggle (default AUS)
  zeigt Companies die Uni-Mail; Audit-Liste „Von Unternehmen angesehen" aus `company_views`.

## I — Company Access (kuratiert, read-only)
- **Allowlist statt Self-Service**: `company_domains` (domain, company_name, approved) — Seed
  ~25 seriöse Arbeitgeber; NUR der Owner approved Neuzugänge (Admin-SQL im Migrationskopf).
- **Rollenvergabe**: `profiles.role` ('student' default | 'company'). Nach OTP-Login ruft der
  Client die SECURITY-DEFINER-RPC `claim_company_role()`: setzt die Rolle NUR, wenn die
  Login-Domain ∈ approved Allowlist; sonst freundliche Warteliste (Client-Text). Studierende
  bleiben unberührt (RPC ist für sie ein No-op).
- **Company-UI**: separater Minimal-Modus (eigene Sidebar): „Projekte entdecken" (Suche/Filter
  über Titel/Tags) — ausschließlich `companies_too`-Projekte (RLS), Studierenden-Alias ohne
  E-Mail, Uni-Mail NUR bei `contact_release=true`. Kein Feed, keine Chats, keine Gruppen/Feuer,
  keine Credits. Jeder Projekt-Aufruf schreibt `company_views` (Audit, für Studierende sichtbar).

## Rollout & Betrieb
1. Owner führt `01→02→03` im SQL-Editor aus (idempotent, `if not exists` durchgängig).
2. Deploy des Clients (dieser PR). Flags: `select * from app_flags` — `feed`, `projects`,
   `companies` einzeln abschaltbar (`update app_flags set enabled=false where key='feed'`).
3. RLS-Testnotizen stehen am Ende jeder Migrationsdatei (als SQL-Kommentare, mit zwei
   Test-Usern durchspielbar).
