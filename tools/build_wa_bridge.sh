#!/bin/bash
# Usage: tools/build_wa_bridge.sh <outDir>  -> <outDir>/bridge.js (esbuild bundle) + <outDir>/node (universal)
set -euo pipefail
die() { echo "build_wa_bridge: $*" >&2; exit 1; }
[ $# -eq 1 ] || die "usage: $0 <outDir>"
HERE="$(cd "$(dirname "$0")" && pwd)"; W="$HERE/wa-bridge"; CACHE="$W/.cache"
OUT="$1"; mkdir -p "$OUT" "$CACHE"; OUT="$(cd "$OUT" && pwd)"

# 1. bundle
cd "$W"
[ -d node_modules/@whiskeysockets/baileys ] && [ -x node_modules/.bin/esbuild ] || npm install --no-audit --no-fund >&2 || die "npm install failed"
node_modules/.bin/esbuild index.js --bundle --platform=node --format=cjs --target=node20 --minify=false \
  --external:sharp --external:jimp --external:link-preview-js --external:qrcode-terminal --external:audio-decode \
  --log-level=warning --outfile="$OUT/bridge.js" || die "esbuild failed"
node "$OUT/bridge.js" --selftest </dev/null | python3 -c "import sys,json;[json.loads(l) for l in sys.stdin]" || die "bundle selftest failed"

# 2. universal node (skipped with NO_NODE=1: the app downloads Node on demand, see Sources/WhatsApp.swift)
[ -n "${NO_NODE:-}" ] && { echo "built $OUT/bridge.js (no node)" >&2; exit 0; }
if [ -x "$OUT/node" ] && lipo -archs "$OUT/node" 2>/dev/null | grep -q arm64 && lipo -archs "$OUT/node" | grep -q x86_64; then
  echo "node already universal: $OUT/node" >&2; exit 0
fi
V="$(/opt/homebrew/bin/node -v 2>/dev/null || node -v)"
fetch() { # arch -> path to node binary
  local a="$1" ver="$2" d="$CACHE/node-$2-darwin-$1"
  if [ ! -x "$d/bin/node" ]; then
    local t="$CACHE/node-$ver-darwin-$a.tar.gz"
    curl -fsSL "https://nodejs.org/dist/$ver/node-$ver-darwin-$a.tar.gz" -o "$t.part" || { rm -f "$t.part"; return 1; }
    mv "$t.part" "$t"; mkdir -p "$d.tmp"; tar -xzf "$t" -C "$d.tmp" --strip-components=1 && rm -rf "$d" && mv "$d.tmp" "$d"
  fi
}
if ! { fetch arm64 "$V" && fetch x64 "$V"; }; then
  echo "node $V tarballs unavailable, falling back to latest LTS" >&2
  V="$(curl -fsSL https://nodejs.org/dist/index.json | python3 -c "import sys,json;print(next(r['version'] for r in json.load(sys.stdin) if r['lts']))")" || die "cannot determine LTS"
  fetch arm64 "$V" && fetch x64 "$V" || die "cannot download node $V"
fi
A="$CACHE/node-$V-darwin-arm64/bin/node"; X="$CACHE/node-$V-darwin-x64/bin/node"
"$A" --version >/dev/null 2>&1 || die "arm64 node does not run"
if arch -x86_64 /usr/bin/true 2>/dev/null; then arch -x86_64 "$X" --version >/dev/null || die "x64 node does not run"; else echo "no Rosetta: x64 node not run-tested" >&2; fi
lipo -create "$A" "$X" -output "$OUT/node.tmp" || die "lipo failed"
chmod +x "$OUT/node.tmp"; mv "$OUT/node.tmp" "$OUT/node"
echo "built $OUT/bridge.js and universal $OUT/node ($V)" >&2
