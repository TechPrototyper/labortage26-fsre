#!/usr/bin/env python3
"""Workshop-Hinweis: "hohe Entropie in 2 oder 4 Byte -> Prüfsumme; CRC16/32-Varianten einfach durchprobieren".
Aufruf: crcbrute.py DATEI OFFSET LÄNGE CHKOFFSET [BREITE=4]
Probiert alle Standard-CRC-Varianten (crcmod.predefined) über DATEI[OFFSET:OFFSET+LÄNGE], beide Byte-Reihenfolgen."""
import sys, crcmod.predefined as p
f, off, ln, chk = sys.argv[1], int(sys.argv[2], 0), int(sys.argv[3], 0), int(sys.argv[4], 0)
w = int(sys.argv[5]) if len(sys.argv) > 5 else 4
d = open(f, "rb").read()
data, stored = d[off:off + ln], d[chk:chk + w]
want = {int.from_bytes(stored, "little"), int.from_bytes(stored, "big")}
for name in p._crc_definitions_by_name:
    try:
        v = p.mkPredefinedCrcFun(name)(data)
    except Exception:
        continue
    if v in want:
        print("TREFFER:", name, hex(v))
