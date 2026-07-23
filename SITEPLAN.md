# SITEPLAN — Verbindlicher Lageplan (App-Koordinaten)

Quelle: `KOMMILO SITE-DOSSIER` (7 Video-Clips, 84 Frames, kalibriert über Türhöhe 2,10 m /
Geschoss 3,30 m / PKW 4,5 m; Toleranz ±10–15 %). Jede Weltänderung in `index.html` zitiert
diese Tabelle. Abweichende Positionen werden im Review abgelehnt.

## Koordinaten-Abbildung Dossier → App

Dossier: X=Ost, Z=Süd, Ursprung = Forumsplatz-Mitte. Das Studierendenhaus (SH) bleibt aus
Bestandsschutz (Interaktion, Klick-Ziele, Kamera-Presets) am App-Ursprung. Daraus folgt:

```
app_x = x_dossier + 15        app_z = z_dossier − 150
```

App −z = Norden (Richtung Campus-Kern), App +x = Osten. Prüfanker: SH Dossier (−15,+150) →
App (0,0) ✓; Forumsplatz-Mitte Dossier (0,0) → App (15,−150).

## Solltabelle (App-Koordinaten, Gebäudemittelpunkte)

| Objekt | App (x, z) | Grundfläche B×T | Höhe | Rotation | Dossier-Ref |
|---|---|---|---|---|---|
| Studierendenhaus | (0, 0) | 32×28 m | 7,4 m | 0° | Teil A, B1/B2 |
| Forumsplatz-Mitte | (15, −150) | 60×45 m Platz | — | — | Teil A, B4 |
| Altgebäude | (15, −98) | 105 (O-W) × 16 (N-S) m | 18 m (Risalit 21) | Portal-Langfront → Nord (−z, zum Platz) | Teil A, B4 |
| Okerhochhaus | (53, −72) | 26 (lang) × 15 m | 47 m (13 OG à 3,3 + Sockel + Technik) | 12° (Langseite ≈ parallel Altgebäude-Rückseite) | Teil A, B5, C2 |
| Parkhof | zwischen Altgebäude-Süd (z=−90) und Turm-Nord (z≈−80) sowie östl. Flügel | Asphalt + Klinkerzufahrten, Hainbuchen-Hecken 1,2 m | — | — | B5 |
| Verbindungsbrücke | Altgebäude-OSTfassade (Südende, x=67,5, z≈−94) ↔ Turm-WESTstirn (≈(40,−75)) | L ≈ 30–33 m (diagonal über Parkhof), B 3 m | OK Boden +7,0 m | folgt Anker-Achse | Teil A, B5, C3 |
| Audimax-Halle | (7, −188) | 42 (O-W) × 30 m | 12 m | Glasfront → Süd (+z, zum Platz) | Teil A, B6 |
| Forumsgebäude-Riegel | (7, −202) | 52 × 16 m | 24 m; schwebt 4,5 m auf Rundstützen über Sockelflügel | 0° | Teil A, B6 |
| Vordach-Pergola | Platzrand West + Süd des Audimax, L-Band 5 m tief | OK 4,2 m, Platte 0,45 m, Holzlamellen-Untersicht | — | L-förmig | B6 |
| Bibliothek | (−40, −140) | 45 × 35 m | 16 m | 0° | Teil A |
| Kinzig-Giebelhaus | (70, −86) | 22 × 12 m | Traufe 9 / First 13,5 m | −8°; PV-Feld auf SÜD-Dachfläche | Teil A, B7, C10 |
| Promenade (B3) | Achse x ≈ −24, z −100 … −186 (zw. Altgebäude-Westflanke und Bib/Forum) | Breite 12–14 m, Fischgrät-Klinker + Granitbänder, beidseitig Hecken-Rasenstreifen | — | N-S | B3, C8 |
| Oker-Flussachse | x ≈ 83, N–S, sanfte S-Kurve | Wasserbreite 12–15 m | Wasserspiegel −2,5 m, beidseitige Böschungen | — | Teil A, B8, C6 |
| Pockelsstraßen-Brücke | (83, −40) | Spannweite 18 m (O-W) × 14 m breit | Fahrbahn 0 m | quert Fluss O–W | Teil A, B8 |
| Ufergasse (B7) | x ≈ 76, N-S entlang Westufer | Asphaltgasse + verzinktes 2-Gurt-Geländer (1,1 m), Blockbalken-Bänke | — | — | B7 |
| Forumsplatz-Ausstattung | Statue ≈ (12, −118) (12 m vor Risalit, leicht W); Lichtstelen 2 Reihen à 4–5 (Raster 8 m) die Achse rahmend; 3–4 Fahnenmasten (8 m) am Audimax-Rand; flaches Brunnenbecken mit Sitzrand | — | — | — | B4 |
| Audimax-Plaza | vor der Glasfront, 2 Stufen unter Promenadenniveau | Anthrazit-Platten 0,8×0,8 + Mosaikbänder + Kies-Felder + Beton-Sitzblöcke (2,4 m) + Corten | — | — | B6 |

