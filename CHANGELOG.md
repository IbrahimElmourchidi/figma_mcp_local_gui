# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - 2026-09-11

### Added
- NodeRuntimeService: self-provisions Node.js with SHA-256 verification
- RuntimeUpdateService: checks upstream SHA, staged swap with rollback
- BootstrapService: ordered init sequence (node, runtime, updates)
- Update banner widget for app and runtime update notifications
- BootstrapScreen for first-run progress display
- On-device build fallback (opt-in from Settings)
- CI/CD: ci.yml, runtime-sync.yml, app-release.yml workflows
- Cross-platform fixes (Windows config dir, orphan cleanup, Figma detection)

### Changed
- Plugin files sourced from runtime directory instead of bundled assets
- ui.html port-substituted to match configured bridge port
- Figma plugin ID configurable from Settings (no longer hardcoded)
- opencode config written cross-platform (XDG_CONFIG_HOME, APPDATA)
- System Checker reports on managed Node.js runtime

### Fixed
- Windows support: correct config directory, orphan cleanup, Figma detection
- Plugin manifest uses user's Figma plugin ID instead of hardcoded value

## [1.0.0] - 2025-09-11

### Added

- Dashboard with server status card, pairing token display, and connection test
- Bridge server lifecycle management (start, stop, restart)
- Orphaned process detection and cleanup (`killOrphanedProcesses`)
- MCP server lifecycle management (start, stop)
- System requirements checker (Node.js version, port availability, Figma Desktop, plugin installation)
- Figma development plugin manager (install, reinstall, uninstall, open folder)
- One-click opencode MCP configuration generation and save (`opencode.json`)
- Settings screen for host, port, auto-start, theme, and logging preferences
- Light and dark theme support with system-aware toggle
- Automatic update checker via GitHub releases
- Persistent settings via SharedPreferences
- Bundled `bridge-cli.cjs` and `mcp-server.cjs` runtime with `RuntimeInstaller`
- Vendored runtime script (`tool/vendor_runtime.sh`) for rebundling figma-mcp-free
- Cross-platform support: Linux (Debian-based), macOS, Windows
- Token passed via environment variable (`FIGMA_PLUGIN_BRIDGE_TOKEN`) to avoid `ps` visibility
- Host field restricted to loopback addresses (`127.0.0.1`, `localhost`, `::1`)
- Figma plugin with loopback-only network access, Host header validation, and snapshot size limits
