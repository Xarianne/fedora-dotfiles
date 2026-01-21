# vim: set ft=make :

# alias for install-jetbrains-toolbox

# Install OpenTabletDriver, an open source, cross-platform, user-mode tablet driver
[group('Apps')]
install-opentabletdriver:
    #!/usr/bin/bash
    gum confirm --affirmative="Install" --negative="Uninstall" "Installer for OpenTabletDriver"
    EXIT_CODE="$?"

    if [ "${EXIT_CODE}" == 0 ] ; then
      echo "Installing OpenTabletDriver..."

      OTD_TMPDIR="$(mktemp -d)"

      curl -s "https://api.github.com/repos/OpenTabletDriver/OpenTabletDriver/releases/latest" \
        | jq -r '.assets | sort_by(.created_at) | .[] | select (.name|test("opentabletdriver.*tar.gz$")) | .browser_download_url' \
        | wget -qi - -O - \
        | tar --strip-components=1 -xvzf - -C "${OTD_TMPDIR}"

      # https://opentabletdriver.net/Wiki/Documentation/RequiredPermissions
      sudo cp "${OTD_TMPDIR}/etc/udev/rules.d/70-opentabletdriver.rules" /etc/udev/rules.d/71-opentabletdriver.rules
      echo -ne "blacklist hid_uclogic\nblacklist wacom\n" | sudo tee /etc/modprobe.d/blacklist-opentabletdriver.conf
      rm -rf "${OTD_TMPDIR}"

      flatpak --system install -y flathub net.opentabletdriver.OpenTabletDriver

      mkdir -p "$HOME/.config/systemd/user"
      curl -s "https://raw.githubusercontent.com/flathub/net.opentabletdriver.OpenTabletDriver/refs/heads/master/scripts/opentabletdriver.service" > "$HOME/.config/systemd/user/opentabletdriver.service"

      systemctl --user daemon-reload
      systemctl enable --user --now opentabletdriver.service
    elif [ "${EXIT_CODE}" == 1 ] ; then
      echo "Uninstalling OpenTabletDriver..."
      sudo rm -f /etc/modprobe.d/blacklist-opentabletdriver.rules /etc/udev/rules.d/71-opentabletdriver.rules
      flatpak --system remove -y flathub net.opentabletdriver.OpenTabletDriver
    fi

# Install DaVinci Resolve using the davincibox container method from any directory
install-resolve:
    #!/usr/bin/env bash
    set -e

    DOWNLOADS_DIR="$HOME/Downloads"
    
    # 1. Check for the zip file in the Downloads folder
    ZIP_FILE=$(ls "$DOWNLOADS_DIR"/DaVinci_Resolve_*_Linux.zip 2>/dev/null | head -n 1)
    
    if [ -z "$ZIP_FILE" ]; then
        echo "Error: Could not find DaVinci_Resolve_..._Linux.zip in $DOWNLOADS_DIR"
        exit 1
    fi

    # 2. Detect GPU and Create Container
    echo "Creating Distrobox container..."
    if lshw -C display 2>/dev/null | grep -qi "nvidia"; then
        echo "NVIDIA GPU detected."
        distrobox create --yes -i ghcr.io/zelikos/davincibox:latest --additional-flags "--device nvidia.com/gpu=all" -n davincibox
    else
        echo "AMD/Intel GPU detected."
        distrobox create --yes -i ghcr.io/zelikos/davincibox-opencl:latest -n davincibox
    fi

    # 3. Perform work in the Downloads directory
    pushd "$DOWNLOADS_DIR" > /dev/null

    echo "Unzipping $(basename "$ZIP_FILE")..."
    unzip -o "$(basename "$ZIP_FILE")"
    
    RUN_FILE=$(ls DaVinci_Resolve_*_Linux.run | head -n 1)
    chmod +x "$RUN_FILE"

    # 4. Extract AppImage contents
    echo "Extracting installer runtime..."
    ./"$RUN_FILE" --appimage-extract

    # 5. Run the setup inside the container
    echo "Running installation inside the container..."
    distrobox enter davincibox -- setup-davinci squashfs-root/AppRun distrobox

    # 6. Cleanup
    echo "Cleaning up temporary files..."
    rm -rf squashfs-root
    
    popd > /dev/null
    echo "Done! Launch DaVinci Resolve from your application menu."