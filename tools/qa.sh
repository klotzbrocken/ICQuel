#!/bin/zsh
# Visual smoke test: renders every window of the debug build in all four themes and checks that each picture exists and is not blank.
# Run tools/test.sh for the logic checks. Pictures land in /tmp/icquel-qa/<theme>/ (open them to review the look).
cd "$(dirname "$0")/.."
DEBUG_BUILD=1 APP_OUT=/tmp/icquel-qa.app ./build.sh 2>&1 | grep -E "error:" && { echo "build failed"; exit 1; }
rm -rf /tmp/icquel-qa; fail=0
for t in classic modern aqua platinum; do
  mkdir -p /tmp/icquel-qa/$t
  ICQ_THEME=$t ICQ_SNAPSHOT=/tmp/icquel-qa/$t /tmp/icquel-qa.app/Contents/MacOS/ICQuel >/dev/null 2>&1
  n=$(ls /tmp/icquel-qa/$t/*.png 2>/dev/null | wc -l | tr -d ' ')
  small=$(find /tmp/icquel-qa/$t -name '*.png' -size -3k | wc -l | tr -d ' ')
  echo "$t: $n pictures, $small suspiciously small"
  [ "$n" -lt 20 ] && { echo "  too few pictures"; fail=1 }
  [ "$small" -gt 0 ] && { find /tmp/icquel-qa/$t -name '*.png' -size -3k; fail=1 }
done
exit $fail
