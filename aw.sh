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
#
# Fitur tambahan:
#   • Memastikan paket utilitas yang dibutuhkan (plocate) terpasang secara otomatis.
#   • Menjalankan kembali updatedb/locate setelah paket dipasang agar dapat memindai residu.
#
# ⚠️  PERINGATAN: Skrip ini menggunakan `rm -rf` dan `sed -i` di banyak lokasi.
#    Jalankan hanya jika Anda benar‑benar ingin membersihkan total.
#    Backup data penting Anda lebih dahulu!

set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "[ERR] Harus dijalankan sebagai root (sudo)." >&2; exit 1; }

log() { echo -e "\e[1;34m[INFO]\e[0m $*"; }
warn() { echo -e "\e[1;33m[WARN]\e[0m $*"; }

# ------------------------------------------------------------
# 0. Pastikan dependensi utilitas tersedia
# ------------------------------------------------------------
REQUIRED_PKGS=(plocate)
APT_UPDATED=false

ensure_pkg() {
  local pkg=$1
  if ! dpkg -s "$pkg" >/dev/null 2>&1; then
    if ! $APT_UPDATED; then
      log "Menjalankan apt-get update (sekali)…"
      apt-get update -qq
      APT_UPDATED=true
    fi
    log "Meng‑install paket $pkg …"
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$pkg"
  fi
}

for p in "${REQUIRED_PKGS[@]}"; do
  ensure_pkg "$p"
done

# ------------------------------------------------------------
# 1. Tutup proses Android Studio
# ------------------------------------------------------------
log "Menutup proses Android Studio …"
pkill -f "bin/studio.sh" 2>/dev/null || true
pkill -f "idea.Main"      2>/dev/null || true
sleep 1

# ------------------------------------------------------------
# 2. Purge paket APT android-studio (jika ada)
# ------------------------------------------------------------
if dpkg -l | grep -q "android-studio"; then
  log "Menghapus paket APT android-studio …"
  apt-get purge --auto-remove -y android-studio
fi

# ------------------------------------------------------------
# 3. Hapus direktori instalasi IDE
# ------------------------------------------------------------
IDE_DIRS=(
  /opt/android-studio
  /usr/local/android-studio
  "$HOME/android-studio"
  "$HOME/Applications/Android Studio"
  "$HOME/.local/share/JetBrains/Toolbox/apps/AndroidStudio"*
)

for dir in "${IDE_DIRS[@]}"; do
  for d in $dir; do
    [[ -d $d ]] && { log "Removing $d"; rm -rf "$d"; }
  done
done

# ------------------------------------------------------------
# 4. Hapus Android SDK
# ------------------------------------------------------------
SDK_DIRS=(
  "$HOME/Android/Sdk"
  /opt/android-sdk
  /opt/Android/Sdk
)

for dir in "${SDK_DIRS[@]}"; do
  [[ -d $dir ]] && { log "Removing $dir"; rm -rf "$dir"; }
done

# ------------------------------------------------------------
# 5. Hapus cache & konfigurasi
# ------------------------------------------------------------
CONFIG_PATTERNS=(
  "$HOME/.android"
  "$HOME/.AndroidStudio"*
  "$HOME/.cache/Google/AndroidStudio"*
  "$HOME/.local/share/Google/AndroidStudio"*
  "$HOME/.config/Google/AndroidStudio"*
  "$HOME/.cache/JetBrains/AndroidStudio"*
  "$HOME/.local/share/JetBrains/AndroidStudio"*
  "$HOME/.config/JetBrains/AndroidStudio"*
)

for pattern in "${CONFIG_PATTERNS[@]}"; do
  for d in $pattern; do
    [[ -e $d ]] && { log "Removing $d"; rm -rf "$d"; }
  done
done

# ------------------------------------------------------------
# 6. Hapus launcher, ikon, aturan udev
# ------------------------------------------------------------
FILES=(
  /usr/share/applications/android-studio.desktop
  /usr/share/pixmaps/android-studio.png
  /usr/share/icons/hicolor/*/apps/android-studio.png
  /etc/udev/rules.d/51-android.rules
)

for f in "${FILES[@]}"; do
  for p in $f; do
    [[ -e $p ]] && { log "Removing $p"; rm -f "$p"; }
  done
done

# ------------------------------------------------------------
# 7. Bersihkan variabel lingkungan di shell rc
# ------------------------------------------------------------
RC_FILES=("$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile")
for rc in "${RC_FILES[@]}"; do
  if [[ -f $rc ]]; then
    # Buat cadangan hanya sekali per file
    if grep -Eq 'ANDROID_HOME|ANDROID_SDK_ROOT|Android/Sdk' "$rc"; then
      cp "$rc" "${rc}.bak.$(date +%s)"
      sed -i -e '/ANDROID_HOME/d' -e '/ANDROID_SDK_ROOT/d' -e '/Android\/Sdk/d' "$rc"
      log "Membersihkan environment di $rc (backup dibuat)"
    fi
  fi
done

# ------------------------------------------------------------
# 8. Perbarui locate DB & tampilkan sisa jejak (jika ada)
# ------------------------------------------------------------
if command -v updatedb >/dev/null 2>&1 && command -v locate >/dev/null 2>&1; then
  log "Memperbarui database locate …"
  updatedb
  if locate -i -e Android | grep -Ei 'Android.?Studio|Android(/| )Sdk' >/dev/null; then
    warn "Masih ada jejak berikut (harap periksa manual):"
    locate -i -e Android | grep -Ei 'Android.?Studio|Android(/| )Sdk'
  else
    log "✅ Sistem bersih — tidak ditemukan jejak Android Studio / SDK."
  fi
else
  warn "'locate' tidak tersedia — melewati pemeriksaan residu."
fi
