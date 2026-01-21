# Justfile for Fedora 42 Snapper & Rollback Setup
# Based on guide: "How to Install Fedora 42 with Snapshot and Rollback Support"

# The main workflow command
setup-snapper: show-grub install-deps config-dnf config-snapper config-updatedb install-grub-btrfs enable-timers
    @echo "✅ Setup complete! A reboot is recommended to verify the GRUB menu."

# Section 3: Post-Installation Configuration
show-grub:
    @echo "Step 1: Unhiding GRUB menu..."
    sudo grub2-editenv - unset menu_auto_hide

# Section 5: Install necessary packages
install-deps:
    @echo "Step 2: Installing dependencies..."
    sudo dnf install -y snapper libdnf5-plugin-actions btrfs-assistant inotify-tools git make

# Section 5: Set Up Automatic Snapshot Creation with DNF
# FIXED: Added shebang (#!/usr/bin/env bash) to treat this block as a single script
config-dnf:
    #!/usr/bin/env bash
    echo "Step 3: Configuring DNF snapshot hooks..."
    sudo mkdir -p /etc/dnf/libdnf5-plugins/actions.d/
    
    # We use a heredoc to write the config file. 
    # The EOF must be aligned with the start of the command in this script block.
    sudo tee /etc/dnf/libdnf5-plugins/actions.d/snapper.actions > /dev/null <<'EOF'
    # Get snapshot description
    pre_transaction::::/usr/bin/sh -c echo "tmp.cmd=$(ps -o command --no-headers -p $PPID)"
    # Creates pre snapshot
    pre_transaction::::/usr/bin/sh -c echo "tmp.snapper_pre_number=$(snapper create -t pre -c number -d "${tmp.cmd}" -u "root")"
    # Creates post snapshot if pre exists
    post_transaction::::/usr/bin/sh -c [ -n "${tmp.snapper_pre_number}" ] && snapper create -t post --pre-number "${tmp.snapper_pre_number}" -d "${tmp.cmd}" -u "root"
    EOF
    
    sudo chmod 644 /etc/dnf/libdnf5-plugins/actions.d/snapper.actions

# Section 5: Create Snapper Configurations
config-snapper:
    @echo "Step 4: Configuring Snapper for root and home..."
    # Create configs if they don't exist (ignore error if they do)
    sudo snapper -c root create-config / || echo "Root config likely exists, skipping creation."
    sudo snapper -c home create-config /home || echo "Home config likely exists, skipping creation."
    
    # Restore SELinux contexts
    # We use '|| true' because this may fail on Read-Only snapshots, which is expected and fine to ignore.
    sudo restorecon -RFv /.snapshots || true
    sudo restorecon -RFv /home/.snapshots || true
    
    # Allow the current user to manage snapshots and sync ACLs
    # Uses $(whoami) to ensure we get the correct user inside the script execution
    sudo snapper -c root set-config ALLOW_USERS=$(whoami) SYNC_ACL=yes
    sudo snapper -c home set-config ALLOW_USERS=$(whoami) SYNC_ACL=yes

# Section 5: Configure updatedb
config-updatedb:
    @echo "Step 5: Excluding snapshots from updatedb..."
    if ! grep -q 'PRUNENAMES = ".snapshots"' /etc/updatedb.conf; then \
        echo 'PRUNENAMES = ".snapshots"' | sudo tee -a /etc/updatedb.conf; \
    fi

# Section 5: Install and Configure grub-btrfs
install-grub-btrfs:
    @echo "Step 6: Installing grub-btrfs..."
    rm -rf /tmp/grub-btrfs
    git clone https://github.com/Antynea/grub-btrfs /tmp/grub-btrfs
    
    # Configure grub-btrfs
    cd /tmp/grub-btrfs && sed -i.bkp \
        -e '/^#GRUB_BTRFS_SNAPSHOT_KERNEL_PARAMETERS/s/^#//' \
        -e 's/#GRUB_BTRFS_MKCONFIG=.*/GRUB_BTRFS_MKCONFIG=\/usr\/sbin\/grub2-mkconfig/' \
        -e 's/#GRUB_BTRFS_SCRIPT_CHECK=.*/GRUB_BTRFS_SCRIPT_CHECK=no/' \
        -e 's/#GRUB_BTRFS_GRUB_DIRNAME=.*/GRUB_BTRFS_GRUB_DIRNAME="\/boot\/grub2"/' \
        config

    # Install the package
    cd /tmp/grub-btrfs && sudo make install

    # Regenerate the GRUB configuration file
    @echo "Regenerating GRUB config..."
    sudo grub2-mkconfig -o /boot/grub2/grub.cfg

# Section 6: Enable Systemd Timers & Services
enable-timers:
    @echo "Step 7: Enabling systemd timers and services..."
    sudo systemctl enable --now snapper-timeline.timer
    sudo systemctl enable --now snapper-cleanup.timer
    sudo systemctl enable --now grub-btrfsd