# ~/.just/setup.just

# =============================================================================
# BOOTSTRAP
# =============================================================================

bootstrap:
    @echo "Starting System Bootstrap..."
    
    # 1. Install Yadm (Git Clone Method)
    @if ! command -v yadm >/dev/null; then \
        echo "Installing Yadm..."; \
        git clone https://github.com/yadm-dev/yadm.git ~/.yadm-project; \
        mkdir -p ~/.local/bin; \
        ln -s ~/.yadm-project/yadm ~/.local/bin/yadm; \
    fi

    # 2. Clone Dotfiles (The Real Install)
    # We clone into Home, overwriting this temporary repo we are running from
    @echo "Cloning Dotfiles..."
    yadm clone https://github.com/Xarianne/fedora-dotfiles.git

    # 3. Snapshot Base OS
    @echo "Installing Metapac..."
    @sudo dnf install cargo gcc openssl-devel -y
    @cargo install metapac || true
    
    @echo "Snapshotting Base OS..."
    @mkdir -p ~/.config/metapac/groups
    @if [ ! -f ~/.config/metapac/groups/base.toml ]; then \
        metapac unmanaged > ~/.config/metapac/groups/base.toml; \
        echo "Base OS secured."; \
    fi

    # 4. Handoff
    @echo "Bootstrap Complete. Handing off to Setup..."
    @just setup-system

# =============================================================================
# SYSTEM SETUP
# =============================================================================

setup-system: setup-repos install-cargo-tools sync setup-shell
    @echo "Provisioning Complete. Please reboot."

setup-repos:
    @echo "Configuring Repositories and Drivers..."
    
    # Terra & Mesa
    sudo dnf install -y --refresh --nogpgcheck --repofrompath "terra,https://repos.fyralabs.com/terra$$(rpm -E %fedora)" terra-release terra-release-mesa terra-release-multimedia
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
    cargo install cargo-update || true
    cargo install topgrade || true

sync:
    @echo "Syncing Packages..."
    sudo metapac sync

setup-shell:
    @if [ "$$SHELL" != "/usr/bin/fish" ]; then \
        echo "Changing shell to Fish..."; \
        sudo lchsh $$USER /usr/bin/fish; \
    fi