# Analyse: EFFS/„MFS“-Dateisystem der Intel Management Engine 8 (Workshop-Material)

Ausgangsmaterial (`~/Projects/labortage/fsanalyse`): Folien `file-system-analysis-mrmcd2026.pdf`, `mfs.bin` (901 120 Byte), `foo.bin` (901 100 Byte)
und das „Intel ME 8 Firmware Repository Pack r11“ (`ime/*.bin`, 53 Abbilder, ME 8.0.0.1178 … 8.1.70.1590).
Alle Offsets unten sind **Dateioffsets** (global), sofern nicht „Seite+…“ dabeisteht. Reproduzierbar mit
`examples/mfs_analyze.py <Abbild> [--cells]`. Gewissheit: **[belegt]** = an allen Abbildern geprüft, **[Hypothese]** = plausibel, nicht bewiesen.

## 1. Woher kommen mfs.bin und foo.bin?
- `mfs.bin` ist **bytegleich** mit dem Bereich 0x3000…0xDF000 von `ime/8.0.0.1178_5MB_PRD_RGN.bin`. [belegt]
- `foo.bin` = `mfs.bin` ab Offset **20** (0x14) – also ohne den 20-Byte-Kopf der Systemseite; es beginnt direkt mit der Eintragstabelle. [belegt]
- Im Abbild steht bei 0x10 `$FPT` (Firmware Partition Table, 0x17 Einträge à 0x20 Byte ab 0x30:
  Name[4], Owner[4], Offset, Größe, …). Der Eintrag **`EFFS`** (Owner `OSID`) zeigt auf Offset 0x3000, Größe 0xDC000 – das ist `mfs.bin`.
  EFFS = „Embedded Flash File System“; das Magic im Inneren heißt „MFS“. [belegt]

## 2. Ebene 1: Seiten
- Größe **0x4000 (16 KiB)**; 0xDC000 / 0x4000 = **55 Seiten** (5-MB-Abbilder), 0x48000 / 0x4000 = **18 Seiten** (1,5-MB-Abbilder). [belegt]
- Seitenkopf (8 Byte): `NN 78 FE FF 00 00 00 00` — `NN` = Seitennummer (00, 01), `78` konstant, `FE FF` = „in Benutzung“; freie Seiten: `FF 78 FF FF 00 00 00 00`. [belegt]
  (In den Folien: `FC FF` bei späteren Seiten → die zwei Bytes sind Statusbits, bei jedem Beschreiben werden Bits gelöscht – typisch für NOR-Flash.) [Hypothese]
- In allen PRD-Abbildern sind **nur Seite 0 und 1 belegt**; Seiten 2…54 sind leer (nur Kopf). [belegt]
  Ausnahmen: `8.0.0.1262_5MB_PRD_EXTR` (Seiten 0–2) und `8.1.3.1325_1.5MB_PRD_EXTR` (Seiten 0–14) – „extrahierte“ Abbilder mit anderem Inhalt.
- **Seite 0 = Systemseite**: Magic `4D 46 53 00` („MFS\0“) bei Seite+8, dann `0F FF FF FF FF FF FF FF` (Seite+0x0C…0x13, in den Folien `1A FE FE FF`; vermutlich Zähler/Statusbytes), danach die Eintragstabelle (Abschnitt 3).
- **Seite 1 = Datenseite** (13 253 von 16 384 Byte belegt).

## 3. Ebene 2: Eintragstabelle in Seite 0 (ab Seite+0x14)
Dichte Folge von **11-Byte-Einträgen**, Aufbau: `DC 70 | b2 b3 | b4 | b5 | b6 | b7 | 01 | AA | BB` [belegt: 68 Einträge in 8.0.0.1178; Anzahl je Abbild siehe unten]

