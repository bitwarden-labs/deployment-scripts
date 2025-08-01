#!/bin/bash

# Script for installing Docker and setting up Bitwarden on Ubuntu

# Parse command line arguments
DIR_ACTION=""
DOCKER_ACTION=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --noinstall)
            shift
            ;;
        --overwrite)
            DIR_ACTION="overwrite"
            shift
            ;;
        --newfolder)
            DIR_ACTION="newfolder"
            shift
            ;;
        --cancel)
            DIR_ACTION="cancel"
            shift
            ;;
        --skip-docker)
            DOCKER_ACTION="skip"
            shift
            ;;
        --reinstall-docker)
            DOCKER_ACTION="reinstall"
            shift
            ;;
        *)
            shift
            ;;
    esac
done

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

# Function for handling directory conflicts
handle_directory_conflict() {
    local dir="$1"
    local action="$2"
    
    if [[ -d "$dir" ]]; then
        if [[ -n "$action" ]]; then
            case "$action" in
                "overwrite")
                    echo "Overwriting existing directory: $dir"
                    sudo rm -rf "$dir"
                    ;;
                "newfolder")
                    local counter=1
                    local new_dir="${dir}_${counter}"
                    while [[ -d "$new_dir" ]]; do
                        counter=$((counter + 1))
                        new_dir="${dir}_${counter}"
                    done
                    echo "Creating new directory: $new_dir"
                    BITWARDEN_INSTALL_DIR="$new_dir"
                    ;;
                "cancel")
                    echo "Installation cancelled by user."
                    exit 0
                    ;;
            esac
        else
            echo "Directory $dir already exists."
            echo "Choose an option:"
            echo "1) Overwrite existing directory"
            echo "2) Create new directory with suffix"
            echo "3) Cancel installation"
            read -p "Enter choice (1-3): " choice
            
            case "$choice" in
                1)
                    echo "Overwriting existing directory: $dir"
                    sudo rm -rf "$dir"
                    ;;
                2)
                    local counter=1
                    local new_dir="${dir}_${counter}"
                    while [[ -d "$new_dir" ]]; do
                        counter=$((counter + 1))
                        new_dir="${dir}_${counter}"
                    done
                    echo "Creating new directory: $new_dir"
                    BITWARDEN_INSTALL_DIR="$new_dir"
                    ;;
                3|*)
                    echo "Installation cancelled by user."
                    exit 0
                    ;;
            esac
        fi
    fi
}

# Function for handling Docker installation
handle_docker_installation() {
    local action="$1"
    
    # Check if Docker is already installed
    if command -v docker &> /dev/null; then
        echo "Docker is already installed."
        docker --version
        
        if [[ -n "$action" ]]; then
            case "$action" in
                "skip")
                    echo "Skipping Docker installation as requested."
                    return 0
                    ;;
                "reinstall")
                    echo "Reinstalling Docker as requested."
                    return 1
                    ;;
            esac
        else
            echo "Docker is already installed. Choose an option:"
            echo "1) Skip Docker installation"
            echo "2) Reinstall Docker"
            echo "3) Cancel installation"
            read -p "Enter choice (1-3): " choice
            
            case "$choice" in
                1)
                    echo "Skipping Docker installation."
                    return 0
                    ;;
                2)
                    echo "Proceeding with Docker reinstallation."
                    return 1
                    ;;
                3|*)
                    echo "Installation cancelled by user."
                    exit 0
                    ;;
            esac
        fi
    fi
    
    # Docker not installed, proceed with installation
    return 1
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

# Check Docker installation
if handle_docker_installation "$DOCKER_ACTION"; then
    echo "Skipping Docker setup."
else
    echo "Setting up Docker..."
    
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
fi

# Create Bitwarden user and directory
if ! id "$BITWARDEN_USER" &>/dev/null; then
    echo "Creating Bitwarden user..."
    sudo useradd -m -p $(openssl passwd -1 $BITWARDEN_USER_PASSWORD) -s /bin/bash "$BITWARDEN_USER" || handle_error "Failed to create Bitwarden user"
else
    echo "Bitwarden user already exists."
fi
sudo usermod -aG docker "$BITWARDEN_USER"

# Handle directory conflicts
handle_directory_conflict "$BITWARDEN_INSTALL_DIR" "$DIR_ACTION"

sudo mkdir -p "$BITWARDEN_INSTALL_DIR"
sudo chmod -R 700 "$BITWARDEN_INSTALL_DIR"
sudo chown -R "$BITWARDEN_USER:$BITWARDEN_USER" "$BITWARDEN_INSTALL_DIR"

# Always download the Bitwarden install script
echo "Downloading Bitwarden install script as $BITWARDEN_USER..."
sudo su - "$BITWARDEN_USER" -c "cd $BITWARDEN_INSTALL_DIR && curl -Lso bitwarden.sh '$BITWARDEN_DOWNLOAD_URL' && chmod 700 bitwarden.sh" || handle_error "Failed to download Bitwarden install script"

# Run install unless --noinstall is passed
if [[ ! " $* " =~ --noinstall ]]; then
    echo "Running Bitwarden install script..."
    sudo su - "$BITWARDEN_USER" -c "cd $BITWARDEN_INSTALL_DIR && ./bitwarden.sh install" || handle_error "Failed to install Bitwarden"
else
    echo "Skipping Bitwarden installation step due to --noinstall flag."
fi
