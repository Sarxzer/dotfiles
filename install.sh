#!/usr/bin/env bash
# install.sh - set up these dotfiles on Arch / CachyOS.
#
#   git clone https://github.com/sarxzer/dotfiles ~/dotfiles
#   cd ~/dotfiles && ./install.sh
#
# Safe to re-run. Existing real files that would collide with a stow link are
# moved to ~/.dotfiles-backup/<timestamp>/ instead of being overwritten.
#
# Options:
#   --skip-packages   don't install system packages (only clone plugins + stow)
#   -h, --help        show this help

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
ZSH_DIR="${ZSH:-$HOME/.oh-my-zsh}"
ZSH_CUSTOM_DIR="${ZSH_CUSTOM:-$ZSH_DIR/custom}"

# Folders in this repo that get stowed into $HOME. Missing ones are skipped,
# so you can add more folders to the repo later without editing this.
PACKAGES=(zsh kitty hypr noctalia applications nvim qt6ct navi)

# Packages stowed WITHOUT directory folding: real directories are created in $HOME
# and only the files are symlinked. navi writes navi.log into ~/.config/navi, and
# with a folded (whole-directory) symlink that log would end up inside the repo.
NO_FOLD_PACKAGES=(navi)

# What the configs rely on. Installed through yay/paru so repo and AUR packages
# are handled the same way. Hardware-specific stuff (GPU drivers, kernels,
# bootloader, ...) is deliberately NOT in here.
PKGS=(
  # base
  git stow base-devel curl
  # shell
  zsh eza bat zoxide navi fzf atuin hyfetch fastfetch less libnotify zsh-autocomplete
  openssh                              # ssh-agent (SSH_AUTH_SOCK in the zshrc)
  tmux btop glow
  ttf-meslo-nerd                       # nerd font for powerlevel10k / eza icons
  # editor + what neovim plugins / LSPs usually need
  neovim lazygit ripgrep fd unzip nodejs npm go tree-sitter-cli
  docker docker-compose
  # terminal + desktop
  kitty dolphin kate
  hyprland noctalia
  xdg-desktop-portal-hyprland xdg-desktop-portal-gtk   # screen sharing, file pickers
  polkit-kde-agent                     # password popups
  wl-clipboard cliphist                # clipboard history
  brightnessctl playerctl
  pipewire pipewire-pulse wireplumber
  # apps
  ratune-bin                           # AUR
  # theming (Noctalia GTK/Qt templates)
  qt6ct-kde adw-gtk-theme nwg-look
)

FAILED_PKGS=()
FAILED_CLONES=()
FAILED_STOW=()

# ---------- helpers ----------
c_info=$'\033[1;34m'; c_warn=$'\033[1;33m'; c_ok=$'\033[1;32m'; c_off=$'\033[0m'
info() { printf '%s==>%s %s\n' "$c_info" "$c_off" "$*"; }
warn() { printf '%s!!%s  %s\n' "$c_warn" "$c_off" "$*" >&2; }
ok()   { printf '%s ok%s %s\n' "$c_ok" "$c_off" "$*"; }

# Prints the header comment block (everything up to the first non-comment line).
usage() { awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "${BASH_SOURCE[0]}"; }

# ---------- packages ----------
AUR_HELPER=""

