#!/bin/zsh

random() {
    seq ${1:-10} | shuf -n 1
}

function fosscopy() {
    original="$HOME/.local/src/0reference/fossify/$1"
    copy="$HOME/.local/src/0reference/fossify_copy/$1"
    vimdiff "$original" "$copy"
}

cmakeclean () {
    set -x

    make clean
    git reset --hard
    git clean -f

    rm -rf build
    x86_64-w64-mingw32-cmake-static -B build -DCMAKE_BUILD_TYPE=Release \
        -DLWS_WITH_STATIC=ON -DLWS_WITH_SHARED=ON \
        -DLWS_LINK_TESTAPPS_DYNAMIC=OFF \
        -DLWS_STATIC_PIC=ON

# # option(LWS_WITH_STATIC "Build the static version of the library" ON)
# # option(LWS_WITH_SHARED "Build the shared version of the library" ON)
# # option(LWS_LINK_TESTAPPS_DYNAMIC "Link the test apps to the shared version of the library. Default is to link statically" OFF)
# # option(LWS_STATIC_PIC "Build the static version of the library with position-independent code" OFF)
# # option(LWS_SUPPRESS_DEPRECATED_API_WARNINGS "Turn off complaints about, eg, openssl 3 deprecated api usage" ON)

    cmake --build build
    cmake --install build

    set +x
}
alias :q='exit'
alias sudo='sudo HOME=/home/lucas/'
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

alias ls='ls --group-directories-first --color=auto -h -p'
alias -g ll='ls -AlF'
alias -g la='ls -A'
alias -g lh='ls -A | grep "^\."'

alias cp='cp -v --reflink=auto'
alias rsync='rsync -HL -ur -ogt -P --fuzzy --info=progress2'
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

zshbuild () {
    if [ -f "build.sh" ]; then
        ./build.sh "$1"
    else
        make "$1"
    fi
}

alias du='du -h'
alias lsblk='lsblk -o NAME,SIZE,LABEL,FSTYPE,FSVER,MOUNTPOINTS,PARTLABEL | lsblk.awk'
alias initrd='sudoedit /etc/mkinitcpio.conf && sudo mkinitcpio -P'
alias grub='sudoedit /etc/default/grub && sudo grub-mkconfig -o /boot/grub/grub.cfg'
boot () {
    sudoedit /boot/loader/loader.conf
    sudoedit /boot/loader/entries/*
    bootctl list
}
fstab ()  {
   sudoedit /etc/fstab /etc/crypttab /etc/crypttab.initramfs \
       && sudo systemctl daemon-reload \
       && sudo mkinitcpio -P
}

# alias -g build='zshbuild'
# alias -g build.sh='zshbuild'
alias ncdu='ncdu --color dark'
alias df='df -h'
alias lsb='lsblk'
alias free='free -h'
alias grep='grep -Ei --color=auto  --exclude-dir=.git'
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

cmount () {
    set -x
    grep "$1" /etc/crypttab
    grep "$1" /etc/fstab

    sudo systemctl daemon-reload
    sudo systemctl start systemd-cryptsetup@$1.service
    sudo mount /dev/mapper/$1
    set -x
}

alias fstab='sudoedit /etc/fstab && sudo systemctl daemon-reload'

gpg-reload () {
     pkill scdaemon
     pkill gpg-agent
     gpg-connect-agent /bye >/dev/null 2>&1
     gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1
     gpgconf --reload gpg-agent
 }

clean_numbers () {
    set +x

    cd /tmp/brn2 || return
    cd /tmp      || return
    rm -rf /tmp/brn2
    mkdir brn2
    cd brn2

    set -x
}

alias monerod='monerod --data-dir "$XDG_DATA_HOME/bitmonero"'
