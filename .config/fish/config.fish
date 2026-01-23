if status is-interactive
    # Commands to run in interactive sessions can go here
end

set -gx MERGE meld

if test -d $HOME/.cargo/bin
    fish_add_path $HOME/.cargo/bin
end

alias metapac-unsorted="metapac unmanaged > $HOME/.config/metapac/groups/unsorted.toml"
# alias code='flatpak run com.visualstudio.code'

eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv fish)"
