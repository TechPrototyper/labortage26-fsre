#!/usr/bin/env bash
# Läuft als root in der VM. Idempotent: alles prüft vorher, was schon da ist.
set -euo pipefail
export LC_ALL=C.UTF-8
export DEBIAN_FRONTEND=noninteractive
: "${LAB_USER:?LAB_USER fehlt}"

log()  { printf '\033[1;34m  ->\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m  !!\033[0m %s\n' "$*" >&2; }
mkdir -p /var/lib/lab

# ---------------------------------------------------------------- Paketlisten
# Alles aus Debian 13, soweit vorhanden (echtes Debian, keine fremden Paketquellen außer VSCodium).
REQUIRED="build-essential git make gdb pkg-config curl ca-certificates gnupg xz-utils unzip cmake jq ripgrep fd-find
  tmux fzf shellcheck bash-completion xxd hexedit bvi
  python3 python3-pip python3-venv python3-construct python3-pytest ipython3 python3-numpy python3-matplotlib python3-crcmod
  golang-go rustup
  binutils file binwalk
  sleuthkit testdisk foremost
  dosfstools e2fsprogs mtools squashfs-tools exfatprogs ntfs-3g btrfs-progs xfsprogs f2fs-tools erofs-utils
  default-jre-headless libtsk-dev python3-kaitaistruct pipx
  p7zip-full unar lz4 zstd lzop cabextract qemu-utils
  x11-utils x11-xserver-utils xdotool xvfb imagemagick xfce4 xfce4-terminal lightdm lightdm-gtk-greeter dbus-x11
  xserver-xorg-core xserver-xorg-input-libinput fonts-dejavu fonts-liberation fonts-firacode mousepad locales zenity
  chromium"
# Nicht jedes Paket gibt es in jeder Debian-Version; fehlende werden übersprungen und gemeldet.
OPTIONAL="wxhexeditor okteta ghex hexyl scalpel ewf-tools gddrescue fatcat libguestfs-tools dcfldd htop tree ncdu lsof"
avail() { LC_ALL=C apt-cache policy "$1" 2>/dev/null | awk '/Candidate:/ {print ($2 != "(none)" && $2 != "")}' | grep -q 1; }

