# Justfile for Fedora 42 Snapper & Rollback Setup
# Based on guide: "How to Install Fedora 42 with Snapshot and Rollback Support"

# The main workflow command
setup-snapper: _show-grub _install-deps _config-dnf _config-snapper _config-updatedb _install-grub-btrfs _enable-timers
    @echo "Setup complete! A reboot is recommended to verify the GRUB menu."

# Section 3: Post-Installation Configuration
_show-grub:
    @echo "Step 1: Unhiding GRUB menu..."
    sudo grub2-editenv - unset menu_auto_hide

# Section 5: Install necessary packages
_install-deps:
    @echo "Step 2: Installing dependencies..."
    sudo dnf install -y snapper libdnf5-plugin-actions btrfs-assistant inotify-tools git make

# Section 5: Set Up Automatic Snapshot Creation with DNF
_config-dnf:
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
_config-snapper:
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
_config-updatedb:
    @echo "Step 5: Excluding snapshots from updatedb..."
    if ! grep -q 'PRUNENAMES = ".snapshots"' /etc/updatedb.conf; then \
        echo 'PRUNENAMES = ".snapshots"' | sudo tee -a /etc/updatedb.conf; \
    fi

# Section 5: Install and Configure grub-btrfs
_install-grub-btrfs:
    @echo "Step 6: Installing grub-btrfs..."
    rm -rf /tmp/grub-btrfs
    git clone https://github.com/Antynea/grub-btrfs /tmp/grub-btrfs
    
    # Configure grub-btrfs
    cd /tmp/grub-btrfs && sed -i.bkp \
        -e '/^#GRUB_BTRFS_SNAPSHOT_KERNEL_PARAMETERS/s/^#//' \
        -e 's/#GRUB_BTRFS_MKCONFIG=.*/GRUB_BTRFS_MKCONFIG=\/usr\/sbin\/grub2-mkconfig/' \
        -e 's/#GRUB_BTRFS_SCRIPT_CHECK=.*/GRUB_BTRFS_SCRIPT_CHECK=grub2-script-check/' \
        -e 's/#GRUB_BTRFS_GRUB_DIRNAME=.*/GRUB_BTRFS_GRUB_DIRNAME="\/boot\/grub2"/' \
        config

    # Install the package
    cd /tmp/grub-btrfs && sudo make install

    # Regenerate the GRUB configuration file
    @echo "Regenerating GRUB config..."
    sudo grub2-mkconfig -o /boot/grub2/grub.cfg

# Section 6: Enable Systemd Timers & Services
_enable-timers:
    @echo "Step 7: Enabling systemd timers and services..."
    sudo systemctl enable --now snapper-timeline.timer
    sudo systemctl enable --now snapper-cleanup.timer
    sudo systemctl enable --now grub-btrfsd

##################

# Interactively verify if a specific snapshot is bootable
verify-snapshot:
    #!/usr/bin/env bash
    set -e
    
    # 1. Select Snapshot with Gum
    echo "Loading snapshots..."
    SELECTED=$(sudo snapper -c root list --columns number,date,cleanup,description | \
        tail -n +3 | \
        gum filter --placeholder "Pick a snapshot to verify..." --height 10)

    if [ -z "$SELECTED" ]; then
        echo "No snapshot selected."
        exit 0
    fi

    # Extract the Snapshot ID (first field)
    SNAP_ID=$(echo "$SELECTED" | awk '{print $1}')
    SNAP_PATH="/.snapshots/$SNAP_ID/snapshot"
    
    # Visuals
    echo ""
    gum style --foreground 212 -- "--> Verifying Snapshot #$SNAP_ID"
    gum style --foreground 240 -- "    Path: $SNAP_PATH"
    echo ""

    # 2. Check for Kernel Module Mismatch
    echo -n "Checking kernel modules... "
    CURRENT_KERNEL=$(uname -r)
    
    if [ -d "$SNAP_PATH/lib/modules/$CURRENT_KERNEL" ]; then
        echo "OK"
    else
        FOUND_COMPATIBLE=0
        for k in /boot/vmlinuz-*; do
            K_VER=$(basename "$k" | sed 's/vmlinuz-//')
            if [ -d "$SNAP_PATH/lib/modules/$K_VER" ]; then
                FOUND_COMPATIBLE=1
                echo "OK (Matches installed kernel $K_VER)"
                break
            fi
        done
        
        if [ $FOUND_COMPATIBLE -eq 0 ]; then
            gum style --foreground 1 -- "WARNING: No modules found for current kernels."
            echo "         This snapshot might not boot graphics/wifi if restored."
        fi
    fi

    # 3. "Boot" the snapshot in a container
    echo -n "Attempting to boot snapshot user-space... "
    
    # We verify by entering the snapshot and reading its OS identity
    # We use single quotes '' around the command so $PRETTY_NAME is expanded INSIDE the snapshot, not by your current shell.
    if SNAP_OS=$(sudo systemd-nspawn -q -D "$SNAP_PATH" /bin/sh -c 'source /etc/os-release && echo $PRETTY_NAME' 2>/dev/null); then
        echo "OK"
        # Print the identity found inside to prove we were there
        gum style --foreground 240 -- "    (Verified identity: $SNAP_OS)"
    else
        gum style --foreground 1 "FAIL"
        gum style --border normal --border-foreground 1 --padding "1 1" \
            "Could not execute /bin/sh inside the snapshot." \
            "The filesystem tree may be corrupted."
        exit 1
    fi
    
    # 4. Check GRUB visibility
    echo -n "Checking GRUB visibility... "
    
    # FIX: Use 'sudo test -f' because regular users cannot read /boot/grub2
    if sudo test -f /boot/grub2/grub-btrfs.cfg && sudo grep -q ".snapshots/$SNAP_ID/snapshot" /boot/grub2/grub-btrfs.cfg; then
        echo "OK (Found in grub-btrfs.cfg)"
    elif sudo grep -q ".snapshots/$SNAP_ID/snapshot" /boot/grub2/grub.cfg; then
        echo "OK (Found in grub.cfg)"
    else
        gum style --foreground 3 -- "FAIL (Not found in GRUB menus)"
        echo "         Run 'just setup-snapper' or 'sudo grub2-mkconfig' to fix."
    fi
    
    echo ""
    gum style --foreground 2 -- "Snapshot #$SNAP_ID appears valid and bootable."