# -----------------------------------------------------------------------------
# MASTER COMMAND
# -----------------------------------------------------------------------------

# Run all checks sequentially. Stops immediately if one fails.
verify-state: check-snapper-services check-flatpak-remotes check-shell check-terra-repos manage-drift verify-snapshot
    @echo -e "\033[0;32m\nSystem state verification complete.\033[0m"

# -----------------------------------------------------------------------------
# INDIVIDUAL MODULES
# -----------------------------------------------------------------------------

# 1. CHECK CRITICAL SERVICES
check-snapper-services:
    #!/usr/bin/env bash
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    NC='\033[0m'
    echo -e "Checking System Timers & Services..."
    SERVICES=("snapper-timeline.timer" "snapper-cleanup.timer" "grub-btrfsd.service")
    ERRORS=0
    for SERVICE in "${SERVICES[@]}"; do
        if systemctl is-active --quiet "$SERVICE"; then
            echo -e "  [${GREEN}OK${NC}] $SERVICE is active"
        else
            echo -e "  [${RED}FAIL${NC}] $SERVICE is NOT active"
            ERRORS=$((ERRORS+1))
        fi
    done
    if [ $ERRORS -ne 0 ]; then exit 1; fi

# 2. CHECK FLATPAK REMOTES
check-flatpak-remotes:
    #!/usr/bin/env bash
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    YELLOW='\033[0;33m'
    NC='\033[0m'
    echo -e "\nChecking Flatpak Remotes..."
    if flatpak remote-list | grep -q "fedora" && ! flatpak remote-list | grep -q "flathub"; then
         echo -e "  [${RED}FAIL${NC}] 'fedora' remote detected or 'flathub' missing."
         exit 1
    elif flatpak remote-list | grep -q "fedora"; then
         echo -e "  [${YELLOW}WARN${NC}] 'fedora' remote is present (preferred: flathub only)."
         # Warning doesn't exit 1, allowing chain to continue
    else
         echo -e "  [${GREEN}OK${NC}] Flatpak remotes look clean."
    fi

# 3. CHECK USER SHELL
check-shell:
    #!/usr/bin/env bash
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    NC='\033[0m'
    echo -e "\nChecking User Shell..."
    EXPECTED_SHELL="/usr/bin/fish"
    if [ "$SHELL" != "$EXPECTED_SHELL" ]; then
        echo -e "  [${YELLOW}WARN${NC}] Current shell is $SHELL (Expected: $EXPECTED_SHELL)"
        # Warning only, generally doesn't need to stop the update
    else
        echo -e "  [${GREEN}OK${NC}] Shell is Fish."
    fi

# 4. CHECK REPOS
check-terra-repos:
    #!/usr/bin/env bash
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    NC='\033[0m'
    echo -e "\nChecking RPM Repositories..."
    if rpm -q terra-release >/dev/null; then
        echo -e "  [${GREEN}OK${NC}] Terra repository installed."
    else
        echo -e "  [${RED}FAIL${NC}] Terra repository missing."
        exit 1
    fi

# 5. DRIFT MANAGEMENT
manage-drift:
    #!/usr/bin/env bash
    set -e
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    YELLOW='\033[0;33m'
    NC='\033[0m'
    
    # ---------------------------------------------------------
    # PART 1: SYNC (Install Missing)
    # ---------------------------------------------------------
    echo -e "\nChecking uninstalled packages..."

    # gum confirm returns 0 for Yes, 1 for No. 
    # The 'if' handles the 1 gracefully so the script doesn't exit.
    if gum confirm "Run 'metapac sync' to install missing packages?"; then
        echo "Running Metapac Sync..."
        ~/.cargo/bin/metapac sync
        echo -e "${GREEN}Sync complete.${NC}"
    else
        echo -e "${YELLOW}Sync skipped.${NC}"
    fi

    # ---------------------------------------------------------
    # PART 2: DRIFT (Remove/Bless Unmanaged)
    # ---------------------------------------------------------
    echo -e "\nChecking for Package Drift..."
    UNMANAGED=$(~/.cargo/bin/metapac unmanaged)

    if [ -z "$UNMANAGED" ]; then
        echo -e "  [${GREEN}OK${NC}] No unmanaged packages found."
    else
        echo -e "  [${YELLOW}DRIFT DETECTED${NC}] The following packages are installed but not in Metapac:"
        echo -e "${RED}${UNMANAGED}${NC}"
        echo ""
        
        echo "Select an action for these packages:"
        ACTION=$(gum choose "Save to unsorted.toml" "Uninstall (Clean)" "Ignore for now")

        case $ACTION in
            "Save to unsorted.toml")
                echo "Blessing packages into configuration..."
                mkdir -p ~/.config/metapac/groups
                ~/.cargo/bin/metapac unmanaged > ~/.config/metapac/groups/unsorted.toml
                echo -e "${GREEN}Saved to ~/.config/metapac/groups/unsorted.toml${NC}"
                echo "Review this file later to organize packages into proper groups."
                ;;
            "Uninstall (Clean)")
                echo "Purging unmanaged packages..."
                ~/.cargo/bin/metapac sync
                echo -e "${GREEN}System cleaned.${NC}"
                ;;
            "Ignore for now")
                echo -e "${YELLOW}Drift ignored. These packages remain installed but unmanaged.${NC}"
                ;;
        esac
    fi