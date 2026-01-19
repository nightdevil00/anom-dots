#!/usr/bin/env bash
set -euo pipefail

### =====================================================
### CONFIG
### =====================================================
REPO_URL="https://github.com/nightdevil00/anom-dots.git"
REPO_DIR="$HOME/anom-dots"
BACKUP_SUFFIX=".bak"

PACMAN_BASE_PKGS=(
    git base-devel curl wget unzip rsync
    wayland wlroots
    pipewire pipewire-pulse wireplumber pavucontrol
    polkit polkit-gnome
    xdg-user-dirs xdg-utils
    qt5-wayland qt6-wayland
    networkmanager network-manager-applet
    noto-fonts noto-fonts-emoji ttf-jetbrains-mono
)

HYPR_PACMAN_PKGS=(
    hyprland
    xdg-desktop-portal
    xdg-desktop-portal-hyprland
    waybar wofi
    grim slurp swappy wl-clipboard
    brightnessctl playerctl
    swww mako
    foot alacritty
    thunar thunar-archive-plugin file-roller
)

HYPR_AUR_PKGS=(
    hyprpicker
    wlogout
    nwg-look
    grimblast-git
)

### =====================================================
### HELPERS
### =====================================================
info() { echo -e "\n[INFO] $1\n"; }
err()  { echo -e "\n[ERROR] $1\n"; exit 1; }

require_non_root() {
    [[ "$EUID" -eq 0 ]] && err "Do not run as root"
}

ensure_yay() {
    if ! command -v yay >/dev/null 2>&1; then
        info "Installing yay"
        cd /tmp
        git clone https://aur.archlinux.org/yay.git
        cd yay
        makepkg -si --noconfirm
        cd ~
    fi
}

detect_repo_deps() {
    grep -RohE '(pacman|yay|paru)[^|;&]*-S[^|;&]*' "$REPO_DIR" \
    | sed -E 's/.*-S(yu|y)?//g' \
    | tr ' ' '\n' \
    | grep -Ev '^(-|sudo$|--needed|--noconfirm|\\|$)' \
    | sort -u
}

sync_configs() {
    for d in .config .local; do
        if [[ -d "$REPO_DIR/$d" ]]; then
            info "Syncing $d"
            rsync -av --backup --suffix="$BACKUP_SUFFIX" \
                "$REPO_DIR/$d/" "$HOME/$d/"
        fi
    done
}

sync_wallpapers() {
    if [[ -d "$REPO_DIR/Wallpapers" ]]; then
        info "Syncing Wallpapers"
        mkdir -p "$HOME/Wallpapers"
        rsync -av --backup --suffix="$BACKUP_SUFFIX" \
            "$REPO_DIR/Wallpapers/" "$HOME/Wallpapers/"
    fi
}

### =====================================================
### ACTIONS
### =====================================================
install_all() {
    require_non_root

    info "Updating system"
    sudo pacman -Syu --noconfirm

    info "Installing pacman packages"
    sudo pacman -S --needed --noconfirm \
        "${PACMAN_BASE_PKGS[@]}" \
        "${HYPR_PACMAN_PKGS[@]}"

    ensure_yay

    info "Installing AUR packages"
    yay -S --needed --noconfirm "${HYPR_AUR_PKGS[@]}"

    if [[ -d "$REPO_DIR" ]]; then
        info "Updating anom-dots"
        git -C "$REPO_DIR" pull
    else
        info "Cloning anom-dots"
        git clone "$REPO_URL" "$REPO_DIR"
    fi

    info "Detecting repo-defined dependencies"
    mapfile -t REPO_DEPS < <(detect_repo_deps)
    if (( ${#REPO_DEPS[@]} )); then
        yay -S --needed --noconfirm "${REPO_DEPS[@]}"
    fi

    sync_configs
    sync_wallpapers

    info "Enabling user services"
    systemctl --user enable --now pipewire.service wireplumber.service

    info "INSTALL COMPLETE — log out and log back in"
}

reload_all() {
    require_non_root
    [[ -d "$REPO_DIR" ]] || err "anom-dots is not installed"

    info "Reloading repository"
    git -C "$REPO_DIR" pull

    info "Re-detecting dependencies"
    mapfile -t REPO_DEPS < <(detect_repo_deps)
    if (( ${#REPO_DEPS[@]} )); then
        yay -S --needed --noconfirm "${REPO_DEPS[@]}"
    fi

    sync_configs
    sync_wallpapers

    info "RELOAD COMPLETE"
}

uninstall_all() {
    require_non_root

    info "Restoring backups"
    find "$HOME/.config" "$HOME/.local" "$HOME/Wallpapers" \
        -name "*$BACKUP_SUFFIX" 2>/dev/null | while read -r bak; do
            mv -f "$bak" "${bak%$BACKUP_SUFFIX}"
        done

    read -rp "Remove Hyprland/Wayland packages? [y/N]: " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        sudo pacman -Rs --noconfirm \
            hyprland waybar wofi swww mako foot alacritty \
            xdg-desktop-portal-hyprland || true
    fi

    read -rp "Remove anom-dots repository? [y/N]: " ans
    [[ "$ans" =~ ^[Yy]$ ]] && rm -rf "$REPO_DIR"

    info "UNINSTALL COMPLETE"
}

### =====================================================
### MENU
### =====================================================
clear
echo "anom-dots installer"
echo "==================="
echo "1) Install"
echo "2) Reload"
echo "3) Uninstall"
echo
read -rp "Select option [1-3]: " choice

case "$choice" in
    1) install_all ;;
    2) reload_all ;;
    3) uninstall_all ;;
    *) err "Invalid option" ;;
esac
