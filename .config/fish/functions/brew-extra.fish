function brew-extra --description 'Check for packages installed on the system but missing from Brewfile'
    echo 'Checking for unlisted packages...'

    # Use the absolute path to your Brewfile
    set -l brewfile_path "$DOT_BREW/Brewfile"

    # 1. Get the list from the Brewfile
    set -l brew_apps (grep '^flatpak' "$brewfile_path" | cut -d '"' -f 2 | cut -d "'" -f 2 | sort)

    # 2. Get the list from the system
    set -l sys_apps (flatpak list --app --columns=application | sort)

    # 3. Compare the two lists and find what's in 'sys' but not in 'brew'
    set -l extras
    for app in $sys_apps
        if not contains $app $brew_apps
            set -a extras $app
        end
    end

    # 4. Results
    if test -n "$extras"
        for app in $extras
            set_color red
            echo "Extra: $app"
            set_color normal
        end
    else
        set_color green
        echo "No extra packages found."
        set_color normal
    end
end