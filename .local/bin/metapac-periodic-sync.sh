#!/bin/bash
# Ensure the directory exists
mkdir -p "$HOME/.config/metapac/groups"

# Generate the unmanaged list into the unsorted file
# This will overwrite the file each time, effectively giving you a 
# "Current State" of your drift.
metapac unmanaged > "$HOME/.config/metapac/groups/unsorted.toml"
