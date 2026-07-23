# SITEPLAN V2 — Verbindlicher Lageplan (aus dem Satellitenbild vermessen)

Ersetzt V1. Koordinaten = App-Koordinaten: Ursprung = Mitte Studierendenhaus, X=Ost, Z=Süd, Meter.
Kalibrierung: SH-Dach 33×26 m, Gegenprobe Audimax ≈48×36 m. Toleranz ±3 m. Dieser Umbau ist
**reine Transform-Arbeit** (Gruppen verschieben/drehen, Straßen/Fluss/Platz-Polygone neu zeichnen,
Filler löschen) — **keine Gebäude neu modelliert**.

## Positionstabelle (umgesetzt)
| Objekt | Mittelpunkt (X,Z) | Ausrichtung | Umsetzung |
|---|---|---|---|
| Studierendenhaus | (0, 0) | fix | unverändert am Ursprung |
| Pockelsstraße (Achse) | X≈+20, Z −170…+35 | N-S, direkt östlich am SH | Asphalt-Rückgrat + Gehwege + Platanenreihen |
| Altgebäude | (+4, −78) U-Block | Prachtfront OSTEN an der Pockelsstraße | Owner: N-S-Prachtflügel an der Straße + Nordflügel (0,7×) + kurzer Südflügel (0,3×) am kleinen Parkplatz → 3 unterschiedlich lange Seiten (nicht identisch). Kein Neubau: Geometrie geteilt |
| Audimax | (+57, −53) | Glasfront WESTEN | Gruppe → (+57,−53), rot −90° |
| Forum-Komplex | (+70, −110) | Riegel N-S | Owner-Korrektur: Riegel 90° nach rechts (im Uhrzeigersinn) gedreht, in-place um die Inhalts-Mitte |
| Forumsplatz | X≈+60, Z −75…−90 | zwischen Audimax & Forum | uf-Ensemble nach Osten geschoben |
| Okerhochhaus | (+21, −169) | Nordende der Achse | Gruppe → (+21,−169), rot 0 |
| Abt-Jerusalem-Str. | Z≈−21, X +20…+115 | E-W | neu gezeichnet |
| Schleinitzstraße | Z≈−137, X −70…−10 | E-W | neu gezeichnet |
| Oker (Punktzug) | (−95,−19)→(−74,−5)→(−44,+16)→(−20,+34)→SO | umschließt SW am SH | `okerX` = stückweise-lineare Interpolation; Boden mit Fluss-Loch |
| Pockelsstraßen-Brücke | (≈−20, +32) | quert Oker SÜDLICH des SH | verschoben auf `okerX(32),+32` |
| Wohnzeilen Ost (Kulisse) | X +95…+115, Z −60…+25 | rote Satteldächer | eastHouses respread |
| Wohnbebauung Nordost | X +75…+115, Z −180…−140 | Kulisse | Kinzig-Haus hierher verschoben |

## Bewusste Abweichungen / gelöschte Filler
1. **Bibliothek** und der alte **Verbindungssteg** stehen NICHT in der V2-Tabelle → Bibliothek
   ausgeblendet; der Steg würde bei den neuen, ~90 m auseinanderliegenden Gebäuden „quer über den
   Rasen" schweben (verboten) → **ausgeblendet** statt platziert.
2. **Kinzig-Haus** (nicht in der Tabelle) → als NO-Wohnkulisse nach (96,−158) verschoben.
3. **Parkhof/Promenade/Ufergasse** (V1-Elemente) entfernt bzw. durch das Straßennetz ersetzt.
4. Der Fluss-Querschnitt nutzt X-Offsets (wie zuvor); auf dem diagonalen SW-Lauf leicht geschert —
   Topologie (SW-Bogen sichtbar) hat Vorrang, Budget-Disziplin.

## Prüfung
`window.__kommilo3d.verifySitePlan()` im Browser → alle Zeilen PASS (Positionen ±3 m,
Orientierungen, Straßen, SW-Oker, Südbrücke, kein schwebender Steg, Validator-Nullstände).
Boot-Log: `[VEG] … 0 Verstöße` + `[LIGHT] …`.
