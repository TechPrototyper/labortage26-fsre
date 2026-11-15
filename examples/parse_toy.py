#!/usr/bin/env python3
"""Parser für toy.img (siehe mktoy.py): listet die Dateien und prüft die CRCs."""
import struct, sys, zlib
img = open(sys.argv[1] if len(sys.argv) > 1 else "toy.img", "rb").read()
magic, ver, bs, n, dir_off = struct.unpack_from("<4sHHII", img, 0)
assert magic == b"TOYF", "kein TOYF-Dateisystem"
for i in range(n):
    name, off, size, crc = struct.unpack_from("<20sIII", img, dir_off + 32 * i)
    data = img[off:off + size]
    ok = "OK" if zlib.crc32(data) == crc else "CRC FALSCH"
    print(f"{name.rstrip(chr(0).encode()).decode():12} {size:6} Byte @0x{off:x}  {ok}")
