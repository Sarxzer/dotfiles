# ~/.zshrc — Oh My Zsh + Powerlevel10k, with Atuin / zoxide / navi
# Profiling startup time? Uncomment the next line and the `zprof` line at the very end.
# zmodload zsh/zprof

# --- Powerlevel10k instant prompt (keep this block at the very top) ------------
# Anything that needs console input (password prompts, [y/n]) must go above it.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Tiny helper: is this command installed? (lets the rc survive a fresh machine)
_have() { (( $+commands[$1] )) }

# --- PATH ----------------------------------------------------------------------
typeset -U path PATH   # no duplicate entries
for dir in "$HOME/.local/bin" "${GOPATH:-$HOME/go}/bin"; do
  [[ -d $dir ]] && path+=("$dir")
done

# --- Oh My Zsh -----------------------------------------------------------------
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
HIST_STAMPS="yyyy-mm-dd"

# Must be set BEFORE oh-my-zsh.sh, which runs compinit (so ~/.zfunc completions load)
fpath=(~/.zfunc $fpath)

# Order matters: zsh-syntax-highlighting goes after the other plugins,
# history-substring-search goes after zsh-syntax-highlighting.
plugins=(
  git
  sudo
  colored-man-pages
  auto-notify
  zsh-autosuggestions
  zsh-syntax-highlighting
  history-substring-search
)

source $ZSH/oh-my-zsh.sh

# auto-notify: notify when a long command finishes (set after the plugin loads
# so the default ignore list is kept, then add to it)
AUTO_NOTIFY_IGNORE+=("lazygit")

# --- History -------------------------------------------------------------------
# Atuin does the heavy lifting, this is the fallback + the raw record.
HISTFILE=~/.zsh_history
HISTSIZE=100000
SAVEHIST=100000
setopt EXTENDED_HISTORY      # timestamp + duration per command
setopt SHARE_HISTORY         # live-share between terminals
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE     # leading space = not recorded (for secrets)
setopt HIST_REDUCE_BLANKS

# --- Prompt --------------------------------------------------------------------
# To customize the prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet
# _have hyfetch && hyfetch

# --- Completion ----------------------------------------------------------------
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' menu select

if [[ -r /usr/share/zsh/plugins/zsh-autocomplete/zsh-autocomplete.plugin.zsh ]]; then
  source /usr/share/zsh/plugins/zsh-autocomplete/zsh-autocomplete.plugin.zsh
  zstyle ':autocomplete:*' widget-style menu-select
fi

# --- Aliases -------------------------------------------------------------------
if _have eza; then
  alias ls='eza --icons auto'
  alias ll='eza --icons --long --header'
  alias la='eza --icons --long --all --header'
  alias lt='eza --icons --tree --level=2'
fi
_have bat      && alias cat='bat --paging=never'
_have kitten   && alias sshk='kitten ssh'
_have nvim     && alias vim='nvim'
_have kcmshell6 && alias mime='kcmshell6 kcm_filetypes'
alias clr='clear'

# --- Environment ---------------------------------------------------------------
if _have nvim; then
  export EDITOR="nvim"
  export VISUAL="nvim"
  export SUDO_EDITOR="nvim"
fi
export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR:-/run/user/$UID}/ssh-agent.socket"

# --- Tool integrations (keep Atuin last: it owns Ctrl-R and the Up arrow) -------
_have navi   && eval "$(navi widget zsh)"
_have zoxide && eval "$(zoxide init zsh)"
_have atuin  && eval "$(atuin init zsh)"

unfunction _have
# zprof
