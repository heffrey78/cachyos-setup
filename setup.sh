#!/bin/bash

# CachyOS Setup Script
# Backup script for systems without 'just' command runner

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check system information
check_system() {
    print_header "System Information"
    echo "GPU Hardware:"
    lspci | grep -E "VGA|3D"
    echo ""
    echo "Current Drivers:"
    inxi -G
    echo ""
}

# Install Intel GPU drivers
install_intel_drivers() {
    print_header "Installing Intel GPU Drivers"
    yay -S --needed --noconfirm intel-media-driver libva-intel-driver intel-gpu-tools
    print_success "Intel drivers installed"
}

# Check Nvidia drivers
check_nvidia_drivers() {
    print_header "Checking Nvidia Drivers"
    if pacman -Qs nvidia-utils > /dev/null; then
        print_success "Nvidia drivers already installed"
        nvidia-smi --query-gpu=name,driver_version --format=csv,noheader
    else
        print_warning "Nvidia drivers not found!"
        echo "Install with: yay -S nvidia-utils nvidia-settings"
    fi
}

# Install all GPU drivers
install_drivers() {
    install_intel_drivers
    check_nvidia_drivers
    print_success "GPU drivers configured"
}

# Update firmware
update_firmware() {
    print_header "Updating Firmware"
    echo "Refreshing firmware database..."
    sudo fwupdmgr refresh --force || true
    echo ""
    echo "Checking for updates..."
    sudo fwupdmgr get-updates || echo "No firmware updates available"
    echo ""
    echo "To apply updates, run: $0 firmware-apply"
    echo ""
    echo "Checking for firmware errors..."
    sudo dmesg | grep -i firmware | grep -i "failed\|error" || echo "No firmware errors found"
}

# Apply firmware updates
apply_firmware() {
    print_header "Applying Firmware Updates"
    sudo fwupdmgr update
}

# Enable Nvidia suspend services
enable_suspend_services() {
    print_header "Enabling Nvidia Suspend Services"
    sudo systemctl enable nvidia-suspend.service
    sudo systemctl enable nvidia-hibernate.service
    sudo systemctl enable nvidia-resume.service
    print_success "Services enabled"
}

# Check kernel parameters
check_kernel_params() {
    print_header "Checking Kernel Parameters"
    echo "Current GRUB config:"
    grep "GRUB_CMDLINE_LINUX_DEFAULT" /etc/default/grub || true
    echo ""
    if grep -q "nvidia.NVreg_PreserveVideoMemoryAllocations=1" /etc/default/grub; then
        print_success "Nvidia suspend parameter already configured"
    else
        print_warning "Nvidia suspend parameter NOT configured"
        echo ""
        echo "To fix, run: $0 add-kernel-params"
    fi
}

# Add kernel parameters for suspend
add_kernel_params() {
    print_header "Adding Nvidia Suspend Parameters"
    echo "This will add 'nvidia.NVreg_PreserveVideoMemoryAllocations=1' to GRUB"
    echo ""
    read -p "Continue? [y/N] " confirm
    if [ "$confirm" != "y" ]; then
        echo "Cancelled"
        exit 1
    fi
    sudo sed -i.bak 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 nvidia.NVreg_PreserveVideoMemoryAllocations=1"/' /etc/default/grub
    sudo grub-mkconfig -o /boot/grub/grub.cfg
    print_success "Kernel parameters updated"
    print_warning "Reboot required!"
}

# Fix suspend issues
fix_suspend() {
    enable_suspend_services
    check_kernel_params
    print_success "Suspend configuration complete"
    echo ""
    print_warning "You must reboot for changes to take effect!"
    echo "After reboot, test with: systemctl suspend"
}

# Install Steam
install_steam() {
    print_header "Installing Steam"
    yay -S --needed --noconfirm steam
    print_success "Steam installed"
}

# Install gaming tools
install_gaming_tools() {
    print_header "Installing Gaming Tools"
    yay -S --needed --noconfirm gamemode lib32-gamemode mangohud lib32-mangohud goverlay protonup-qt
    print_success "Gaming tools installed"
    echo ""
    echo "Tips:"
    echo "  - Use goverlay to configure MangoHud"
    echo "  - Use protonup-qt to install Proton GE"
    echo "  - GameMode activates automatically for games"
}

