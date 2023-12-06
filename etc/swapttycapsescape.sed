#!/usr/bin/env -S sed -E -f

# usage: $0 /usr/share/kbd/keymaps/i386/qwerty/br-abnt2.map.gz
#         > /usr/local/share/kbd/keymaps/br-abnt2-custom.map.gz

s/Caps_Lock/CCCC/g;
s/Escape/Caps_Lock/g;
s/CCCC/Escape/g;

s/semicolon/SSSS/g;
s/colon/HHHH/g;
s/\+ccedilla/semicolon/g;
s/\+Ccedilla/colon/g;
s/SSSS/+ccedilla/g;
s/HHHH/+Ccedilla/g;
