## Liberar <C-s>
    stty -ixon

lastpane () {
    if [ -n "$ZLE_FIFO" ]; then
        tmux last-pane
    fi
    clear
    zle reset-prompt
}
zle -N lastpane

## Atalhos
    bindkey '^e' edit-command-line
    bindkey '^I' first-tab
    bindkey '^H' backward-delete-word
    bindkey '^L' lastpane

## vi mode jkl;
    bindkey -M vicmd j  vi-backward-char
    bindkey -M vicmd k  vi-down-line-or-history
    bindkey -M vicmd l  vi-up-line-or-history
    bindkey -M vicmd \; vi-forward-char

## Corrigir bug com <backspace> e <delete>
    bindkey -a '^[[3~'    delete-char
    bindkey '^[[3~'       delete-char
    bindkey -M vicmd '^?' backward-delete-char
    bindkey -v '^?'       backward-delete-char

## Use vim keys in tab complete menu:
    bindkey -M menuselect 'j' vi-backward-char
    bindkey -M menuselect 'k' vi-down-line-or-history
    bindkey -M menuselect 'l' vi-up-line-or-history
    bindkey -M menuselect ';' vi-forward-char
