# labortage26-fsre – Experimentiermaschine für „File System Analysis“

Lima-VM (Debian 13 ARM64, Apple Virtualization.framework) für den Workshop *File System Analysis* von CyReVolt
(Labortage 2026 / [Folien](https://metaspora.org/file-system-analysis-mrmcd2026.pdf), CC BY 4.0).
Komplett skriptgesteuert und idempotent; gleiches Gerüst wie `labortage26-kubers`.

```bash
./run-all.sh        # Mac-Tooling, VM, Software, Repos, Test, Herunterfahren + StartFsre-Icon
```

Enthalten: ImHex 1.38.1 (arm64-AppImage, gepinnt), bless/wxhexeditor/okteta/hexedit/xxd, The Sleuth Kit (`fls`, `icat`, `mmls`),
binwalk (`-E` = Entropie), foremost/scalpel, testdisk, radare2, Kaitai Struct, reveng (CRC-Parameter) + python3-crcmod, pytsk3, jefferson (CRC-Varianten durchprobieren),
mkfs-Werkzeuge für FAT/ext4/SquashFS/exFAT/NTFS/btrfs/XFS/F2FS/EROFS, Python (construct, numpy, matplotlib),
C, Go, Rust, VSCodium (+ Hex-Editor, Python, Rust), Chromium, Claude Code / OpenCode / Qwen Code.

Ordner in der VM: `~/Projects/fsre/{labortage26-fsre, intel_fw, code→Mac}`; `code` liegt auf dem Mac
(`~/Projects/fsre/code`) und überlebt jeden VM-Neuaufbau. Eigene Abbilder gern dort ablegen.
`labortage` zeigt auf den Mac-Ordner `~/Projects/labortage` (Folien, Firmware-Abbilder `fsanalyse/`, Analyse-Notizen).

`examples/`: `mktoy.py` (erfindet ein Mini-Dateisystem), `parse_toy.py` (Parser), `toy.hexpat` (ImHex-Muster),
`crcbrute.py` (CRC-Variante finden), `mfs_analyze.py` + `docs/ANALYSE-MFS-ME8.md` (Beispielanalyse: Intel-ME-8-Dateisystem). Die Workshop-Tipps: Ausrichtung 16 B…64 K, Little Endian,
runde Zahlen/Grenzen = Offsets, hohe Entropie in 2–4 Byte = Prüfsumme, globale Dateioffsets ausgeben.
