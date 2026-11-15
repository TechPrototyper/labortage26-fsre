#!/usr/bin/env bash
# Läuft als Benutzer, nachdem die Repos geklont sind: Autostart für labzoom, Workspace, Desktop-Starter.
set -euo pipefail
export LC_ALL=C.UTF-8
log() { printf '\033[1;34m  ->\033[0m %s\n' "$*"; }

mkdir -p "$HOME/Desktop" "$HOME/.config/labzoom" "$HOME/.config/autostart"
cat > "$HOME/.config/autostart/labzoom.desktop" <<AUTO
[Desktop Entry]
Type=Application
Name=Anzeigegröße anwenden
Exec=/usr/local/bin/labzoom apply
Terminal=false
X-GNOME-Autostart-Phase=Initialization
AUTO

# Standard-Browser: Chromium (Debian). Google Chrome gibt es für Linux nur für x86_64, nicht für ARM64.
xdg-settings set default-web-browser chromium.desktop >/dev/null 2>&1 || true
mkdir -p "$HOME/.config/xfce4"
if grep -q '^WebBrowser=' "$HOME/.config/xfce4/helpers.rc" 2>/dev/null; then
  sed -i 's/^WebBrowser=.*/WebBrowser=chromium/' "$HOME/.config/xfce4/helpers.rc"
else
  echo 'WebBrowser=chromium' >> "$HOME/.config/xfce4/helpers.rc"
fi

# Workspace mit eigenem Code und diesem Repo
cat > "$HOME/Fsre.code-workspace" <<'WS'
{
  "folders": [
    { "name": "code (liegt auf dem Mac)", "path": "Projects/fsre/code" },
    { "name": "intel_fw", "path": "Projects/fsre/intel_fw" },
    { "name": "examples", "path": "Projects/fsre/labortage26-fsre/examples" },
    { "name": "labortage26-fsre", "path": "Projects/fsre/labortage26-fsre" }
  ]
}
WS

mk() { # mk <Datei> <Name> <Exec> <Icon> [Terminal]
  f="$HOME/Desktop/$1.desktop"
  cat > "$f" <<DESK
[Desktop Entry]
Type=Application
Name=$2
Exec=$3
Icon=$4
Terminal=${5:-false}
StartupNotify=false
DESK
  chmod +x "$f"
}
mk fsre-ide     "Fsre IDE"              "codium \$HOME/Fsre.code-workspace"                         vscodium
mk fsre-term    "Terminal"              "xfce4-terminal --working-directory=\$HOME/Projects/fsre"   utilities-terminal
mk fsre-imhex   "ImHex (Hex-Editor)"    "sh -c 'command -v imhex >/dev/null && exec imhex || exec bless'"  accessories-text-editor
mk fsre-zoom    "Anzeigegröße"          "/usr/local/bin/labzoom pick"                                preferences-desktop-font
rm -f "$HOME/Desktop/labcomp-"*.desktop

# Als vertrauenswürdig markieren (sonst fragt XFCE bei jedem Start nach). Braucht den Session-Bus.
bus="/run/user/$(id -u)/bus"
if [ -S "$bus" ]; then
  for f in "$HOME"/Desktop/fsre-*.desktop; do
    sum="$(sha256sum "$f" | cut -d' ' -f1)"
    DBUS_SESSION_BUS_ADDRESS="unix:path=$bus" gio set -t string "$f" metadata::xfce-exe-checksum "$sum" 2>/dev/null \
      && DBUS_SESSION_BUS_ADDRESS="unix:path=$bus" gio set "$f" metadata::trusted true 2>/dev/null || true
  done
else
  echo "  !! kein Session-Bus - Starter nicht als vertrauenswürdig markiert (beim ersten Start bestätigen)" >&2
fi
log "Desktop-Starter angelegt"

# Gewählte Anzeigegröße sofort anwenden (nicht kritisch, wenn keine Sitzung läuft)
/usr/local/bin/labzoom apply || true
