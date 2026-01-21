# =============================================================================
# VARIABLES
# =============================================================================
fedora_ver := shell("rpm -E %fedora")
current_user := shell("whoami")

# =============================================================================
# BOOTSTRAP (Post-Clone)
# =============================================================================

bootstrap:
    @echo "Initializing System State..."
    
    # 1. Finalize Yadm State
    @echo "Aligning Dotfiles..."
    @yadm clone https://github.com/Xarianne/fedora-dotfiles.git || echo "⚠️  Repo already exists. Skipping clone."
    @yadm reset --hard HEAD

    # 2. Install Metapac
    @echo "Installing Metapac..."
    @sudo dnf install cargo gcc openssl-devel -y
    
    # FIX: Run 'cargo' directly (it's in /usr/bin), but verify installation first
    @echo "Building Metapac binary..."
    @cargo install metapac || true
    
    # 3. Snapshot Base OS
    @echo "Snapshotting Base OS..."
    @mkdir -p ~/.config/metapac/groups
    @if [ ! -f ~/.config/metapac/groups/base.toml ]; then \
        echo "   Generating snapshot..."; \
        # FIX: Metapac LIVES in ~/.cargo/bin, so we use the full path here
        ~/.cargo/bin/metapac unmanaged > ~/.config/metapac/groups/base.toml; \
        echo "   Base OS secured."; \
    fi

    # 4. Handoff
    @echo "Bootstrap Complete. Handing off to Setup..."
    @just setup-system

# =============================================================================
# SYSTEM SETUP
# =============================================================================

setup-system: setup-shell setup-repos install-cargo-tools sync
    @echo "Provisioning Complete. Please reboot."

setup-shell:
    @echo "Configuring Shell..."
    @# FIX: Use 'current_user' variable to guarantee we get the right name
    @if [ "$$SHELL" != "/usr/bin/fish" ]; then \
        echo "Changing shell to Fish..."; \
        sudo lchsh {{current_user}} /usr/bin/fish; \
    fi

setup-repos:
    @echo "Configuring Repositories and Drivers..."
    
    # Terra & Mesa
    @echo "Adding Terra for Fedora {{fedora_ver}}..."
    sudo dnf install -y --refresh --nogpgcheck --repofrompath "terra,https://repos.fyralabs.com/terra{{fedora_ver}}" terra-release terra-release-mesa terra-release-multimedia
    
    @echo "Upgrading Mesa stack..."
    sudo dnf upgrade -y --allowerasing mesa* libgbm
    
    @echo "Installing Codecs..."
    sudo dnf install -y --allowerasing ffmpeg gstreamer1-plugins-bad gstreamer1-plugins-bad-free-extras gstreamer1-plugins-ugly
    
    # COPRs
    @echo "Enabling COPRs..."
    sudo dnf copr enable -y bieszczaders/kernel-cachyos-addons
    sudo dnf copr enable -y xariann/tools

    # Flatpak Cleanup
    @echo "Fixing Flatpaks..."
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    flatpak remote-delete fedora --force || true
    flatpak remote-delete fedora-testing --force || true

install-cargo-tools:
    @echo "Installing Cargo tools..."
    # FIX: Use 'cargo' (system) to install 'topgrade' (user binary)
    @cargo install cargo-update || true
    @cargo install topgrade || true

sync:
    @echo "Syncing Packages..."
    # FIX: Point to the user binary path
    ~/.cargo/bin/metapac sync