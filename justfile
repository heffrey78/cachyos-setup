# CachyOS Setup Automation
# Run `just --list` to see all available commands

# Default recipe - shows help
default:
    @just --list

# Run complete setup (all components)
setup-all: check-system drivers firmware suspend-fix gaming vr scanning printing dev-tools dev-node dev-claude verify
    @echo "================================"
    @echo "✓ Complete setup finished!"
    @echo "================================"
    @echo ""
    @echo "Next steps:"
    @echo "  1. Reboot your system"
    @echo "  2. Test suspend/resume"
    @echo "  3. Run 'just verify' to check everything"
    @echo "  4. Restart your shell to load nvm"
    @echo "  5. Set up Quest 3: Install ALVR from Meta AppLab"
    @echo "  6. Launch VR: just vr-launch"

# Check system information
check-system:
    @echo "=== System Information ==="
    @echo "GPU Hardware:"
    @lspci | grep -E "VGA|3D"
    @echo ""
    @echo "Current Drivers:"
    @inxi -G
    @echo ""

# Install and configure GPU drivers
drivers: intel-drivers nvidia-check
    @echo "✓ GPU drivers configured"

# Install Intel GPU drivers and tools
intel-drivers:
    @echo "=== Installing Intel GPU Drivers ==="
    yay -S --needed --noconfirm intel-media-driver libva-intel-driver intel-gpu-tools
    @echo "✓ Intel drivers installed"

# Verify Nvidia drivers (already installed)
nvidia-check:
    @echo "=== Checking Nvidia Drivers ==="
    @if pacman -Qs nvidia-utils > /dev/null; then \
        echo "✓ Nvidia drivers already installed"; \
        nvidia-smi --query-gpu=name,driver_version --format=csv,noheader; \
    else \
        echo "⚠ Nvidia drivers not found!"; \
        echo "Install with: yay -S nvidia-utils nvidia-settings"; \
    fi

# Update system firmware
firmware:
    @echo "=== Updating Firmware ==="
    @echo "Refreshing firmware database..."
    sudo fwupdmgr refresh --force || true
    @echo ""
    @echo "Checking for updates..."
    sudo fwupdmgr get-updates || echo "No firmware updates available"
    @echo ""
    @echo "To apply updates, run: just firmware-apply"
    @echo ""
    @echo "Checking for firmware errors..."
    @sudo dmesg | grep -i firmware | grep -i "failed\|error" || echo "No firmware errors found"

# Apply firmware updates
firmware-apply:
    @echo "=== Applying Firmware Updates ==="
    sudo fwupdmgr update

# Fix suspend/resume issues
suspend-fix: suspend-services suspend-kernel-params
    @echo "✓ Suspend configuration complete"
    @echo ""
    @echo "⚠ You must reboot for changes to take effect!"
    @echo "After reboot, test with: systemctl suspend"

# Enable Nvidia suspend services
suspend-services:
    @echo "=== Enabling Nvidia Suspend Services ==="
    sudo systemctl enable nvidia-suspend.service
    sudo systemctl enable nvidia-hibernate.service
    sudo systemctl enable nvidia-resume.service
    @echo "✓ Services enabled"

# Configure kernel parameters for suspend
suspend-kernel-params:
    @echo "=== Checking Kernel Parameters ==="
    @echo "Current GRUB config:"
    @grep "GRUB_CMDLINE_LINUX_DEFAULT" /etc/default/grub || true
    @echo ""
    @if grep -q "nvidia.NVreg_PreserveVideoMemoryAllocations=1" /etc/default/grub; then \
        echo "✓ Nvidia suspend parameter already configured"; \
    else \
        echo "⚠ Nvidia suspend parameter NOT configured"; \
        echo ""; \
        echo "To fix, run: just suspend-kernel-params-add"; \
    fi

# Add Nvidia suspend kernel parameters (interactive)
suspend-kernel-params-add:
    @echo "=== Adding Nvidia Suspend Parameters ==="
    @echo "This will add 'nvidia.NVreg_PreserveVideoMemoryAllocations=1' to GRUB"
    @echo ""
    @read -p "Continue? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 1
    sudo sed -i.bak 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 nvidia.NVreg_PreserveVideoMemoryAllocations=1"/' /etc/default/grub
    sudo grub-mkconfig -o /boot/grub/grub.cfg
    @echo "✓ Kernel parameters updated"
    @echo "⚠ Reboot required!"

# Install gaming tools and libraries
gaming: gaming-steam gaming-tools gaming-wine
    @echo "✓ Gaming setup complete"

# Install Steam
gaming-steam:
    @echo "=== Installing Steam ==="
    yay -S --needed --noconfirm steam
    @echo "✓ Steam installed"

# Install gaming performance tools
gaming-tools:
    @echo "=== Installing Gaming Tools ==="
    yay -S --needed --noconfirm gamemode lib32-gamemode mangohud lib32-mangohud goverlay protonup-qt
    @echo "✓ Gaming tools installed"
    @echo ""
    @echo "Tips:"
    @echo "  - Use goverlay to configure MangoHud"
    @echo "  - Use protonup-qt to install Proton GE"
    @echo "  - GameMode activates automatically for games"

# Install Wine and compatibility layers
gaming-wine:
    @echo "=== Installing Wine ==="
    yay -S --needed --noconfirm wine-staging winetricks lib32-vkd3d lib32-giflib lib32-gnutls
    @echo "✓ Wine installed"

# Configure esync for better gaming performance
gaming-esync:
    @echo "=== Configuring Esync ==="
    @echo "Esync improves Wine/Proton performance by using eventfd-based synchronization"
    @echo ""
    @current=$$(ulimit -Hn); \
    if [ "$$current" -ge 524288 ]; then \
        echo "✓ File descriptor limit already sufficient: $$current"; \
    else \
        echo "Current hard limit: $$current"; \
        echo "Recommended: 524288"; \
        echo ""; \
        echo "Adding limits to /etc/security/limits.conf..."; \
        if grep -q "nofile 524288" /etc/security/limits.conf 2>/dev/null; then \
            echo "✓ Limits already configured"; \
        else \
            echo "* hard nofile 524288" | sudo tee -a /etc/security/limits.conf; \
            echo "* soft nofile 524288" | sudo tee -a /etc/security/limits.conf; \
            echo "✓ Limits configured"; \
            echo ""; \
            echo "⚠ Log out and back in for changes to take effect"; \
        fi; \
    fi

# Check esync status
gaming-esync-status:
    @echo "=== Esync Status ==="
    @echo ""
    @echo "Current limits:"
    @echo "  Soft limit: $$(ulimit -Sn)"
    @echo "  Hard limit: $$(ulimit -Hn)"
    @echo ""
    @if [ "$$(ulimit -Hn)" -ge 524288 ]; then \
        echo "✓ Esync ready (limit >= 524288)"; \
    else \
        echo "✗ Esync may not work properly"; \
        echo "  Run: just gaming-esync"; \
    fi

# Install Lutris (optional game launcher)
gaming-lutris:
    @echo "=== Installing Lutris ==="
    yay -S --needed --noconfirm lutris
    @echo "✓ Lutris installed"

# Install scanning support
scanning: scanning-packages scanning-status
    @echo "✓ Scanning setup complete"
    @echo ""
    @echo "Launch Skanlite: just scan"
    @echo "Launch XSane: just scan-xsane"

# Install scanning packages
scanning-packages:
    @echo "=== Installing Scanning Packages ==="
    @if pacman -Qs skanlite > /dev/null 2>&1; then \
        echo "✓ Skanlite already installed"; \
    else \
        echo "Installing Skanlite..."; \
        yay -S --needed --noconfirm skanlite; \
        echo "✓ Skanlite installed"; \
    fi
    @if pacman -Qs xsane > /dev/null 2>&1; then \
        echo "✓ XSane already installed"; \
    else \
        echo "Installing XSane..."; \
        yay -S --needed --noconfirm xsane; \
        echo "✓ XSane installed"; \
    fi
    @if pacman -Qs gimp > /dev/null 2>&1; then \
        echo "✓ GIMP already installed"; \
    else \
        echo "Installing GIMP for image editing..."; \
        yay -S --needed --noconfirm gimp; \
        echo "✓ GIMP installed"; \
    fi
    @echo "✓ Scanning packages installed"

