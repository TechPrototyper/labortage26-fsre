#!/usr/bin/env bash
# Läuft als Benutzer in der VM: Rust-Toolchain, IDE-Erweiterungen.
set -euo pipefail
export LC_ALL=C.UTF-8
export PATH="$HOME/.cargo/bin:$HOME/go/bin:$PATH"
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
log()  { printf '\033[1;34m  ->\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m  !!\033[0m %s\n' "$*" >&2; }

# ---- Rust über rustup (Debian-Paket "rustup", Toolchains von static.rust-lang.org): stable, aktuell bei jedem Lauf
log "Rust: stable-Toolchain mit clippy, rustfmt, rust-analyzer, rust-src und musl-Zielen"
rustup set profile minimal >/dev/null 2>&1 || true
rustup toolchain install stable --profile minimal \
  -c clippy -c rustfmt -c rust-analyzer -c rust-src \
  >/dev/null 2>&1 \
  || warn "rustup toolchain install fehlgeschlagen"
rustup default stable >/dev/null 2>&1 || true
log "$(rustc --version 2>/dev/null || echo 'rustc fehlt')"

# ---- Python-Werkzeuge: pytsk3 (Sleuth-Kit-Anbindung) in einer venv, jefferson (JFFS2) per pipx
if [ ! -x "$HOME/.venvs/fsre/bin/python" ]; then python3 -m venv --system-site-packages "$HOME/.venvs/fsre"; fi
"$HOME/.venvs/fsre/bin/pip" install -q --upgrade pytsk3 >/tmp/pip-pytsk3.log 2>&1 && log "pytsk3 installiert (venv ~/.venvs/fsre)" || warn "pytsk3 nicht installierbar (Log /tmp/pip-pytsk3.log)"
pipx install jefferson >/tmp/pipx-jefferson.log 2>&1 || pipx upgrade jefferson >>/tmp/pipx-jefferson.log 2>&1 || warn "jefferson nicht installierbar (Log /tmp/pipx-jefferson.log)"
pipx ensurepath >/dev/null 2>&1 || true

# ---- IDE-Erweiterungen (Open VSX)
installed="$(codium --list-extensions 2>/dev/null | tr 'A-Z' 'a-z' || true)"
ext() {
  if grep -qix "$(tr 'A-Z' 'a-z' <<<"$1")" <<<"$installed"; then log "Erweiterung $1 vorhanden"; return; fi
  if codium --install-extension "$1" >/dev/null 2>&1; then log "Erweiterung $1 installiert"; else warn "Erweiterung $1 nicht installierbar (übersprungen)"; fi
}
for id in rust-lang.rust-analyzer vadimcn.vscode-lldb tamasfe.even-better-toml golang.go ms-python.python \
          ms-vscode.hexeditor llvm-vs-code-extensions.vscode-clangd \
          ms-vscode.makefile-tools eamodio.gitlens usernamehw.errorlens editorconfig.editorconfig; do
  ext "$id"
done

# ---- Editor-Einstellungen (nur fehlende Schlüssel setzen, eigene Werte bleiben)
cfg="$HOME/.config/VSCodium/User/settings.json"
mkdir -p "$(dirname "$cfg")"
[ -f "$cfg" ] || echo '{}' > "$cfg"
python3 - "$cfg" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
for k, v in {
  "telemetry.telemetryLevel": "off", "update.mode": "none", "workbench.startupEditor": "none",
  "editor.fontSize": 15, "terminal.integrated.fontSize": 14, "debug.console.fontSize": 14,
  "editor.fontFamily": "'Fira Code', 'DejaVu Sans Mono', monospace", "editor.fontLigatures": True,
  "editor.minimap.enabled": False, "window.zoomLevel": 0, "security.workspace.trust.enabled": False,
  "rust-analyzer.check.command": "clippy",
}.items():
    d.setdefault(k, v)
json.dump(d, open(p, "w"), indent=2, ensure_ascii=False)
PY
log "user.sh fertig"
