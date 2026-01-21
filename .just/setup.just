# SETUP ORCHESTRATOR

# The Master Sequence
setup-system: setup-repos install-cargo-tools sync setup-shell
    @echo "Provisioning Complete. Please reboot."

# 1. Repositories & Drivers
setup-repos:
    @echo "Configuring Repositories, Drivers, and Codecs..."
    
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

# 2. Rust Tooling
install-cargo-tools:
    @echo "Installing Cargo base..."
    cargo install cargo-update || true
    cargo install topgrade || true

# 3. Package Sync
sync:
    @echo "Syncing Packages & Services..."
    sudo metapac sync

# 4. Shell Setup
setup-shell:
    @if [ "$$SHELL" != "/usr/bin/fish" ]; then \
        echo "Changing shell to Fish..."; \
        sudo lchsh $$USER /usr/bin/fish; \
    fi