# Check scanning setup status
scanning-status:
    @echo "=== Scanning Status ==="
    @echo ""
    @echo "SANE Backend:"
    @if command -v scanimage > /dev/null; then \
        echo "  ✓ SANE installed"; \
        scanimage --version 2>&1 | head -1 | sed 's/^/    /'; \
    else \
        echo "  ✗ SANE not installed"; \
    fi
    @echo ""
    @echo "Scanning Applications:"
    @if command -v skanlite > /dev/null; then \
        echo "  ✓ Skanlite installed"; \
    else \
        echo "  ✗ Skanlite missing"; \
    fi
    @if command -v xsane > /dev/null; then \
        echo "  ✓ XSane installed"; \
    else \
        echo "  ✗ XSane missing"; \
    fi
    @echo ""
    @echo "Image Editing:"
    @if command -v gimp > /dev/null; then \
        echo "  ✓ GIMP installed"; \
        gimp --version 2>&1 | head -1 | sed 's/^/    /'; \
    else \
        echo "  ✗ GIMP missing (run: just scanning-packages)"; \
    fi
    @echo ""
    @echo "Detecting scanners..."
    @scanimage -L 2>/dev/null || echo "  No scanners detected (make sure scanner is connected and powered on)"

# Launch Skanlite for scanning
scan:
    @echo "=== Launching Skanlite ==="
    @if command -v skanlite > /dev/null; then \
        skanlite; \
    else \
        echo "✗ Skanlite not installed"; \
        echo "Install with: just scanning"; \
    fi

# Launch XSane for advanced scanning
scan-xsane:
    @echo "=== Launching XSane ==="
    @if command -v xsane > /dev/null; then \
        xsane; \
    else \
        echo "✗ XSane not installed"; \
        echo "Install with: just scanning"; \
    fi

# List available scanners
scan-list:
    @echo "=== Available Scanners ==="
    @if command -v scanimage > /dev/null; then \
        scanimage -L; \
    else \
        echo "✗ SANE not installed"; \
        echo "Install with: yay -S sane"; \
    fi

# Quick scan with command line (save to scan.png)
scan-quick:
    @echo "=== Quick Scan ==="
    @if command -v scanimage > /dev/null; then \
        echo "Scanning to scan.png..."; \
        scanimage --format=png > scan.png && echo "✓ Saved to scan.png"; \
    else \
        echo "✗ SANE not installed"; \
        echo "Install with: yay -S sane"; \
    fi

# Install printing support and configure printers
printing: printing-packages printing-enable printing-canon
    @echo "✓ Printing setup complete"
    @echo ""
    @echo "CUPS web interface: http://localhost:631"
    @echo "To add Canon TS7720: just printing-add-canon"

# Install CUPS and printing packages
printing-packages:
    @echo "=== Installing Printing Packages ==="
    yay -S --needed --noconfirm cups cups-filters cups-pdf system-config-printer gutenprint foomatic-db-engine foomatic-db foomatic-db-ppds foomatic-db-nonfree-ppds
    @echo "✓ Printing packages installed"

# Enable and start CUPS service
printing-enable:
    @echo "=== Enabling CUPS Service ==="
    sudo systemctl enable cups.service
    sudo systemctl start cups.service
    @echo "✓ CUPS service enabled and started"
    @echo ""
    @systemctl status cups.service --no-pager | head -5

# Install Canon printer drivers
printing-canon:
    @echo "=== Installing Canon Printer Drivers ==="
    @if pacman -Qs cnijfilter2 > /dev/null 2>&1; then \
        echo "✓ Canon drivers already installed"; \
    else \
        echo "Installing Canon drivers from AUR..."; \
        yay -S --needed --noconfirm cnijfilter2; \
        echo "✓ Canon drivers installed"; \
    fi
    @echo ""
    @echo "Canon TS7720 driver installed"
    @echo "To add printer: just printing-add-canon"

# Add Canon TS7720 printer (USB or Network)
printing-add-canon:
    @echo "=== Adding Canon TS7720 Printer ==="
    @echo ""
    @echo "Choose connection method:"
    @echo "  1. USB - Printer connected via USB cable"
    @echo "  2. Network - Printer on Wi-Fi/Ethernet"
    @echo ""
    @read -p "Enter choice [1-2]: " choice; \
    case $$choice in \
        1) just printing-add-canon-usb ;; \
        2) just printing-add-canon-network ;; \
        *) echo "Invalid choice" ;; \
    esac

# Add Canon TS7720 via USB
printing-add-canon-usb:
    @echo "=== Adding Canon TS7720 (USB) ==="
    @echo ""
    @echo "Available USB printers:"
    @lpinfo -v | grep usb || echo "No USB printers detected"
    @echo ""
    @echo "Make sure printer is:"
    @echo "  - Connected via USB"
    @echo "  - Powered on"
    @echo ""
    @echo "Opening CUPS web interface..."
    @echo "Navigate to: Administration > Add Printer"
    @echo ""
    @xdg-open http://localhost:631/admin || firefox http://localhost:631/admin || chromium http://localhost:631/admin || echo "Open http://localhost:631/admin in your browser"

# Add Canon TS7720 via Network
printing-add-canon-network:
    @echo "=== Adding Canon TS7720 (Network) ==="
    @echo ""
    @echo "Scanning for network printers (this may take 30 seconds)..."
    @lpinfo -v | grep -E "dnssd|ipp|lpd|socket" || echo "No network printers detected"
    @echo ""
    @echo "Make sure printer is:"
    @echo "  - Connected to same network as this PC"
    @echo "  - Powered on"
    @echo "  - Find printer IP in printer settings menu"
    @echo ""
    @echo "Opening CUPS web interface..."
    @echo "Navigate to: Administration > Add Printer"
    @echo ""
    @xdg-open http://localhost:631/admin || firefox http://localhost:631/admin || chromium http://localhost:631/admin || echo "Open http://localhost:631/admin in your browser"

# Open CUPS web interface
printing-web:
    @echo "=== Opening CUPS Web Interface ==="
    @xdg-open http://localhost:631 || firefox http://localhost:631 || chromium http://localhost:631 || echo "Open http://localhost:631 in your browser"

# Check printing status
printing-status:
    @echo "=== Printing Status ==="
    @echo ""
    @echo "CUPS Service:"
    @systemctl status cups.service --no-pager | head -5
    @echo ""
    @echo "Installed Printers:"
    @lpstat -p -d 2>/dev/null || echo "No printers configured yet"
    @echo ""
    @echo "Print Queue:"
    @lpstat -o 2>/dev/null || echo "No print jobs"
    @echo ""
    @echo "Web Interface: http://localhost:631"

# Test print
printing-test:
    @echo "=== Test Print ==="
    @echo ""
    @echo "Available printers:"
    @lpstat -p -d 2>/dev/null || echo "No printers configured"
    @echo ""
    @read -p "Enter printer name: " printer; \
    echo "Sending test page to $$printer..."; \
    echo "This is a test print from CachyOS" | lp -d $$printer && echo "✓ Test page sent to printer"

# Install VR streaming tools for Quest 3
vr: vr-libs vr-steamvr vr-alvr
    @echo "✓ VR setup complete"
    @echo ""
    @echo "Next steps for Quest 3:"
    @echo "  1. Install ALVR on Quest 3 from Meta AppLab:"
    @echo "     https://www.meta.com/experiences/alvr/7674846229245715/"
    @echo "  2. Connect Quest 3 to 5GHz Wi-Fi (same network as PC)"
    @echo "  3. Launch ALVR: just vr-launch"
    @echo "  4. Start ALVR app on Quest 3"
    @echo "  5. Accept trust prompt on PC when headset appears"
    @echo ""
    @echo "Tips:"
    @echo "  - Connect PC via ethernet for best performance"
    @echo "  - Use Wi-Fi 6 router if available"
    @echo "  - Configure bitrate in ALVR dashboard (30-100 Mbps typical)"

# Install required 32-bit libraries for VR
vr-libs:
    @echo "=== Installing VR Libraries ==="
    yay -S --needed --noconfirm lib32-gtk2 lib32-libva lib32-libvdpau lib32-vulkan-icd-loader
    @if lspci | grep -i nvidia > /dev/null; then \
        echo "Installing Nvidia 32-bit libraries..."; \
        yay -S --needed --noconfirm lib32-nvidia-utils || true; \
    fi
    @echo "✓ VR libraries installed"