- `DC 70` konstant (Eintragsmarke), `01` konstant (vor der Adresse).
- **`AA.BB` = Adresse einer Zelle in Seite 1**: `AA` = **Slot** (256-Byte-Abschnitt, Seite+AA·0x100), `BB` = **Zellennummer** im Slot. Die Einträge sind nach (AA,BB) sortiert; BB zählt je Slot hoch, AA springt in Sprüngen (0,1,2,4,5,7,8,9,0xB,0xD,0xE,0x10,0x12,0x13,0x14). [belegt]
- Die Felder b2…b7 beschreiben die Zelle (Länge/Typ/Verweise); eindeutig bestätigt nur: b6 + 2 = Länge der Zelle für Slot 1 (`0C` ↔ Länge 14 `0E`). Rest: offen.
- **Anzahl der Einträge** je Abbild: 5-MB-8.0.x: 67–68, 5-MB-8.1.x: 68 (8.1.70: 69), 1,5-MB-8.0.x: 31, 1,5-MB-8.1.x: 32. Die 36–37 zusätzlichen Einträge der 5-MB-Variante sind die AMT-Dateien (Zertifikate, Konfiguration). [belegt]
- Die letzte Zeile (`DC F0 00 01 00 FF 78 00 01 14 01`) weicht ab (F0 statt 70): Abschlussmarke bzw. noch nicht fertig geschriebener Eintrag. [Hypothese]

## 4. Ebene 3: Slots und Zellen in Seite 1
Seite 1 ist in **64 Slots à 256 Byte** unterteilt. Die Zellen eines Slots stehen 16-Byte-ausgerichtet hintereinander:

```
Zelle = [Tag][Länge][Nutzdaten …]        Länge zählt Tag+Länge+Nutzdaten, nächste Zelle bei aufgerundet auf 16
Tag   = 0x80 | Flags | Zellnummer(4 Bit)  0x80 = gültig, 0x20 = letzte Zelle im Slot (a2, a8 …), 0x10 = Fortsetzungs-Slot (90, b0)
```
[belegt für Slots 0…0xB in allen 5-MB- und allen 1,5-MB-Abbildern: die Zellenzahl pro Slot stimmt exakt mit der Tabelle aus Seite 0 überein.]

Slot-Karte 8.0.0.1178 (Seite 1 = Dateioffset 0x7000):

| Slot | Offset | Zellen | Inhalt (soweit erkannt) |
|---|---|---|---|
| 0x00 | 0x7000 | 3 | Header: Bytefeld `00 01 02 … 0C 2F 30 … 36` (0x709D, 21 Byte, vermutlich Dateinummern-Liste); Zellen: `06 "public\0"` (Name), `83 00 00 00`, 16-Byte-Metazelle |
| 0x01 | 0x7100 | 15 | 15 gleich gebaute 14-Byte-Zellen `80 81 NN FF A FF B FF 00 FF 00 00` (NN = 1…F, A/B = Werte wie 0F, 20, 1E, 25 – vermutlich Dateiattribute: Besitzer, Rechte, Größe …; die `FF`-Bytes sind „ungeschriebene“ Füllbytes) |
| 0x02 | 0x7200 | 9 | u. a. `62 42 63 42` („bBcB“), 42 Byte Nullen, Konfigurationszellen |
| 0x04…0x0B | | 2–5 | Konfigurationsdaten (Nullfelder, Zähler), Zelle `$DAT` bei 0x7932 und `IFRP` bei 0x794A; **Energiepakete**: „Desktop: ON in S0, ME Wake in S3, S4-5“, „Mobile: ON in S0, ME Wake in S3, S4-5 (AC only)“ (AMT-Power-Package-Namen) |
| 0x03, 0x06, 0x0A, … | | – | beginnen mit `B0` bzw. `90`: **Fortsetzungs-Slots** zu großen Zellen davor [Hypothese] |
| 0x0C…0x11 | 0x7C00… | – | **Root-Zertifikat-Tabelle** (Erkennung wie auf den Folien „The Power of Recognition“): Namen „VeriSign Class 3 Primary CA-G1/G2/G3/G5“, „Go Daddy Class 2 CA“, „Comodo AAA CA“, „Starfield Class 2 CA“, „GTE CyberTrust Global Root“, „Baltimore CyberTrust Root“, „Cybertrust Global Root“, „Verizon Global Root“, „Entrust.net CA (2048)“, „Entrust Root CA“, „VeriSign Universal Root CA“. Je Eintrag: Name (ASCII, nullgefüllt) + Hash-Typ/Länge (`1E 01` …) + Hash. Das sind die **AMT-Standard-Root-Zertifikat-Hashes** aus dem Intel-AMT-Implementierungsguide. Diese Slots haben **keine** Zellentags; die Tabelle zählt hier andere Zellen (offen). |
| 0x1x | 0x9F11… | – | AMT-Konfiguration: `admin`, `$$uns`, `$$OsAdmin`, `http://localhost:0` (Standard-AMT-Benutzer/Realm), Namenskürzel `NVKR NVTD NVCM NVOS NVSH BIAL PLDM NVCL NVJC NVCP` bei 0xA631…. Das sind Namen von ME-Partitionen/-Datenblöcken (auch in der FPT: `BIAL BIEL BIIS NVCL`) |

