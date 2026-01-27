# Full System Update
update:
    @echo "Running Topgrade..."
    topgrade
    
    @echo "Syncing package state with Metapac..."
    ~/.cargo/bin/metapac sync
    
    @echo "Cleaning up dnf orphans and cache..."
    sudo dnf autoremove -y
    sudo dnf clean packages
    
    @echo "Cleaning up unused Flatpak runtimes..."
    flatpak uninstall --unused -y

    @echo "Checking for config conflicts..."
    @sudo rpmconf -a || echo "No conflicts found."
    
    @echo "Update and cleanup complete."