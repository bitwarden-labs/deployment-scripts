#!/bin/bash

# Script for installing Docker and setting up Bitwarden on Ubuntu

# Define variables
DOCKER_REPO="https://download.docker.com/linux/ubuntu"
DOCKER_GPG_KEY="/etc/apt/keyrings/docker.gpg"
BITWARDEN_DOWNLOAD_URL="https://func.bitwarden.com/api/dl/?app=self-host&platform=linux"
BITWARDEN_INSTALL_DIR="/opt/bitwarden"
BITWARDEN_USER="bitwarden"
BITWARDEN_USER_PASSWORD="bitwarden"

# Function for error handling
handle_error() {
    echo "Error: $1"
    exit 1
}

# Remove conflicting packages
conflicting_packages=("docker.io" "docker-doc" "docker-compose" "podman-docker" "containerd" "runc")
for pkg in "${conflicting_packages[@]}"; do

if dpkg -l | grep -qw "$pkg"; then
    echo "Package $pkg is installed. Removing..."
    sudo apt-get remove -y "$pkg"
    echo "Package $pkg has been removed."
else
    echo "Package $pkg is not installed."
fi

done

# Setup Docker repository
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL "${DOCKER_REPO}/gpg" | sudo gpg --dearmor -o "$DOCKER_GPG_KEY" || handle_error "Failed to add Docker GPG key"
sudo chmod a+r "$DOCKER_GPG_KEY"
echo "deb [arch=$(dpkg --print-architecture) signed-by=$DOCKER_GPG_KEY] $DOCKER_REPO $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt-get update -y && sudo apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || handle_error "Failed to install Docker"
sudo systemctl enable docker.service
sudo systemctl enable containerd.service

# Create Bitwarden user and directory
sudo useradd -m -p $(openssl passwd -1 $BITWARDEN_USER_PASSWORD) -s /bin/bash "$BITWARDEN_USER" || handle_error "Failed to create Bitwarden user"
sudo usermod -aG docker "$BITWARDEN_USER"
sudo mkdir -p "$BITWARDEN_INSTALL_DIR"
sudo chmod -R 700 "$BITWARDEN_INSTALL_DIR"
sudo chown -R "$BITWARDEN_USER:$BITWARDEN_USER" "$BITWARDEN_INSTALL_DIR"

# Install Bitwarden
echo "Switching to the $BITWARDEN_USER user"
sudo su - "$BITWARDEN_USER" -c "cd $BITWARDEN_INSTALL_DIR && curl -Lso bitwarden.sh '$BITWARDEN_DOWNLOAD_URL' && chmod 700 bitwarden.sh && ./bitwarden.sh install" || handle_error "Failed to install Bitwarden"
