## XDG directories
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_SCRIPTS_DIR="$HOME/.local/scripts"
export XDG_BIN_DIR="$HOME/.local/bin"
export XDG_DOCUMENTS_DIR="$HOME/docs"
export XDG_DOWNLOAD_DIR="$HOME/down"
export XDG_MUSIC_DIR="$HOME/mus"
export XDG_PICTURES_DIR="$HOME/imgs"
export XDG_VIDEOS_DIR="$HOME/vids"
export XDG_DESKTOP_DIR="$HOME"
export XDG_PUBLICSHARE_DIR="$HOME"
export XDG_TEMPLATES_DIR="$HOME/docs/templates"
# export XDG_RUNTIME_DIR="/tmp/$USER"

## tirar lixo de $HOME
export INPUTRC="$XDG_CONFIG_HOME/inputrc"
export ZDOTDIR="$XDG_CONFIG_HOME/zsh/"
export GTK2_RC_FILES="$XDG_CONFIG_HOME/gtk-2.0/gtkrc"
export GTK_THEME="Raleigh"
export GTK_USE_PORTAL=1
# export GDBHISTFILE="$XDG_DATA_HOME/gdb/history"
export LESSKEYIN="$XDG_CONFIG_HOME/less/lesskey"
export LESSHISTFILE="$XDG_CONFIG_HOME/less/lesshistory"
export OCTAVE_HISTFILE="$XDG_CONFIG_HOME/octave/octave-hsts"
export OCTAVE_SITE_INITFILE="$XDG_CONFIG_HOME/octave/octaverc"
export PYTHONHISTFILE="$XDG_CACHE_HOME/python/history.py"
export PYTHONPYCACHEPREFIX="$XDG_CACHE_HOME/python"
export PYTHONUSERBASE="$XDG_DATA_HOME/python"
export RXVT_SOCKET="$XDG_CACHE_HOME/urxvt/daemon"
export LYNX_CFG_PATH="$XDG_CONFIG_HOME/lynx/"
export XAUTHORITY="$XDG_RUNTIME_DIR/Xauthority"
export ZATHURA_PLUGINS_PATH="/usr/lib/zathura/"
export GNUPGHOME="$XDG_DATA_HOME/gnupg"
export PASSWORD_STORE_DIR="$XDG_DATA_HOME/pass"
export WGETRC="$XDG_CONFIG_HOME/wget/wgetrc"
export VIMINIT='let $MYVIMRC="$XDG_CONFIG_HOME/vim/vimrc" | source $MYVIMRC'
export RUSTUP_HOME="$XDG_DATA_HOME/rustup"
export CARGO_HOME="$XDG_DATA_HOME/cargo"
export CARGO_INSTALL_ROOT="$HOME/.local"
export KERAS_HOME="$XDG_DATA_HOME/keras"
export JUPYTER_CONFIG_DIR="$XDG_CONFIG_HOME/jupyter"
export NPM_CONFIG_USERCONFIG="$XDG_CONFIG_HOME/npm/npmrc"
export KAGGLE_CONFIG_DIR="$XDG_CONFIG_HOME/kaggle"
export CUDA_CACHE_PATH="$XDG_CACHE_HOME/nv"
export PYTHONSTARTUP="$XDG_CONFIG_HOME/python/pythonrc.py"
export WINEPREFIX="$HOME/.local/wine"

## dwmblocks2 e dustify
export DWMBLOCKS2_RECORD=1
export DWMBLOCKS2_CLIPBOARD=2
export DWMBLOCKS2_YOUTUBE=3
export DWMBLOCKS2_DRIVES0=4
export DWMBLOCKS2_DRIVES1=5
export DWMBLOCKS2_DRIVES2=6
export DWMBLOCKS2_MUSIC=7
export DWMBLOCKS2_VOLUME=8
export DWMBLOCKS2_MICROPHONE=9
export DWMBLOCKS2_BRIGHT=10
export DWMBLOCKS2_RAM=11
export DWMBLOCKS2_CPU=12
export DWMBLOCKS2_NETWORK=13
export DWMBLOCKS2_BLUETOOTH=14
export DWMBLOCKS2_BATTERY=15
export DWMBLOCKS2_CLOCK=16
export DWMBLOCKS2_UPTIME=17
export DWMBLOCKS2_TRAFIC=18

## PROGRAMAS
export CLIPSIM_SIGNAL_NUMBER=$DWMBLOCKS2_CLIPBOARD
export CLIPSIM_SIGNAL_PROGRAM="dwmblocks2"
export CLIPSIM_IMAGE_PREVIEW="stiv_draw"
export REDSHIFT_CACHE="$XDG_CACHE_HOME/redshift"
export WANDB_DISABLED="true"
export SUDO_ASKPASS="/usr/local/bin/dmenupass.sh"
export MPD_PORT=6600
export EDITOR="vim"
export OPENER="xdg-open"
export VISUAL="vim"
export PAGER="less -F -X -x4"
export BROWSER="brave"
export TERMINAL="st"
export GOPATH="$XDG_DATA_HOME/go"
export LESS="-R -F -X -x4"
export MAKEFLAGS='-j16'
#export QT_STYLE_OVERRIDE="gtk2"
export QT_QPA_PLATFORMTHEME="qt5ct"
export RUST_BACKTRACE=1

