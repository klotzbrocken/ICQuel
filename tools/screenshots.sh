#!/bin/zsh
# Renders the app's own windows (no screen capture) for the four main themes into screenshots/: contact list + message window.
# The debug build runs on a throw-away store with made-up nicknames and iMessage names, never on your real data.  Usage: tools/screenshots.sh
cd "$(dirname "$0")/.."
DBG=/tmp/ICQuel-debug.app
APP_OUT=$DBG DEBUG_BUILD=1 ./build.sh >/dev/null || exit 1
OUT=screenshots; rm -rf $OUT; mkdir -p $OUT
run() {  # name theme [light]
    local d=$(mktemp -d)
    if [[ "$3" == light ]]; then export ICQ_LIGHT=1; else unset ICQ_LIGHT; fi
    ICQ_ONLY=main,incoming ICQ_SCALE=1.05 ICQ_SNAPSHOT=$d ICQ_THEME=$2 $DBG/Contents/MacOS/ICQuel >/dev/null
    cp $d/main-main.png $OUT/$1-main.png; cp $d/incoming-in*.png $OUT/$1-message.png 2>/dev/null || cp $d/incoming-*.png $OUT/$1-message.png
    rm -rf $d
}
run windows-classic classic; run macos-classic platinum; run aqua aqua; run modern modern light
unset ICQ_LIGHT; ls $OUT
