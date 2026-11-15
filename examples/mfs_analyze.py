#!/usr/bin/env python3
"""Analyse der EFFS/"MFS"-Partition einer Intel-ME-8-Firmware (Workshop File System Analysis).

Aufruf:  mfs_analyze.py ABBILD [--cells]
  ABBILD = komplettes ME-Region-Abbild (8.x.x.x_*_PRD_RGN.bin, FPT bei 0x10) ODER nur die EFFS-Partition (mfs.bin).
Alle Offsets in der Ausgabe sind GLOBALE Dateioffsets (Workshop-Tipp).
Befunde und Belege: docs/ANALYSE-MFS-ME8.md
"""
import re, struct, sys
from collections import defaultdict

PAGE, SLOT = 0x4000, 0x100

def load(path):
    x = open(path, "rb").read()
    base = 0
    if x[0x10:0x14] == b"$FPT":
        n = struct.unpack_from("<I", x, 0x14)[0]
        for k in range(n):                       # FPT-Eintrag: name[4] owner[4] offset size ... (0x20 Byte)
            o = 0x30 + 0x20 * k
            if x[o:o + 4] == b"EFFS":
                base, size = struct.unpack_from("<II", x, o + 8)
                print(f"FPT: EFFS-Partition @0x{base:x}, Größe 0x{size:x}")
                return x[base:base + size], base
        sys.exit("keine EFFS-Partition in der FPT")
    return x, 0

def entries(m):
    """Seite 0: Tabelle aus 11-Byte-Einträgen ab 0x14, je 'dc 70 ... 01 AA BB' (AA=Slot, BB=Zelle)."""
    out, o = [], 0x14
    while o + 11 <= PAGE and m[o] == 0xdc:
        out.append((o, m[o:o + 11])); o += 11
    return out

def cells(pg, aa, first):
    """Zellen eines 256-Byte-Slots: [Tag][Länge][Nutzdaten], 16-Byte-ausgerichtet; Tag = 0x80 | Flags | Zellnummer."""
    base, q, seq, res = aa * SLOT, None, first, []
    for c in range(base, base + SLOT, 16):
        if pg[c] & 0x80 and (pg[c] & 0xf) == first & 0xf: q = c; break
    while q is not None and q < base + SLOT and pg[q] & 0x80 and (pg[q] & 0xf) == seq & 0xf:
        ln = pg[q + 1]; res.append((q, pg[q], ln)); q = (q + max(ln, 1) + 15) & ~15; seq += 1
    return res

def main():
    path = sys.argv[1]; show = "--cells" in sys.argv
    m, base = load(path)
    print(f"Partition: {len(m)} Byte = {len(m)//PAGE} Seiten à 0x{PAGE:x}")
    print("\nSeiten (Kopf = erste 8 Byte):")
    for i in range(len(m) // PAGE):
        pg = m[i * PAGE:(i + 1) * PAGE]
        used = sum(1 for b in pg if b != 0xff)
        kind = "System" if pg[8:12] == b"MFS\0" else ("frei" if pg[0] == 0xff else "Daten")
        if kind != "frei" or i < 4:
            print(f"  Seite {i:2} @0x{base+i*PAGE:06x}  {kind:6} Kopf={pg[:8].hex(' ')}  belegt={used} Byte")
    ents = entries(m)
    print(f"\nSeite 0: {len(ents)} Einträge à 11 Byte ab 0x{base+0x14:x} (Magic 'MFS' @0x{base+8:x})")
    g = defaultdict(list)
    for _, e in ents: g[e[9]].append(e[10])
    pg1 = m[PAGE:2 * PAGE]
    print("\nSlot (AA) -> Zellen laut Tabelle  |  Zellen, die im Datenseite-1-Slot wirklich gefunden werden")
    for aa in sorted(g):
        f = cells(pg1, aa, min(g[aa]))
        okk = "OK " if [c for c in range(min(g[aa]), min(g[aa]) + len(f))] == sorted(g[aa]) else "?? "
        print(f"  {okk}Slot 0x{aa:02x} @0x{base+PAGE+aa*SLOT:06x}: {sorted(g[aa])}  |  {len(f)} Zellen")
        if show:
            for q, t, ln in f: print(f"        @0x{base+PAGE+q:06x} tag={t:02x} len={ln:3} {pg1[q+2:q+min(ln,22)].hex(' ')}")
    print("\nZeichenketten (>=5) in Seite 1:")
    for s in re.finditer(rb"[\x20-\x7e]{5,}", pg1):
        print(f"  @0x{base+PAGE+s.start():06x} {s.group().decode()}")

if __name__ == "__main__":
    main()
