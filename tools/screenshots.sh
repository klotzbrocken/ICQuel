#!/bin/zsh
# Renders the app's own windows (no screen capture) for every built-in theme into screenshots/.  Usage: tools/screenshots.sh
cd "$(dirname "$0")/.."
OUT=screenshots; rm -rf $OUT; mkdir -p $OUT
run() {  # name theme [light]
    local d=$(mktemp -d)
    if [[ "$3" == light ]]; then export ICQ_LIGHT=1; else unset ICQ_LIGHT; fi
    ICQ_SCALE=1.05 ICQ_SNAPSHOT=$d ICQ_THEME=$2 ./ICQuel.app/Contents/MacOS/ICQuel
    cp $d/main-main.png $OUT/$1-contacts.png; cp $d/send-send*.png $OUT/$1-message.png 2>/dev/null || cp $d/send-*.png $OUT/$1-message.png
    cp $d/p0-prefs.png $OUT/$1-preferences.png; cp $d/add-add.png $OUT/$1-add-users.png; cp $d/setup-wizard.png $OUT/$1-setup.png
    rm -rf $d
}
run retro classic; run aqua aqua; run classic-mac platinum; run modern-light modern light; run modern-dark modern
unset ICQ_LIGHT; ls $OUT
