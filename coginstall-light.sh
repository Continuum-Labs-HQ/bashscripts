#!/bin/bash

# This script sets up a Unix system with various tools and libraries.
# - Enables Bash strict mode to prevent potential issues
# - Installs basic tools and utilities
# - Ensures that tools like snap, Docker, MiniConda, CUDA Toolkit, and Oh My Zsh are installed and set up
# - Ends by summarizing the changes made to the system

set -euo pipefail  # Enable bash strict mode
trap "echo 'Script interrupted by user'; exit 1" INT

print_message() {
    echo -e "\033[1;34m$1\033[0m"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

print_error() {
    echo "Error: $1" >&2
    exit 1
}

spin() {
    local -a spinner=('|' '/' '-' '\')
    while true; do
        for i in "${spinner[@]}"; do
            echo -ne "\r$i"
            sleep 0.2
        done
    done
}

# Check for essential commands
for cmd in curl wget sudo dpkg getent; do
    if ! command_exists "$cmd"; then
        print_error "$cmd is required but it's not installed."
    fi
done

# Ensure snap is installed
if ! command_exists snap; then
    print_message "Installing snap..."
    sudo apt install -y snapd
else
    echo "snap is already installed."
fi

sudo systemctl start snapd

# Install common utilities and libraries.
# Each installation step provides a short description for clarity.
print_message "Updating System and Installing Basic Libraries"

sudo apt update
sudo apt upgrade -y

install_package() {
    print_message "Installing $1: $2"
    sudo apt install -y $1
}

install_package git "Distributed version control system."
install_package awscli "Command-line interface for interacting with AWS services."
install_package curl "Command-line tool for making web requests."
install_package vim "Highly configurable text editor."
install_package htop "Interactive process viewer for Unix."
install_package tmux "Terminal multiplexer for managing multiple terminal sessions."
install_package build-essential "Contains reference libraries for compiling C programs on Ubuntu."
install_package zsh "Z shell - an extended Bourne shell with numerous improvements."
install_package software-properties-common "Provides scripts for managing software."
install_package apt-transport-https "Allows the package manager to transfer files and data over https."
install_package ca-certificates "Common CA certificates for SSL applications."
install_package gnupg-agent "GPG agent to handle private keys operations."
install_package cmake "Manages the build process in an OS and in a compiler-independent manner."
install_package gnupg "For encrypting and signing your data and communication."
install_package nvtop "NVIDIA GPUs htop like monitoring tool."
install_package screen "Tool for multiplexing several virtual consoles."
install_package glances "Cross-platform monitoring tool."
install_package parallel "Shell tool for executing jobs in parallel."
install_package git-lfs "Git extension for versioning large files."
install_package ffmpeg "Multimedia framework for various operations."
install_package bash-completion "Programmable completion for bash commands."
install_package silversearcher-ag "Ultra-fast text searcher."
install_package tldr "Community-driven man pages."
install_package fzf "Command-line fuzzy finder."
install_package ncdu "Disk usage analyzer with ncurses interface."
install_package jq "Command-line JSON processor."
install_package tree "Displays directories as trees."
install_package tmate "Instant terminal sharing."
install_package byobu "Text-based window manager and terminal multiplexer."
install_package ranger "Console file manager with vi-like keybinding."
install_package bat "Cat clone with syntax highlighting."
install_package ripgrep "Ultra-fast text searcher."
install_package neofetch "System info written in Bash."
install_package mc "Visual file manager."
install_package iproute2 "Network tools."

sudo snap install lsd

# Install Starship 
sudo snap install --edge starship

print_message "Setting up Docker"
# Set up Docker only if it isn't already installed.
if ! command_exists docker; then
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io

# Check if docker group exists before attempting to add it
    if ! getent group docker > /dev/null; then
        sudo groupadd docker
    fi
    sudo usermod -aG docker $USER
    echo "NOTE: Please restart or re-login for Docker group changes to take effect."
else
    echo "Docker is already installed, skipping installation."
fi

print_message "Setting up Miniconda"
if [ ! -d "$HOME/anaconda3" ]; then
    pushd /tmp
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
    bash Miniconda3-latest-Linux-x86_64.sh -b -p $HOME/anaconda3
    rm -f Miniconda3-latest-Linux-x86_64.sh 
    popd

# These commands are appending the string "conda activate base" to the respective shell configuration files
grep -qxF 'conda activate base' ~/.bashrc || echo 'conda activate base' >> ~/.bashrc
grep -qxF 'conda activate base' ~/.zshrc || echo 'conda activate base' >> ~/.zshrc


    echo "To finish the conda installation, run: source ~/.bashrc && conda --version"
else
    echo "Miniconda is already installed, skipping installation."
fi

# Installing CUDA Drivers **NOTE VERSION 11.8**"
print_message "Installing CUDA Toolkit - **NOTE VERSION 11.8"
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-ubuntu2004.pin
sudo mv cuda-ubuntu2004.pin /etc/apt/preferences.d/cuda-repository-pin-600
wget https://developer.download.nvidia.com/compute/cuda/11.8.0/local_installers/cuda-repo-ubuntu2004-11-8-local_11.8.0-520.61.05-1_amd64.deb
sudo dpkg -i cuda-repo-ubuntu2004-11-8-local_11.8.0-520.61.05-1_amd64.deb
sudo cp /var/cuda-repo-ubuntu2004-11-8-local/cuda-*-keyring.gpg /usr/share/keyrings/
sudo apt-get update
sudo apt-get -y install cuda

# Setting up NVIDIA Toolkit for GPU-accelerated container support.
print_message "Setting up NVIDIA Toolkit"
distribution=$(. /etc/os-release;echo $ID$VERSION_ID) \
        && curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
        && curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
            sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
            sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt update
sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

# Clean up CUDA installation as done with MiniConda
print_message "Cleaning up CUDA installation files..."
rm -f cuda-repo-ubuntu2004-11-8-local_11.8.0-520.61.05-1_amd64.deb

# Check if the CUDA bin directory is already in the PATH
if [[ ":$PATH:" != *":/usr/local/cuda-11.8/bin:"* ]]; then
    echo "Adding CUDA to the system PATH..."

# Add CUDA bin directory to PATH for the current session
export PATH=$PATH:/usr/local/cuda-11.8/bin

# Make this change permanent by adding it to ~/.bashrc and ~/.zshrc (if you use Zsh)
echo 'export PATH=$PATH:/usr/local/cuda-11.8/bin' >> ~/.bashrc
    [[ -f ~/.zshrc ]] && echo 'export PATH=$PATH:/usr/local/cuda-11.8/bin' >> ~/.zshrc
fi

# Wait for Docker to be ready
while ! sudo docker info >/dev/null 2>&1; do
    echo "Waiting for Docker to start..."
    sleep 2
done

# Echo before pulling Docker images
echo "Pulling Docker images..."
spin &  # Start the spinner in the background
SPIN_PID=$!

sudo docker pull nvcr.io/nvidia/pytorch:23.05-py3

kill -9 $SPIN_PID  # Kill the spinner after the images have been pulled
echo -e "\rDocker images pulled successfully.          "

trap "kill -9 $SPIN_PID" EXIT  # Ensure spinner stops when the script exits

print_message "Setting up Oh My Zsh"
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    # Install Oh My Zsh first
    RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

    # Now run the plugins setup script
    wget https://raw.githubusercontent.com/Cognitive-Agency/bashscripts/main/setupzsh_plugins.sh
    chmod +x setupzsh_plugins.sh
    ./setupzsh_plugins.sh
    rm -f setupzsh_plugins.sh  # Cleanup the setup script
else
    echo "Oh My Zsh is already installed, skipping installation."
fi

print_message "Installation Summary:"
echo "1. Updated the system and installed basic libraries."
echo "2. Installed snap tool."
echo "3. Set up Docker."
echo "4. Installed Miniconda."
echo "5. Installed CUDA Toolkit version 11.8."
echo "6. Set up NVIDIA Toolkit."
echo "7. Installed Oh My Zsh and its plugins."
echo "Please review any notes or warnings provided during the installation process."