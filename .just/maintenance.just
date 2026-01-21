# MAINTENANCE

# Full System Update
update:
    @echo "Creating safety snapshot..."
    sudo snapper -c root create -d "Pre-Update"
    @echo "Running Topgrade..."
    topgrade
    @echo "Cleaning up..."
    sudo dnf autoremove -y

# Utils
check-path:
    @echo "Checking for shadowed binaries..."
    @type -a curl python3 git