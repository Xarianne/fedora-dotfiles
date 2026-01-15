function brew-missing --description 'Check if any packages in the Brewfile are not installed'
    echo 'Checking for missing packages...'
    if brew bundle check --file $DOT_BREW/Brewfile > /dev/null 2>&1
        set_color green
        echo "All listed packages are present."
        set_color normal
    else
        # If check fails, show exactly what is missing
        brew bundle check --file $DOT_BREW/Brewfile
    end
end