# Install SteamVR
vr-steamvr:
    @echo "=== Setting up SteamVR ==="
    @if command -v steam > /dev/null; then \
        echo "✓ Steam already installed"; \
    else \
        echo "Installing Steam..."; \
        yay -S --needed --noconfirm steam; \
    fi
    @echo ""
    @echo "SteamVR setup:"
    @echo "  1. Launch Steam"
    @echo "  2. Install 'SteamVR' from the store"
    @echo "  3. Launch SteamVR once, then close it"
    @echo "  4. ALVR will use SteamVR automatically"

# Install ALVR for Quest streaming
vr-alvr:
    @echo "=== Installing ALVR ==="
    @echo "ALVR enables wireless streaming from PC to Quest 3"
    @echo ""
    @if pacman -Qs "^alvr" > /dev/null; then \
        echo "✓ ALVR already installed"; \
        pacman -Qs "^alvr"; \
    else \
        if lspci | grep -i nvidia > /dev/null; then \
            echo "Installing ALVR for Nvidia..."; \
            yay -S --needed --noconfirm alvr-nvidia; \
        else \
            echo "Installing ALVR..."; \
            yay -S --needed --noconfirm alvr; \
        fi; \
        echo "✓ ALVR installed"; \
    fi
    @echo ""
    @echo "ALVR installed! Launch with: just vr-launch"

# Launch ALVR dashboard
vr-launch:
    @echo "=== Launching ALVR Dashboard ==="
    @if command -v alvr_dashboard > /dev/null; then \
        alvr_dashboard; \
    else \
        echo "✗ ALVR not installed"; \
        echo "Install with: just vr"; \
    fi

# Configure firewall for ALVR (if using firewalld)
vr-firewall:
    @echo "=== Configuring Firewall for ALVR ==="
    @if systemctl is-active --quiet firewalld; then \
        echo "Opening ALVR ports (9943-9944 TCP/UDP)..."; \
        sudo firewall-cmd --permanent --add-port=9943-9944/tcp; \
        sudo firewall-cmd --permanent --add-port=9943-9944/udp; \
        sudo firewall-cmd --reload; \
        echo "✓ Firewall configured"; \
    else \
        echo "⚠ firewalld not active, skipping"; \
        echo "If using another firewall, open ports:"; \
        echo "  TCP/UDP: 9943-9944"; \
    fi

# Check VR setup status
vr-status:
    @echo "=== VR Setup Status ==="
    @echo ""
    @echo "SteamVR:"
    @if [ -d "$$HOME/.steam/steam/steamapps/common/SteamVR" ]; then \
        echo "  ✓ SteamVR installed"; \
    else \
        echo "  ✗ SteamVR not found"; \
        echo "    Install from Steam store"; \
    fi
    @echo ""
    @echo "ALVR:"
    @if command -v alvr_dashboard > /dev/null; then \
        echo "  ✓ ALVR installed"; \
        pacman -Qs "^alvr" | grep "^local" | sed 's/^/    /'; \
    else \
        echo "  ✗ ALVR not installed"; \
        echo "    Run: just vr"; \
    fi
    @echo ""
    @echo "Required Libraries:"
    @if pacman -Qs lib32-vulkan-icd-loader > /dev/null; then \
        echo "  ✓ 32-bit libraries installed"; \
    else \
        echo "  ✗ 32-bit libraries missing"; \
    fi
    @echo ""
    @echo "GPU (for VR encoding):"
    @if command -v nvidia-smi > /dev/null; then \
        echo "  ✓ Nvidia GPU with NVENC"; \
        nvidia-smi --query-gpu=name --format=csv,noheader | sed 's/^/    /'; \
    else \
        echo "  ⚠ Check GPU encoding support"; \
    fi
    @echo ""
    @echo "Network Tips:"
    @echo "  - Connect Quest 3 to 5GHz Wi-Fi"
    @echo "  - Connect PC via ethernet (recommended)"
    @echo "  - Use Wi-Fi 6 router for best quality"
    @echo "  - Typical bitrate: 30-100 Mbps"

# Install VR game examples (optional)
vr-games-demo:
    @echo "=== Free VR Demos on Steam ==="
    @echo ""
    @echo "To install via Steam:"
    @echo "  - The Lab (Valve's VR showcase)"
    @echo "  - Google Earth VR"
    @echo "  - VRChat (social VR)"
    @echo "  - Rec Room (free multiplayer)"
    @echo ""
    @echo "Popular paid VR games:"
    @echo "  - Half-Life: Alyx"
    @echo "  - Beat Saber"
    @echo "  - Superhot VR"
    @echo "  - Boneworks"

# Configure git with user information
dev-git:
    @echo "=== Configuring Git ==="
    @echo "Setting git user email to heffrey78@gmail.com..."
    git config --global user.email "heffrey78@gmail.com"
    @echo "Setting git user name..."
    @if git config --global user.name > /dev/null 2>&1; then \
        echo "✓ Git user name already set to: $$(git config --global user.name)"; \
    else \
        read -p "Enter your full name for git commits: " name; \
        git config --global user.name "$$name"; \
        echo "✓ Git user name set to: $$name"; \
    fi
    @echo ""
    @echo "Setting default branch name to 'main'..."
    git config --global init.defaultBranch main
    @echo ""
    @echo "Setting pull strategy to rebase..."
    git config --global pull.rebase false
    @echo ""
    @if command -v gh > /dev/null; then \
        echo "Configuring GitHub CLI as git credential helper..."; \
        gh auth setup-git; \
        echo "✓ GitHub credential helper configured"; \
    else \
        echo "⚠ GitHub CLI not installed, skipping credential setup"; \
        echo "  Install with: just dev-gh, then run: gh auth login"; \
    fi
    @echo ""
    @echo "✓ Git configuration complete"
    @echo ""
    @echo "Current git config:"
    @git config --global --list | grep -E "^user\.(name|email)" | sed 's/^/  /'
    @git config --global --list | grep -E "^init\.defaultBranch" | sed 's/^/  /'

# Development tools
dev-tools: dev-git dev-core dev-docker dev-languages dev-gh
    @echo "✓ Development tools installed"

# Install core development tools
dev-core:
    @echo "=== Installing Core Dev Tools ==="
    yay -S --needed --noconfirm git base-devel cmake ninja gdb
    @echo "✓ Core tools installed"

# Install and configure Docker
dev-docker:
    @echo "=== Installing Docker ==="
    yay -S --needed --noconfirm docker docker-compose docker-buildx
    sudo systemctl enable docker
    sudo systemctl start docker || true
    @echo ""
    @if groups | grep -q docker; then \
        echo "✓ User already in docker group"; \
    else \
        echo "Adding user to docker group..."; \
        sudo usermod -aG docker $$USER; \
        echo "⚠ Log out and back in for docker group to take effect"; \
    fi
    @echo "✓ Docker installed"

# Install programming languages and runtimes
dev-languages:
    @echo "=== Installing Languages ==="
    yay -S --needed --noconfirm python python-pip rust go
    @echo "✓ Languages installed"
    @echo ""
    @echo "Node.js: Use nvm to install versions"
    @echo "  nvm install --lts"
    @echo "  nvm install node"

# Install VS Code with recommended extensions
dev-vscode: dev-vscode-install dev-vscode-extensions-prompt
    @echo "✓ VS Code setup complete"
    @echo ""
    @echo "Launch with: code"
    @echo "Documentation: https://code.visualstudio.com/docs"

# Install VS Code binary
dev-vscode-install:
    @echo "=== Installing VS Code ==="
    yay -S --needed --noconfirm visual-studio-code-bin
    @echo "✓ VS Code installed"

# Prompt for optional extensions
dev-vscode-extensions-prompt:
    @echo ""
    @echo "Install recommended extensions? (requires code to be in PATH)"
    @echo "Run: just dev-vscode-extensions"

# Install recommended extensions for development
dev-vscode-extensions:
    @echo "=== Installing VS Code Extensions ==="
    @echo ""
    @echo "Core Extensions:"
    code --install-extension editorconfig.editorconfig
    code --install-extension eamodio.gitlens
    @echo ""
    @echo "Docker:"
    code --install-extension ms-azuretools.vscode-docker
    @echo ""
    @echo "Node.js/JavaScript/TypeScript:"
    code --install-extension dbaeumer.vscode-eslint
    code --install-extension esbenp.prettier-vscode
    @echo ""
    @echo "Python:"
    code --install-extension ms-python.python
    code --install-extension ms-python.vscode-pylance
    @echo ""
    @echo "Rust:"
    code --install-extension rust-lang.rust-analyzer
    @echo ""
    @echo "Go:"
    code --install-extension golang.go
    @echo ""
    @echo "✓ Extensions installed"
    @echo ""
    @echo "Additional recommended extensions:"
    @echo "  - GitHub Copilot: code --install-extension github.copilot"
    @echo "  - Remote SSH: code --install-extension ms-vscode-remote.remote-ssh"
    @echo "  - Live Share: code --install-extension ms-vsliveshare.vsliveshare"

