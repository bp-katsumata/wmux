# wmux ZDOTDIR wrapper — relay user's .zshrc, then source wmux integration
[ -f "$HOME/.zshrc" ] && source "$HOME/.zshrc"
[ -n "$WMUX_BASH_SCRIPT" ] && source "$WMUX_BASH_SCRIPT"