# Install Wine
install_wine() {
    print_header "Installing Wine"
    yay -S --needed --noconfirm wine-staging winetricks lib32-vkd3d lib32-giflib lib32-gnutls
    print_success "Wine installed"
}

# Install all gaming components
install_gaming() {
    install_steam
    install_gaming_tools
    install_wine
    print_success "Gaming setup complete"
}

# Install core dev tools
install_dev_core() {
    print_header "Installing Core Dev Tools"
    yay -S --needed --noconfirm git base-devel cmake ninja gdb
    print_success "Core tools installed"
}

# Install Docker
install_docker() {
    print_header "Installing Docker"
    yay -S --needed --noconfirm docker docker-compose docker-buildx
    sudo systemctl enable docker
    sudo systemctl start docker || true
    echo ""
    if groups | grep -q docker; then
        print_success "User already in docker group"
    else
        echo "Adding user to docker group..."
        sudo usermod -aG docker $USER
        print_warning "Log out and back in for docker group to take effect"
    fi
    print_success "Docker installed"
}

# Install programming languages
install_languages() {
    print_header "Installing Languages"
    yay -S --needed --noconfirm python python-pip rust go
    print_success "Languages installed"
}

# Install nvm
install_nvm() {
    print_header "Installing nvm"
    if [ -d "$HOME/.nvm" ]; then
        print_success "nvm already installed"
    else
        echo "Installing nvm..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
        print_success "nvm installed"
    fi
    echo ""
    echo "Installing fisher and nvm plugin for fish shell..."
    if command -v fish > /dev/null; then
        fish -c "curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher" || true
        fish -c "fisher install jorgebucaran/nvm.fish" || true
        print_success "Fish shell nvm plugin installed"
    else
        print_warning "Fish shell not found, skipping fish nvm plugin"
    fi
    echo ""
    print_warning "Restart your shell to use nvm"
}

