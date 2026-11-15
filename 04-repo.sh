#!/usr/bin/env bash
# d) Projektverzeichnisse in der VM einrichten (idempotent):
#   ~/Projects/fsre/labortage26-fsre     dieses Repository
#   ~/Projects/fsre/code                   Verknüpfung auf den Mac-Ordner $LAB_CODE_DIR (eigener Code, bleibt erhalten)
# Weitere Repositories legst du einfach als weitere Ordner unter ~/Projects/fsre/ ab.
source "$(dirname "$0")/lib.sh"
vm_running || die "VM läuft nicht - erst 02-vm.sh"
mkdir -p "$LAB_CODE_DIR"

vm_sh bash -s "$LAB_ENV_REPO_URL" <<'GUEST'
set -euo pipefail
base="$HOME/Projects/fsre"
mkdir -p "$base"
clone_or_pull() { # url dir
  if [ -d "$2/.git" ]; then
    echo "  -> $(basename "$2") vorhanden, aktualisiere"
    git -C "$2" pull --ff-only || echo "  !! pull nicht möglich (lokale Änderungen?) - übersprungen" >&2
  else
    echo "  -> Klone $1"
    git clone "$1" "$2"
  fi
  git -C "$2" log --oneline -1
}
# Dieses Repo: ist es (noch) nicht öffentlich erreichbar, bleibt der Ordner leer und wird unten vom Mac kopiert.
clone_or_pull "$1" "$base/labortage26-fsre" || echo "  !! Repo nicht klonbar (noch nicht veröffentlicht?) - wird vom Mac kopiert" >&2
# Intel-ME-Flash-Werkzeug aus dem Workshop (Rust): Beispiel für "Dateisystem eines Firmware-Images" (MFS)
clone_or_pull https://github.com/platform-system-interface/intel_fw.git "$base/intel_fw" || echo "  !! intel_fw nicht klonbar" >&2
ln -sfn /mnt/code "$base/code"
[ -d "$base/code" ] || { echo "  !! $base/code zeigt ins Leere - ist der Mount /mnt/code vorhanden?" >&2; exit 1; }
GUEST

# Fallback: Repo nicht per git in der VM vorhanden -> lokalen Stand vom Mac hinüberkopieren
if ! vm_sh bash -c 'test -d "$HOME/Projects/fsre/labortage26-fsre/.git"' 2>/dev/null; then
  log "Kopiere dieses Repository vom Mac in die VM"
  vm_sh bash -c 'mkdir -p "$HOME/Projects/fsre/labortage26-fsre"'
  limactl copy -r "$LAB_DIR/." "$VM_NAME:Projects/fsre/labortage26-fsre/"
fi

log "Desktop-Starter"
vm_sh bash -s < "$LAB_DIR/guest/desktop.sh"
