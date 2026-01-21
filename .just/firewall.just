# Set up LocalSend and Steam Local Transfer firewall services
set-firewall-zone:
    @echo "Creating services..."
    # Create the service names (system will handle the XML files now)
    sudo firewall-cmd --permanent --new-service=localsend || true
    sudo firewall-cmd --permanent --new-service=steam-local || true
    
    @echo "Adding ports..."
    sudo firewall-cmd --permanent --service=localsend --add-port=53317/tcp
    sudo firewall-cmd --permanent --service=localsend --add-port=53317/udp
    sudo firewall-cmd --permanent --service=steam-local --add-port=27040/udp
    
    @echo "Applying and enabling..."
    sudo firewall-cmd --reload
    sudo firewall-cmd --permanent --zone=public --add-service=localsend
    sudo firewall-cmd --permanent --zone=public --add-service=steam-local
    sudo firewall-cmd --set-default-zone=public
    
    sudo firewall-cmd --reload
    @echo "Done! Configuration active."

# Check current status
check-firewall:
    @echo "--- Default Zone ---"
    @firewall-cmd --get-default-zone
    @echo ""
    @echo "--- Services in Public Zone ---"
    @firewall-cmd --zone=public --list-services

# Remove and fully purge
remove-firewall-config:
    @echo "Removing configuration..."
    sudo firewall-cmd --permanent --zone=public --remove-service=localsend
    sudo firewall-cmd --permanent --zone=public --remove-service=steam-local
    sudo firewall-cmd --permanent --delete-service=localsend || true
    sudo firewall-cmd --permanent --delete-service=steam-local || true
    sudo firewall-cmd --reload
    @echo "Cleanup complete."