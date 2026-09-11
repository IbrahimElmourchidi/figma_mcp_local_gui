#!/usr/bin/env bash
# Builds the figma-mcp-free runtime bundle and generates runtime.json manifest.
# Used by both local tool/vendor_runtime.sh and CI workflows.
#
# Usage: tool/build_runtime_bundle.sh <path-to-figma-mcp-free-checkout> <output-dir>
#
# Requires the checkout to already be built (pnpm -r run build).

set -euo pipefail

SRC="${1:?Usage: tool/build_runtime_bundle.sh <checkout> <output-dir>}"
OUT="${2:?Usage: tool/build_runtime_bundle.sh <checkout> <output-dir>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ ! -f "$SRC/packages/mcp-server/dist/index.js" ]; then
  echo "error: $SRC/packages/mcp-server/dist/index.js not found" >&2
  exit 1
fi

mkdir -p "$OUT"

# CJS output, not ESM: esbuild's ESM output shims `require()` in a way
# that breaks on commander's internal dynamic `require("node:events")`
# (throws "Dynamic require ... is not supported" at startup). Bundling to
# CJS resolves everything (including ESM-only deps like
# @modelcontextprotocol/sdk) into a single plain CommonJS file, which node
# runs natively regardless of file extension or any sibling package.json.
echo "Bundling mcp-server..."
npx --yes esbuild@0.28.2 "$SRC/packages/mcp-server/dist/index.js" \
  --bundle --platform=node --format=cjs --target=node18 \
  --outfile="$OUT/mcp-server.cjs"

echo "Bundling bridge-cli..."
npx --yes esbuild@0.28.2 "$SRC/packages/cli/dist/bridge-cli.js" \
  --bundle --platform=node --format=cjs --target=node18 \
  --outfile="$OUT/bridge-cli.cjs"

# Copy plugin files. Upstream keeps these at plugins/local-bridge/, not
# packages/plugin/ - and only manifest.template.json is tracked there
# (manifest.json itself is generated per-user/per-port and gitignored).
echo "Copying plugin files..."
mkdir -p "$OUT/plugin"
if [ -f "$SRC/plugins/local-bridge/code.js" ]; then
  cp "$SRC/plugins/local-bridge/code.js" "$OUT/plugin/code.js"
fi
if [ -f "$SRC/plugins/local-bridge/ui.html" ]; then
  cp "$SRC/plugins/local-bridge/ui.html" "$OUT/plugin/ui.html"
fi
if [ -f "$SRC/plugins/local-bridge/manifest.template.json" ]; then
  cp "$SRC/plugins/local-bridge/manifest.template.json" "$OUT/plugin/manifest.template.json"
fi

# Gather metadata
SHA="$(git -C "$SRC" rev-parse HEAD 2>/dev/null || echo unknown)"
DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
ESBUILD_VERSION="0.28.2"

# Write legacy VERSION file
printf '%s\n' "$SHA" > "$OUT/VERSION"

# Generate runtime.json manifest
cat > "$OUT/runtime.json" <<EOF
{
  "schema": 1,
  "upstreamRepo": "superdoccimo/figma-mcp-free",
  "upstreamSha": "$SHA",
  "upstreamCommittedAt": "$DATE",
  "builtAt": "$DATE",
  "builtBy": "${GITHUB_ACTIONS:-local}",
  "esbuildVersion": "$ESBUILD_VERSION",
  "nodeTarget": "node18",
  "files": {}
}
EOF

# Compute SHA-256 for each file
echo "Computing checksums..."
for file in mcp-server.cjs bridge-cli.cjs plugin/code.js plugin/ui.html plugin/manifest.template.json; do
  if [ -f "$OUT/$file" ]; then
    HASH=$(sha256sum "$OUT/$file" | cut -d' ' -f1)
    # Use python for JSON manipulation (available on all CI runners)
    python3 -c "
import json
with open('$OUT/runtime.json', 'r') as f:
    data = json.load(f)
data['files']['$file'] = '$HASH'
with open('$OUT/runtime.json', 'w') as f:
    json.dump(data, f, indent=2)
"
  fi
done

echo "Built runtime bundle @ $SHA ($DATE) into $OUT"
echo "  $(du -h "$OUT/mcp-server.cjs" | cut -f1)  mcp-server.cjs"
echo "  $(du -h "$OUT/bridge-cli.cjs" | cut -f1)  bridge-cli.cjs"
echo "  $(du -h "$OUT/plugin/" | cut -f1)  plugin/"
echo "  $(du -h "$OUT/runtime.json" | cut -f1)  runtime.json"
