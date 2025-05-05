#!/bin/bash
#
# Clean Linux Installation Script
# This script sets up a minimal Ubuntu 20.04 environment with essential tools
#

# Set strict error handling
set -e

# Environment setup
ROOTFS_DIR=$(pwd)
export PATH=$PATH:~/.local/usr/bin
ARCH=$(uname -m)
max_retries=3
timeout=10

# Log function
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Error handling function
error_exit() {
  log "ERROR: $1"
  exit 1
}

# Architecture detection
log "Detecting system architecture..."
if [ "$ARCH" = "x86_64" ]; then
  ARCH_ALT=amd64
elif [ "$ARCH" = "aarch64" ]; then
  ARCH_ALT=arm64
else
  error_exit "Unsupported CPU architecture: ${ARCH}"
fi

# Distribution configuration
DISTRO="ubuntu"
URL="http://cdimage.ubuntu.com/ubuntu-base/releases/20.04/release/ubuntu-base-20.04.4-base-${ARCH_ALT}.tar.gz"
PKG_MANAGER="apt-get"
PKG_UPDATE="update"
PKG_INSTALL="install -y"

# Clean any existing installation
if [ -e "$ROOTFS_DIR/.installed" ]; then
  log "Cleaning previous installation..."
  rm -f "$ROOTFS_DIR/.installed"
fi

# Download and extract rootfs
log "Downloading $DISTRO..."
wget --tries=$max_retries --timeout=$timeout --no-hsts -O /tmp/rootfs.tar.gz "$URL" || error_exit "Failed to download rootfs"
log "Extracting rootfs..."
tar -xf /tmp/rootfs.tar.gz -C $ROOTFS_DIR || error_exit "Failed to extract rootfs"
rm -f /tmp/rootfs.tar.gz

# Install proot
log "Installing proot..."
mkdir -p $ROOTFS_DIR/usr/local/bin
wget --tries=$max_retries --timeout=$timeout --no-hsts -O $ROOTFS_DIR/usr/local/bin/proot "https://raw.githubusercontent.com/foxytouxxx/freeroot/main/proot-${ARCH}" || error_exit "Failed to download proot"
chmod 755 $ROOTFS_DIR/usr/local/bin/proot
touch $ROOTFS_DIR/.installed

# Set up DNS
log "Setting up DNS..."
printf "nameserver 1.1.1.1\nnameserver 8.8.8.8" > ${ROOTFS_DIR}/etc/resolv.conf

# Install essential packages
log "Updating package lists and installing essential tools..."
$ROOTFS_DIR/usr/local/bin/proot --rootfs="$ROOTFS_DIR" -0 -w "/root" /bin/sh -c "
  $PKG_MANAGER $PKG_UPDATE && \
  $PKG_MANAGER $PKG_INSTALL vim nano git wget curl python3 python3-pip
"

# Set up Python environment
log "Setting up Python environment..."
$ROOTFS_DIR/usr/local/bin/proot --rootfs="$ROOTFS_DIR" -0 -w "/root" /bin/sh -c "
  pip3 install virtualenv && \
  virtualenv -p python3 ~/pyenv && \
  echo 'source ~/pyenv/bin/activate' >> ~/.bashrc
"

# Set up SSH (with a secure default password)
log "Setting up SSH for remote access..."
$ROOTFS_DIR/usr/local/bin/proot --rootfs="$ROOTFS_DIR" -0 -w "/root" /bin/sh -c "
  $PKG_MANAGER $PKG_INSTALL openssh-server && \
  mkdir -p /var/run/sshd && \
  echo 'root:change_this_password_immediately' | chpasswd && \
  sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
"

# Create a startup script
log "Creating startup script..."
cat > $ROOTFS_DIR/root/start.sh << 'EOF'
#!/bin/bash
# Start SSH server
service ssh start

# Display system information
echo "System is ready"
echo "-----------------------------"
uname -a
echo "-----------------------------"
ip addr | grep "inet " | grep -v 127.0.0.1
echo "-----------------------------"
echo "Use 'ssh root@<IP_ADDRESS>' to connect"
echo "Default password: change_this_password_immediately"
echo "Please change your password immediately using 'passwd' command"

# Keep the session alive
exec /bin/bash
EOF

chmod +x $ROOTFS_DIR/root/start.sh

# Create a convenient launcher
cat > ./start_environment.sh << 'EOF'
#!/bin/bash
ROOTFS_DIR=$(pwd)
$ROOTFS_DIR/usr/local/bin/proot \
  --rootfs="${ROOTFS_DIR}" \
  -0 -w "/root" -b /dev -b /sys -b /proc -b /etc/resolv.conf --kill-on-exit \
  /root/start.sh
EOF

chmod +x ./start_environment.sh

# Display Completion Message
CYAN='\e[0;36m'
GREEN='\e[0;32m'
WHITE='\e[0;37m'
RESET_COLOR='\e[0m'

echo -e "${WHITE}====================================================${RESET_COLOR}"
echo -e "${CYAN}         Installation Completed Successfully!${RESET_COLOR}"
echo -e "${WHITE}====================================================${RESET_COLOR}"
echo -e ""
echo -e "${GREEN}To start your environment:${RESET_COLOR}"
echo -e "  ./start_environment.sh"
echo -e ""
echo -e "${GREEN}After starting the environment:${RESET_COLOR}"
echo -e "  1. Change the default root password with: passwd"
echo -e "  2. Connect via SSH from another terminal"
echo -e ""
echo -e "${WHITE}====================================================${RESET_COLOR}"

# Clean up
log "Cleaning up temporary files..."
find $ROOTFS_DIR -name "*.tmp" -delete 2>/dev/null || true
