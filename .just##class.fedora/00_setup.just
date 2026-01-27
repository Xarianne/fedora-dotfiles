# =============================================================================
# VARIABLES
# =============================================================================
fedora_ver := shell("rpm -E %fedora")
current_user := shell("whoami")

# =============================================================================
# FULL SYSTEM SETUP
# =============================================================================

# Full System Setup: Prepares configurations and provisions the machine
setup-system: _init setup-shell setup-repos install-cargo-tools _sync
    @echo "Provisioning Complete. Please reboot your machine."

# =============================================================================
# SETUP STEPS
# =============================================================================

# Internal: Prepare configurations (Yadm, Metapac, and Base Snapshot)
_init:
    @echo "--------------------------------------------------------"
    @echo "REMINDER: Ensure yadm is installed before proceeding."
    @echo "See README from dotfiles repo"
    @echo "--------------------------------------------------------"

    @echo "Preparing configurations..."
    # Finalize Yadm State
    @yadm clone https://github.com/Xarianne/dotfiles.git || echo "Repo already exists."
    @yadm reset --hard HEAD
    # Install Metapac
    @if ! command -v ~/.cargo/bin/metapac >/dev/null; then \
        sudo dnf install cargo gcc openssl-devel -y; \
        cargo install metapac || true; \
    fi
    # Snapshot Base OS
    @mkdir -p ~/.config/metapac/groups
    @if [ ! -f ~/.config/metapac/groups/base.toml ]; then \
        ~/.cargo/bin/metapac unmanaged > ~/.config/metapac/groups/base.toml; \
    fi

setup-shell:
    @echo "Checking User Shell..."
    @if [ "$$SHELL" != "/usr/bin/fish" ]; then \
        echo "Changing shell to Fish..."; \
        sudo usermod --shell /usr/bin/fish {{current_user}}; \
    else \
        echo "Shell is already Fish."; \
    fi

setup-repos:
    @echo "Configuring Repositories..."
    
    # Terra Repository Check
    @if ! rpm -q terra-release >/dev/null; then \
        echo "Adding Terra for Fedora {{fedora_ver}}..."; \
        sudo dnf install -y --refresh --nogpgcheck --repofrompath "terra,https://repos.fyralabs.com/terra{{fedora_ver}}" terra-release terra-release-mesa terra-release-multimedia; \
    else \
        echo "Terra repository is already installed."; \
    fi
    
    # Mesa Upgrade (safe to run repeatedly, dnf handles 'nothing to do')
    @echo "Checking Mesa stack..."
    @sudo dnf upgrade -y --allowerasing mesa* libgbm
    
    # Codecs Check (checks for one key package)
    @if ! rpm -q gstreamer1-plugins-ugly >/dev/null; then \
        echo "Installing Codecs..."; \
        sudo dnf install -y --allowerasing ffmpeg gstreamer1-plugins-bad gstreamer1-plugins-bad-free-extras gstreamer1-plugins-ugly; \
    else \
        echo "Codecs are already installed."; \
    fi
    
    # COPR Checks (checks if the repo file exists in /etc/yum.repos.d)
    @echo "Checking COPRs..."
    @if [ ! -f /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:bieszczaders:kernel-cachyos-addons.repo ]; then \
        sudo dnf copr enable -y bieszczaders/kernel-cachyos-addons; \
    fi
    @if [ ! -f /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:xariann:tools.repo ]; then \
        sudo dnf copr enable -y xariann/tools; \
    fi

    # Flatpak Cleanup
    @echo "Configuring Flatpaks..."
    @flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    
    # CRITICAL: Download the app catalog so Metapac can find packages
    @echo "Refreshing Flatpak catalog..."
    @flatpak update --appstream

    @if flatpak remote-list | grep -q "fedora"; then \
        flatpak remote-delete fedora --force; \
    fi
    @if flatpak remote-list | grep -q "fedora-testing"; then \
        flatpak remote-delete fedora-testing --force; \
    fi
    
install-cargo-tools:
    @echo "Checking Cargo Tools..."
    @if ! [ -f ~/.cargo/bin/cargo-install-update ]; then \
        cargo install cargo-update; \
    else \
        echo "cargo-update is already installed."; \
    fi
    @if ! [ -f ~/.cargo/bin/topgrade ]; then \
        cargo install topgrade; \
    else \
        echo "topgrade is already installed."; \
    fi

_sync:
    @echo "Syncing Packages..."
    @~/.cargo/bin/metapac sync