enpt () {
    trans en:pt "$@"
}

restart () {
    killall "$1"
    setsid -f "$@" >/dev/null 2>&1 
}

gr () {
    grep --color=auto "\<$1\>" src/*.[ch] src/cvode/*.[ch] $2
}

rf () {
    grep -l "\<${1}\>" src/*.[ch] src/cuda/*.[ch] src/cvode/*.[ch] \
        | while read file; do
            sed -Ei "s/\<$1\(/${2}_${1}(/g" "$file";
        done
}

rfall () {
    grep -E -l "\<${1}\>" src/*.[ch] src/cuda/*.[ch] src/cvode/*.[ch] \
        | while read file; do
            sed -E -i "s/\<$1\>\(/${2}(/g" "$file";
        done
}

rnall () {
    grep -E -l "\<${1}\>" src/*.[ch] src/cuda/*.[ch] src/cvode/*.[ch] \
        | while read file; do
            sed -E -i "s/\<$1\>/${2}/g" "$file";
        done
}

fzfscripts () { 
    pushd ~ || exit
	linha=$(grep --line-buffered -r "" .local/scripts/ | fzf --layout=reverse --multi)
	arqui="${linha%%:*}"
	linha=$(echo "$linha" | awk -F: '{print $2}')
	if  [ "$(echo "$arqui" | wc -l)" = 1 ]; then
		if [ -f "$arqui" ]; then
			vim "$arqui" +/"$linha"
            popd || exit
		elif [ -d "$arqui" ]; then
			cd "$arqui" || exit
		fi
	else
		echo "$arqui" | xargs -o vim -p
        popd || exit
	fi
}

fzfconfig () { 
    pushd ~ || exit
	arqui=$(find .config/ .local/scripts/ .local/sourcecode/ 2> /dev/null \
            | fzf --preview='wrap.sh {} $FZF_PREVIEW_COLUMNS $FZF_PREVIEW_LINES 2> /dev/null') ;
	if [[ -f "$arqui" ]]; then
		vim "$arqui"
        popd || exit
	elif [[ -d "$arqui" ]]; then
		cd "$arqui" || exit
	fi
}

fzf-cd-file() {
    # source start_ueberzug.sh "zsh" 2> /dev/null
    stiv_clear
    oque=$(find . 2> /dev/null \
        | fzf --print0 --preview='wrap.sh {} $FZF_PREVIEW_COLUMNS $FZF_PREVIEW_LINES 2> /dev/null' --reverse --header='Pesquisar: ' \
        | xargs -0 -I{} realpath "{}")
    echo ""
    if [[ -d "$oque" ]]; then
        cd "$oque" || exit
    fi
    if [[ -f "$oque" ]]; then
        cd "${oque%/*}" || exit
    fi
    zle fzf-redraw-prompt
    stiv_clear
}
zle     -N   fzf-cd-file
bindkey '^F' fzf-cd-file
