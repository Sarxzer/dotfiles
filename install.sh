#!/usr/bin/env bash
# install.sh - set up these dotfiles on Arch / CachyOS.
#
#   git clone https://github.com/sarxzer/dotfiles ~/dotfiles
#   cd ~/dotfiles && ./install.sh          # everything, then the guided steps
#   ./install.sh --help                    # all commands and options
#
# Safe to re-run. Existing real files that would collide with a stow link are
# moved to ~/.dotfiles-backup/<timestamp>/ instead of being overwritten.

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
  btop
  ttf-meslo-nerd                       # nerd font for powerlevel10k / eza icons
  # editor + what the neovim config needs (lazygit, telescope, treesitter)
  neovim lazygit ripgrep fd unzip tree-sitter-cli
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

# Guided per-machine steps, in the order they run. Each one is a function named
# step_<name> (dashes become underscores) and can be run alone: ./install.sh post <name>
POST_STEPS=(local-lua noctalia qt6ct atuin)

SKIP_PACKAGES=0
NO_POST=0
ASSUME_YES=0
EXPLICIT=0          # 1 when a step was named on the command line: no confirmation prompts
POSITIONAL=()

FAILED_PKGS=()
FAILED_CLONES=()
FAILED_STOW=()
SKIPPED_STEPS=()

# ---------- helpers ----------
c_info=$'\033[1;34m'; c_warn=$'\033[1;33m'; c_ok=$'\033[1;32m'; c_off=$'\033[0m'
info() { printf '%s==>%s %s\n' "$c_info" "$c_off" "$*"; }
warn() { printf '%s!!%s  %s\n' "$c_warn" "$c_off" "$*" >&2; }
ok()   { printf '%s ok%s %s\n' "$c_ok" "$c_off" "$*"; }
note() { printf '    %s\n' "$*"; }

usage() {
  cat <<'EOF'
Usage: ./install.sh [command] [options]

Commands:
  all                 (default) packages, zsh, link, nvim, services, login shell,
                      then the guided per-machine steps
  packages            install the system packages (yay/paru, builds yay-bin if needed)
  zsh                 clone / update oh-my-zsh, powerlevel10k and the plugins
  link                stow the config folders into $HOME (backs up conflicting files)
  nvim                install neovim plugins (lazy.nvim)
  services            enable ssh-agent.socket
  shell               make zsh your login shell
  post [step...]      guided per-machine steps; name steps to run only those:
                        local-lua   create ~/.config/hypr/local.lua and open it in $EDITOR
                        noctalia    reminder: gui.toml settings + Qt/KColorScheme/GTK templates
                        qt6ct       open qt6ct so you can pick the "noctalia" color scheme
                        atuin       import your old shell history (atuin import auto)
  help                show this help

Options:
  --skip-packages     with `all`: don't install system packages
  --no-post           with `all`: skip the guided steps, just print what is left to do
  -y, --yes           accept the default answer to every prompt
  -h, --help          show this help

Examples:
  ./install.sh                      everything, with prompts for the guided steps
  ./install.sh --no-post            everything, but leave the per-machine steps for later
  ./install.sh link                 just re-stow after editing the repo
  ./install.sh post qt6ct atuin     only those two steps, no questions asked
EOF
}

# ask <question> [y|n]  - yes/no prompt. Default answer is the 2nd argument (y if omitted).
# Steps named on the command line never prompt, --yes takes the default, and with no
# terminal to answer on the answer is "no" (the manual list is printed instead).
ask() {
  local q=$1 def=${2:-y} hint reply
  ((EXPLICIT)) && return 0
  if ((ASSUME_YES)); then [[ $def == y ]]; return; fi
  [[ -t 0 ]] || return 1
  if [[ $def == y ]]; then hint="[Y/n]"; else hint="[y/N]"; fi
  read -r -p "    $q $hint " reply || reply=""
  reply=${reply,,}
  [[ -z $reply ]] && reply=$def
  [[ $reply == y || $reply == yes ]]
}

# Wait for Enter after a manual step (only when someone is there to press it).
pause() {
  if [[ -t 0 ]] && ((ASSUME_YES == 0)) && ((EXPLICIT == 0)); then
    read -r -p "    Press Enter when done... " _ || true
  fi
  return 0
}

editor_cmd() { printf '%s' "${VISUAL:-${EDITOR:-nvim}}"; }

open_editor() {  # open_editor <file>
  local -a cmd
  read -ra cmd <<<"$(editor_cmd)"
  if ! command -v "${cmd[0]:-}" >/dev/null 2>&1; then
    local e
    for e in nvim nano vim vi; do
      if command -v "$e" >/dev/null 2>&1; then cmd=("$e"); break; fi
    done
  fi
  "${cmd[@]}" "$1"
}

have_gui() { [[ -n ${WAYLAND_DISPLAY:-}${DISPLAY:-} ]]; }

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
}

