#!/bin/bash

### Install Docker, Setup Bitwarden Pre-Install, on Raspbian ###

# https://bitwarden.com/help/install-on-premise-linux/
# https://docs.docker.com/engine/install/
# https://docs.docker.com/engine/install/raspbian/


# uninstall conflicting packages
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do sudo apt-get remove $pkg; done

# Setup repository
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/raspbian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/raspbian \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null


# Install latest version of Docker Engine
sudo apt-get update -y && sudo apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# The docker service starts automatically on Debian based distributions.
# On RPM based distributions, such as CentOS, Fedora, RHEL or SLES, you need to start it manually using the appropriate systemctl or service command.

# Configure Docker to start on boot with systemd
sudo systemctl enable docker.service
sudo systemctl enable containerd.service

# To disable docker start on boot:
# sudo systemctl disable docker.service
# sudo systemctl disable containerd.service

# Create Bitwarden local user & directory
# Set Password Variable
export PASS=bitwarden
# sudo adduser bitwarden
sudo useradd -m -p $(openssl passwd -1 $PASS) -s /bin/bash bitwarden
# sudo passwd bitwarden
# sudo groupadd docker
sudo usermod -aG docker bitwarden
sudo mkdir /opt/bitwarden
sudo chmod -R 700 /opt/bitwarden
sudo chown -R bitwarden:bitwarden /opt/bitwarden

# Install Bitwarden
# If you have created a Bitwarden user & directory, complete the following as the bitwarden user from the /opt/bitwarden directory.

sudo su bitwarden
cd /opt/bitwarden/
curl -Lso bitwarden.sh "https://func.bitwarden.com/api/dl/?app=self-host&platform=linux" && chmod 700 bitwarden.sh
# ./bitwarden.sh install