#!/usr/bin/env bash
#
# uninstall_android_studio.sh
# ---------------------------
# Hapus Android Studio, Android SDK, dan seluruh konfigurasi pengguna
# dari mesin Ubuntu Desktop.
#
# • Jalankan dengan sudo.
# • Gunakan --yes untuk mode non-interaktif.

set -euo pipefail

#----------------------------#
#  Helper functions          #
#----------------------------#
ask() {
  # Jika --yes dipakai, langsung jawab ya
  if [[ "${AUTO_CONFIRM:-false}" == "true" ]]; then
    return 0
  fi
  read -rp "$1 [y/N] " ans
  [[ "${ans,,}" == "y" || "${ans,,}" == "yes" ]]
}

info()  { echo -e "\e[1;34m[INFO]\e[0m $*"; }
warn()  { echo -e "\e[1;33m[WARN]\e[0m $*"; }
error() { echo -e "\e[1;31m[ERROR]\e[0m $*"; exit 1; }

#----------------------------#
#  Arg parsing               #
#----------------------------#
AUTO_CONFIRM="false"
for arg in "$@"; do
  case "$arg" in
    --yes|-y) AUTO_CONFIRM="true" ;;
    *) error "Argumen tidak dikenal: $arg" ;;
  esac
done

[[ $EUID -eq 0 ]] || error "Harus dijalankan sebagai root (sudo)."

#----------------------------#
#  1. Hentikan proses Studio #
#----------------------------#
info "Menghentikan proses Android Studio (bila ada)…"
pkill -f "bin/studio.sh" 2>/dev/null || true
pkill -f "idea.Main"      2>/dev/null || true

#----------------------------#
#  2. Lepas paket snap/apt   #
#----------------------------#
if snap list | grep -q "^android-studio"; then
  if ask "Hapus paket snap android-studio?"; then
    info "Menghapus paket snap…"
    snap remove android-studio
  fi
fi

if dpkg -l | grep -q "android-studio"; then
  if ask "Hapus paket apt android-studio?"; then
    info "Menghapus paket apt…"
    apt-get purge --auto-remove -y android-studio
  fi
fi

#----------------------------#
#  3. Hapus folder instalasi #
#----------------------------#
INSTALL_DIRS=(
  "/opt/android-studio"
  "/usr/local/android-studio"
  "$HOME/android-studio"
  "$HOME/Applications/Android Studio"
)

for dir in "${INSTALL_DIRS[@]}"; do
  if [[ -d "$dir" ]]; then
    if ask "Hapus direktori instalasi $dir ?"; then
      info "Removing $dir"
      rm -rf "$dir"
    fi
  fi
done

#----------------------------#
#  4. Hapus Android SDK      #
#----------------------------#
SDK_DIRS=(
  "$HOME/Android/Sdk"
  "/opt/android-sdk"
  "/opt/Android/Sdk"
)

for dir in "${SDK_DIRS[@]}"; do
  if [[ -d "$dir" ]]; then
    if ask "Hapus Android SDK di $dir ?"; then
      info "Removing SDK $dir"
      rm -rf "$dir"
    fi
  fi
done

#----------------------------#
#  5. Hapus konfigurasi user #
#----------------------------#
CONFIG_DIRS=(
  "$HOME/.android"
  "$HOME/.AndroidStudio"*   # versi-spesifik
  "$HOME/.config/Google/AndroidStudio"* 
  "$HOME/.cache/Google/AndroidStudio"*
  "$HOME/.local/share/Google/AndroidStudio"*
)

for pattern in "${CONFIG_DIRS[@]}"; do
  for dir in $pattern; do
    [[ -e "$dir" ]] || continue
    if ask "Hapus konfigurasi $dir ?"; then
      info "Removing $dir"
      rm -rf "$dir"
    fi
  done
done

#----------------------------#
#  6. Bersihkan desktop file #
#----------------------------#
DESKTOP_FILE="/usr/share/applications/android-studio.desktop"
if [[ -f "$DESKTOP_FILE" ]]; then
  if ask "Hapus launcher $DESKTOP_FILE ?"; then
    info "Removing $DESKTOP_FILE"
    rm -f "$DESKTOP_FILE"
  fi
fi

#----------------------------#
#  7. Saran edit shell rc    #
#----------------------------#
warn "Jika ANDROID_HOME, ANDROID_SDK_ROOT, atau PATH masih di-export"
warn "dalam ~/.bashrc, ~/.zshrc, dll, hapus baris tersebut secara manual."

info "Selesai! Android Studio dan komponennya telah dihapus."
