#!/usr/bin/env python3
"""Erzeugt toy.img: ein winziges, selbst erfundenes Dateisystem zum Üben (Reverse Engineering).

Layout (little endian):
  0x000  Superblock: magic "TOYF", u16 version, u16 block_size, u32 nfiles, u32 dir_offset
  dir_offset  je Eintrag 32 Byte: name[20] (NUL-gefüllt), u32 offset, u32 size, u32 crc32
Dateien liegen blockweise ausgerichtet hinter dem Superblock.
"""
import struct, sys, zlib
files = {"hello.txt": b"Hallo Labortage!\n", "secret.bin": bytes(range(256)), "notes.md": b"# Notizen\nDas ist ein Test.\n" * 8}
bs = 512
img = bytearray(bs)
entries = []
for name, data in files.items():
    off = len(img)
    img += data + b"\0" * (-len(data) % bs)
    entries.append((name.encode().ljust(20, b"\0"), off, len(data), zlib.crc32(data)))
dir_off = len(img)
for e in entries:
    img += struct.pack("<20sIII", *e)
img += b"\0" * (-len(img) % bs)
img[0:16] = struct.pack("<4sHHII", b"TOYF", 1, bs, len(entries), dir_off)[:16]
open(sys.argv[1] if len(sys.argv) > 1 else "toy.img", "wb").write(img)
