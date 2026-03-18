#!/usr/bin/env bash
# Setup script for Kiran's dotfiles (tmux + neovim)
# Usage: ./setup.sh [--nvim-only | --tmux-only | --gnome-only]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d_%H%M%S)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

backup_if_exists() {
    local target="$1"
    if [ -e "$target" ] || [ -L "$target" ]; then
        mkdir -p "$BACKUP_DIR"
        info "Backing up $target -> $BACKUP_DIR/"
        cp -rL "$target" "$BACKUP_DIR/" 2>/dev/null || true
    fi
}

# ---------- Package installation ----------

install_packages() {
    info "Installing required packages..."

    if ! command -v apt-get &>/dev/null; then
        error "Only apt-based systems (Debian/Ubuntu) are supported. Install these manually:
  tmux neovim git curl python3 dconf-cli"
    fi

    local pkgs=(
        # Core
        tmux
        git
        curl
        wget
        # Neovim build deps / runtime
        python3
        python3-pip
        ripgrep          # telescope live-grep
        fd-find          # telescope file finder
        unzip            # lazy.nvim plugin extraction
        # Tmux scripts
        jq               # news.sh JSON parsing
        bc               # marquee.sh math
        # Gnome terminal
        dconf-cli
        # General
        build-essential
        gcc
        g++
        make
    )

    info "The following packages will be installed:"
    echo "  ${pkgs[*]}"
    echo ""
    read -rp "Proceed? [Y/n] " yn
    case "${yn,,}" in
        n*) info "Skipping package installation."; return ;;
    esac

    sudo apt-get update
    sudo apt-get install -y "${pkgs[@]}"

    # Neovim (install latest stable from GitHub releases to ~/.local — no sudo needed)
    local nvim_bin="$HOME/.local/bin/nvim"
    if [[ ! -x "$nvim_bin" ]] || [[ "$("$nvim_bin" --version | head -1)" != *"v0.11"* ]]; then
        info "Installing Neovim v0.11.x to ~/.local (no sudo required)..."
        local nvim_url="https://github.com/neovim/neovim/releases/download/v0.11.6/nvim-linux-x86_64.tar.gz"
        mkdir -p "$HOME/.local"
        curl -fsSL "$nvim_url" | tar xz --strip-components=1 -C "$HOME/.local"
        info "Neovim $("$nvim_bin" --version | head -1) installed to ~/.local."
    else
        info "Neovim v0.11.x already installed at ~/.local/bin/nvim, skipping."
    fi

    # Node.js (needed by many LSP servers)
    if ! command -v node &>/dev/null; then
        info "Installing Node.js via nodesource..."
        curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
        sudo apt-get install -y nodejs
    fi

    info "Packages installed."
}

# ---------- Tmux setup ----------

setup_tmux() {
    info "Setting up tmux (gpakosz/.tmux + custom config)..."

    # Install gpakosz/.tmux framework
    if [ ! -d "$HOME/.tmux" ]; then
        git clone --depth 1 https://github.com/gpakosz/.tmux.git "$HOME/.tmux"
    else
        info "$HOME/.tmux already exists, pulling latest..."
        git -C "$HOME/.tmux" pull --ff-only 2>/dev/null || true
    fi

    # Install our .tmux.conf (with path substitution)
    backup_if_exists "$HOME/.tmux.conf"
    sed "s|/home/kiran|$HOME|g" "$SCRIPT_DIR/.tmux.conf" > "$HOME/.tmux.conf"

    # Install our custom .tmux.conf.local (with path substitution)
    backup_if_exists "$HOME/.tmux.conf.local"
    sed "s|/home/kiran|$HOME|g" "$SCRIPT_DIR/.tmux.conf.local" > "$HOME/.tmux.conf.local"

    # Install tmux helper scripts
    local scripts=(weather.sh marquee.sh marquee.conf marquee.txt news.sh)
    for f in "${scripts[@]}"; do
        cp "$SCRIPT_DIR/scripts/$f" "$HOME/.tmux/$f"
    done

    # Install graphics
    mkdir -p "$HOME/.tmux/graphics"
    cp "$SCRIPT_DIR/scripts/graphics/"* "$HOME/.tmux/graphics/"

    # Fix paths in all scripts
    find "$HOME/.tmux" -maxdepth 1 -name '*.sh' -exec sed -i "s|/home/kiran|$HOME|g" {} +
    find "$HOME/.tmux" -maxdepth 1 -name '*.conf' -exec sed -i "s|/home/kiran|$HOME|g" {} +
    chmod +x "$HOME/.tmux/"*.sh

    info "Tmux setup complete."
}

# ---------- Neovim setup ----------

setup_nvim() {
    info "Setting up Neovim (LazyVim)..."

    local nvim_dir="$HOME/.config/nvim"
    backup_if_exists "$nvim_dir"
    rm -rf "$nvim_dir"
    mkdir -p "$nvim_dir"

    # Copy neovim config files
    cp "$SCRIPT_DIR/init.lua"        "$nvim_dir/"
    cp "$SCRIPT_DIR/lazyvim.json"    "$nvim_dir/"
    cp "$SCRIPT_DIR/lazy-lock.json"  "$nvim_dir/"
cp "$SCRIPT_DIR/stylua.toml"     "$nvim_dir/"
    cp "$SCRIPT_DIR/.gitignore"      "$nvim_dir/"

    # Copy lua directory structure
    cp -r "$SCRIPT_DIR/lua" "$nvim_dir/"

    # First launch will auto-install lazy.nvim and all plugins
    info "Launching Neovim headless to install plugins..."
    "$HOME/.local/bin/nvim" --headless "+Lazy! sync" +qa 2>/dev/null || {
        warn "Headless plugin install had issues. Plugins will install on first manual launch."
    }

    info "Neovim setup complete."
}

# ---------- Gnome Terminal setup ----------

setup_gnome() {
    info "Setting up Gnome Terminal profile..."

    if ! command -v dconf &>/dev/null; then
        warn "dconf not found, skipping Gnome Terminal setup."
        return
    fi

    if [ -f "$SCRIPT_DIR/gnome_terminal_settings.txt" ]; then
        info "Applying Gnome Terminal settings..."
        dconf load /org/gnome/terminal/ < "$SCRIPT_DIR/gnome_terminal_settings.txt"
        info "Gnome Terminal settings applied."
    else
        warn "gnome_terminal_settings.txt not found, skipping."
    fi
}

# ---------- Main ----------

main() {
    echo ""
    echo "========================================="
    echo "  Kiran's Dotfiles Setup"
    echo "  tmux + neovim + gnome-terminal"
    echo "========================================="
    echo ""

    case "${1:-all}" in
        --nvim-only)
            install_packages
            setup_nvim
            ;;
        --tmux-only)
            install_packages
            setup_tmux
            ;;
        --gnome-only)
            install_packages
            setup_gnome
            ;;
        all|*)
            install_packages
            setup_tmux
            setup_nvim
            setup_gnome
            ;;
    esac

    echo ""
    info "Setup complete!"
    if [ -d "$BACKUP_DIR" ]; then
        info "Previous configs backed up to: $BACKUP_DIR"
    fi
    echo ""
    info "Next steps:"
    info "  1. Start a new tmux session:  tmux new -s main"
    info "  2. Open Neovim:               nvim"
    info "     (plugins will auto-install on first launch if not already)"
    info "  3. Dev workspace shortcut:    <prefix> + h  (inside tmux)"
    echo ""
}

main "$@"
