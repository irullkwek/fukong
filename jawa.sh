#!/usr/bin/env bash
#
# uninstall_android_studio_force.sh
# ---------------------------------
# Paksa hapus SELURUH jejak Android Studio & Android SDK di Ubuntu.
#
# Jalankan:
#   sudo ./uninstall_android_studio_force.sh
#
# Tested on Ubuntu 22.04–24.04.

set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "[ERR] Harus dijalankan sebagai root (sudo)." >&2; exit 1; }

log() { echo -e "\e[1;34m[INFO]\e[0m $*"; }

# 1. Tutup IDE
log "Menutup proses Android Studio…"
pkill -f "bin/studio.sh" 2>/dev/null || true
pkill -f "idea.Main"      2>/dev/null || true
sleep 1

# 2. Purge paket APT (jika ada)
if dpkg -l | grep -q "android-studio"; then
  log "Menghapus paket APT android-studio…"
  apt-get purge --auto-remove -y android-studio
fi

# 3. Hapus direktori instalasi IDE
for dir in \
  /opt/android-studio \
  /usr/local/android-studio \
  "$HOME/android-studio" \
  "$HOME/Applications/Android Studio" \
  "$HOME/.local/share/JetBrains/Toolbox/apps/AndroidStudio"*; do
  [[ -d $dir ]] && { log "Removing $dir"; rm -rf "$dir"; }
done

# 4. Hapus Android SDK
for dir in \
  "$HOME/Android/Sdk" \
  /opt/android-sdk \
  /opt/Android/Sdk; do
  [[ -d $dir ]] && { log "Removing $dir"; rm -rf "$dir"; }
done

# 5. Hapus cache & konfigurasi
for pattern in \
  "$HOME/.android" \
  "$HOME/.AndroidStudio"* \
  "$HOME/.cache/Google/AndroidStudio"* \
  "$HOME/.local/share/Google/AndroidStudio"* \
  "$HOME/.config/Google/AndroidStudio"* \
  "$HOME/.cache/JetBrains/AndroidStudio"* \
  "$HOME/.local/share/JetBrains/AndroidStudio"* \
  "$HOME/.config/JetBrains/AndroidStudio"*; do
  for d in $pattern; do
    [[ -e $d ]] && { log "Removing $d"; rm -rf "$d"; }
  done
done

# 6. Hapus launcher, ikon, aturan udev
for f in \
  /usr/share/applications/android-studio.desktop \
  /usr/share/pixmaps/android-studio.png \
  /usr/share/icons/hicolor/*/apps/android-studio.png \
  /etc/udev/rules.d/51-android.rules; do
  for p in $f; do
    [[ -e $p ]] && { log "Removing $p"; rm -f "$p"; }
  done
done

# 7. Bersihkan variabel lingkungan di shell rc
for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
  [[ -f $rc ]] && \
    sed -i.bak -e '/ANDROID_HOME/d' -e '/ANDROID_SDK_ROOT/d' -e '/Android\/Sdk/d' "$rc"
done

# 8. Perbarui locate DB & tampilkan sisa jejak (jika ada)
log "Memperbarui database locate…"
updatedb
if locate -i -e Android | grep -Ei 'Android.?Studio|Android(\/| )Sdk' >/dev/null; then
  echo -e "\e[1;33m[WARN]\e[0m Masih ada jejak berikut (harap periksa manual):"
  locate -i -e Android | grep -Ei 'Android.?Studio|Android(\/| )Sdk'
else
  log "✅ Sistem bersih—tidak ditemukan jejak Android Studio / SDK."
fi
