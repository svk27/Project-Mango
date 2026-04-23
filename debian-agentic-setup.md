# Update the package lists
sudo apt update

# Upgrade all installed packages to their latest versions
sudo apt upgrade -y

# Install essential utilities for downloading and managing packages
sudo apt install wget curl nano ufw software-properties-common -y

# Install the core KDE Plasma desktop without recommended bloatware
sudo apt install --no-install-recommends kde-plasma-desktop -y

# Install a basic terminal emulator and file manager for the GUI
sudo apt install konsole dolphin -y

# (Optional) Ensure standard Wayland support packages are present
sudo apt install plasma-workspace-wayland kwin-wayland -y

# OR (For KDE Plasma)
sudo apt install kde-plasma-desktop sddm xdg-desktop-portal-kde pipewire -y
sudo systemctl enable sddm
sudo systemctl start sddm


cd /tmp
wget https://github.com/lamco-admin/lamco-rdp-server/releases/latest/download/lamco-rdp-server_1.4.2_amd64.deb
sudo dpkg -i lamco-rdp-server_*_amd64.deb
sudo apt install -f -y
systemctl --user enable lamco-rdp-server
systemctl --user start lamco-rdp-server
