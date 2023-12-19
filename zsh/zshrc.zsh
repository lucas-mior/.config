#!/usr/bin/zsh
## PROMPTS
    PS1=$'%{\033[01;38;5;11m%}%n%{\033[01;38;5;01m%}\@%M% %{\033[01;38;5;136m%} %1~ %{\033[0;37m%}$ %{\033[0m%}'
    PS2=$'%{\033[0;38;5;03m%}%_ %{\033[0m%}>              '

## History
    export HISTSIZE=1000000
    export SAVEHIST=1000000
    export HISTFILE=$XDG_DATA_HOME/zsh/history.zsh

## Basic auto/tab complete:
    autoload -U compinit
    zstyle ':completion:*' menu select
    zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
    zmodload zsh/complist
    compinit
    _comp_options+=(globdots)       # Include hidden files.

## vi mode
    bindkey -v
    autoload -U select-quoted
    zle -N select-quoted
    for m in visual viopp; do
        for c in {a,i}{\',\",\`}; do
            bindkey -M $m $c select-quoted
        done
    done
    export KEYTIMEOUT=1

## Change cursor shape for different vi modes.
    zle-keymap-select () {
        if [[ ${KEYMAP} == vicmd ]] || [[ $1 = 'block' ]]; then
            echo -ne '\e[2 q\e]12;yellow\x7'
        elif [[ ${KEYMAP} == main ]] || [[ ${KEYMAP} == viins ]] \
            || [[ ${KEYMAP} = '' ]] || [[ $1 = 'beam' ]]; then
            echo -ne '\e[6 q\e]12;blue\x7'
        fi
    }
    zle -N zle-keymap-select
    zle-line-init() {
        zle -K viins                               
        echo -ne "\e[6 q\e]12;blue\x7"
    }
    zle -N zle-line-init
    # Use beam shape cursor on startup.
    echo -ne '\e[6 q\e]12;blue\x7'                 
    preexec() {
        # Use beam shape cursor for each new prompt.
        echo -ne '\e[6 q\e]12;blue\x7'
    }

    autoload edit-command-line; zle -N edit-command-line

## outras configura
	source $XDG_CONFIG_HOME/zsh/aliases.zsh
	source $XDG_CONFIG_HOME/zsh/comandos.zsh
	source $XDG_CONFIG_HOME/zsh/mappings.zsh
	source $XDG_CONFIG_HOME/zsh/altgr.zsh
	source $XDG_CONFIG_HOME/zsh/.arquivos.zsh
	source $XDG_CONFIG_HOME/zsh/.pastas.zsh
	source $XDG_CONFIG_HOME/zsh/fzf.zsh
	source $XDG_CONFIG_HOME/zsh/highlights.zsh

## primeira tabula auto completa
    first-tab() {
        if [[ $#BUFFER == 0 ]]; then
            export BUFFER="cd "
            export CURSOR=3
            zle list-choices
        else
            zle expand-or-complete
        fi
    }
    zle -N first-tab

## algumas opções
    chpwd () {
        ls -A
        printf "\033]0;${PWD/\/home\/lucas/~}/\007" > /dev/tty
    }
    setopt autocd             #cd sem digitar cd, apenas dirname
    setopt cshjunkiequotes
    setopt histignoredups
    setopt histignorespace
    setopt interactivecomments
    # set -o ignoreeof # dont exit on ctrl-d

    _zlf() {
        emulate -L zsh
        local d=$(mktemp -d) || return 1
        {
            mkfifo -m 600 $d/fifo || return 1
            tmux split -bf zsh -c "exec {ZLE_FIFO}>$d/fifo; export ZLE_FIFO; exec lf" || return 1
            local fd
            exec {fd}<$d/fifo
            zle -Fw $fd _zlf_handler
        } always {
            rm -rf $d
        }
    }
    zle -N _zlf
    bindkey '\ek' _zlf

    _zlf_handler() {
        emulate -L zsh
        local line
        if ! read -r line <&$1; then
            zle -F $1
            exec {1}<&-
            return 1
        fi
        eval $line
        zle -R
    }
    zle -N _zlf_handler

## PLUGINS
    source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
    printf "\033]0;${PWD/\/home\/lucas/~}/\007" > /dev/tty ## seta o title do terminal
	source /home/lucas/.config/zsh/.arquivos.zsh
	source /home/lucas/.config/zsh/.pastas.zsh
    stiv_clear
