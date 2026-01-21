# JUSTFILE

set shell := ["bash", "-c"]

import ".just/00_setup.just"
import ".just/maintenance.just"
import ".just/dev.just"
import ".just/apps.just"
import ".just/firewall.just"

# Default Menu
_default:
    @just --choose