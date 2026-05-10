# Roblox Sync

Sync your Roblox Studio projects with VS Code so you can code in a real editor instead of that tiny Studio script editor. Two-way sync, console streaming, and automated workflows included.

## Features

- **Two-way sync** between VS Code and Roblox Studio
- **Real-time updates** - code changes instantly appear in Studio
- **Console streaming** - see Roblox output in VS Code terminal
- **Auto-sync** - file watcher keeps everything in sync automatically
- **File format support** - `.luau` scripts and `.rbxjson` instance files
- **Auto-extraction** - Pull entire games to version-controlled files
- **Script Scaffolding** - Create server/client/module scripts with boilerplate

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ VS Code Extension / CLI                                   │
└──────────────────────────┬──────────────────────────────────┘
                         │ HTTP (localhost:44755)
┌──────────────────────────▼──────────────────────────────────┐
│ Rust Server                                           │
│ • File watching with auto-sync                           │
│ • Chunked extraction handling                             │
│ • Git operations                                          │
│ • Multi-workspace routing                                │
└──────────────────────────┬──────────────────────────────────┘
                         │ HTTP/WebSocket
┌──────────────────────────▼──────────────────────────────────┐
│ Studio Plugin (Luau)                                     │
│ • API dump reflection                                     │
│ • Instance serialization                                  │
│ • Console output capture                                  │
│ • Play test automation                                    │
└─────────────────────────────────────────────────────────────┘
```

## Installation

### 1. Install CLI (Required)

**Windows (PowerShell):**
```powershell
irm https://raw.githubusercontent.com/your-repo/roblox-sync/master/scripts/install.ps1 | iex
```

**macOS/Linux:**
```bash
curl -fsSL https://raw.githubusercontent.com/your-repo/roblox-sync/master/scripts/install.sh | sh
```

**From Source:**
```bash
git clone https://github.com/your-repo/roblox-sync
cd roblox-sync
cargo build --release
```

### 2. Install Studio Plugin

1. Download `RobloxSync.rbxm` from [Releases](https://github.com/your-repo/roblox-sync/releases)
2. Copy to plugins folder:
   - **Windows**: `%LOCALAPPDATA%\Roblox\Plugins\`
   - **macOS**: `~/Documents/Roblox/Plugins/`
3. Restart Roblox Studio

### 3. Install VS Code Extension

Search "Roblox Sync" in the VS Code Marketplace or install from the `.vsix` file.

## Quick Start

1. **Initialize Project:**
   ```bash
   rbxsync init --name MyGame
   cd MyGame
   rbxsync serve
   ```

2. **Connect Studio:**
   - Open Roblox Studio
   - Set project path in the RbxSync widget
   - Click "Connect"

3. **Extract Game:**
   ```bash
   rbxsync extract
   ```

4. **Start Developing:**
   - Edit `.luau` files in VS Code
   - Changes sync automatically to Studio
   - View console output in VS Code terminal

## File Formats

### Script Files (.luau)
```
MyScript.server.luau → Script (runs on server)
MyScript.client.luau → LocalScript (runs on client)  
MyScript.luau → ModuleScript
```

### Instance Files (.rbxjson)
```json
{
  "className": "Part",
  "name": "Baseplate",
  "properties": {
    "Anchored": { "type": "bool", "value": true },
    "Size": { "type": "Vector3", "value": { "x": 512, "y": 20, "z": 512 } },
    "Material": { "type": "Enum", "value": { "enumType": "Material", "value": "Grass" } }
  }
}
```

## CLI Commands

### Core Commands
```bash
rbxsync init --name <project>    # Initialize new project
rbxsync serve                     # Start sync server
rbxsync extract                   # Extract game from Studio
rbxsync sync                      # Sync changes to Studio
rbxsync build                     # Build .rbxl file
```

### Utility Commands
```bash
rbxsync status                    # Show connection status
rbxsync console                   # Stream console output
rbxsync test                      # Run integration tests
rbxsync clean                     # Clean build artifacts
```

## API Endpoints

The Rust server exposes these HTTP endpoints for the VS Code extension and Studio plugin:

- `POST /api/connect` - Register a client (VS Code or Studio)
- `POST /api/disconnect/:id` - Unregister a client
- `POST /api/extract` - Initialize project structure / extract game
- `POST /api/sync` - Push file changes (file_change, file_create, file_delete)
- `POST /api/console` - Send a console message from Studio
- `GET /api/console/stream` - Retrieve buffered console messages
- `GET /api/project` - Get current project info
- `POST /api/project` - Set current project info
- `GET /api/clients` - List connected clients
- `GET /api/health` - Server health check

## VS Code Extension Features

- **Auto-server start** when opening Roblox projects
- **File watching** with instant sync and cooldown throttle
- **Console streaming** in dedicated output channel with auto-poll
- **Sidebar integration** with quick actions
- **Status bar** showing connection status and client count
- **Restart Server** command for quick server restart
- **New Script** command to scaffold server/client/module scripts
- **Auto-reconnect** on connection failure

## Project Structure

```
my-game/
├── rbxsync.json          # Project configuration
├── src/
│   ├── Workspace/        # Workspace instances
│   ├── Lighting/         # Lighting settings
│   ├── ReplicatedFirst/  # Client-first scripts
│   ├── ReplicatedStorage/ # Shared modules
│   ├── ServerScriptService/ # Server scripts
│   ├── ServerStorage/    # Server-only data
│   ├── StarterPlayer/    # Player scripts
│   ├── StarterGui/       # UI elements
│   └── Teams/           # Team configurations
└── out/                  # Built .rbxl files
```

## Configuration

### rbxsync.json
```json
{
  "name": "MyGame",
  "tree": {
    "$className": "DataModel"
  },
  "metadata": {
    "syncPort": 44755,
    "autoSync": true,
    "consoleBuffer": 1000
  }
}
```

### VS Code Settings
```json
{
  "robloxSync.autoStart": true,
  "robloxSync.serverPort": 44755,
  "robloxSync.consoleLines": 100
}
```

## Troubleshooting

### Server won't start
- Check if port 44755 is available
- Verify Rust installation
- Run `rbxsync --version` to confirm installation

### Plugin not connecting  
- Ensure Studio plugin is installed
- Check firewall settings
- Verify server is running on localhost:44755

### Changes not syncing
- Check file extensions (.luau, .rbxjson)
- Verify project path in Studio plugin
- Check console for error messages

### Build fails with property errors
- Review .rbxjson file syntax
- Check for unsupported property types
- Validate property values

## Development

### Building from Source
```bash
git clone https://github.com/your-repo/roblox-sync
cd roblox-sync
cargo build --release
```

### Running Tests
```bash
cargo test
```

### Building VS Code Extension
```bash
cd vscode-extension
npm install
npm run compile
vsce package
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

MIT License - see LICENSE file for details.

## Support

- **GitHub Issues**: [Report bugs](https://github.com/your-repo/roblox-sync/issues)
- **Discord**: [Community support](https://discord.gg/roblox-sync)
- **Documentation**: [Full docs](https://roblox-sync.dev)

---

**Built with ❤️ for the Roblox development community**