## Verbindliche Regeln (aus Teil C/D)

- **C1** Städtisches Ensemble: Kernbereich = Plätze/Promenaden/Parkhöfe, Rasen NUR als
  heckengefasste Streifen. Keine Riesen-Wiese zwischen den Kerngebäuden.
- **C3** Brücke bündig Fassade↔Fassade, geschlossen verglast, 2 Stützenpaare, KEINE freien
  Enden. Länge folgt der realen Anker-Geometrie dieser Tabelle (≈ 30–33 m diagonal).
- **C4** Vegetationsgesetz: Kronenansatz ≥ 3 m; nahe Gebäuden Krone über Traufe; KEINE
  Durchdringung Baum↔Gebäude/Brücke/Lichtkette (Build-Time-Validator, Log der Verstöße);
  kein Baum höher als der Turm (47 m).
- **C5** Lichterketten NUR nach `LIGHT_PLAN` (Trauf-Anker 3,2–3,6 m + Platz-Masten),
  Kettenlinien-Durchhang, Segment-vs-AABB-Prüfung mit Re-Routing, Log.
- **C6** Fluss eingeschnitten (−2,5 m), weiche bewachsene Böschungen beidseits, KEIN flaches
  Band auf Rasen; Straßenbrücke nach Tabelle; Holzsteg optional weiter nördlich NUR mit
  Widerlagern in den Böschungen.
- **C9** Interieur SH: helles fugenloses Linoleum (kein Teppich), weiße BAUMSTÜTZEN
  (3–4 gerundete Arme), Holz-Felder-Decke (~3×3 m) mit Ø1,1 m LED-Scheiben, Ø1,8 m Oculi
  mit Geländerringen, offene Stahltreppen mit Holzstufen, bernsteingelbe Vorhänge,
  mintgrüne Sitzsäcke.

## Bewusste, dokumentierte Abweichungen

1. **SH-Straße (E1) + Parkplatz (E2)** bleiben an ihrer akzeptierten Position zwischen SH
   und Campus-Kern (real: Straßenraum Pockelsstraße/Abt-Jerusalem-Straße liegt dazwischen —
   Street-View-Frames). Bestandsschutz der interaktiven SH-Zone.
2. **Brücke**: Anker-Geometrie gewinnt. Umsetzung: Rückfassaden-Anker am Ostflügel (60,−90)
   ↔ Turm-Weststirn (≈40.3,−69.3) → Spannweite ≈ 28,6 m (im Dossier-Soll 28–32 ✓), bündig
   1,2 m in beide Fassaden eingebunden, exakt 2 Stützenpaare.
3. Teil A Text nennt den Turm „nordöstlich" hinter dem Altgebäude; die Koordinaten-Tabelle
   und die B4-Sichtachse (Turm erscheint über der Dachkante VOM PLATZ aus) ergeben südöstlich
   HINTER der Portalfront. Die Tabelle gewinnt (Teil D: „implement EXACTLY" auf die Tabelle).
4. **Dossier-interner Überlapp Turm/Kinzig/Fluss**: Mit den Tabellenwerten überschneiden sich
   Turm (53,−72, 12°-Ausdehnung), Kinzig (70,−86, 22 m Firstlänge) und der Kanalkorridor
   (x_d≈68) geometrisch. Auflösung nach Konfliktreihenfolge (Topologie > Einzelmaß, alles
   innerhalb ±10–15 %): Turm bleibt EXAKT auf Tabellenposition; **Kinzig → (67,−91)**
   (3–5 m SE); **Oker-Achse → App-x 90** (x_d 75); **Straßenbrücke → (≈90,−40)**. Die
   Ufergasse (B7) läuft dadurch wie im Video SCHMAL zwischen Kinzig-Ostgiebel und Böschung.
