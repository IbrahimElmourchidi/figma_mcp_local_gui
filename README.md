# Figma Local MCP GUI

A cross-platform Flutter desktop application for managing the **Figma MCP Local Bridge Server**. Provides a native GUI to control the bridge server, manage the Figma development plugin, run system diagnostics, and configure [opencode](https://opencode.ai) integration — all from a single dashboard.

## Features

- **Server Lifecycle Control** — Start, stop, and restart the bridge server with one click; orphaned process detection and cleanup
- **Pairing Token Management** — Display and copy the bridge pairing token for Figma plugin authentication
- **System Requirements Diagnostics** — Verify Node.js version, port availability, Figma Desktop status, and plugin installation
- **Figma Plugin Manager** — Install, reinstall, or uninstall the `figma-mcp-free` development plugin directly into Figma's Development directory
- **MCP Server Control** — Start and stop the `mcp-server` process with environment configuration
- **opencode Integration** — One-click generation and save of `opencode.json` MCP configuration with atomic writes and backup
- **Automatic Update Checker** — Query GitHub releases for new versions
- **Persistent Settings** — Port, host, auto-start, theme, and logging preferences saved across sessions
- **Light & Dark Theme** — System-aware theming with manual override

## Architecture

```
lib/
├── main.dart                     # Entry point with Provider setup
├── app.dart                      # Root widget with navigation shell
├── core/
│   ├── constants.dart            # App-wide constants
│   ├── theme.dart                # Light/dark theme definitions
│   └── utils.dart                # Utility helpers
├── models/
│   ├── server_status.dart        # Server state & status enum
│   ├── system_requirement.dart   # System check result model
│   ├── bridge_config.dart        # Configuration model (host, port, token, paths)
│   └── app_update.dart           # GitHub release info model
├── services/
│   ├── bridge_service.dart       # Bridge server lifecycle (start/stop/restart/orphan cleanup)
│   ├── mcp_service.dart          # MCP server lifecycle & opencode config generation
│   ├── process_manager.dart      # Low-level Node.js process spawning
│   ├── runtime_installer.dart    # Bundled runtime extraction to app-data directory
│   ├── system_checker_service.dart # Node.js, port, Figma, plugin verification
│   ├── plugin_manager.dart       # Figma development plugin install/uninstall
│   ├── update_service.dart       # GitHub release polling
│   ├── storage_service.dart      # SharedPreferences persistence
│   └── theme_service.dart        # Theme mode management
├── screens/
│   ├── dashboard_screen.dart     # Main control panel with server status & cards
│   ├── settings_screen.dart      # Configuration editor
│   ├── system_check_screen.dart  # Requirements diagnostic view
│   └── about_screen.dart         # Version info & update check
└── widgets/
    ├── server_status_card.dart   # Live server status display
    ├── token_display.dart        # Token copy-to-clipboard interface
    ├── connection_test.dart      # Loopback connectivity test
    ├── requirement_tile.dart     # Individual system requirement row
    └── update_banner.dart        # Update available notification
```

## Bundled Runtime

The `assets/bundled/` directory ships self-contained, dependency-free bundles of the [figma-mcp-free](https://github.com/nicobailon/figma-mcp-free) MCP server and bridge CLI (`mcp-server.cjs`, `bridge-cli.cjs`). On first run, `RuntimeInstaller` copies these into the platform-appropriate app-data directory (`~/.local/share/figma_local_mcp_gui/runtime/` on Linux) so the app never depends on a volatile checkout or `node_modules` tree.

To refresh the bundled runtime against a newer figma-mcp-free checkout:

```bash
# In the figma-mcp-free checkout:
pnpm -r run build

# From this project:
tool/vendor_runtime.sh /path/to/figma-mcp-free
```

This re-bundles both files with esbuild and records the source commit SHA in `assets/bundled/VERSION`.

## Prerequisites

| Dependency | Version |
|------------|---------|
| Flutter SDK | >= 3.13.2 |
| Dart SDK | >= 3.13.2 |
| Node.js | >= 18 |
| Figma Desktop | Latest |

## Getting Started

### Clone & Run (Development)

```bash
git clone https://github.com/<your-username>/figma-local-mcp-gui.git
cd figma-local-mcp-gui/figma_local_mcp_gui

flutter pub get
flutter run -d linux   # or: macos, windows
```

### Build Release Artifacts

```bash
# Linux
flutter build linux --release

# macOS
flutter build macos --release

# Windows
flutter build windows --release
```

The release binaries are located in `build/linux/x64/release/bundle/`, `build/macos/Build/Products/Release/`, or `build/windows/x64/runner/Release/` respectively.

## Platform Support

| Platform | Status |
|----------|--------|
| Linux (Debian-based) | Supported |
| macOS | Supported |
| Windows | Supported |

## Configuration

Settings are persisted via `SharedPreferences` and include:

| Setting | Default | Description |
|---------|---------|-------------|
| `host` | `127.0.0.1` | Bridge server bind address (loopback only) |
| `port` | `3845` | Bridge server HTTP port |
| `password` | *(auto-generated)* | Pairing token for plugin authentication |
| `autoStart` | `false` | Start bridge server on app launch |
| `figmaToken` | *(empty)* | Optional Figma personal access token |
| `mcpServerPath` | *(bundled)* | Custom path to `mcp-server.cjs` |
| `mcpEnabled` | `false` | Start MCP server alongside bridge |

## Security

- The bridge server binds exclusively to loopback addresses (`127.0.0.1`, `localhost`, `::1`)
- Pairing tokens are passed via environment variables, not CLI arguments (not visible in `ps`)
- The Figma plugin validates `Host` headers and rejects redirects
- Bridge snapshots are held in memory only (10 MiB max, single-session)
- `opencode.json` writes use atomic rename with `.bak` backup

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -m 'Add my feature'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Open a Pull Request

## License

MIT License. See [LICENSE](LICENSE) for details.
