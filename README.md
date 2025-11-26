# CachyOS Setup Guide

This repository contains setup scripts and documentation for configuring a CachyOS system with Intel/Nvidia hybrid graphics for gaming and development.

## System Specifications

- **OS**: CachyOS (Arch-based)
- **Intel GPU**: CometLake-H GT2 [UHD Graphics]
- **Nvidia GPU**: GeForce RTX 3070 Mobile / Max-Q
- **Display**: Wayland + KWin compositor
- **Pre-installed**: nvm, node, yay

## Quick Start

### Option 1: Using `just` (Recommended)

```bash
# Install just
yay -S just

# View available commands
just --list

# Run full setup
just setup-all

# Or run individual components
just drivers
just gaming
just printing
just dev-tools
just dev-gh      # Install GitHub CLI
just dev-node    # Install nvm and Node.js
just dev-claude  # Install Claude CLI
```

### Option 2: Using bash script

```bash
# Make executable
chmod +x setup.sh

# Run full setup
./setup.sh all

# Or run individual components
./setup.sh drivers
./setup.sh gaming
./setup.sh printing
./setup.sh dev
./setup.sh gh       # Install GitHub CLI
./setup.sh node     # Install nvm and Node.js
./setup.sh claude   # Install Claude CLI
```

## Setup Components

### 1. GPU Drivers

**Current Status:**
- ✅ Intel i915 driver (kernel built-in)
- ✅ Nvidia 580.95.05 driver (open-source variant)
- ✅ Mesa 25.2.5 for Intel
- ✅ Vulkan support for both GPUs

**Additional packages to install:**
- `intel-media-driver` - Hardware video acceleration
- `libva-intel-driver` - VA-API support
- `intel-gpu-tools` - Intel GPU debugging and monitoring

**Nvidia packages already installed:**
- nvidia-utils, nvidia-settings
- nvidia-prime (GPU switching)
- OpenCL support
- Vulkan support

### 2. Firmware Updates

**Tools:**
- `fwupd` - Firmware update manager (already installed)

**Commands:**
```bash
sudo fwupdmgr refresh        # Update firmware database
sudo fwupdmgr get-updates    # Check for updates
sudo fwupdmgr update         # Apply updates
```

**Check for firmware issues:**
```bash
sudo dmesg | grep -i firmware | grep -i failed
sudo journalctl -b -p 3 | grep -i firmware
```

### 3. Suspend/Resume Fix

**Common Issue:** Nvidia GPUs often prevent proper suspend/resume on laptops.

**Solution 1: Enable Nvidia power management services**
```bash
sudo systemctl enable nvidia-suspend.service
sudo systemctl enable nvidia-hibernate.service
sudo systemctl enable nvidia-resume.service
```

**Solution 2: Add kernel parameters**

Edit `/etc/default/grub` and add to `GRUB_CMDLINE_LINUX_DEFAULT`:
```
nvidia.NVreg_PreserveVideoMemoryAllocations=1
```

Then regenerate grub config:
```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

**Solution 3: Additional kernel parameters (if needed)**
```
nvidia_drm.modeset=1
```

**Testing:**
```bash
# Test suspend
systemctl suspend

# Check suspend logs after resume
journalctl -b -1 | grep -i suspend
```

### 4. Printing Setup

**CUPS (Common Unix Printing System):**

Setup printing support with one command:
```bash
just printing
```

This installs:
- CUPS printing system
- Canon TS7720 drivers (cnijfilter2)
- PPD files and filters
- system-config-printer GUI tool

**Add Canon TS7720:**
```bash
# Interactive setup for USB or Network
just printing-add-canon

# Or directly:
just printing-add-canon-usb      # USB connection
just printing-add-canon-network  # Wi-Fi/Ethernet connection
```

**Managing Printers:**
```bash
# Check status
just printing-status

# Open CUPS web interface
just printing-web                # http://localhost:631

# Send test page
just printing-test
```

**Troubleshooting:**

If printer not detected:
```bash
# Check CUPS service
systemctl status cups.service

# List available printers
lpinfo -v

# Check printer status
lpstat -p -d
```

For network printers:
- Ensure printer and PC are on same network
- Find printer IP in printer's settings menu
- Use IPP protocol: `ipp://PRINTER-IP/ipp/print`

### 5. Gaming Setup

**Essential packages:**
```bash
# Steam and Proton
steam

# Performance tools
gamemode lib32-gamemode      # Automatic CPU/GPU optimization
mangohud lib32-mangohud      # Performance overlay (FPS, temps, etc)
goverlay                     # GUI for MangoHud configuration

# Proton GE - Enhanced Proton for better game compatibility
protonup-qt                  # GUI tool to manage Proton versions

# Wine and compatibility layers
wine-staging                 # Latest Wine with experimental features
winetricks                   # Easy DLL/component installation
lib32-vkd3d                  # DirectX 12 to Vulkan translation
lib32-giflib lib32-gnutls    # Wine dependencies
```

**Performance tips:**
- Enable MangoHud: `mangohud %command%` in Steam launch options
- Enable GameMode: Games detect it automatically when installed
- Use Proton GE for better compatibility with Windows games

**Lutris (optional):**
```bash
yay -S lutris
```

