# ~/Justfile

# 1. Global Settings
set shell := ["bash", "-c"]

# 2. Import Modules
import .just/setup.just
import .just/maintenance.just

# 3. Default Menu
default:
    @just --choose