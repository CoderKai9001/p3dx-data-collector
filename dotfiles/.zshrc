POWERLEVEL9K_DISABLE_INSTANT_PROMPT=true
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Keybindings
bindkey -e
bindkey "${terminfo[kcuu1]}" history-search-backward
bindkey "${terminfo[kcud1]}" history-search-forward
#bindkey 'v' history-search-backward

# History
HISTSIZE=100000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups

# Completion styling
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' menu no
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'eza -1 --color=always $realpath'

# helpful aliases
alias c='clear' # clear terminal
alias vc='code' # gui code editor

# directory navigation shortcuts
alias ..='cd ..'
alias ...='cd ../..'
alias .3='cd ../../..'
alias .4='cd ../../../..'
alias .5='cd ../../../../..'
alias l='ls -laFh --color=auto --group-directories-first' # better ls

# always mkdir a path (this doesn't inhibit functionality to make a single dir)
alias mkdir='mkdir -p'
source /root/powerlevel10k/powerlevel10k.zsh-theme
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
# to customize prompt, run `p10k configure` or edit ~/.p10k.zsh
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

export DIRENV_LOG_FORMAT=""

bindkey "\e[1;5D" backward-word
bindkey "\e[1;5C" forward-word

bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
