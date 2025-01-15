#!/bin/bash
{
    timeout --foreground 1s bluetoothctl power on
    timeout --foreground 1s bluetoothctl discoverable on
    timeout --foreground 1s bluetoothctl pairable on
    timeout --foreground 1s bluetoothctl scan on
} > /dev/null 2>&1
echo "50" > /tmp/volume.old

while read -r dir; do 
    [ ! -d "$dir" ] && mkdir -p "$dir"
done < "$XDG_CONFIG_HOME/tempdirs"

/home/lucas/.local/scripts/count_ydl.sh
setfont ter-124n

sudo setsid -f keyd

find / > /dev/null 2>&1 &
