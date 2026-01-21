# Justfile for Fedora 42 Snapper & Rollback Setup
# Based on guide: "How to Install Fedora 42 with Snapshot and Rollback Support"

# The main workflow command
setup-snapper: show-grub install-deps config-dnf config-snapper config-updatedb install-grub-btrfs enable-timers
    @echo "Setup complete! A reboot is recommended to verify the GRUB menu."

# Section 3: Post-Installation Configuration
# We must unset menu_auto_hide so the GRUB menu appears for rollbacks.
show-grub:
    @echo "Step 1: Unhiding GRUB menu..."
    sudo grub2-editenv unset menu_auto_hide

# Section 5: Install necessary packages
install-deps:
    @echo "Step 2: Installing dependencies..."
    sudo dnf install -y snapper libdnf5-plugin-actions btrfs-assistant inotify-tools git make

# Section 5: Set Up Automatic Snapshot Creation with DNF
# Creates the actions file so DNF takes snapshots before/after package changes.
config-dnf:
    @echo "Step 3: Configuring DNF snapshot hooks..."
    sudo mkdir -p /etc/dnf/libdnf5-plugins/actions.d/
    # Writing the action file content using cat/heredoc to avoid shell escaping issues
    sudo bash -c "cat > /etc/dnf/libdnf5-plugins/actions.d/snapper.actions" <<EOF
    # Get snapshot description
    pre_transaction::::/usr/bin/sh -c echo \"tmp.cmd=\\\$\$(ps -o command --no-headers -p \\\$\$PPID)\"
    # Creates pre snapshot
    pre_transaction::::/usr/bin/sh -c echo \"tmp.snapper_pre_number=\\\$\$(snapper create -t pre -c number -d \\\"\$\${tmp.cmd}\\\" -u \\\"root\\\")\"
    # Creates post snapshot if pre exists
    post_transaction::::/usr/bin/sh -c [ -n \"\$\${tmp.snapper_pre_number}\" ] && snapper create -t post --pre-number \"\$\${tmp.snapper_pre_number}\" -d \"\$\${tmp.cmd}\" -u \"root\"
    EOF
    sudo chmod 644 /etc/dnf/libdnf5-plugins/actions.d/snapper.actions

# Section 5: Create Snapper Configurations
config-snapper:
    @echo "Step 4: Configuring Snapper for root and home..."
    # Create configs if they don't exist (ignore error if they do)
    sudo snapper -c root create-config / || echo "Root config likely exists, skipping creation."
    sudo snapper -c home create-config /home || echo "Home config likely exists, skipping creation."
    
    # Restore SELinux contexts
    sudo restorecon -RFv /.snapshots
    sudo restorecon -RFv /home/.snapshots
    
    # Allow the current user to manage snapshots and sync ACLs
    sudo snapper -c root set-config ALLOW_USERS=$USER SYNC_ACL=yes
    sudo snapper -c home set-config ALLOW_USERS=$USER SYNC_ACL=yes

# Section 5: Configure updatedb
# Prevents system slowdowns by stopping updatedb from indexing snapshots.
config-updatedb:
    @echo "Step 5: Excluding snapshots from updatedb..."
    if ! grep -q 'PRUNENAMES = ".snapshots"' /etc/updatedb.conf; then \
        echo 'PRUNENAMES = ".snapshots"' | sudo tee -a /etc/updatedb.conf; \
    fi

# Section 5: Install and Configure grub-btrfs
# Allows booting into read-only snapshots from the GRUB menu.
install-grub-btrfs:
    @echo "Step 6: Installing grub-btrfs..."
    # Clone repository
    rm -rf /tmp/grub-btrfs
    git clone https://github.com/Antynea/grub-btrfs /tmp/grub-btrfs
    
    # Apply Fedora-specific configurations to the config file using sed
    cd /tmp/grub-btrfs && sed -i.bkp \
        -e '/^#GRUB_BTRFS_SNAPSHOT_KERNEL_PARAMETERS=/a GRUB_BTRFS_SNAPSHOT_KERNEL_PARAMETERS="rd.live.overlay.overlayfs=1"' \
        -e '/^#GRUB_BTRFS_GRUB_DIRNAME=/a GRUB_BTRFS_GRUB_DIRNAME="/boot/grub2"' \
        -e '/^#GRUB_BTRFS_MKCONFIG=/a GRUB_BTRFS_MKCONFIG=/usr/bin/grub2-mkconfig' \
        -e '/^#GRUB_BTRFS_SCRIPT_CHECK=/a GRUB_BTRFS_SCRIPT_CHECK=grub2-script-check' \
        config
        
    # Install and enable
    cd /tmp/grub-btrfs && sudo make install
    sudo systemctl enable --now grub-btrfsd.service
    
    # Clean up
    rm -rf /tmp/grub-btrfs

# Section 6: Enable Automatic Timeline Snapshots
enable-timers:
    @echo "Step 7: Enabling timeline snapshots..."
    # Disable timeline for home to avoid clutter (as recommended in guide)
    sudo snapper -c home set-config TIMELINE_CREATE=no
    
    # Enable automatic hourly snapshots for root
    sudo systemctl enable --now snapper-timeline.timer
    sudo systemctl enable --now snapper-cleanup.timer