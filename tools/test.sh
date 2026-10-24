#!/bin/zsh
# Unit checks against the real code: builds a debug copy and runs ICQuel's built-in self-test (Sources/SelfTest.swift). Exit code != 0 on any failure.
cd "$(dirname "$0")/.."
DEBUG_BUILD=1 APP_OUT=/tmp/icquel-test.app ./build.sh 2>&1 | grep -E "error:" && { echo "build failed"; exit 1; }
ICQ_SELFTEST=1 /tmp/icquel-test.app/Contents/MacOS/ICQuel 2>&1 | grep -v sandbox_extension
exit ${pipestatus[1]}