# Install modern CLI tools
dev-cli-tools:
    @echo "=== Installing Modern CLI Tools ==="
    yay -S --needed --noconfirm ripgrep fd bat eza tmux lazygit lazydocker github-cli
    @echo "✓ CLI tools installed"

# Install and authenticate GitHub CLI
dev-gh:
    @echo "=== Installing GitHub CLI ==="
    yay -S --needed --noconfirm github-cli
    @echo "✓ GitHub CLI installed"
    @echo ""
    @echo "To authenticate with GitHub, run:"
    @echo "  gh auth login"

# Install database tools
dev-databases:
    @echo "=== Installing Databases ==="
    yay -S --needed --noconfirm postgresql redis
    @echo ""
    @echo "To enable PostgreSQL:"
    @echo "  sudo systemctl enable postgresql"
    @echo "  sudo systemctl start postgresql"

# Install and configure nvm
dev-nvm:
    @echo "=== Installing nvm ==="
    @if [ -d "$$HOME/.nvm" ]; then \
        echo "✓ nvm already installed"; \
    else \
        echo "Installing nvm..."; \
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash; \
        echo "✓ nvm installed"; \
    fi
    @echo ""
    @echo "Installing fisher and nvm plugin for fish shell..."
    @if command -v fish > /dev/null; then \
        fish -c "curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher" || true; \
        fish -c "fisher install jorgebucaran/nvm.fish" || true; \
        echo "✓ Fish shell nvm plugin installed"; \
    else \
        echo "⚠ Fish shell not found, skipping fish nvm plugin"; \
    fi
    @echo ""
    @echo "⚠ Restart your shell to use nvm"

# Install Node.js via nvm
dev-node: dev-nvm
    @echo "=== Installing Node.js via nvm ==="
    @bash -c "source $$HOME/.nvm/nvm.sh && nvm install --lts && nvm install node && nvm alias default lts/* && nvm use default"
    @echo "✓ Node.js installed"
    @echo ""
    @echo "Installed versions:"
    @bash -c "source $$HOME/.nvm/nvm.sh && nvm list"

# Install Claude CLI
dev-claude: dev-node
    @echo "=== Installing Claude CLI ==="
    @bash -c "source $$HOME/.nvm/nvm.sh && nvm use default && npm install -g @anthropic-ai/claude-code"
    @echo "✓ Claude CLI installed"
    @echo ""
    @echo "Run 'claude' to get started"
    @echo "Documentation: https://docs.claude.com/claude-code"

# Install Google Antigravity (AI-powered IDE)
dev-antigravity:
    @echo "=== Installing Google Antigravity ==="
    @if command -v antigravity > /dev/null 2>&1; then \
        echo "✓ Antigravity already installed"; \
        antigravity --version 2>/dev/null || true; \
    else \
        echo "Installing Antigravity from AUR..."; \
        yay -S --needed --noconfirm antigravity-bin; \
        echo "✓ Antigravity installed"; \
    fi
    @echo ""
    @echo "Launch with: antigravity"
    @echo "Or find 'Antigravity' in your application menu"

# Check Antigravity status
dev-antigravity-status:
    @echo "=== Antigravity Status ==="
    @if command -v antigravity > /dev/null 2>&1; then \
        echo "✓ Antigravity installed"; \
        echo "  Location: $$(which antigravity)"; \
        antigravity --version 2>/dev/null | sed 's/^/  /' || true; \
        pacman -Qi antigravity-bin 2>/dev/null | grep -E "^(Name|Version|Install Date):" | sed 's/^/  /'; \
    else \
        echo "✗ Antigravity not installed"; \
        echo "  Install with: just dev-antigravity"; \
    fi

# Update Antigravity to latest version
dev-antigravity-update:
    @echo "=== Updating Antigravity ==="
    yay -Syu --needed antigravity-bin
    @echo "✓ Antigravity updated"

# Uninstall Antigravity
dev-antigravity-uninstall:
    @echo "=== Uninstalling Antigravity ==="
    yay -Rns antigravity-bin
    @echo "✓ Antigravity uninstalled"

# Install lifecycle-mcp globally
dev-lifecycle-mcp: dev-languages
    @echo "=== Installing Lifecycle MCP Server ==="
    @if command -v lifecycle-mcp > /dev/null; then \
        echo "✓ lifecycle-mcp already installed"; \
        lifecycle-mcp --version 2>/dev/null || echo "  (installed via pip)"; \
    else \
        echo "Installing lifecycle-mcp from GitHub..."; \
        if command -v uv > /dev/null; then \
            echo "Using uv tool..."; \
            uv tool install git+https://github.com/heffrey78/lifecycle-mcp.git; \
        else \
            echo "Using pip..."; \
            pip install --user git+https://github.com/heffrey78/lifecycle-mcp.git; \
        fi; \
        echo "✓ lifecycle-mcp installed globally"; \
    fi
    @echo ""
    @echo "Configure for Claude Code:"
    @echo "  claude mcp add lifecycle lifecycle-mcp"
    @echo ""
    @echo "Or manually in Claude Desktop config:"
    @echo "  Add to ~/.config/Claude/claude_desktop_config.json:"
    @echo '  "lifecycle": { "command": "lifecycle-mcp" }'

# Update lifecycle-mcp to latest version
dev-lifecycle-mcp-update:
    @echo "=== Updating Lifecycle MCP Server ==="
    @if command -v uv > /dev/null; then \
        echo "Using uv tool..."; \
        uv tool install --force git+https://github.com/heffrey78/lifecycle-mcp.git; \
    else \
        echo "Using pip..."; \
        pip install --user --upgrade --force-reinstall git+https://github.com/heffrey78/lifecycle-mcp.git; \
    fi
    @echo "✓ lifecycle-mcp updated"

# Uninstall lifecycle-mcp
dev-lifecycle-mcp-uninstall:
    @echo "=== Uninstalling Lifecycle MCP Server ==="
    @if command -v uv > /dev/null && uv tool list | grep -q lifecycle-mcp; then \
        uv tool uninstall lifecycle-mcp; \
        echo "✓ lifecycle-mcp uninstalled (uv tool)"; \
    elif pip show lifecycle-mcp > /dev/null 2>&1; then \
        pip uninstall -y lifecycle-mcp; \
        echo "✓ lifecycle-mcp uninstalled (pip)"; \
    else \
        echo "⚠ lifecycle-mcp not found"; \
    fi

# Check lifecycle-mcp status
dev-lifecycle-mcp-status:
    @echo "=== Lifecycle MCP Status ==="
    @echo ""
    @if command -v lifecycle-mcp > /dev/null; then \
        echo "✓ lifecycle-mcp installed"; \
        echo "  Location: $$(which lifecycle-mcp)"; \
        echo ""; \
        if uv tool list 2>/dev/null | grep -q lifecycle-mcp; then \
            echo "  Installation method: uv tool"; \
            uv tool list | grep lifecycle-mcp; \
        elif pip show lifecycle-mcp > /dev/null 2>&1; then \
            echo "  Installation method: pip"; \
            pip show lifecycle-mcp | grep -E "^(Name|Version|Location):"; \
        fi; \
        echo ""; \
        echo "MCP Configuration:"; \
        if [ -f ~/.config/Claude/claude_desktop_config.json ]; then \
            if grep -q lifecycle ~/.config/Claude/claude_desktop_config.json 2>/dev/null; then \
                echo "  ✓ Configured in Claude Desktop"; \
            else \
                echo "  ✗ Not configured in Claude Desktop"; \
            fi; \
        fi; \
        if command -v claude > /dev/null; then \
            echo ""; \
            echo "Claude Code MCP Servers:"; \
            claude mcp list 2>/dev/null | grep -A1 lifecycle || echo "  ✗ Not configured in Claude Code"; \
        fi; \
    else \
        echo "✗ lifecycle-mcp not installed"; \
        echo "  Install with: just dev-lifecycle-mcp"; \
    fi

# Install and configure NordVPN
nordvpn: nordvpn-install nordvpn-setup
    @echo "✓ NordVPN setup complete"
    @echo ""
    @echo "To connect:"
    @echo "  just nordvpn-connect"
    @echo "To connect to specific country:"
    @echo "  nordvpn connect <country>"
    @echo ""
    @echo "Login first with: nordvpn login"

