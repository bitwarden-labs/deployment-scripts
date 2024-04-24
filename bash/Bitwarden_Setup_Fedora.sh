#!/bin/bash

# Script for installing Docker and setting up Bitwarden on Fedora

# Define variables
DOCKER_REPO="https://download.docker.com/linux/fedora/docker-ce.repo"
BITWARDEN_DOWNLOAD_URL="https://func.bitwarden.com/api/dl/?app=self-host&platform=linux"
BITWARDEN_INSTALL_DIR="/opt/bitwarden"
BITWARDEN_USER="bitwarden"
BITWARDEN_USER_PASSWORD="bitwarden"

# Function for error handling
handle_error() {
    echo "Error: $1"
    exit 1
}

# Uninstall old versions of Docker
sudo dnf remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-selinux docker-engine-selinux docker-engine || handle_error "Failed to remove old Docker versions"

# Set up Docker RPM repository
sudo dnf -y install dnf-plugins-core || handle_error "Failed to install dnf-plugins-core"
sudo dnf config-manager --add-repo "$DOCKER_REPO" || handle_error "Failed to add Docker repository"

# Install Latest Docker Engine
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || handle_error "Failed to install Docker"

# Start Docker
# sudo systemctl start docker

# Configure Docker to start on boot with systemd
sudo systemctl enable docker.service
sudo systemctl enable containerd.service

# Create Bitwarden local user and directory
sudo useradd -m -p $(openssl passwd -1 $BITWARDEN_USER_PASSWORD) -s /bin/bash "$BITWARDEN_USER" || handle_error "Failed to create Bitwarden user"
sudo usermod -aG docker "$BITWARDEN_USER"
sudo mkdir -p "$BITWARDEN_INSTALL_DIR"
sudo chmod -R 700 "$BITWARDEN_INSTALL_DIR"
sudo chown -R "$BITWARDEN_USER:$BITWARDEN_USER" "$BITWARDEN_INSTALL_DIR"

# Install Bitwarden
echo "Switching to the $BITWARDEN_USER user"
sudo su - "$BITWARDEN_USER" -c "cd $BITWARDEN_INSTALL_DIR && curl -Lso bitwarden.sh '$BITWARDEN_DOWNLOAD_URL' && chmod 700 bitwarden.sh && ./bitwarden.sh install" || handle_error "Failed to install Bitwarden"