# ---------- guided per-machine steps ----------
step_local_lua() {
  local f="$HOME/.config/hypr/local.lua"

  if [[ -e $f ]]; then
    ok "$f already exists"
    if ask "Open it in $(editor_cmd)?" n; then open_editor "$f"; fi
    return 0
  fi

  if ! ask "Create $f and open it in $(editor_cmd)?" y; then
    SKIPPED_STEPS+=(local-lua)
    return 0
  fi

  mkdir -p "$(dirname "$f")"
  printf '%s\n' \
    '-- Per-machine Hyprland overrides (monitors, tweaks that differ between computers).' \
    '-- Not shared between machines: keep it out of git.' >"$f"
  ok "created $f"

  # If stow folded ~/.config/hypr into a single symlink, this file really lives in the repo.
  case "$(readlink -f "$f")" in
    "$DOTFILES_DIR"/*) warn "this file is inside the repo - add hypr/.config/hypr/local.lua to .gitignore" ;;
  esac

  open_editor "$f"
}

step_noctalia() {
  local gui
  gui="$(find "$DOTFILES_DIR/noctalia" -name gui.toml -print -quit 2>/dev/null || true)"
  info "Noctalia"
  note "1. Copy your gui.toml settings over${gui:+ (the repo has one at ${gui#"$DOTFILES_DIR"/})}."
  note "2. In Noctalia's settings, enable the Qt, KColorScheme and GTK templates."
  note "   (Do this before the qt6ct step: the \"noctalia\" color scheme only exists once they ran.)"
  pause
}

step_qt6ct() {
  if ! command -v qt6ct >/dev/null 2>&1; then
    warn "qt6ct is not installed (it comes from the qt6ct-kde package)"
    SKIPPED_STEPS+=(qt6ct)
    return 0
  fi
  if ! have_gui; then
    warn "no graphical session here, run qt6ct from your desktop: pick the \"noctalia\" color scheme"
    SKIPPED_STEPS+=(qt6ct)
    return 0
  fi
  if ask "Open qt6ct now to pick the \"noctalia\" color scheme?" y; then
    note "Appearance tab -> Palette: choose \"noctalia\", then Apply and close the window."
    qt6ct || warn "qt6ct exited with an error"
  else
    SKIPPED_STEPS+=(qt6ct)
  fi
}

step_atuin() {
  if ! command -v atuin >/dev/null 2>&1; then
    warn "atuin is not installed, skipping history import"
    SKIPPED_STEPS+=(atuin)
    return 0
  fi
  if ask "Import your old shell history into atuin? (only needed once)" y; then
    atuin import auto || warn "atuin import failed - try again later with: atuin import auto"
  else
    SKIPPED_STEPS+=(atuin)
  fi
}

print_manual_list() {
  cat <<'EOF'

Per-machine things still to do (each one is a step of `./install.sh post <name>`):
  * local-lua  create ~/.config/hypr/local.lua
  * noctalia   copy gui.toml settings, then enable the Qt/KColorScheme/GTK templates
  * qt6ct      run it once and pick the "noctalia" color scheme
  * atuin      run `atuin import auto` to pull in your old zsh history
EOF
}

print_relogin() {
  echo
  note "Log out and back in so the shell, env vars and portals pick everything up."
}

run_post() {  # run_post [step...]
  local steps=("$@") s

  if ((${#steps[@]} == 0)); then
    steps=("${POST_STEPS[@]}")
  else
    EXPLICIT=1
    for s in "${steps[@]}"; do
      [[ " ${POST_STEPS[*]} " == *" $s "* ]] || { warn "unknown step: $s (steps: ${POST_STEPS[*]})"; exit 1; }
    done
  fi

  # Nobody to answer the prompts (piped input, cron, ...): leave the list instead.
  if ((EXPLICIT == 0 && ASSUME_YES == 0)) && [[ ! -t 0 ]]; then
    warn "not running in a terminal, skipping the guided steps"
    print_manual_list
    return 0
  fi

  info "Guided per-machine steps (Ctrl-C to stop; re-run any time with: ./install.sh post)"
  for s in "${steps[@]}"; do
    "step_${s//-/_}" || warn "step '$s' failed"
  done

  if ((${#SKIPPED_STEPS[@]})); then
    warn "Skipped: ${SKIPPED_STEPS[*]} (run ./install.sh post <name> when you want them)"
  fi
  print_relogin
}

# ---------- main ----------
summary() {
  if ((${#FAILED_PKGS[@]})); then
    warn "These packages could not be installed (renamed or missing?): ${FAILED_PKGS[*]}"
  fi
  if ((${#FAILED_CLONES[@]})); then
    warn "These repos could not be cloned: ${FAILED_CLONES[*]}"
  fi
  if ((${#FAILED_STOW[@]})); then
    warn "These stow packages failed (check the stow error above): ${FAILED_STOW[*]}"
  fi
  if [[ -d $BACKUP_DIR ]]; then
    warn "Replaced files were saved in $BACKUP_DIR"
  fi
}

main() {
  while (($#)); do
    case $1 in
      --skip-packages)  SKIP_PACKAGES=1 ;;
      --no-post)        NO_POST=1 ;;
      -y|--yes)         ASSUME_YES=1 ;;
      -h|--help)        usage; exit 0 ;;
      -*)               warn "unknown option: $1"; usage >&2; exit 1 ;;
      *)                POSITIONAL+=("$1") ;;
    esac
    shift
  done

  local cmd=${POSITIONAL[0]:-all}
  local -a rest=()
  if ((${#POSITIONAL[@]} > 1)); then rest=("${POSITIONAL[@]:1}"); fi

  if ((${#rest[@]})) && [[ $cmd != post ]]; then
    warn "'$cmd' takes no arguments (got: ${rest[*]})"
    exit 1
  fi

  case $cmd in
    all)
      ((SKIP_PACKAGES)) || install_packages
      install_zsh_stuff
      stow_packages
      sync_nvim
      enable_services
      set_default_shell
      echo
      ok "Done."
      summary
      if ((NO_POST)); then
        print_manual_list
        print_relogin
      else
        run_post
      fi
      ;;
    packages) install_packages; summary ;;
    zsh)      install_zsh_stuff; summary ;;
    link)     stow_packages; summary ;;
    nvim)     sync_nvim ;;
    services) enable_services ;;
    shell)    set_default_shell ;;
    post)     run_post "${rest[@]+"${rest[@]}"}" ;;
    help)     usage ;;
    *)        warn "unknown command: $cmd"; usage >&2; exit 1 ;;
  esac
}

# Run main only when executed, so the functions can be sourced for testing.
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  main "$@"
fi
