#!/bin/zsh
# Starts ICQuel on made-up data (random nicknames, fake iMessage contacts) for screenshots. Your real data is not touched.
# The demo data lives in /tmp/icquel-demo and is recreated on every run.  Usage: tools/demo.sh
cd "$(dirname "$0")/.."
D=/tmp/icquel-demo
python3 tools/make_dummy_store.py $D || exit 1
pkill ICQuel; sleep 1
open -n --env ICQUEL_DATA_DIR=$D ICQuel.app