## 5. Was daraus über die Struktur folgt
```
EFFS-Partition (FPT-Eintrag "EFFS", 0x3000 / 0xDC000)
└── Seite 0x4000 × 55
    ├── Seite 0  System: 8 B Kopf | "MFS\0" | 8 B Status | 11-B-Tabelle (68 Einträge: AA.BB → Zelle)
    ├── Seite 1  Daten:  8 B Kopf | 64 Slots à 256 B | Zellen [Tag][Länge][Daten] 16-B-ausgerichtet
    └── Seiten 2…54: frei (FF 78 FF FF …)
```
Das ist ein **protokollartiges Flash-Dateisystem** (Seiten wie Löschblöcke, Statusbits, nur Bits löschen). Verzeichnisse und Dateinamen („public“, Namenskürzel) liegen in Slot 0/1; Dateiinhalt in den Zellen dahinter; große Objekte (Zertifikate) laufen über mehrere Slots.

## 6. Offene Fragen (Ideen für die Gruppenarbeit)
1. Bedeutung von b2…b7 der 11-Byte-Einträge (Länge? Verweis auf Eltern? Rechte?) – Hypothese: b6+2 = Zellenlänge; passt nicht für Zelle (0,2) (`A2 10`).
2. `FF`-Füllbytes in Slot 1: 16-Bit-Felder mit gelöschtem oberem Byte, oder redundante Ablage?
3. Prüfsummen: Auf den Folien ein Hinweis „hohe Entropie in 2–4 Byte → CRC“. Bisher nicht untersucht: Zellen/Tabelleneinträge nach 2- oder 4-Byte-Feldern absuchen und mit `examples/crcbrute.py` gegen die Zellendaten probieren.
4. Zuordnung der Slots 0xC…0x11 (Zertifikate) zu den Tabelleneinträgen 0xD/0xE/0x10/0x12–0x14.
5. Was bedeutet die `0F`-Zahl in Seite+0x0C (in den Folien `1A`)? Vergleich mit den 53 Abbildern zeigt `0F` überall außer `8.1.3.1325_1.5MB_PRD_EXTR` (`0F FE FE FF …`).
6. Das Referenzwerkzeug <https://github.com/platform-system-interface/intel_fw> (wird in `~/Projects/fsre/intel_fw` geklont) parst die FPT, aber – Stand heute – nicht den MFS-Inhalt: ein Parser wäre ein schöner Beitrag.

## 7. Methode (so wurde vorgegangen – Workshop-Regeln)
1. `file`/`xxd`: Datei `foo.bin` ≙ `mfs.bin` ab 20 → Verschiebung gefunden (gleiche Bytes, anderer Anfang).
2. Mit `mfs.bin` als Suchmuster im Repository-Pack: 0x3000 in 8.0.0.1178 → FPT gelesen → Partition `EFFS`.
3. Ausrichtung 0x4000 → Seiten; „viele Proben“: EFFS aus allen 53 Abbildern geschnitten, Kopf/Seitenzahl/Tabellenlänge verglichen.
4. Periodizität: `DC 70` alle 11 Byte → Tabelle. Zählen ergab (AA,BB)-Adressen, die genau zu den 256-Byte-Slots in Seite 1 passen (Test an allen Abbildern).
5. Strings (`strings`, hier `re`) verraten Inhalte: Zertifikatsnamen, Energiepakete, `admin`.
