#!/usr/bin/env bash
# e) Abnahmetest in der VM: Werkzeuge, Browser, KI-Werkzeuge, Beispiel-Dateisysteme anlegen und parsen.
set -euo pipefail
export LC_ALL=C.UTF-8
export PATH="$HOME/.cargo/bin:$HOME/go/bin:$PATH:/opt/node/bin:$HOME/.npm-global/bin:$HOME/.local/bin"
pass() { printf '\033[1;32m  PASS\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m  FAIL\033[0m %s\n' "$*"; exit 1; }
ex="$HOME/Projects/fsre/labortage26-fsre/examples"
[ -d "$ex" ] && pass "Beispiele vorhanden" || fail "Beispiele fehlen"
[ -L "$HOME/Projects/fsre/code" ] && [ -d "$HOME/Projects/fsre/code" ] && pass "code -> Mac-Ordner" || fail "code-Link"

# 1. Werkzeuge
for t in xxd hexedit python3 gcc go rustc cargo file binwalk fls icat mmls testdisk foremost mkfs.vfat mkfs.ext4 mcopy mksquashfs 7z; do
  command -v "$t" >/dev/null 2>&1 && pass "$t" || fail "$t fehlt"
done
command -v imhex >/dev/null 2>&1 && [ -x /opt/imhex/AppRun ] && pass "ImHex (AppImage entpackt)" || fail "ImHex"
python3 -c 'import construct; print(construct.version)' >/dev/null 2>&1 && pass "python3-construct" || fail "construct"
codium --version >/dev/null 2>&1 && pass "VSCodium" || fail "codium"

# 2. Eigenes Toy-Dateisystem: erzeugen, mit Python parsen, Hexdump zeigt Magic
t="$(mktemp -d)"; trap 'rm -rf "$t"' EXIT
python3 "$ex/mktoy.py" "$t/toy.img"
python3 "$ex/parse_toy.py" "$t/toy.img" | grep -q 'hello.txt.*OK' && pass "Toy-FS: Python-Parser" || fail "Toy-FS Parser"
[ "$(xxd -l4 -p "$t/toy.img")" = 544f5946 ] && pass "Toy-FS: Magic TOYF im Hexdump" || fail "Magic"

# 3. Echte Dateisysteme: FAT, ext4 -> mit The Sleuth Kit auslesen
echo "hallo fat" > "$t/a.txt"
truncate -s 8M "$t/fat.img"; mkfs.vfat "$t/fat.img" >/dev/null
mcopy -i "$t/fat.img" "$t/a.txt" ::A.TXT
fls "$t/fat.img" | grep -qi 'a.txt' && pass "FAT: fls listet Datei" || fail "FAT fls"
[ "$(icat "$t/fat.img" "$(fls "$t/fat.img" | awk '/A.TXT/ {print $2}' | tr -d :)")" = "hallo fat" ] && pass "FAT: icat liest Inhalt" || fail "FAT icat"
mkdir "$t/root"; cp "$t/a.txt" "$t/root/"
truncate -s 16M "$t/ext.img"; mkfs.ext4 -q -d "$t/root" "$t/ext.img"
fls "$t/ext.img" | grep -q a.txt && pass "ext4: fls listet Datei" || fail "ext4 fls"
mksquashfs "$t/root" "$t/sq.img" -quiet >/dev/null 2>&1 && file "$t/sq.img" | grep -qi squashfs && pass "SquashFS erzeugt" || fail "SquashFS"
# Datei-Carving: foremost findet ein eingebettetes PNG im Rohabbild
convert -size 8x8 xc:red "$t/x.png"
cat "$t/fat.img" "$t/x.png" > "$t/raw.img"
foremost -q -t png -i "$t/raw.img" -o "$t/carve" >/dev/null 2>&1; ls "$t"/carve/png/* >/dev/null 2>&1 && pass "foremost: PNG aus Rohabbild geschnitten" || fail "foremost"
binwalk "$t/raw.img" 2>/dev/null | grep -qi png && pass "binwalk erkennt PNG im Abbild" || fail "binwalk"

# 4. Parser in C, Go und Rust (Workshop: "eine Sprache zum Parser-Schreiben")
cat > "$t/p.c" <<'C'
#include <stdio.h>
#include <string.h>
int main(int c,char**v){FILE*f=fopen(v[1],"rb");char m[4];fread(m,1,4,f);return memcmp(m,"TOYF",4)!=0;}
C
gcc -o "$t/pc" "$t/p.c" && "$t/pc" "$t/toy.img" && pass "C-Parser" || fail "C"
mkdir "$t/go" && cat > "$t/go/main.go" <<'G'
package main
import ("os";"fmt";"bytes")
func main(){b,_:=os.ReadFile(os.Args[1]);if !bytes.HasPrefix(b,[]byte("TOYF")){os.Exit(1)};fmt.Println("go-ok")}
G
(cd "$t/go" && go run main.go "$t/toy.img" | grep -q go-ok) && pass "Go-Parser" || fail "Go"
cat > "$t/p.rs" <<'R'
fn main(){let b=std::fs::read(std::env::args().nth(1).unwrap()).unwrap();std::process::exit(if b.starts_with(b"TOYF"){0}else{1})}
R
rustc -o "$t/prs" "$t/p.rs" 2>/dev/null && "$t/prs" "$t/toy.img" && pass "Rust-Parser" || fail "Rust"

# 5. Browser
chromium --version >/dev/null 2>&1 && pass "$(chromium --version)" || fail "chromium"
[ "$(xdg-settings get default-web-browser 2>/dev/null)" = chromium.desktop ] && pass "Standard-Browser: Chromium" || fail "Standard-Browser"
dom="$(timeout 60 chromium --headless=new --no-sandbox --disable-gpu --dump-dom 'data:text/html,<p id=t>browser-ok</p>' 2>/dev/null || true)"
grep -q 'browser-ok' <<<"$dom" && pass "Chromium rendert (headless)" || fail "Chromium headless"

# 6. KI-Werkzeuge und Erweiterungen
for c in claude opencode qwen; do
  v="$("$c" --version 2>/dev/null | head -1 || true)"
  [ -n "$v" ] && pass "$c $v" || fail "$c nicht gefunden"
done
for e in anthropic.claude-code sst-dev.opencode qwenlm.qwen-code-vscode-ide-companion saoudrizwan.claude-dev github.copilot-chat \
         rust-lang.rust-analyzer golang.go ms-python.python ms-vscode.hexeditor; do
  codium --list-extensions 2>/dev/null | grep -qix "$e" && pass "Erweiterung $e" || fail "Erweiterung $e"
done
[ -f "$HOME/Fsre.code-workspace" ] && pass "Workspace-Datei" || fail "Workspace-Datei"
echo "Alle Tests bestanden."
