# FEATURES — Spezifikation Campus Feed (G), Projekt-Portfolio (H), Company Access (I)

Verbindliche Spec **vor** dem Code (Master-Brief). Deutsch fürs Produkt, englischer Code.
Backend = bestehendes Supabase-Projekt (OTP-Auth, `profiles`-Tabelle vorhanden; die App
upsertet beim Login bereits `profiles(id, uni_email)`).

**Migrationen — vom Owner im Supabase-SQL-Editor in dieser Reihenfolge VOR dem Merge ausführen:**
`kommilo-backend/01-feed.sql` → `02-projects.sql` → `03-companies.sql`.
Alle idempotent (`create … if not exists`, `on conflict … do nothing/update`), mehrfach lauffähig.

## Grundprinzipien (aus Best-Practice-Recherche verdichtet)
1. **Server ist die Wahrheit.** Jede Sichtbarkeit wird per RLS erzwungen; die UI filtert nur
   zusätzlich. Kein Client-Trick liest private Daten. Views laufen mit `security_invoker=true`,
   damit RLS des Aufrufers greift (kein Owner-Bypass).
2. **Uni-angemessen statt TikTok-Klon.** Kein Endlos-Algorithmus, keine Follower-Graphen, keine
   Personen-Rankings. Chronologischer Campus-Feed mit harten Limits (Bild ≤ 10 MB; Video
   ≤ 60 s / ≤ 50 MB; nur `jpg/png/mp4/webm`) und Moderation ab dem ersten Zeichen (`modCheck`
   clientseitig + serverseitige Report-Pipeline).
3. **Kill-Switch zuerst.** `app_flags` (Server) schaltet Feed/Projekte/Companies global ab. Der
   Client liest die Flags beim Boot (Fallback = an; Flags sind eine Abschalt-Sicherung, keine
   Freigabe sensibler Daten — RLS schützt unabhängig).
4. **Datensparsamkeit.** Companies sehen NUR Projekte mit `visibility='companies_too'`, niemals
   Feed-Medien (Storage-Policy blockt die `feed/`-Ablage für die Rolle `company`), Chats oder
   E-Mails. Kontakt erst nach expliziter Freigabe pro Projekt.
5. **Auditierbarkeit.** Jeder Company-Blick auf ein Projekt landet in `company_views` und ist für
   die Studierende Person einsehbar; Sichtbarkeit jederzeit widerrufbar.

## G — Campus Feed & Reels
- **Tabellen** (`01-feed.sql`): `posts` (id, author→auth.users, type `text|image|video`,
  storage_path, caption ≤ 500, activity_tag, created_at), `post_likes` (unique post/user),
  `post_reports` (unique post/reporter).
- **Storage**: privater Bucket `media`. Pfad-Konvention `feed/<uid>/<uuid>.<ext>`. Anzeige über
  kurzlebige **signed URLs** (60 min). Upload nur in den eigenen `<uid>`-Prefix (Policy).
  Lesen der `feed/`-Objekte nur für Rolle `student` (Companies sehen nie Feed-Medien).
- **Sichtbarkeit**: Lesen = alle Authentifizierten; Insert/Delete = Autor. **DSGVO-Löschung**:
  der Client entfernt ERST das Storage-Objekt, DANN die Zeile (Reihenfolge im Code kommentiert).
- **Report-Pipeline**: ≥ 3 Reports ⇒ Post fällt aus der View `feed_visible_posts` bis zur Review —
  kein Client-Ermessen. Eigene Blockliste (`DB.user.blockedUsers`) filtert zusätzlich clientseitig.
- **Likes**: Insert/Delete auf `post_likes`; Zählung über View `post_like_counts`.
- **Feed-UI**: Sidebar-Sektion „Campus Feed": vertikale Karten (Autor-Alias, Zeit, Medium,
  Caption ≤ 500 durch `modCheck`, ♥ Like + Zahl, Melden, Blockieren, eigenes Löschen). Upload-
  Flow mit Fortschritts-/Ladeanzeige + Client-Validierung (Typ/Größe/Dauer + Kompressionshinweis).
  Bilder lazy; Video-Karten: stumm-Autoplay, Tap = Ton.
- **Reels-Player**: „▶ Reels"-Button öffnet einen **swipebaren Vollbild-Player** (vertikales
  Scroll-Snap über alle Videos): stumm-Autoplay des sichtbaren Clips (IntersectionObserver),
  Tap schaltet Ton, Wisch/Scroll = nächstes Video, ✕ schließt. Kein Autoplay-Ton (Browser-Policy).