# Install NordVPN package
nordvpn-install:
    @echo "=== Installing NordVPN ==="
    @if pacman -Qs nordvpn-bin > /dev/null 2>&1; then \
        echo "✓ NordVPN already installed"; \
    else \
        echo "Installing NordVPN from AUR..."; \
        yay -S --needed --noconfirm nordvpn-bin; \
        echo "✓ NordVPN installed"; \
    fi

# Configure NordVPN service
nordvpn-setup:
    @echo "=== Configuring NordVPN Service ==="
    sudo systemctl enable nordvpnd.service
    sudo systemctl start nordvpnd.service
    @if groups | grep -q nordvpn; then \
        echo "✓ User already in nordvpn group"; \
    else \
        echo "Adding user to nordvpn group..."; \
        sudo usermod -aG nordvpn $$USER; \
        echo "⚠ Log out and back in for nordvpn group to take effect"; \
    fi
    @echo "✓ NordVPN service configured"
    @echo ""
    @echo "Login with: nordvpn login"

# Connect to NordVPN (best server)
nordvpn-connect:
    @echo "=== Connecting to NordVPN ==="
    nordvpn connect

# Disconnect from NordVPN
nordvpn-disconnect:
    @echo "=== Disconnecting from NordVPN ==="
    nordvpn disconnect

# Check NordVPN status
nordvpn-status:
    @echo "=== NordVPN Status ==="
    @echo ""
    @echo "Service:"
    @systemctl status nordvpnd.service --no-pager | head -5
    @echo ""
    @echo "Connection:"
    @nordvpn status || echo "Not logged in. Run: nordvpn login"
    @echo ""
    @echo "Settings:"
    @nordvpn settings || true

# Login to NordVPN
nordvpn-login:
    @echo "=== NordVPN Login ==="
    nordvpn login

# List available NordVPN countries
nordvpn-countries:
    @echo "=== Available Countries ==="
    nordvpn countries

# Install and configure Mesh (MeshCentral Agent)
mesh: mesh-prompt
    @echo "✓ Mesh setup instructions provided"

# Mesh installation instructions
mesh-prompt:
    @echo "=== MeshCentral Agent Installation ==="
    @echo ""
    @echo "MeshCentral is typically installed by connecting to a MeshCentral server."
    @echo ""
    @echo "Installation methods:"
    @echo "  1. Browser-based: Get invite link from your MeshCentral server admin"
    @echo "  2. Manual: Download agent from your server's mesh page"
    @echo "  3. Command-line: Use server-specific installation URL"
    @echo ""
    @echo "Common installation URL format:"
    @echo "  wget 'https://your-meshcentral-server/meshagents?id=XXXX' -O ./meshagent && chmod 755 ./meshagent && sudo ./meshagent -install"
    @echo ""
    @read -p "Do you have a MeshCentral server URL? [y/N] " confirm; \
    if [ "$$confirm" = "y" ]; then \
        read -p "Enter your MeshCentral installation URL: " mesh_url; \
        if [ -n "$$mesh_url" ]; then \
            just mesh-install "$$mesh_url"; \
        fi; \
    else \
        echo ""; \
        echo "Visit your MeshCentral server's web interface to get the agent URL"; \
        echo "Or contact your server administrator"; \
    fi

# Install Mesh agent from URL
mesh-install url:
    @echo "=== Installing MeshCentral Agent ==="
    @echo "Downloading from: {{url}}"
    wget '{{url}}' -O /tmp/meshagent
    chmod 755 /tmp/meshagent
    sudo /tmp/meshagent -install
    @echo "✓ MeshCentral agent installed"
    @echo ""
    @echo "Check status: just mesh-status"

# Check Mesh agent status
mesh-status:
    @echo "=== MeshCentral Agent Status ==="
    @if [ -f /usr/local/mesh_services/meshagent/meshagent ]; then \
        echo "✓ Mesh agent installed"; \
        echo ""; \
        sudo systemctl status meshagent --no-pager | head -10 || echo "Service not running"; \
    else \
        echo "✗ Mesh agent not installed"; \
        echo "Run: just mesh"; \
    fi

# Uninstall Mesh agent
mesh-uninstall:
    @echo "=== Uninstalling MeshCentral Agent ==="
    @if [ -f /usr/local/mesh_services/meshagent/meshagent ]; then \
        sudo /usr/local/mesh_services/meshagent/meshagent -uninstall; \
        echo "✓ Mesh agent uninstalled"; \
    else \
        echo "✗ Mesh agent not installed"; \
    fi

# Install Hyprland (tiling Wayland compositor)
hyprland: hyprland-install hyprland-deps hyprland-status
    @echo "✓ Hyprland setup complete"
    @echo ""
    @echo "To use Hyprland:"
    @echo "  1. Log out of your current session"
    @echo "  2. Select 'Hyprland' from the session menu at login"
    @echo "  3. Default config: ~/.config/hypr/hyprland.conf"
    @echo ""
    @echo "Resources:"
    @echo "  - Wiki: https://wiki.hypr.land/"
    @echo "  - Config examples: https://github.com/hyprland-community/awesome-hyprland"
    @echo "  - Status: just hyprland-status"

# Install Hyprland package
hyprland-install:
    @echo "=== Installing Hyprland ==="
    @if pacman -Qs "^hyprland " > /dev/null 2>&1; then \
        echo "✓ Hyprland already installed"; \
    else \
        echo "Installing Hyprland from official repos..."; \
        yay -S --needed --noconfirm hyprland; \
        echo "✓ Hyprland installed"; \
    fi

# Install Hyprland ecosystem and recommended tools
hyprland-deps:
    @echo "=== Installing Hyprland Dependencies & Tools ==="
    @echo "Installing core ecosystem..."
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
    @echo "✓ Core dependencies installed"
    @echo ""
    @echo "Optional tools (install separately if needed):"
    @echo "  - File manager: thunar dolphin"
    @echo "  - Terminal: alacritty foot wezterm"
    @echo "  - App launcher: rofi-wayland fuzzel"
    @echo "  - Screenshot: swappy"
    @echo "  - Screen recording: wf-recorder obs-studio"
    @echo "  - Network: nm-applet"
    @echo "  - Audio: pavucontrol"

# Install optional Hyprland tools
hyprland-extras:
    @echo "=== Installing Optional Hyprland Tools ==="
    yay -S --needed --noconfirm \
        thunar \
        alacritty \
        rofi-wayland \
        swaylock-effects \
        swayidle \
        wlogout \
        network-manager-applet \
        pavucontrol \
        blueman \
        swappy \
        wf-recorder
    @echo "✓ Optional tools installed"

# Create default Hyprland configuration
hyprland-config:
    @echo "=== Setting up Hyprland Configuration ==="
    @if [ -f ~/.config/hypr/hyprland.conf ]; then \
        echo "⚠ Config already exists at ~/.config/hypr/hyprland.conf"; \
        echo "Backup will be created..."; \
        cp ~/.config/hypr/hyprland.conf ~/.config/hypr/hyprland.conf.bak; \
        echo "✓ Backup created: ~/.config/hypr/hyprland.conf.bak"; \
    else \
        echo "Creating default configuration..."; \
        mkdir -p ~/.config/hypr; \
        hyprland --config - --version > /dev/null 2>&1 || echo "# Hyprland configuration" > ~/.config/hypr/hyprland.conf; \
        echo "✓ Default config created"; \
    fi
    @echo ""
    @echo "Edit config with: nvim ~/.config/hypr/hyprland.conf"
    @echo "Or: code ~/.config/hypr/hyprland.conf"

