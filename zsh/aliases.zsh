#!/bin/zsh

alias :q='exit'
alias x='startx "$XDG_CONFIG_HOME/X11/xinitrc"'
alias X='startx "$XDG_CONFIG_HOME/X11/xinitrc"'
alias xrdbxr='xrdb $HOME/.config/X11/Xresources'
alias ka='killall'
alias kad='killall dunst && setsid dunst &'
alias kas='killall sxhkd && setsid sxhkd &'
alias ffmpeg='ffmpeg -hide_banner'

alias vig='vim .git/info/exclude'
alias lucas='git checkout lucas'
alias master='git checkout master'
alias gitcs='sed -n "/\[alias\]/,/\[core\]/p" ~/.config/git/config'

alias ls='ls --group-directories-first --color=auto -h'
alias ll='ls -AlF'
alias la='ls -A'
alias lh='ls -A | grep "^\."'

alias cp='cp -v'
alias mv='mv -iv'
alias rm='rm -dv'
alias mkd='mkdir -pv'
alias cm='chmod -v'
alias co='chown -v'
alias gdb='gdb -q'
alias py='python'

## GIT
alias g='git'
diff () {
    git diff --no-index "$1" "$2"
}

# alias splint='splint -warnposix +ptrnegate'

alias ..='cd ..'
alias ...='cd ../..'
alias push='pushd'
alias pop='popd'
alias bc='bc -l'

cat () {
    for file in "$@"; do
        piscou "$file" $COLUMNS $LINES 2> /dev/null
    done
}

makeee () {
    if [ -n "$1" ]; then
        make "$@"
    else
        make && sudo make install
    fi
}
alias make=makeee

alias du='du -h'
alias ncdu='ncdu --color dark'
alias df='df -h'
alias lsb='lsblk'
alias free='free -h'
alias grep='grep -Ei --color=auto'
alias sed='sed -E'
alias dmenu='dmenu -i'
# alias diff='diff --color=auto --tabsize=4'
alias yv='yt-dlp.sh video'
alias ya='yt-dlp.sh audio'

alias blue='bluetoothctl'
alias qute='qutebrowser'
alias kid='kid3-qt -style kvantum-dark'
alias cat0='/usr/bin/cat'
alias diff0='/usr/bin/diff'

vg () { grep -iRl "$1" ./* | xargs -o vim "+/$1" ; }
v () { vim "$@" ; }
vi () { vim "$@" ; }
