// ImHex-Muster für toy.img (Pattern Language): Datei > Muster laden
struct Super { char magic[4]; u16 version; u16 block_size; u32 nfiles; u32 dir_offset; };
struct Entry { char name[20]; u32 offset; u32 size; u32 crc32; };
Super sb @ 0x00;
Entry entries[sb.nfiles] @ sb.dir_offset;
