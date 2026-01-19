#!/usr/bin/env bash
set -euo pipefail

### =====================================================
### CONFIG
### =====================================================
REPO_URL="https://github.com/nightdevil00/anom-dots.git"
BACKUP_SUFFIX=".bak"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PACMAN_BASE_PKGS=(
    git base-devel curl wget unzip rsync blueman
    wayland ttf-nerd-fonts-symbols ttf-cascadia-mono-nerd ttf-nerd-fonts-symbols-mono
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
    waybar
    grim slurp swappy wl-clipboard
    brightnessctl playerctl
    swww mako
    foot alacritty
    thunar thunar-archive-plugin file-roller
    rofi
    fastfetch
)

HYPR_AUR_PKGS=(
    hyprpicker
    wlogout
    nwg-look
    google-chrome
    gemini-cli
    opencode
    grimblast-git
    matugen-bin
    swaync-git
)

### =====================================================
### DETECT USER
### =====================================================
if [[ "$EUID" -eq 0 ]]; then
    MAIN_USER=$(logname 2>/dev/null || echo "${SUDO_USER:-}")
    HOME_DIR="/home/$MAIN_USER"
    [[ -z "$MAIN_USER" ]] && { echo "[ERROR] Cannot determine user"; exit 1; }
else
    MAIN_USER="$USER"
    HOME_DIR="$HOME"
fi

REPO_DIR="$HOME_DIR/anom-dots"

### =====================================================
### HELPERS
### =====================================================
info() { echo -e "\n[INFO] $1\n"; }
err()  { echo -e "\n[ERROR] $1\n"; exit 1; }

require_privileges() {
    if [[ "$EUID" -ne 0 ]]; then
        if ! sudo -n true 2>/dev/null; then
            info "No passwordless sudo available. Will install files only."
            return 1
        fi
    fi
    return 0
}

ensure_yay() {
    # Check if yay is available system-wide or for user
    if command -v yay >/dev/null 2>&1 || sudo -u "$MAIN_USER" command -v yay >/dev/null 2>&1; then
        info "yay already available, skipping installation"
        return 0
    fi
    
    info "Installing yay for $MAIN_USER"
    cd /tmp
    sudo -u "$MAIN_USER" git clone https://aur.archlinux.org/yay.git
    cd yay
    sudo -u "$MAIN_USER" makepkg -si --noconfirm
    cd /tmp
    rm -rf yay
    cd "$HOME_DIR"
}

ensure_paru() {
    # Check if paru is available system-wide or for user
    if command -v paru >/dev/null 2>&1 || sudo -u "$MAIN_USER" command -v paru >/dev/null 2>&1; then
        info "paru already available, skipping installation"
        return 0
    fi
    
    info "Installing paru for $MAIN_USER"
    cd /tmp
    sudo -u "$MAIN_USER" git clone https://aur.archlinux.org/paru.git
    cd paru
    sudo -u "$MAIN_USER" makepkg -si --noconfirm
    cd /tmp
    rm -rf paru
    cd "$HOME_DIR"
}

get_aur_helper() {
    # Check system-wide first, then user-specific
    if command -v yay >/dev/null 2>&1 || sudo -u "$MAIN_USER" command -v yay >/dev/null 2>&1; then
        echo "yay"
    elif command -v paru >/dev/null 2>&1 || sudo -u "$MAIN_USER" command -v paru >/dev/null 2>&1; then
        echo "paru"
    else
        echo ""
    fi
}

detect_repo_deps() {
    [[ -d "$REPO_DIR" ]] || return 0
    grep -RohE '(pacman|yay|paru)[[:space:]]+-S[^|;&]*' "$REPO_DIR" 2>/dev/null || true \
    | sed -E 's/.*-S(yu|y)?[[:space:]]*//g' \
    | tr ' ' '\n' \
    | grep -vE '^(-|sudo$|--needed|--noconfirm|\\|\$|\{|\})' \
    | grep -v 'install.sh' \
    | sort -u
}