- **Ohne Login/Netz/Flag**: Sektion zeigt Gate/Offline-/Pausiert-Hinweis; keine Fake-Daten.

## H — Projekt-Portfolio („Projekte & Ideen" im Profil)
- **Tabelle** (`02-projects.sql`): `projects` (owner→auth.users, title ≤ 80, summary ≤ 280,
  description ≤ 5000 (Markdown), tags text[] ≤ 8, links jsonb `[{label,url}]` max 5 **nur https**
  (client- UND serverseitig per Trigger erzwungen), cover_path (Bucket `media`, `projects/<uid>/…`),
  status `idea|in_progress|done`, visibility `public_students|companies_too|private`,
  contact_release bool default **false**, created/updated).
- **RLS**: Owner schreibt (`for all`); Lesen: `private`→Owner, `public_students`→alle
  Studierenden, `companies_too`→Studierende UND Companies. Rollen-getrennt, serverseitig erzwungen.
- **UI**: Profil-Abschnitt „Projekte & Ideen" — Karten-Grid → Anlegen/Bearbeiten als Wizard
  (Titel/Kurzfassung/Beschreibung/Tags/Links/Status/Sichtbarkeit + optionales Cover-Bild ≤ 10 MB;
  alle Texte durch `modCheck`, Links-https client + Server). Badge „Von Unternehmen sichtbar" bei
  `companies_too`; „Kontaktfreigabe"-Toggle (default AUS) gibt Companies die Uni-Mail frei;
  Audit-Zeile „N× von Unternehmen angesehen" aus `company_views`.

## I — Company Access (kuratiert, read-only) — `03-companies.sql`
- **Allowlist statt Self-Service**: `company_domains` (domain, company_name, approved) — Seed
  ~25 seriöse deutsche Arbeitgeber (approved). Neuzugänge NUR per Admin-Snippet (Owner, im
  Migrationskopf dokumentiert).
- **Rollenvergabe**: `profiles.role` (`student` default | `company`). Nach OTP-Login ruft der
  Client die SECURITY-DEFINER-RPC `claim_company_role()`: setzt die Rolle NUR, wenn die
  Login-Domain ∈ approved Allowlist; sonst freundliche Warteliste (Client-Text). Für
  Studierende ein No-op.
