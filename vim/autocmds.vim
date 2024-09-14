vim9script
    # au CursorHold   * redraw
    au BufWritePost */key-handler                           !atualizar.sed % > $XDG_CONFIG_HOME/lf/nsxiv
    au BufWritePost ~/.config/tmux/tmux.conf                !tmux source-file %
    au BufWritePost ~/.config/X11/*                         !xrdb ~/.config/X11/Xresources
    au BufWritePost ~/.config/sxhkd/sxhkdrc                 !pkill -SIGUSR1 sxhkd
    au BufWritePost ~/.config/dunst/dunstrc                 !killall dunst; setsid -f dunst 2>&1 > /dev/null
    au BufWritePost ~/.config/atalhos,*/atalhos.awk         !atalhos.awk   ~/.config/atalhos
    au BufWritePost ~/.config/ls_colors.css,*/ls_colors.awk !ls_colors.awk ~/.config/ls_colors.css
    au BufWritePost ~/.config/lf_icons.conf,*/lf_icons.awk  !lf_icons.awk  ~/.config/lf_icons.conf
    au BufRead */Makefile,*.mk,
               \*/src/dmenu/*,*/src/sent/*,*/src/st/*,*/src/swarp/*,
               \*/src/lf/*,*/src/nsxiv/*,*/src/nsxiv-extra/* setlocal noexpandtab
    au BufRead */Makefile setlocal textwidth=100
# compilações
    au BufWritePost *.sh,*.bash,*.zsh   !shellcheck -e SC2059 % 
    au BufWritePost */src/a_c/*.c       !test_c_program.sh % execute
    au BufWritePost */src/0wayland/*.c  !test_c_program.sh %
    au BufWritePost */src/a_c++/*.cpp   !g++ -Wall -Wextra -Wpedantic % -o /tmp/%.out && /tmp/%.out
    au BufWritePost */src/a_python/*.py !python %
    au BufWritePost */src/a_rust/*.rs   !rustc % -o /tmp/%.out && /tmp/%.out
    au BufWritePost */src/dwmblocks2/*  !restart.sh dwmblocks2

# meus highlights
    au BufRead *.mo,*.mod        set ft=modelica
    au BufRead /var/tmp/fstab*   set ft=fstab
    au BufRead *.sp,*.MOD,       set ft=spice
    au BufRead *.plt             set ft=gnuplot
    au BufRead */X11/urxvt       set ft=xdefaults
    au BufRead */zathura/*       set ft=zathurarc
    au BufRead *.sent            set ft=sent
    au BufRead *.sed             set ft=sed
    au BufRead *.pgn             set ft=pgn
    au BufRead */COMMIT_EDITMSG  set ft=gitcommit
    au BufRead,BufNewFile *.tab  set ft=tab
    au BufRead ~/.config/*       set autochdir
    au BufRead *.bib             set autochdir

# cd to file dir on startup
    au VimEnter * lcd %:p:h
    au WinResized * wincmd =
