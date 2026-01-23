# My Fedora Setup

## Bootstrap
Run these commands on a fresh installation.

### 1. Install Yadm

Use [OBS](https://software.opensuse.org//download.html?project=home%3ATheLocehiliosan%3Ayadm&package=yadm) as described in the Yadm docs. Pick the distro, then choose the install method.

### 2. Install just (and git if needed). Example for Fedora:
```
sudo dnf install just git
```

Clone the repo:
```
yadm clone https://github.com/Xarianne/dotfiles.git
```

### Run just
```
just --choose
```
Pick `setup-system`.