## pass generate [-n] <N>
PASSWORD_STORE_CHARACTER_SET=""
PASSWORD_STORE_CHARACTER_SET+='abcdefghijkmnpqrstuvwxyz'
PASSWORD_STORE_CHARACTER_SET+='ABCDEFGHJKLMNPQRSTUVWXYZ'
PASSWORD_STORE_CHARACTER_SET+='123456789'
PASSWORD_STORE_CHARACTER_SET+='!@#$%&*_=+-'
export PASSWORD_STORE_CHARACTER_SET="$PASSWORD_STORE_CHARACTER_SET"
export PASSWORD_STORE_GENERATED_LENGTH=$(($RANDOM%3+35))

## meus scripts
export TRANSFILES="/tmp/transfiles"
export MAGIC_TMP_FILE="/tmp/magic_tmp_file"
export TRANSLOG="$HOME/.cache/trans.log"
export SCRIPTS="$HOME/.local/scripts"

## CORES
export RES="\033[0;m"
export BOL="\033[01;38;2;255;255;255m"
export BGB="\033[01;38;2;000;048;002;255;255;255m"
export BLA="\033[01;38;2;000;000;000m"
export RED="\033[01;38;2;255;000;000m"
export GRE="\033[01;38;2;000;255;000m"
export YEL="\033[01;38;2;255;255;000m"
export BLU="\033[01;38;2;000;000;255m"
export PUR="\033[01;38;2;255;000;255m"
export CYA="\033[01;38;2;000;169;169m"
export WHY="\033[01;38;2;255;255;255m"
export GRA="\033[01;38;2;051;051;051m"
export ORA="\033[01;38;2;255;102;000m"
export VER="\033[01;38;2;000;204;000m"
export FOL="\033[01;38;2;000;136;255m"
export PIN="\033[01;38;2;198;000;198m"

## PATH
PATH=$(du $XDG_BIN_DIR     | grep -v ".git" | cut -f 2 | tr '\n' ':' | sed 's/:*$//'):$PATH
PATH=$(du $XDG_SCRIPTS_DIR | grep -v ".git" | cut -f 2 | tr '\n' ':' | sed 's/:*$//'):$PATH
PATH=$PATH:/opt/freefilesync/Bin/
PATH=$PATH:/usr/share/fslint/fslint/
PATH=$PATH:/usr/share/labcontrole/
PATH=$PATH:/opt/scilab/bin/
PATH="$PATH:/home/lucas/.local/wine/drive_c/Program Files/MATLAB/R2017a/bin/"
PATH="$PATH:/home/lucas/.local/wine/drive_c/Program Files/OpenModelica/bin/"
PATH="$PATH:/home/lucas/.local/wine/drive_c/Program Files (x86)/Dynamis/Vulcano-2.5/Vulcano.exe"
PATH="$PATH:/home/lucas/.local/wine/Program Files/OpenModelica1.23.0-64bit/bin/"
PATH="$PATH:/opt/anaconda/bin/"
PATH="$PATH:/opt/android-sdk/platform-tools/"
export PATH

## FZF CONFIG
FZFO+=" --bind=ctrl-k:down,ctrl-l:up,alt-k:down,alt-l:up,ctrl-h:backward-kill-word"
FZFO+=" --tiebreak=end --scroll-off=5 --bind change:first"
FZFO+=" --bind=f8:down,f9:up --border=none --no-scrollbar"
FZFO+=" --preview-window=:noborder:wrap"
FZFO+=" --color=fg:248,fg+:007,bg+:000,preview-fg:007,hl:009,hl+:009"
FZFO+=" --color=gutter:-1,info:006,border:246,prompt:110,pointer:199"
FZFO+=" --color=marker:011,spinner:190,header:007"
export FZF_DEFAULT_OPTS=$FZFO
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'

## LF CONFIG
export COLORTERM=truecolor
export TCELL_TRUECOLOR=on
## LS_COLORS e LF_ICONS
source "$XDG_CONFIG_HOME/zsh/cores.zsh"
source "$XDG_CONFIG_HOME/zsh/lf_icons.zsh"

export OMC_LDFLAGS_LINK_TYPE="static"
export KBD_PATH="/usr/share/kbd/keymaps/i386/qwerty/br-abnt2.map.gz"
export KBD_CUSTOM_DIR="/usr/local/share/kbd/keymaps/i386/qwerty/"
export AWKPATH="$HOME/.local/scripts/awk/"
export PKGEXT=".pkg.tar"
export SRCEXT=".src.tar"
export MODELICAPATH="$HOME/.openmodelica/libraries/"
export LFS=/mnt/lfs/