# Check Hyprland installation status
hyprland-status:
    @echo "=== Hyprland Status ==="
    @echo ""
    @echo "Installation:"
    @if command -v Hyprland > /dev/null; then \
        echo "  ✓ Hyprland installed"; \
        Hyprland --version 2>&1 | head -1 | sed 's/^/    /'; \
    else \
        echo "  ✗ Hyprland not installed (run: just hyprland)"; \
    fi
    @echo ""
    @echo "Core Components:"
    @if command -v waybar > /dev/null; then \
        echo "  ✓ Waybar (status bar)"; \
    else \
        echo "  ✗ Waybar missing"; \
    fi
    @if command -v wofi > /dev/null; then \
        echo "  ✓ Wofi (app launcher)"; \
    else \
        echo "  ✗ Wofi missing"; \
    fi
    @if command -v hyprlock > /dev/null; then \
        echo "  ✓ Hyprlock (screen locker)"; \
    else \
        echo "  ✗ Hyprlock missing"; \
    fi
    @if command -v hyprpaper > /dev/null; then \
        echo "  ✓ Hyprpaper (wallpaper)"; \
    else \
        echo "  ✗ Hyprpaper missing"; \
    fi
    @echo ""
    @echo "Configuration:"
    @if [ -f ~/.config/hypr/hyprland.conf ]; then \
        echo "  ✓ Config file exists"; \
        echo "    Location: ~/.config/hypr/hyprland.conf"; \
    else \
        echo "  ⚠ No config file (will use defaults)"; \
        echo "    Run: just hyprland-config"; \
    fi
    @echo ""
    @echo "Session:"
    @if [ "$$XDG_CURRENT_DESKTOP" = "Hyprland" ]; then \
        echo "  ✓ Currently running Hyprland"; \
        echo "    Session type: $$XDG_SESSION_TYPE"; \
    else \
        echo "  ℹ Not currently in Hyprland session"; \
        echo "    Current desktop: $$XDG_CURRENT_DESKTOP"; \
        echo "    Log out and select Hyprland at login screen"; \
    fi

# Switch to Hyprland session (create instructions)
hyprland-switch:
    @echo "=== Switch to Hyprland ==="
    @echo ""
    @if [ "$$XDG_CURRENT_DESKTOP" = "Hyprland" ]; then \
        echo "✓ Already running Hyprland!"; \
    else \
        echo "To switch to Hyprland:"; \
        echo "  1. Save your work and close applications"; \
        echo "  2. Log out from your current session"; \
        echo "  3. At the login screen, find the session selector"; \
        echo "     (usually a gear icon or dropdown menu)"; \
        echo "  4. Select 'Hyprland' from the list"; \
        echo "  5. Enter your password and log in"; \
        echo ""; \
        echo "First time setup:"; \
        echo "  - Press SUPER+Q to open terminal (Kitty)"; \
        echo "  - Press SUPER+R to launch apps (Wofi)"; \
        echo "  - Press SUPER+M to exit Hyprland"; \
        echo "  - Edit config: ~/.config/hypr/hyprland.conf"; \
    fi

# Uninstall Hyprland
hyprland-uninstall:
    @echo "=== Uninstalling Hyprland ==="
    @echo ""
    @read -p "Remove Hyprland and dependencies? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 1
    @echo "Removing Hyprland..."
    yay -Rns hyprland hyprpaper hyprlock hypridle waybar wofi dunst
    @echo ""
    @read -p "Remove config files? [y/N] " confirm; \
    if [ "$$confirm" = "y" ]; then \
        echo "Backing up config..."; \
        [ -d ~/.config/hypr ] && mv ~/.config/hypr ~/.config/hypr.backup.$(date +%Y%m%d_%H%M%S); \
        echo "✓ Config backed up"; \
    fi
    @echo "✓ Hyprland uninstalled"

# Install Oriedita (origami design software)
oriedita: oriedita-install oriedita-desktop
    @echo "✓ Oriedita setup complete"
    @echo ""
    @echo "Launch with: just oriedita-launch"
    @echo "Or find 'Oriedita' in your application menu"

# Install Oriedita portable version
oriedita-install:
    @echo "=== Installing Oriedita ==="
    @if [ -d ~/.local/share/oriedita ]; then \
        echo "✓ Oriedita already installed"; \
    else \
        echo "Downloading Oriedita portable (version 1.1.3)..."; \
        mkdir -p /tmp/oriedita-install; \
        wget -O /tmp/oriedita-install/oriedita.zip https://github.com/oriedita/oriedita/releases/download/v1.1.3/Oriedita.Portable.Linux.1.1.3.zip; \
        echo "Extracting..."; \
        unzip -q /tmp/oriedita-install/oriedita.zip -d /tmp/oriedita-install; \
        mkdir -p ~/.local/share; \
        mv /tmp/oriedita-install/Oriedita ~/.local/share/oriedita; \
        chmod +x ~/.local/share/oriedita/bin/Oriedita; \
        rm -rf /tmp/oriedita-install; \
        echo "✓ Oriedita installed to ~/.local/share/oriedita"; \
    fi

# Create desktop entry for Oriedita
oriedita-desktop:
    @echo "=== Creating Desktop Entry ==="
    @mkdir -p $$HOME/.local/share/applications
    @printf '%s\n' \
        '[Desktop Entry]' \
        'Name=Oriedita' \
        'Comment=Origami design software' \
        'Exec='$$HOME'/.local/share/oriedita/bin/Oriedita' \
        'Icon='$$HOME'/.local/share/oriedita/lib/Oriedita.png' \
        'Terminal=false' \
        'Type=Application' \
        'Categories=Graphics;Education;' \
        'MimeType=application/x-oriedita-cp;application/x-oriedita-ori;' \
        > $$HOME/.local/share/applications/oriedita.desktop
    @chmod +x $$HOME/.local/share/applications/oriedita.desktop
    @update-desktop-database $$HOME/.local/share/applications 2>/dev/null || true
    @echo "✓ Desktop entry created"

# Launch Oriedita
oriedita-launch:
    @echo "=== Launching Oriedita ==="
    @if [ -f ~/.local/share/oriedita/bin/Oriedita ]; then \
        ~/.local/share/oriedita/bin/Oriedita & \
    else \
        echo "✗ Oriedita not installed"; \
        echo "Install with: just oriedita"; \
    fi

# Check Oriedita installation status
oriedita-status:
    @echo "=== Oriedita Status ==="
    @if [ -d ~/.local/share/oriedita ]; then \
        echo "✓ Oriedita installed"; \
        echo "  Location: ~/.local/share/oriedita"; \
        if [ -f ~/.local/share/oriedita/bin/Oriedita ]; then \
            echo "  ✓ Executable found"; \
        fi; \
        if [ -f ~/.local/share/applications/oriedita.desktop ]; then \
            echo "  ✓ Desktop entry created"; \
        fi; \
    else \
        echo "✗ Oriedita not installed"; \
        echo "Install with: just oriedita"; \
    fi

# Update Oriedita to latest version
oriedita-update:
    @echo "=== Updating Oriedita ==="
    @echo "Removing old version..."
    @rm -rf $$HOME/.local/share/oriedita
    @echo "Installing latest version..."
    @just oriedita-install
    @echo "✓ Oriedita updated"

# Uninstall Oriedita
oriedita-uninstall:
    @echo "=== Uninstalling Oriedita ==="
    @if [ -d ~/.local/share/oriedita ]; then \
        rm -rf ~/.local/share/oriedita; \
        rm -f ~/.local/share/applications/oriedita.desktop; \
        update-desktop-database ~/.local/share/applications 2>/dev/null || true; \
        echo "✓ Oriedita uninstalled"; \
    else \
        echo "✗ Oriedita not installed"; \
    fi