sync_configs() {
    local src_dir="$REPO_DIR/.config"
    local dst_dir="$HOME_DIR/.config"
    
    if [[ -d "$src_dir" ]]; then
        info "Syncing .config to $MAIN_USER"
        mkdir -p "$dst_dir"
        
        if [[ "$EUID" -eq 0 ]]; then
            sudo -u "$MAIN_USER" rsync -av --backup --suffix="$BACKUP_SUFFIX" \
                "$src_dir/" "$dst_dir/"
        else
            rsync -av --backup --suffix="$BACKUP_SUFFIX" \
                "$src_dir/" "$dst_dir/"
        fi
    fi
    
    # Also sync .local if it exists
    src_dir="$REPO_DIR/.local"
    dst_dir="$HOME_DIR/.local"
    
    if [[ -d "$src_dir" ]]; then
        info "Syncing .local to $MAIN_USER"
        mkdir -p "$dst_dir"
        
        if [[ "$EUID" -eq 0 ]]; then
            sudo -u "$MAIN_USER" rsync -av --backup --suffix="$BACKUP_SUFFIX" \
                "$src_dir/" "$dst_dir/"
        else
            rsync -av --backup --suffix="$BACKUP_SUFFIX" \
                "$src_dir/" "$dst_dir/"
        fi
    fi
}

sync_wallpapers() {
    local src_dir="$REPO_DIR/Wallpapers"
    local dst_dir="$HOME_DIR/Wallpapers"
    
    if [[ -d "$src_dir" ]]; then
        info "Syncing Wallpapers to $MAIN_USER"
        mkdir -p "$dst_dir"
        
        if [[ "$EUID" -eq 0 ]]; then
            sudo -u "$MAIN_USER" rsync -av --backup --suffix="$BACKUP_SUFFIX" \
                "$src_dir/" "$dst_dir/"
        else
            rsync -av --backup --suffix="$BACKUP_SUFFIX" \
                "$src_dir/" "$dst_dir/"
        fi
    fi
}