# Install Node.js via nvm
install_node() {
    install_nvm
    print_header "Installing Node.js via nvm"
    # Source nvm and install Node
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    nvm install --lts
    nvm install node
    nvm alias default lts/*
    nvm use default

    print_success "Node.js installed"
    echo ""
    echo "Installed versions:"
    nvm list
}

# Install Claude CLI
install_claude() {
    install_node
    print_header "Installing Claude CLI"
    # Source nvm and install Claude
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    nvm use default
    npm install -g @anthropic-ai/claude-code

    print_success "Claude CLI installed"
    echo ""
    echo "Run 'claude' to get started"
    echo "Documentation: https://docs.claude.com/claude-code"
}

# Install Google Antigravity
install_antigravity() {
    print_header "Installing Google Antigravity"
    if command -v antigravity > /dev/null 2>&1; then
        print_success "Antigravity already installed"
        antigravity --version 2>/dev/null || true
    else
        echo "Installing Antigravity from AUR..."
        yay -S --needed --noconfirm antigravity-bin
        print_success "Antigravity installed"
    fi
    echo ""
    echo "Launch with: antigravity"
    echo "Or find 'Antigravity' in your application menu"
}

# Install GitHub CLI
install_gh() {
    print_header "Installing GitHub CLI"
    yay -S --needed --noconfirm github-cli
    print_success "GitHub CLI installed"
    echo ""
    echo "To authenticate with GitHub, run:"
    echo "  gh auth login"
}

# Install all dev tools
install_dev_tools() {
    install_dev_core
    install_docker
    install_languages
    install_gh
    install_node
    install_claude
    print_success "Development tools installed"
}

# Install Hyprland
install_hyprland() {
    print_header "Installing Hyprland"
    if pacman -Qs "^hyprland " > /dev/null 2>&1; then
        print_success "Hyprland already installed"
    else
        echo "Installing Hyprland from official repos..."
        yay -S --needed --noconfirm hyprland
        print_success "Hyprland installed"
    fi
}

# Install Hyprland dependencies
install_hyprland_deps() {
    print_header "Installing Hyprland Dependencies & Tools"
    echo "Installing core ecosystem..."
    yay -S --needed --noconfirm \
        xdg-desktop-portal-hyprland \
        qt5-wayland qt6-wayland \
        hyprpaper hyprlock hypridle \
        waybar \
        wofi \
        kitty \
        dunst \
        grim slurp \
        wl-clipboard \
        polkit-kde-agent \
        pipewire wireplumber
    print_success "Core dependencies installed"
    echo ""
    echo "Optional tools (install separately if needed):"
    echo "  - File manager: thunar dolphin"
    echo "  - Terminal: alacritty foot wezterm"
    echo "  - App launcher: rofi-wayland fuzzel"
    echo "  - Screenshot: swappy"
    echo "  - Screen recording: wf-recorder obs-studio"
    echo "  - Network: nm-applet"
    echo "  - Audio: pavucontrol"
}

# Check Hyprland status
check_hyprland_status() {
    print_header "Hyprland Status"
    echo ""
    echo "Installation:"
    if command -v Hyprland > /dev/null; then
        print_success "Hyprland installed"
        Hyprland --version 2>&1 | head -1 | sed 's/^/    /'
    else
        print_error "Hyprland not installed (run: $0 hyprland)"
    fi
    echo ""
    echo "Core Components:"
    if command -v waybar > /dev/null; then
        print_success "Waybar (status bar)"
    else
        print_error "Waybar missing"
    fi
    if command -v wofi > /dev/null; then
        print_success "Wofi (app launcher)"
    else
        print_error "Wofi missing"
    fi
    if command -v hyprlock > /dev/null; then
        print_success "Hyprlock (screen locker)"
    else
        print_error "Hyprlock missing"
    fi
    if command -v hyprpaper > /dev/null; then
        print_success "Hyprpaper (wallpaper)"
    else
        print_error "Hyprpaper missing"
    fi
    echo ""
    echo "Configuration:"
    if [ -f ~/.config/hypr/hyprland.conf ]; then
        print_success "Config file exists"
        echo "    Location: ~/.config/hypr/hyprland.conf"
    else
        print_warning "No config file (will use defaults)"
        echo "    Default config will be created on first launch"
    fi
    echo ""
    echo "Session:"
    if [ "$XDG_CURRENT_DESKTOP" = "Hyprland" ]; then
        print_success "Currently running Hyprland"
        echo "    Session type: $XDG_SESSION_TYPE"
    else
        echo "  ℹ Not currently in Hyprland session"
        echo "    Current desktop: $XDG_CURRENT_DESKTOP"
        echo "    Log out and select Hyprland at login screen"
    fi
}

# Install complete Hyprland setup
install_hyprland_complete() {
    install_hyprland
    install_hyprland_deps
    check_hyprland_status
    print_success "Hyprland setup complete"
    echo ""
    echo "To use Hyprland:"
    echo "  1. Log out of your current session"
    echo "  2. Select 'Hyprland' from the session menu at login"
    echo "  3. Default config: ~/.config/hypr/hyprland.conf"
    echo ""
    echo "Resources:"
    echo "  - Wiki: https://wiki.hypr.land/"
    echo "  - Config examples: https://github.com/hyprland-community/awesome-hyprland"
}

# Verify installation
verify() {
    print_header "Verification"
    echo ""
    echo "GPU Drivers:"
    if lspci | grep -q VGA; then
        print_success "GPUs detected"
    else
        print_error "No GPUs found"
    fi

    if command -v nvidia-smi > /dev/null; then
        print_success "Nvidia driver installed"
        nvidia-smi --query-gpu=name --format=csv,noheader | sed 's/^/    /'
    else
        print_error "Nvidia driver missing"
    fi

    echo ""
    echo "Vulkan Support:"
    if command -v vulkaninfo > /dev/null; then
        print_success "Vulkan tools installed"
    else
        print_error "Vulkan tools missing"
    fi

    echo ""
    echo "Gaming:"
    if command -v steam > /dev/null; then
        print_success "Steam installed"
    else
        print_error "Steam missing"
    fi

    if command -v mangohud > /dev/null; then
        print_success "MangoHud installed"
    else
        print_error "MangoHud missing"
    fi

    if command -v gamemoded > /dev/null; then
        print_success "GameMode installed"
    else
        print_error "GameMode missing"
    fi

    echo ""
    echo "Development:"
    if command -v git > /dev/null; then
        print_success "Git installed"
    else
        print_error "Git missing"
    fi

    if command -v docker > /dev/null; then
        print_success "Docker installed"
        docker --version | sed 's/^/    /'
    else
        print_error "Docker missing"
    fi

    if [ -d "$HOME/.nvm" ]; then
        print_success "nvm installed"
    else
        print_error "nvm missing"
    fi

    if command -v node > /dev/null; then
        print_success "Node.js installed"
        node --version | sed 's/^/    /'
    else
        print_warning "Node.js missing (run: $0 node)"
    fi

    if command -v npm > /dev/null; then
        print_success "npm installed"
        npm --version | sed 's/^/    /'
    else
        print_error "npm missing"
    fi

    if command -v claude > /dev/null; then
        print_success "Claude CLI installed"
    else
        print_warning "Claude CLI missing (run: $0 claude)"
    fi

    if command -v gh > /dev/null; then
        print_success "GitHub CLI installed"
        gh --version | head -1 | sed 's/^/    /'
    else
        print_warning "GitHub CLI missing (run: $0 gh)"
    fi

    if command -v python > /dev/null; then
        print_success "Python installed"
        python --version | sed 's/^/    /'
    else
        print_error "Python missing"
    fi

    echo ""
}

# Run all setup steps
setup_all() {
    check_system
    install_drivers
    update_firmware
    fix_suspend
    install_gaming
    install_dev_tools
    verify

    print_header "Setup Complete!"
    echo ""
    echo "Next steps:"
    echo "  1. Reboot your system"
    echo "  2. Test suspend/resume"
    echo "  3. Run '$0 verify' to check everything"
    echo "  4. Restart your shell to load nvm"
}

# Show help
show_help() {
    cat << EOF
CachyOS Setup Script

Usage: $0 [command]

Commands:
  all              Run complete setup (recommended)
  check            Check system information
  drivers          Install GPU drivers
  firmware         Check firmware updates
  firmware-apply   Apply firmware updates
  suspend          Fix suspend/resume issues
  add-kernel-params Add kernel parameters for suspend
  gaming           Install gaming tools
  dev              Install development tools
  gh               Install GitHub CLI
  nvm              Install nvm (Node Version Manager)
  node             Install Node.js via nvm
  claude           Install Claude CLI
  antigravity      Install Google Antigravity (AI-powered IDE)
  hyprland         Install Hyprland (tiling Wayland compositor)
  hyprland-status  Check Hyprland installation status
  verify           Verify installation
  help             Show this help message

Examples:
  $0 all           # Run full setup
  $0 drivers       # Install only drivers
  $0 gaming        # Install only gaming tools
  $0 node          # Install nvm and Node.js
  $0 claude        # Install Claude CLI
  $0 hyprland      # Install Hyprland window manager

For more information, see README.md
EOF
}

# Main script logic
case "${1:-help}" in
    all)
        setup_all
        ;;
    check)
        check_system
        ;;
    drivers)
        install_drivers
        ;;
    firmware)
        update_firmware
        ;;
    firmware-apply)
        apply_firmware
        ;;
    suspend)
        fix_suspend
        ;;
    add-kernel-params)
        add_kernel_params
        ;;
    gaming)
        install_gaming
        ;;
    dev)
        install_dev_tools
        ;;
    gh)
        install_gh
        ;;
    nvm)
        install_nvm
        ;;
    node)
        install_node
        ;;
    claude)
        install_claude
        ;;
    antigravity)
        install_antigravity
        ;;
    hyprland)
        install_hyprland_complete
        ;;
    hyprland-status)
        check_hyprland_status
        ;;
    verify)
        verify
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run '$0 help' for usage information"
        exit 1
        ;;
esac