log "apt update"
apt-get update -qq
log "Pflichtpakete"
# shellcheck disable=SC2086
apt-get install -y -qq $REQUIRED
log "Optionale Pakete"
want=(); skipped=()
for p in $OPTIONAL; do if avail "$p"; then want+=("$p"); else skipped+=("$p"); fi; done
[ ${#want[@]} -gt 0 ] && apt-get install -y -qq "${want[@]}" || true
[ ${#skipped[@]} -gt 0 ] && warn "Nicht verfügbar (übersprungen): ${skipped[*]}"

# ------------------------------------------------- Bildschirmsperre entfernen
# Das Lab-Konto hat kein Passwort; eine Sperre würde die Sitzung aussperren.
apt-get purge -y -qq xfce4-screensaver light-locker 2>/dev/null || true

# ------------------------------------------------------------ Locale/Tastatur
# Meldungen und Programmsprache: Englisch (en_US.UTF-8). Deutsch bleiben die Tastatur (de, siehe unten) sowie
# Zahlen-, Datums- und Währungsformat, Maßeinheiten und Papierformat (LC_*=de_DE.UTF-8).
if ! locale -a | grep -qi '^en_US.utf8' || ! locale -a | grep -qi '^de_DE.utf8'; then
  sed -i 's/^# *\(de_DE.UTF-8 UTF-8\)/\1/; s/^# *\(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen
  locale-gen >/dev/null
fi
want_locale='LANG=en_US.UTF-8
LC_NUMERIC=de_DE.UTF-8
LC_TIME=de_DE.UTF-8
LC_MONETARY=de_DE.UTF-8
LC_PAPER=de_DE.UTF-8
LC_MEASUREMENT=de_DE.UTF-8
LC_NAME=de_DE.UTF-8
LC_ADDRESS=de_DE.UTF-8
LC_TELEPHONE=de_DE.UTF-8'
if [ "$(cat /etc/default/locale 2>/dev/null)" != "$want_locale" ]; then
  printf '%s\n' "$want_locale" > /etc/default/locale
  echo 1 > /var/lib/lab/needs-reboot      # neue Anmeldung/Neustart nötig, damit die Sitzung es übernimmt
fi
cat > /etc/default/keyboard <<'KBD'
XKBMODEL="pc105"
XKBLAYOUT="de"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
KBD
timedatectl set-timezone Europe/Berlin 2>/dev/null || ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime

# ------------------------------------------------------ Desktop / Autologin
mkdir -p /etc/lightdm/lightdm.conf.d
want_conf="[Seat:*]
autologin-user=$LAB_USER
autologin-user-timeout=0
autologin-session=xfce
"
if [ "$(cat /etc/lightdm/lightdm.conf.d/50-lab.conf 2>/dev/null)" != "${want_conf%$'\n'}" ]; then
  printf '%s' "$want_conf" > /etc/lightdm/lightdm.conf.d/50-lab.conf
  touch /var/lib/lab/needs-reboot; echo 1 > /var/lib/lab/needs-reboot
fi
echo /usr/sbin/lightdm > /etc/X11/default-display-manager
if [ "$(systemctl get-default)" != graphical.target ]; then
  systemctl set-default graphical.target
  echo 1 > /var/lib/lab/needs-reboot
fi
systemctl enable lightdm >/dev/null 2>&1 || true

# ------------------------------------------------------------------ VSCodium
# Offizielles Repo des VSCodium-Projekts (Open-Source-Build von VS Code ohne Telemetrie).
if ! dpkg -s codium >/dev/null 2>&1; then
  log "VSCodium installieren"
  curl -fsSL https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg \
    | gpg --dearmor --yes -o /usr/share/keyrings/vscodium-archive-keyring.gpg
  cat > /etc/apt/sources.list.d/vscodium.sources <<'SRC'
Types: deb
URIs: https://download.vscodium.com/debs
Suites: vscodium
Components: main
Architectures: amd64 arm64
Signed-by: /usr/share/keyrings/vscodium-archive-keyring.gpg
SRC
  apt-get update -qq
  apt-get install -y -qq codium
else
  log "VSCodium bereits installiert"
fi


# Hilfsprogramme aus dem Repo (labzoom); 03-provision.sh legt sie in /tmp/fsre-bin ab
if [ -d /tmp/fsre-bin ]; then
  install -m 755 /tmp/fsre-bin/* /usr/local/bin/
fi

# Weitere Werkzeuge, die es in Debian 13 nicht gibt: gepinnte Pakete/Quellen mit SHA-256-Prüfung
fetch_verified() { # url sha256 ziel
  curl -fsSL -o "$3" "$1"
  echo "$2  $3" | sha256sum -c --status || { echo "Prüfsumme falsch: $1" >&2; exit 1; }
}
install_deb() { # name url sha256
  if [ "$(cat "/var/lib/lab/$1.sha" 2>/dev/null)" = "$3" ]; then log "$1 bereits installiert"; return; fi
  log "Installiere $1"
  tmp="$(mktemp -d)"; fetch_verified "$2" "$3" "$tmp/p.deb"
  apt-get install -y -qq "$tmp/p.deb"; echo "$3" > "/var/lib/lab/$1.sha"; rm -rf "$tmp"
}
install_deb radare2 https://github.com/radareorg/radare2/releases/download/6.2.6/radare2_6.2.6_arm64.deb 527a8c8a970d5d5013d46ba20d50ef884e33650285c9b3ced64f225b87b7573d
install_deb kaitai-struct-compiler https://github.com/kaitai-io/kaitai_struct_compiler/releases/download/0.11/kaitai-struct-compiler_0.11_all.deb 28d6b6ec917e394ed41cb6f62169a8f6b584d9a5242cbe0785b0568d95e032ea
# CRC RevEng (Greg Cook): CRC-Parameter aus Beispielen bestimmen (Workshop-Tipp "CRC-Varianten durchprobieren")
REVENG_SHA=914146bf7f4a4467826904cb913d5d21dc5c2997ef24fa7cf9bdcc43eccf15f0
if [ "$(cat /var/lib/lab/reveng.sha 2>/dev/null)" != "$REVENG_SHA" ] || ! command -v reveng >/dev/null; then
  log "reveng 3.0.5 bauen"
  tmp="$(mktemp -d)"; fetch_verified "https://sourceforge.net/projects/reveng/files/3.0.5/reveng-3.0.5.tar.gz/download" "$REVENG_SHA" "$tmp/r.tgz"
  tar -xzf "$tmp/r.tgz" -C "$tmp"
  # 64-Bit-Wortbreite (sonst bricht der Selbsttest "configuration fault" ab)
  sed -i -e 's/^#define BMP_BIT   32/#define BMP_BIT   64/' -e 's/^#define BMP_SUB   16/#define BMP_SUB   32/' "$tmp/reveng-3.0.5/config.h"
  make -C "$tmp/reveng-3.0.5" -j"$(nproc)" >/dev/null 2>&1 || make -C "$tmp/reveng-3.0.5" >/dev/null
  install -m 755 "$tmp/reveng-3.0.5/reveng" /usr/local/bin/reveng
  echo "$REVENG_SHA" > /var/lib/lab/reveng.sha; rm -rf "$tmp"
else
  log "reveng bereits installiert"
fi

# ImHex (Hex-Editor mit Mustersprache; nicht in Debian): offizielles arm64-AppImage, SHA-256 gepinnt, entpackt (kein FUSE nötig)
IMHEX_VER=1.38.1
IMHEX_SHA=9a334bb59a825eb0b218c19ea3ca3f9c2d524957fa2de6a6feeb8f035a45acc3
if [ "$(cat /var/lib/lab/imhex.sha 2>/dev/null)" != "$IMHEX_SHA" ] || [ ! -x /opt/imhex/AppRun ]; then
  log "ImHex $IMHEX_VER installieren"
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/imhex.AppImage" "https://github.com/WerWolv/ImHex/releases/download/v$IMHEX_VER/imhex-$IMHEX_VER-arm64.AppImage"
  echo "$IMHEX_SHA  $tmp/imhex.AppImage" | sha256sum -c --status || { echo "Prüfsumme ImHex falsch" >&2; exit 1; }
  chmod +x "$tmp/imhex.AppImage"
  (cd "$tmp" && ./imhex.AppImage --appimage-extract >/dev/null)
  rm -rf /opt/imhex; mv "$tmp/squashfs-root" /opt/imhex
  echo "$IMHEX_SHA" > /var/lib/lab/imhex.sha
  rm -rf "$tmp"
else
  log "ImHex bereits installiert"
fi
# Wrapper statt Symlink: AppRun findet sein Verzeichnis sonst nicht
rm -f /usr/local/bin/imhex
printf '#!/bin/sh\nexec /opt/imhex/AppRun "$@"\n' > /usr/local/bin/imhex
chmod 755 /usr/local/bin/imhex

mkdir -p /etc/profile.d
cat > /etc/profile.d/fsre.sh <<'FSRE'
case ":$PATH:" in *":$HOME/.cargo/bin:"*) ;; *) export PATH="$HOME/.cargo/bin:$PATH" ;; esac
case ":$PATH:" in *":$HOME/go/bin:"*) ;; *) export PATH="$PATH:$HOME/go/bin" ;; esac
FSRE
grep -q 'fsre.sh' /etc/bash.bashrc || printf '\n[ -r /etc/profile.d/fsre.sh ] && . /etc/profile.d/fsre.sh\n' >> /etc/bash.bashrc

log "system.sh fertig"