### =====================================================
### ACTIONS
### =====================================================
install_all() {
    require_privileges

    info "Updating system"
    sudo pacman -Syu --noconfirm

    info "Installing pacman packages"
    sudo pacman -S --needed --noconfirm \
        "${PACMAN_BASE_PKGS[@]}" \
        "${HYPR_PACMAN_PKGS[@]}"

    # Check for available AUR helper
    AUR_HELPER=$(get_aur_helper)
    if [[ -z "$AUR_HELPER" ]]; then
        info "No AUR helper found, installing yay..."
        ensure_yay
        AUR_HELPER="yay"
    else
        info "Found $AUR_HELPER available"
    fi
    
    info "Installing AUR packages using $AUR_HELPER"
    if [[ "$EUID" -eq 0 ]]; then
        sudo -u "$MAIN_USER" "$AUR_HELPER" -S --needed --noconfirm "${HYPR_AUR_PKGS[@]}" || true
    else
        "$AUR_HELPER" -S --needed --noconfirm "${HYPR_AUR_PKGS[@]}" || true
    fi

    # Clone/update repo or copy from current directory
    if [[ "$SCRIPT_DIR" != "$REPO_DIR" ]]; then
        if [[ -d "$REPO_DIR" ]]; then
            info "Updating anom-dots"
            sudo -u "$MAIN_USER" git -C "$REPO_DIR" pull
        else
            info "Cloning anom-dots"
            sudo -u "$MAIN_USER" git clone "$REPO_URL" "$REPO_DIR"
        fi
    else
        info "Using current directory as source"
        REPO_DIR="$SCRIPT_DIR"
    fi

    info "Detecting repo-defined dependencies"
    mapfile -t REPO_DEPS < <(detect_repo_deps)
    if (( ${#REPO_DEPS[@]} )); then
        info "Installing additional dependencies: ${REPO_DEPS[*]}"
        sudo -u "$MAIN_USER" "$AUR_HELPER" -S --needed --noconfirm "${REPO_DEPS[@]}" || true
    fi

    sync_configs
    sync_wallpapers

    info "Setting correct permissions for configs"
    sudo -u "$MAIN_USER" find "$HOME_DIR/.config" "$HOME_DIR/.local" -type f -exec chmod 644 {} \;
    sudo -u "$MAIN_USER" find "$HOME_DIR/.config" "$HOME_DIR/.local" -type d -exec chmod 755 {} \;

    # Make scripts executable
    sudo -u "$MAIN_USER" find "$HOME_DIR/.config" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

    info "Enabling user services for $MAIN_USER"
    sudo -u "$MAIN_USER" systemctl --user enable --now pipewire.service wireplumber.service 2>/dev/null || true

    info "Updating font cache"
    sudo -u "$MAIN_USER" fc-cache -f 2>/dev/null || true

    info "INSTALL COMPLETE — log out and log back in"
}

reload_all() {
    [[ -d "$REPO_DIR" ]] || REPO_DIR="$SCRIPT_DIR"
    
    AUR_HELPER=$(get_aur_helper)
    if [[ -z "$AUR_HELPER" ]]; then
        info "No AUR helper found, installing yay..."
        ensure_yay
        AUR_HELPER="yay"
    else
        info "Found $AUR_HELPER available"
    fi

    info "Reloading repository"
    if [[ -d "$REPO_DIR/.git" ]]; then
        sudo -u "$MAIN_USER" git -C "$REPO_DIR" pull
    else
        info "Not a git repository, skipping update"
    fi

    info "Re-detecting repo-defined dependencies"
    mapfile -t REPO_DEPS < <(detect_repo_deps)
    if (( ${#REPO_DEPS[@]} )); then
        info "Installing additional dependencies: ${REPO_DEPS[*]}"
        sudo -u "$MAIN_USER" "$AUR_HELPER" -S --needed --noconfirm "${REPO_DEPS[@]}" || true
    fi

    sync_configs
    sync_wallpapers

    info "Setting correct permissions"
    sudo -u "$MAIN_USER" find "$HOME_DIR/.config" "$HOME_DIR/.local" -type f -exec chmod 644 {} \; 2>/dev/null || true
    sudo -u "$MAIN_USER" find "$HOME_DIR/.config" "$HOME_DIR/.local" -type d -exec chmod 755 {} \; 2>/dev/null || true
    sudo -u "$MAIN_USER" find "$HOME_DIR/.config" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

    info "RELOAD COMPLETE"
}

uninstall_all() {
    info "Restoring backups for $MAIN_USER"
    find "$HOME_DIR/.config" "$HOME_DIR/.local" "$HOME_DIR/Wallpapers" \
        -name "*$BACKUP_SUFFIX" 2>/dev/null | while read -r bak; do
            sudo -u "$MAIN_USER" mv -f "$bak" "${bak%$BACKUP_SUFFIX}"
        done

    read -rp "Remove Hyprland/Wayland packages? [y/N]: " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        sudo pacman -Rs --noconfirm \
            hyprland waybar wofi swww mako foot alacritty \
            xdg-desktop-portal-hyprland || true
    fi

    read -rp "Remove anom-dots repository? [y/N]: " ans
    [[ "$ans" =~ ^[Yy]$ ]] && sudo -u "$MAIN_USER" rm -rf "$REPO_DIR"

    info "UNINSTALL COMPLETE"
}

### =====================================================
### MENU
### =====================================================
install_files_only() {
    info "Installing files only (no system packages)"
    
    # Use current directory as source
    REPO_DIR="$SCRIPT_DIR"
    
    sync_configs
    sync_wallpapers
    
    info "Setting correct permissions"
    find "$HOME_DIR/.config" "$HOME_DIR/.local" -type f -exec chmod 644 {} \; 2>/dev/null || true
    find "$HOME_DIR/.config" "$HOME_DIR/.local" -type d -exec chmod 755 {} \; 2>/dev/null || true
    find "$HOME_DIR/.config" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
    
    info "FILES INSTALL COMPLETE"
}

clear
echo "anom-dots installer"
echo "==================="
echo "1) Full Install (packages + configs) - requires sudo"
echo "2) Files Only (configs only) - no sudo needed"
echo "3) Reload configs"
echo "4) Uninstall"
echo
read -rp "Select option [1-4]: " choice

case "$choice" in
    1) install_all ;;
    2) install_files_only ;;
    3) reload_all ;;
    4) uninstall_all ;;
    *) err "Invalid option" ;;
esac