# Verify installation
verify:
    @echo "=== Verification ==="
    @echo ""
    @echo "GPU Drivers:"
    @if lspci | grep -q VGA; then echo "  ✓ GPUs detected"; else echo "  ✗ No GPUs found"; fi
    @if command -v nvidia-smi > /dev/null; then echo "  ✓ Nvidia driver installed"; nvidia-smi --query-gpu=name --format=csv,noheader | sed 's/^/    /'; else echo "  ✗ Nvidia driver missing"; fi
    @echo ""
    @echo "Vulkan Support:"
    @if command -v vulkaninfo > /dev/null; then echo "  ✓ Vulkan tools installed"; else echo "  ✗ Vulkan tools missing"; fi
    @echo ""
    @echo "Gaming:"
    @if command -v steam > /dev/null; then echo "  ✓ Steam installed"; else echo "  ✗ Steam missing"; fi
    @if command -v mangohud > /dev/null; then echo "  ✓ MangoHud installed"; else echo "  ✗ MangoHud missing"; fi
    @if command -v gamemoded > /dev/null; then echo "  ✓ GameMode installed"; else echo "  ✗ GameMode missing"; fi
    @echo ""
    @echo "VR (Quest 3 Streaming):"
    @if command -v alvr_dashboard > /dev/null; then echo "  ✓ ALVR installed"; else echo "  ✗ ALVR missing (run: just vr)"; fi
    @if [ -d "$$HOME/.steam/steam/steamapps/common/SteamVR" ]; then echo "  ✓ SteamVR installed"; else echo "  ✗ SteamVR missing (install from Steam)"; fi
    @if pacman -Qs lib32-vulkan-icd-loader > /dev/null 2>&1; then echo "  ✓ VR libraries installed"; else echo "  ✗ VR libraries missing"; fi
    @echo ""
    @echo "Scanning:"
    @if command -v scanimage > /dev/null; then echo "  ✓ SANE backend installed"; else echo "  ✗ SANE missing"; fi
    @if command -v skanlite > /dev/null; then echo "  ✓ Skanlite installed"; else echo "  ✗ Skanlite missing (run: just scanning)"; fi
    @if command -v xsane > /dev/null; then echo "  ✓ XSane installed"; else echo "  ✗ XSane missing (run: just scanning)"; fi
    @if command -v gimp > /dev/null; then echo "  ✓ GIMP installed"; else echo "  ⚠ GIMP missing (run: just scanning-packages)"; fi
    @echo ""
    @echo "Printing:"
    @if systemctl is-active --quiet cups.service; then echo "  ✓ CUPS service running"; else echo "  ✗ CUPS not running (run: just printing)"; fi
    @if command -v lp > /dev/null; then \
        if lpstat -p > /dev/null 2>&1; then \
            echo "  ✓ Printers configured:"; \
            lpstat -p 2>/dev/null | sed 's/^/    /'; \
        else \
            echo "  ⚠ CUPS installed but no printers configured"; \
            echo "    Run: just printing-add-canon"; \
        fi; \
    else \
        echo "  ✗ CUPS not installed (run: just printing)"; \
    fi
    @echo ""
    @echo "Development:"
    @if command -v git > /dev/null; then echo "  ✓ Git installed"; else echo "  ✗ Git missing"; fi
    @if command -v docker > /dev/null; then echo "  ✓ Docker installed"; docker --version | sed 's/^/    /'; else echo "  ✗ Docker missing"; fi
    @if command -v code > /dev/null; then echo "  ✓ VS Code installed"; code --version | head -1 | sed 's/^/    /'; else echo "  ✗ VS Code missing (run: just dev-vscode)"; fi
    @if command -v gh > /dev/null; then echo "  ✓ GitHub CLI installed"; gh --version | head -1 | sed 's/^/    /'; else echo "  ✗ GitHub CLI missing (run: just dev-gh)"; fi
    @if [ -d "$$HOME/.nvm" ]; then echo "  ✓ nvm installed"; else echo "  ✗ nvm missing"; fi
    @if command -v node > /dev/null; then echo "  ✓ Node.js installed"; node --version | sed 's/^/    /'; else echo "  ✗ Node.js missing (run: just dev-node)"; fi
    @if command -v npm > /dev/null; then echo "  ✓ npm installed"; npm --version | sed 's/^/    /'; else echo "  ✗ npm missing"; fi
    @if command -v claude > /dev/null; then echo "  ✓ Claude CLI installed"; else echo "  ✗ Claude CLI missing (run: just dev-claude)"; fi
    @if command -v antigravity > /dev/null 2>&1; then echo "  ✓ Antigravity installed"; else echo "  ✗ Antigravity missing (run: just dev-antigravity)"; fi
    @if command -v lifecycle-mcp > /dev/null; then echo "  ✓ Lifecycle MCP installed"; else echo "  ✗ Lifecycle MCP missing (run: just dev-lifecycle-mcp)"; fi
    @if command -v python > /dev/null; then echo "  ✓ Python installed"; python --version | sed 's/^/    /'; else echo "  ✗ Python missing"; fi
    @if command -v uv > /dev/null; then echo "  ✓ uv installed"; uv --version | sed 's/^/    /'; else echo "  ✗ uv missing (recommended for Python)"; fi
    @echo ""
    @echo "VPN:"
    @if command -v nordvpn > /dev/null; then echo "  ✓ NordVPN installed"; nordvpn --version | sed 's/^/    /'; else echo "  ✗ NordVPN missing (run: just nordvpn)"; fi
    @if systemctl is-active --quiet nordvpnd.service; then echo "  ✓ NordVPN service running"; else echo "  ⚠ NordVPN service not running"; fi
    @echo ""
    @echo "Remote Management:"
    @if [ -f /usr/local/mesh_services/meshagent/meshagent ]; then echo "  ✓ MeshCentral agent installed"; else echo "  ✗ MeshCentral agent missing (run: just mesh)"; fi
    @if systemctl is-active --quiet meshagent 2>/dev/null; then echo "  ✓ MeshCentral agent running"; fi
    @echo ""
    @echo "Creative Apps:"
    @if [ -f ~/.local/share/oriedita/bin/Oriedita ]; then echo "  ✓ Oriedita installed"; else echo "  ✗ Oriedita missing (run: just oriedita)"; fi
    @echo ""

# Show GPU status
gpu-status:
    @echo "=== GPU Status ==="
    @echo ""
    @echo "Hardware:"
    @lspci | grep -E "VGA|3D"
    @echo ""
    @echo "Drivers:"
    @inxi -G
    @echo ""
    @if command -v nvidia-smi > /dev/null; then \
        echo "Nvidia GPU:"; \
        nvidia-smi; \
    fi

# Monitor Nvidia GPU
gpu-monitor:
    @echo "=== Monitoring Nvidia GPU (Ctrl+C to exit) ==="
    watch -n 1 nvidia-smi

# Monitor Intel GPU
gpu-monitor-intel:
    @echo "=== Monitoring Intel GPU (Ctrl+C to exit) ==="
    @if command -v intel_gpu_top > /dev/null; then \
        sudo intel_gpu_top; \
    else \
        echo "intel_gpu_top not installed"; \
        echo "Install with: just intel-drivers"; \
    fi

# Test video acceleration
test-vaapi:
    @echo "=== Video Acceleration Support ==="
    @if command -v vainfo > /dev/null; then \
        vainfo; \
    else \
        echo "vainfo not installed"; \
        echo "Install with: just intel-drivers"; \
    fi

# Test Vulkan
test-vulkan:
    @echo "=== Vulkan Information ==="
    @if command -v vulkaninfo > /dev/null; then \
        vulkaninfo --summary; \
    else \
        echo "vulkaninfo not installed"; \
        echo "Install with: yay -S vulkan-tools"; \
    fi

# Test suspend/resume
test-suspend:
    @echo "=== Testing Suspend ==="
    @echo "System will suspend in 5 seconds..."
    @echo "Press Ctrl+C to cancel"
    @sleep 5
    systemctl suspend

# Check suspend logs
suspend-logs:
    @echo "=== Recent Suspend Logs ==="
    journalctl -b -0 | grep -i "suspend\|nvidia" | tail -50

# System update (comprehensive)
update:
    @echo "=== Updating System ==="
    @echo ""
    @echo "Step 1: Updating keyring to avoid signature issues..."
    sudo pacman -Sy --noconfirm archlinux-keyring cachyos-keyring
    @echo ""
    @echo "Step 2: Running full system update..."
    yay -Syu --needed
    @echo ""
    @echo "Step 3: Checking firmware updates..."
    sudo fwupdmgr refresh --force || true
    sudo fwupdmgr get-updates || echo "No firmware updates available"
    @echo ""
    @echo "=== Post-Update Summary ==="
    @just health
    @echo ""
    @echo "Recommended next steps:"
    @echo "  - If core packages updated: reboot your system"
    @echo "  - After reboot: just post-update"
    @echo "  - Clean cache: just clean"
    @echo "  - Remove orphans: just orphans"

# Quick update (no firmware check, no health check)
update-quick:
    @echo "=== Quick System Update ==="
    @echo "Updating keyring..."
    sudo pacman -Sy --noconfirm archlinux-keyring cachyos-keyring
    @echo ""
    @echo "Running system update..."
    yay -Syu --needed

# Full maintenance (update + cleanup + health check)
maintenance: update clean orphans
    @echo ""
    @echo "=== Maintenance Complete ==="
    @echo ""
    @echo "Summary of actions:"
    @echo "  ✓ System updated"
    @echo "  ✓ Package cache cleaned"
    @echo "  ✓ Orphaned packages checked"
    @echo ""
    @echo "If a reboot is needed, run 'just post-update' after rebooting"

