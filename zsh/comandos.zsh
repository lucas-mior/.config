enpt () { trans en:pt "$@" ; }
restart () {
    killall "$1"; setsid -f "$1" 2>&1 > /dev/null
}

fzfscripts () { 
    pushd ~
	linha=$(grep --line-buffered -r "" .local/scripts/ | fzf --layout=reverse --multi)
	arqui="${linha%%:*}"
	linha=$(echo $linha | awk -F: '{print $2}')
	if  [ $(echo $arqui | wc -l) = 1 ]; then
		if [ -f "$arqui" ]; then
			vim "$arqui" +/"$linha"
            popd
		elif [ -d "$arqui" ]; then
			cd "$arqui"
		fi
	else
		echo $arqui | xargs -o vim -p
        popd
	fi
}
fzfconfig () { 
    pushd ~
	arqui=$(find .config/ .local/scripts/ .local/sourcecode/ 2> /dev/null | fzf --preview='wrap.sh {} $FZF_PREVIEW_COLUMNS $FZF_PREVIEW_LINES 2> /dev/null') ;
	if [[ -f "$arqui" ]]; then
		vim "$arqui"
        popd
	elif [[ -d "$arqui" ]]; then
		cd "$arqui"
	fi
}

fzf-cd-file() {
    # source start_ueberzug.sh "zsh" 2> /dev/null
    stiv -c
    oque=$(find . 2> /dev/null \
        | fzf --print0 --preview='wrap.sh {} $FZF_PREVIEW_COLUMNS $FZF_PREVIEW_LINES 2> /dev/null' --reverse --header='Pesquisar: ' \
        | xargs -0 -I{} realpath "{}")
    echo ""
    [[ -d "$oque" ]] && cd "$oque"
    [[ -f "$oque" ]] && cd "${oque%/*}"
    zle fzf-redraw-prompt
    stiv -c
}
zle     -N   fzf-cd-file
bindkey '^F' fzf-cd-file
