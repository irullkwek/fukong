#!/bin/bash
# Mencegah auto-shutdown pada Ubuntu

echo "Disabling automatic shutdown..."

# Menonaktifkan service shutdown otomatis jika ada
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

# Menonaktifkan idle shutdown dari logind
sudo sed -i 's/^#*IdleAction=.*/IdleAction=ignore/' /etc/systemd/logind.conf
sudo sed -i 's/^#*IdleActionSec=.*/IdleActionSec=0/' /etc/systemd/logind.conf

# Restart logind untuk menerapkan perubahan
sudo systemctl restart systemd-logind

echo "Automatic shutdown has been disabled."
