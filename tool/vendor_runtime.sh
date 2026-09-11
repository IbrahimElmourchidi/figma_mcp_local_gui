#!/usr/bin/env bash
# Vendors the figma-mcp-free MCP server and bridge CLI into this app's
# assets/bundled/ directory as self-contained ESM bundles, so the GUI can
# install them into its own app-data directory at runtime and run them
# without depending on a volatile checkout (e.g. under /tmp) or a node_modules
# tree with workspace symlinks.
#
# Usage: tool/vendor_runtime.sh <path-to-figma-mcp-free-checkout>
#
# Requires the checkout to already be built (pnpm -r run build), so that
# packages/*/dist/*.js exist. Requires network access the first time, to
# fetch esbuild via npx.

set -euo pipefail

SRC="${1:?Usage: tool/vendor_runtime.sh <path-to-figma-mcp-free-checkout>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$HERE/assets/bundled"

if [ ! -f "$SRC/packages/mcp-server/dist/index.js" ]; then
  echo "error: $SRC/packages/mcp-server/dist/index.js not found - run 'pnpm -r run build' in the checkout first" >&2
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

SHA="$(git -C "$SRC" rev-parse HEAD 2>/dev/null || echo unknown)"
DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf '%s\n' "$SHA" > "$OUT/VERSION"

echo "Vendored figma-mcp-free @ $SHA ($DATE) into $OUT"
echo "  $(du -h "$OUT/mcp-server.cjs" | cut -f1)  mcp-server.cjs"
echo "  $(du -h "$OUT/bridge-cli.cjs" | cut -f1)  bridge-cli.cjs"