- **Company-UI**: separater Minimal-Modus (eigene Sidebar „Projekte entdecken" + Einstellungen).
  Suche/Filter über Titel/Tags — ausschließlich `companies_too`-Projekte (RLS). Studierenden-Alias
  ohne E-Mail; Uni-Mail nur via RPC `company_get_contact()` bei `contact_release=true`. Kein Feed,
  keine Chats, keine Gruppen/Feuer, keine Credits, kein Matching. Jeder Projekt-Aufruf schreibt
  `company_views` (Audit, für Studierende sichtbar).
- **Kontakt/Datenschutz**: die frühere Kontakt-View wurde durch die RPC `company_get_contact()`
  (SECURITY DEFINER, Rollen- + Freigabe-Check) ersetzt — so kann kein anderer Nutzer über eine
  RLS-lose View fremde Uni-Mails abgreifen.

## Rollout & Betrieb
1. Owner führt `01 → 02 → 03` im SQL-Editor aus (in dieser Reihenfolge; `role` wird bereits in
   `01` angelegt, weil `02`s Policies darauf verweisen).
2. Client-Deploy (dieser PR). Flags prüfen/schalten: `select * from app_flags;`
   `update app_flags set enabled=false where key='feed';` (analog `projects`, `companies`).
3. RLS-Testnotizen stehen am Ende jeder Migrationsdatei (mit zwei Test-Usern A/B durchspielbar).

## CAMPUS PULS — der Feed als lebendige Oberfläche (Owner-Brief, ersetzt die Sidebar-Sektion)
Der Feed ist kein Menüpunkt mehr, sondern der sichtbare Herzschlag des Campus — in ≤3 s
spürbar, ohne Klick. Migration: `kommilo-backend/04-puls.sql` (nach 01–03).

**1 · Puls-Fenster** (Signature-Element): schwebende Glaskarte ~220×360 unten rechts über den
Stat-Chips, atmet 1–2 px. Zykelt die neuesten Posts STUMM (~6 s, dünner Fortschrittsring),
Autor-Chip + Tag, sanfter Parallax-Tilt auf dem Medium. Hover: ♥/↗; Tap sonst = Theater.
Smart: pausiert bei offenem Modal/Gate, verstecktem Tab und während Kamera-Drag (nie GPU von
der Interaktion stehlen — max. EIN dekodierendes Video, Vorschau bevorzugt Thumbnail).
Einklappbar zum pulsierenden Punkt; Zustand persistiert (`puls_ui_v1`). Leerer Feed: NIE
Fake-Aktivität — klar gelabelte „Kommilo-Redaktion · Starter"-Karten + warmer CTA
(„Zeig den Campus deinen Leuten — poste das erste Reel 🎬"); ehrliche Zahlen, keine erfundenen.

**2 · Puls-Theater**: kein schwarzer Screen — die 3D-Welt bleibt geblurrt/gedimmt sichtbar,
zentrierter vertikaler Player (Glas, Indigo-Edge-Glow). Vertikales Snap-Scrollen (Wheel/Touch/
Pfeiltasten), Tap = Ton, Doppel-Tap = ♥ (mit Herz-Burst). Rechte Rail: Like, Kommentar
(≤300, modCheck), In-App-Teilen (in einen aktiven Match-Chat), Melden; Autor-Chip → Mini-Profil
(nur Alias, Blockieren). Caption + tappbare Tags (#Modul → Filter „Lernen", #Aktivität →
„Aktivitäten"); Filter-Chips oben: Alles · Mein Studiengang · Aktivitäten · Lernen.
ANTI-DOOMSCROLL: nach ~5 min Karte „Genug gescrollt — dein Lerntisch wartet 😉" mit
„Zur Lerngruppe" / „5 min weiter" — nie blockierend, nichts wird invasiv geloggt (nur ein
flüchtiger Sekundenzähler im Speicher). Exit = weiches Schrumpfen zurück ins Mini-Fenster.

**3 · In-World Puls**: (a) **Litfaßsäule** (~1,2 m Ø, 3 m) auf dem Studierendenhaus-Vorplatz:
3 aktuelle Post-Plakate als Textur, dreht sanft, glüht nachts, Klick → Theater. (b) **Puls-Board**:
schlanker Landscape-Screen im Studierendenhaus nahe dem Eingang, zykelt Top-Posts als Bild.
(c) **Ort-Bubbles**: Posts mit Ort-Tag (Studierendenhaus/Terrasse/Lagerfeuer) erscheinen als
Polaroid-Bubble über dem Ort (Billboard-Sprite, Thumb + Autor-Punkt), max. 5, ältere blasser;
Klick → Theater. **Performance-Gesetz**: NUR Texturen (kein In-World-Video-Decode), Medien lazy,
alle Animationen ausschließlich auf ohnehin gerenderten Frames (On-Demand-Renderer bleibt Chef).

**Creation-Flow** (3 Taps): „＋" auf Fenster/Theater → Datei (Video ≤60 s/50 MB, Bild ≤10 MB)
→ Caption ≤300 (modCheck) → optionale Tags Modul/Aktivität/Ort (aktueller 3D-Ort als Chip) →
Posten. Client generiert beim Upload ein Thumbnail (Canvas-Frame-Grab) → `thumb_path`; optimistische
Karte „Wird veröffentlicht …" sofort im Fenster. Fortschritt: unbestimmter Ring (supabase-js v2
liefert keine Upload-Progress-Events — dokumentierte Annäherung).

**Bewusst dokumentierte Abweichungen (v1.1-Kandidaten)**: Kommilo-Sticker-Pack (Brief: optional)
noch nicht enthalten; In-World-Video-Decode nahe der Litfaßsäule bewusst weggelassen (Texturen
genügen, Performance-Gesetz); echter %-Fortschritt beim Upload s. o.

## Bekannte, bewusst akzeptierte Restrisiken (v1)
- `media_read` erlaubt jeder Rolle das Lesen von `projects/<uid>/…`-Objekten bei bekanntem Pfad
  (Pfad enthält UUID → nicht erratbar). Feed-Objekte sind für Companies gesperrt. Eine feinere
  Bindung „Cover nur bei sichtbarem Projekt" ist v1.1 (dokumentiert, nicht in diesem PR).