### 6. Development Tools

**Core tools:**
```bash
git                          # Version control (likely installed)
base-devel                   # GCC, make, etc (needed for AUR)
cmake ninja                  # Build systems
gdb                          # Debugger
```

**nvm (Node Version Manager):**
```bash
# Install nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

# For fish shell support (if using fish)
# Install fisher (fish plugin manager)
curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source
fisher install jorgebucaran/fisher

# Install nvm.fish
fisher install jorgebucaran/nvm.fish

# Restart your shell to load nvm
```

**Node.js via nvm:**
```bash
nvm install --lts            # Latest LTS version
nvm install node             # Latest stable version
nvm alias default lts/*      # Set LTS as default
nvm use default              # Use default version

# Verify installation
node --version
npm --version
```

**GitHub CLI:**
```bash
# Install GitHub CLI
yay -S github-cli

# Authenticate with GitHub
gh auth login

# Verify installation
gh --version

# Common commands
gh repo list           # List your repositories
gh repo clone <repo>   # Clone a repository
gh pr list             # List pull requests
gh issue list          # List issues
```

**Claude CLI:**
```bash
# Install Claude Code CLI globally
npm install -g @anthropic-ai/claude-code

# Verify installation
claude --version

# Get started
claude

# Documentation
# https://docs.claude.com/claude-code
```

**Containers:**
```bash
docker docker-compose        # Container runtime
docker-buildx               # Advanced build features

# Enable and start Docker
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker $USER  # Add user to docker group
```

**Editors/IDEs:**
```bash
visual-studio-code-bin       # VS Code
neovim                       # Modern Vim
```

**Languages and runtimes:**
```bash
python python-pip            # Python 3
rust                         # Rust toolchain
go                           # Go language
jdk-openjdk                 # Java
```

**Database tools:**
```bash
postgresql                   # PostgreSQL
mongodb-bin                  # MongoDB
redis                        # Redis cache
```

**Additional dev tools:**
```bash
kubectl helm                 # Kubernetes tools
terraform                    # Infrastructure as code
ansible                      # Configuration management
ripgrep fd bat eza          # Modern CLI tools
tmux zellij                 # Terminal multiplexers
lazygit lazydocker          # TUI git/docker interfaces
```

## Verification Commands

### Check GPU status
```bash
# Hardware detection
lspci | grep -E "VGA|3D"

# Driver status
inxi -G

# Vulkan support
vulkaninfo | head -20

# Nvidia info
nvidia-smi
```

### Check OpenGL/Vulkan
```bash
# OpenGL info
glxinfo | grep "OpenGL renderer"

# Vulkan devices
vulkaninfo --summary
```

### Check video acceleration
```bash
# VA-API (Intel)
vainfo

# Should show hardware decode support for H264, HEVC, etc
```

### Monitor GPU usage
```bash
# Intel GPU
intel_gpu_top

# Nvidia GPU
nvidia-smi -l 1  # Updates every second
watch -n 1 nvidia-smi
```

## Troubleshooting

### Suspend doesn't work
1. Check Nvidia services are enabled (see section 3)
2. Check kernel parameters are set
3. Try `nvidia.NVreg_EnableS0ixPowerManagement=1` parameter
4. Check logs: `journalctl -b -1 | grep -i "suspend\|nvidia"`

### Games won't start
1. Verify Vulkan: `vulkaninfo`
2. Check Steam is using correct GPU
3. Try Proton GE instead of regular Proton
4. Enable MangoHud to see which GPU is active: `MANGOHUD=1 %command%`

### Poor gaming performance
1. Enable GameMode
2. Check if using Nvidia GPU: `nvidia-smi` while game runs
3. Use `prime-run` prefix: `prime-run steam`
4. Check thermals: `sensors` (install `lm_sensors`)

### Docker permission denied
```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Log out and back in, or:
newgrp docker
```

## Post-Setup Checklist

- [ ] GPU drivers installed and working
- [ ] Firmware updated
- [ ] Suspend/resume tested and working
- [ ] Steam installed and launches
- [ ] Canon TS7720 printer configured and working
- [ ] Docker running and user in docker group
- [ ] GitHub CLI installed and authenticated
- [ ] nvm installed and working
- [ ] Node.js and npm installed via nvm
- [ ] Claude CLI installed and accessible
- [ ] Development environment tested (git, docker, etc)

## Useful Aliases

Add to `~/.bashrc` or `~/.zshrc`:

```bash
# GPU monitoring
alias gpu-intel='intel_gpu_top'
alias gpu-nvidia='watch -n 1 nvidia-smi'

# Gaming
alias steam-nvidia='prime-run steam'

# Printing
alias print-status='lpstat -p -d'
alias print-queue='lpstat -o'

# System updates
alias update-all='yay -Syu && sudo fwupdmgr update'

# Development
alias dc='docker-compose'
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
```

## Resources

- [CachyOS Wiki](https://wiki.cachyos.org/)
- [Arch Linux Nvidia Guide](https://wiki.archlinux.org/title/NVIDIA)
- [Arch Linux Gaming Guide](https://wiki.archlinux.org/title/Gaming)
- [ProtonDB](https://www.protondb.com/) - Game compatibility database
