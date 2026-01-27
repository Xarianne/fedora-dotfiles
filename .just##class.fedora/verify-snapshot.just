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