# Fix package signature errors
update-fix-keys:
    @echo "=== Fixing Package Signature Issues ==="
    @echo "Updating keyrings..."
    sudo pacman -Sy --noconfirm archlinux-keyring cachyos-keyring
    @echo ""
    @echo "Initializing pacman keyring..."
    sudo pacman-key --init
    @echo ""
    @echo "Populating keyrings..."
    sudo pacman-key --populate archlinux cachyos
    @echo ""
    @echo "✓ Keyrings updated"
    @echo ""
    @echo "Now try: just update"

# Optimize mirror list for faster downloads
mirrors:
    @echo "=== Optimizing Mirror List ==="
    @if command -v cachyos-rate-mirrors > /dev/null; then \
        echo "Rating mirrors (this may take a minute)..."; \
        sudo cachyos-rate-mirrors; \
        echo "✓ Mirror list optimized"; \
    else \
        echo "cachyos-rate-mirrors not found"; \
        echo "Install with: yay -S cachyos-rate-mirrors"; \
    fi

# Clean package cache (keep last 2 versions)
clean:
    @echo "=== Cleaning Package Cache ==="
    @if command -v paccache > /dev/null; then \
        echo "Cleaning with paccache (keeping last 2 versions)..."; \
        sudo paccache -rk2; \
        echo ""; \
        echo "Cleaning uninstalled packages..."; \
        sudo paccache -ruk0; \
    else \
        echo "paccache not found, using yay..."; \
        yay -Sc --noconfirm; \
    fi
    @echo "✓ Cache cleaned"

# Remove orphaned packages (unused dependencies)
orphans:
    @echo "=== Checking for Orphaned Packages ==="
    @orphans=$$(pacman -Qtdq 2>/dev/null); \
    if [ -n "$$orphans" ]; then \
        echo "Found orphaned packages:"; \
        echo "$$orphans"; \
        echo ""; \
        read -p "Remove these packages? [y/N] " confirm; \
        if [ "$$confirm" = "y" ]; then \
            sudo pacman -Rns $$orphans; \
            echo "✓ Orphaned packages removed"; \
        else \
            echo "Skipped"; \
        fi; \
    else \
        echo "✓ No orphaned packages found"; \
    fi

# Check for .pacnew configuration files
pacnew:
    @echo "=== Checking for .pacnew Files ==="
    @pacnew_files=$$(sudo find /etc -name "*.pacnew" 2>/dev/null); \
    if [ -n "$$pacnew_files" ]; then \
        echo "Found .pacnew files that need attention:"; \
        echo "$$pacnew_files"; \
        echo ""; \
        echo "Use 'sudo pacdiff' to merge these files"; \
        echo "Or manually compare with: diff -u /etc/file /etc/file.pacnew"; \
    else \
        echo "✓ No .pacnew files found"; \
    fi

# Check for failed systemd services
failed-services:
    @echo "=== Failed Services ==="
    @failed=$$(systemctl --failed --no-legend 2>/dev/null); \
    if [ -n "$$failed" ]; then \
        echo "Failed services found:"; \
        systemctl --failed; \
        echo ""; \
        echo "Check logs with: journalctl -xe -u <service-name>"; \
    else \
        echo "✓ No failed services"; \
    fi

# Check system health after update
health:
    @echo "=== System Health Check ==="
    @echo ""
    @just failed-services
    @echo ""
    @just pacnew
    @echo ""
    @echo "Recent Errors (last hour):"
    @errors=$$(journalctl -p 3 -S "1 hour ago" --no-pager 2>/dev/null | head -20); \
    if [ -n "$$errors" ]; then \
        echo "$$errors"; \
        echo ""; \
        echo "(Showing first 20 entries, use 'journalctl -p 3 -xb' for full log)"; \
    else \
        echo "✓ No critical errors in the last hour"; \
    fi

# Install recommended maintenance tools
maintenance-tools:
    @echo "=== Installing Maintenance Tools ==="
    yay -S --needed --noconfirm pacman-contrib informant
    @echo ""
    @echo "Installed:"
    @echo "  - pacman-contrib: paccache, checkupdates, pacdiff"
    @echo "  - informant: Shows Arch news before updates"
    @echo ""
    @echo "✓ Maintenance tools installed"

# Fix consolefont warning in mkinitcpio
fix-consolefont:
    @echo "=== Fixing Consolefont Warning ==="
    @if pacman -Qs terminus-font > /dev/null 2>&1; then \
        echo "✓ terminus-font already installed"; \
    else \
        echo "Installing terminus-font..."; \
        yay -S --needed --noconfirm terminus-font; \
    fi
    @echo ""
    @if grep -q "^FONT=" /etc/vconsole.conf 2>/dev/null; then \
        echo "✓ Console font already configured in /etc/vconsole.conf"; \
        grep "^FONT=" /etc/vconsole.conf; \
    else \
        echo "Adding console font to /etc/vconsole.conf..."; \
        echo "FONT=ter-v16n" | sudo tee -a /etc/vconsole.conf; \
        echo "✓ Console font configured"; \
    fi
    @echo ""
    @echo "Rebuilding initramfs..."
    sudo mkinitcpio -P
    @echo "✓ Consolefont fix complete"

# Check pacman configuration for optimizations
check-pacman-config:
    @echo "=== Pacman Configuration Check ==="
    @echo ""
    @echo "Parallel Downloads:"
    @if grep -q "^ParallelDownloads" /etc/pacman.conf; then \
        grep "^ParallelDownloads" /etc/pacman.conf | sed 's/^/  /'; \
    else \
        echo "  ✗ Not enabled (add 'ParallelDownloads = 5' to /etc/pacman.conf)"; \
    fi
    @echo ""
    @echo "Color:"
    @if grep -q "^Color" /etc/pacman.conf; then \
        echo "  ✓ Enabled"; \
    else \
        echo "  ✗ Not enabled (uncomment 'Color' in /etc/pacman.conf)"; \
    fi
    @echo ""
    @echo "VerbosePkgLists:"
    @if grep -q "^VerbosePkgLists" /etc/pacman.conf; then \
        echo "  ✓ Enabled"; \
    else \
        echo "  ✗ Not enabled (uncomment 'VerbosePkgLists' in /etc/pacman.conf)"; \
    fi

# Enable parallel downloads in pacman
enable-parallel-downloads:
    @echo "=== Enabling Parallel Downloads ==="
    @if grep -q "^ParallelDownloads" /etc/pacman.conf; then \
        echo "✓ Already enabled"; \
        grep "^ParallelDownloads" /etc/pacman.conf; \
    else \
        echo "Enabling ParallelDownloads = 5..."; \
        sudo sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 5/' /etc/pacman.conf; \
        if ! grep -q "^ParallelDownloads" /etc/pacman.conf; then \
            echo "ParallelDownloads = 5" | sudo tee -a /etc/pacman.conf > /dev/null; \
        fi; \
        echo "✓ Parallel downloads enabled"; \
    fi

# Post-update verification (run after reboot)
post-update:
    @echo "=== Post-Update Verification ==="
    @echo ""
    @echo "Checking NVIDIA driver..."
    @if command -v nvidia-smi > /dev/null; then \
        if nvidia-smi > /dev/null 2>&1; then \
            echo "✓ NVIDIA driver loaded successfully"; \
            nvidia-smi --query-gpu=name,driver_version --format=csv,noheader | sed 's/^/  /'; \
        else \
            echo "✗ NVIDIA driver failed to load!"; \
            echo "  Check: journalctl -b | grep -i nvidia"; \
        fi; \
    else \
        echo "  NVIDIA driver not installed"; \
    fi
    @echo ""
    @echo "Checking OpenGL..."
    @if command -v glxinfo > /dev/null; then \
        glxinfo 2>/dev/null | grep "OpenGL version" | sed 's/^/  /' || echo "  Unable to query OpenGL"; \
    else \
        echo "  glxinfo not installed (yay -S mesa-utils)"; \
    fi
    @echo ""
    @just failed-services
    @echo ""
    @echo "Kernel version:"
    @uname -r | sed 's/^/  /'
    @echo ""
    @echo "Uptime:"
    @uptime -p | sed 's/^/  /'

# Show system information
info:
    @echo "=== System Information ==="
    @echo ""
    @echo "OS:"
    @cat /etc/os-release | grep PRETTY_NAME
    @echo ""
    @echo "Kernel:"
    @uname -r
    @echo ""
    @echo "CPU:"
    @lscpu | grep "Model name" | sed 's/Model name: *//'
    @echo ""
    @echo "Memory:"
    @free -h | grep Mem | awk '{print $2 " total, " $3 " used, " $7 " available"}'
    @echo ""
    @just gpu-status
