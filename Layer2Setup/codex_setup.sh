#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

# ==========================================
# UI Helpers & Colors
# ==========================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_stage() {
    echo -e "\n${BLUE}================================================================${NC}"
    echo -e "${CYAN}>> $1${NC}"
    echo -e "${BLUE}================================================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✔ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✖ $1${NC}"
}

# ==========================================
# Pre-Flight Checks
# ==========================================
echo -e "${CYAN}Welcome to the Codex CLI Setup Wizard!${NC}"
echo -e "This script will prepare your Debian 13 system, install dependencies, and configure Codex.\n"

# 1. Check for root privileges
if [ "$EUID" -ne 0 ]; then
  print_error "Please run this script as root or using sudo."
  echo "Example: sudo bash setup_codex.sh"
  exit 1
fi

# 2. Check for Debian 13 exclusively
if [ -f /etc/os-release ]; then
    . /etc/os-release
    # Ensure ID is debian and VERSION_ID starts with 13
    if [ "$ID" != "debian" ] || [[ ! "$VERSION_ID" =~ ^13 ]]; then
        print_error "This script is designed exclusively for Debian 13. Detected OS: $PRETTY_NAME"
        exit 1
    fi
else
    print_error "Cannot determine the operating system. This script requires Debian 13."
    exit 1
fi

# 3. Check RAM and handle Swap for fresh VPS environments
TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
if [ "$TOTAL_RAM" -lt 2000 ]; then
    print_warning "Low RAM detected (${TOTAL_RAM}MB). To prevent crashes, setting up a 2GB Swap file..."
    if [ ! -f /swapfile ]; then
        fallocate -l 2G /swapfile
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
        # Persist swap on reboot if not already in fstab
        if ! grep -q '/swapfile' /etc/fstab; then
            echo '/swapfile none swap sw 0 0' >> /etc/fstab
        fi
        print_success "2GB Swap file created and enabled successfully."
    else
        print_success "Swap file already exists. Skipping creation."
    fi
else
    print_success "Sufficient RAM detected (${TOTAL_RAM}MB). No swap creation needed."
fi

# ==========================================
# Stage 1: System Update
# ==========================================
print_stage "Stage 1/3: Updating System Packages"
echo "Fetching latest package lists and upgrading system (this might take a minute)..."

apt-get update -y
apt-get upgrade -y
print_success "System updated successfully!"

# ==========================================
# Stage 2: Install Dependencies
# ==========================================
print_stage "Stage 2/3: Installing Required Dependencies"
echo "Installing core utilities (curl, wget, git, build-essential)..."
apt-get install -y curl wget git build-essential jq python3

echo "Setting up NodeSource repository for Node.js (v22 is recommended for Codex CLI)..."
curl -fsSL https://deb.nodesource.com/setup_22.x -o nodesource_setup.sh
bash nodesource_setup.sh
rm nodesource_setup.sh

echo "Installing Node.js and npm..."
apt-get install -y nodejs

node_version=$(node -v)
print_success "Dependencies installed! (Node.js version: $node_version)"

# ==========================================
# Stage 3: Install Codex CLI
# ==========================================
print_stage "Stage 3/3: Installing Codex CLI"
echo "Installing @openai/codex globally via npm..."

npm install -g @openai/codex

print_success "Codex CLI installed successfully!"
codex --version || true

# ==========================================
# Setup Complete
# ==========================================
print_stage "Setup Complete!"
echo -e "${GREEN}Your Debian 13 system is fully prepared, and Codex CLI is ready to use natively.${NC}"
echo -e "To authenticate with your OpenAI account, run: ${YELLOW}codex login${NC}"
echo -e "To start a project session, navigate to your directory and run: ${YELLOW}codex${NC}"
exit 0
