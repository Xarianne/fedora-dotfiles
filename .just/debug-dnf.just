# Debugging Section
debug-dnf:
    #!/usr/bin/env bash
    echo "Creating debug hook..."
    
    # We use a heredoc piped to sudo tee. 
    # The shebang above ensures this whole indented block runs as one script.
    cat <<'EOF' | sudo tee /etc/dnf/libdnf5-plugins/actions.d/debug.actions > /dev/null
    # Log when the hook triggers
    pre_transaction::::/usr/bin/sh -c echo "DEBUG: Hook triggered at $(date)" >> /tmp/dnf_debug.log
    # Log the PID variable resolution
    pre_transaction::::/usr/bin/sh -c echo "DEBUG: PID is '${pid}'" >> /tmp/dnf_debug.log
    # Try to list snapshots to see if Snapper works in this context
    pre_transaction::::/usr/bin/sh -c /usr/bin/snapper list >> /tmp/dnf_debug.log 2>&1
    EOF
    
    sudo chmod 644 /etc/dnf/libdnf5-plugins/actions.d/debug.actions
    echo "Debug hook installed."