ensure_aur_helper() {
  if command -v yay >/dev/null 2>&1; then AUR_HELPER=yay; return; fi
  if command -v paru >/dev/null 2>&1; then AUR_HELPER=paru; return; fi

  info "No AUR helper found, building yay-bin"
  sudo pacman -S --needed --noconfirm git base-devel
  local tmp
  tmp="$(mktemp -d)"
  git clone --depth=1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
  (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
  rm -rf "$tmp"
  AUR_HELPER=yay
}

install_packages() {
  command -v pacman >/dev/null 2>&1 || { warn "pacman not found - this script targets Arch/CachyOS. Install the packages by hand."; return; }
  ensure_aur_helper

  info "Installing packages with $AUR_HELPER (${#PKGS[@]} packages)"
  if "$AUR_HELPER" -S --needed --noconfirm "${PKGS[@]}"; then
    ok "packages installed"
    return
  fi

  # One bad/renamed package name fails the whole batch, so retry one by one
  # and report only the ones that actually failed.
  warn "Batch install failed, retrying package by package"
  local p
  for p in "${PKGS[@]}"; do
    "$AUR_HELPER" -S --needed --noconfirm "$p" || FAILED_PKGS+=("$p")
  done
}

# ---------- zsh / oh-my-zsh ----------
clone_or_update() {  # clone_or_update <url> <dest>
  local url=$1 dest=$2

  if [[ -d $dest/.git ]]; then
    git -C "$dest" pull --ff-only --quiet || warn "could not update $dest"
    return 0
  fi

  # Something is in the way but it isn't a git checkout: an empty folder is just
  # removed, anything else is moved aside so git clone doesn't die on it.
  if [[ -d $dest && -z $(ls -A "$dest") ]]; then
    rmdir "$dest"
  elif [[ -e $dest || -L $dest ]]; then
    mkdir -p "$BACKUP_DIR"
    mv "$dest" "$BACKUP_DIR/$(basename "$dest")-$$"
    warn "$dest was not a git checkout, moved it to $BACKUP_DIR"
  fi

  git clone --depth=1 --quiet "$url" "$dest" || FAILED_CLONES+=("$url")
}

install_zsh_stuff() {
  info "oh-my-zsh + theme + plugins"
  # Cloned directly (not via the installer) so it never touches ~/.zshrc or the shell.
  clone_or_update https://github.com/ohmyzsh/ohmyzsh.git "$ZSH_DIR"
  mkdir -p "$ZSH_CUSTOM_DIR/plugins" "$ZSH_CUSTOM_DIR/themes"

  clone_or_update https://github.com/romkatv/powerlevel10k.git              "$ZSH_CUSTOM_DIR/themes/powerlevel10k"
  clone_or_update https://github.com/zsh-users/zsh-autosuggestions.git      "$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions"
  clone_or_update https://github.com/zsh-users/zsh-syntax-highlighting.git  "$ZSH_CUSTOM_DIR/plugins/zsh-syntax-highlighting"
  clone_or_update https://github.com/MichaelAquilina/zsh-auto-notify.git    "$ZSH_CUSTOM_DIR/plugins/auto-notify"
  # git, sudo, colored-man-pages and history-substring-search ship with oh-my-zsh.
  # zsh-autocomplete comes from the system package (sourced from /usr/share/zsh/plugins).
  if ((${#FAILED_CLONES[@]})); then
    warn "some zsh plugins could not be cloned (see the summary at the end)"
  else
    ok "zsh plugins ready"
  fi
}

set_default_shell() {
  command -v zsh >/dev/null 2>&1 || return 0
  local zsh_path; zsh_path="$(command -v zsh)"
  if [[ ${SHELL:-} != "$zsh_path" ]]; then
    info "Setting zsh as your login shell (asks for your password)"
    chsh -s "$zsh_path" || warn "chsh failed - run: chsh -s $zsh_path"
  fi
}

# ---------- stow ----------
# Move real files that stow would refuse to overwrite into the backup dir.
# Skips anything that already resolves to the repo copy (e.g. a folded dir symlink),
# so re-running the script can never move the repo's own files.
backup_conflicts() {  # backup_conflicts <package>
  local pkg=$1 f rel tgt
  while IFS= read -r -d '' f; do
    rel=${f#"$DOTFILES_DIR/$pkg/"}
    tgt="$HOME/$rel"
    [[ -e $tgt || -L $tgt ]] || continue
    [[ $(readlink -f "$tgt") == "$(readlink -f "$f")" ]] && continue
    mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
    mv "$tgt" "$BACKUP_DIR/$rel"
    warn "backed up existing $tgt -> $BACKUP_DIR/$rel"
  done < <(find "$DOTFILES_DIR/$pkg" -type f -print0)
}

stow_packages() {
  command -v stow >/dev/null 2>&1 || { warn "stow is not installed, skipping linking"; return; }
  info "Linking configs with stow"
  local pkg opts
  for pkg in "${PACKAGES[@]}"; do
    if [[ ! -d $DOTFILES_DIR/$pkg ]]; then
      warn "no '$pkg' folder in the repo, skipping"
      continue
    fi
    backup_conflicts "$pkg"

    opts=(-R)
    if [[ " ${NO_FOLD_PACKAGES[*]} " == *" $pkg "* ]]; then
      opts+=(--no-folding)
    fi

    if stow "${opts[@]}" -d "$DOTFILES_DIR" -t "$HOME" "$pkg"; then
      ok "stowed $pkg"
    else
      FAILED_STOW+=("$pkg")
    fi
  done
}

# ---------- neovim ----------
sync_nvim() {
  [[ -d $DOTFILES_DIR/nvim ]] || return 0
  command -v nvim >/dev/null 2>&1 || return 0
  # Only lazy.nvim is handled here. Other plugin managers need their own sync command.
  # grep -R (not -r): -r skips symlinked files, which is what stow creates when it
  # doesn't fold the whole directory.
  if grep -Rqs "lazy" "$HOME/.config/nvim" 2>/dev/null; then
    # "install" only adds missing plugins and, when lazy-lock.json exists, uses the
    # locked commits - it doesn't bump versions the way "sync" would.
    info "Installing neovim plugins (lazy.nvim)"
    timeout 600 nvim --headless "+Lazy! install" +qa || warn "nvim plugin install failed - open nvim once and run :Lazy"
  else
    warn "nvim config found but it doesn't look like lazy.nvim - open nvim and sync plugins manually"
  fi
}

# ---------- services ----------
enable_services() {
  command -v systemctl >/dev/null 2>&1 || return 0
  info "Enabling services"

  # The zshrc points SSH_AUTH_SOCK at this socket.
  if command -v ssh-agent >/dev/null 2>&1; then
    systemctl --user enable --now ssh-agent.socket \
      && ok "ssh-agent socket enabled" \
      || warn "could not enable ssh-agent.socket - run: systemctl --user enable --now ssh-agent.socket"
  fi

  if command -v docker >/dev/null 2>&1; then
    sudo systemctl enable --now docker.service \
      && ok "docker service enabled" \
      || warn "could not enable docker - run: sudo systemctl enable --now docker.service"
  fi
}

# ---------- main ----------
main() {
  local skip_packages=0
  while (($#)); do
    case $1 in
      --skip-packages) skip_packages=1 ;;
      -h|--help) usage; exit 0 ;;
      *) warn "unknown option: $1"; usage; exit 1 ;;
    esac
    shift
  done

  ((skip_packages)) || install_packages
  install_zsh_stuff
  stow_packages
  sync_nvim
  enable_services
  set_default_shell

  echo
  ok "Done."
  if ((${#FAILED_PKGS[@]})); then
    warn "These packages could not be installed (renamed or missing?): ${FAILED_PKGS[*]}"
  fi
  if ((${#FAILED_CLONES[@]})); then
    warn "These repos could not be cloned: ${FAILED_CLONES[*]}"
  fi
  if ((${#FAILED_STOW[@]})); then
    warn "These stow packages failed (check the stow error above): ${FAILED_STOW[*]}"
  fi
  [[ -d $BACKUP_DIR ]] && warn "Replaced files were saved in $BACKUP_DIR"
  cat <<'EOF'

Per-machine things this script does NOT do:
  * create ~/.config/hypr/local.lua
  * Noctalia: copy gui.toml settings, then enable the Qt/KColorScheme/GTK templates
  * qt6ct: run it once and pick the "noctalia" color scheme
  * atuin: run `atuin import auto` to pull in your old zsh history
  * docker without sudo: sudo usermod -aG docker "$USER" (root-equivalent, so opt in)
  * Log out and back in so the shell, env vars, groups and portals pick everything up
EOF
}

# Run main only when executed, so the functions can be sourced for testing.
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  main "$@"
fi
