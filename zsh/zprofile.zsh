timeout --foreground 1s bluetoothctl power on        > /dev/null 2>&1
timeout --foreground 1s bluetoothctl discoverable on > /dev/null 2>&1
timeout --foreground 1s bluetoothctl pairable on     > /dev/null 2>&1
timeout --foreground 1s bluetoothctl scan on         > /dev/null 2>&1
echo "50" > /tmp/volume.old

brightdir="/sys/class/backlight/intel_backlight"
sudo chmod 666 "${brightdir}/brightness"
/usr/bin/cat "${brightdir}/max_brightness" > "${brightdir}/brightness"

while read dir; do 
    [ ! -d "$dir" ] && mkdir -p "$dir"
done < $XDG_CONFIG_HOME/tempdirs

/home/lucas/.local/scripts/count_ydl.sh
setfont ter-124n
