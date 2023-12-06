set ft=tab
syntax match notas     "\([sbhpr\/~|-]\)\@<=[0-9][0-9]\=\([bhprs\/~|-]\|$\)\@="
syntax match ligados   "\(^[A-Ge]\=|.\+\)\@<=[sbhpr~\/\\]\+\((\|[0-9-$]\)\@="
syntax match fantasma  "\(-\)\@<=x\(-\)\@="
syntax region tablatura matchgroup=Normal start="^[A-Ge]\?|" end="$" transparent contains=notas,ligados

syntax match acordes "\(^\|\s\)\@<=[A-G][#b]\=[Mmº°]\=\([0-9][0-9]\=\(M\|-\|+\)\=\)\=\($\|\/\|(\|\(maj\|sus\|add\|dim\)\|\s\+\([A-G]\|)\|[0-9]x\|$\)\)\@="
syntax match acordes "\(\/\|(\)\@<=[A-G]\=[#b]\=[Mmº°]\=\([0-9][0-9]\=[bM+-]\=\)\{}\($\|\/\|)\|(\|\(maj\|sus\|add\|dim\)\|\s\+\|\([A-G]\|)\)\)\@="
syntax match acordes "\(maj\|sus\|add\|dim\)\@<=[0-9]\+"

hi amarelo   ctermfg=Yellow ctermbg=NONE cterm=bold
hi verde     ctermfg=Green  ctermbg=NONE cterm=bold
hi amarelocl ctermfg=Yellow ctermbg=NONE cterm=NONE
hi azul      ctermfg=4      ctermbg=NONE cterm=NONE

highlight link acordes   amarelo
highlight link tablatura azul
highlight link ligados   verde
highlight link fantasma  amarelocl
highlight link notas     amarelo
highlight link parte     String
