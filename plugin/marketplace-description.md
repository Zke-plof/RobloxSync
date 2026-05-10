# Roblox Sync - Studio Plugin

Sync your Roblox Studio projects with VS Code for a way better scripting experience.

## 🚀 Features

- **Live Sync** - Edit code in VS Code and see changes instantly in Studio
- **Console Streaming** - View Studio output in VS Code terminal  
- **Auto-sync** - Changes sync instantly between VS Code and Studio
- **Project Extraction** - Pull entire games to version-controlled files
- **Auto-Connection** - Automatically connects to sync server
- **Script Scaffolding** - Create new scripts with proper boilerplate

## 📦 Installation

### From Roblox Creator Store
1. Open Roblox Studio
2. Go to **Plugins > Creator Store**
3. Search for "Roblox Sync"
4. Click **Install**

### Manual Installation
1. Download `RobloxSync.rbxm` from [Releases](https://github.com/your-repo/roblox-sync/releases)
2. In Roblox Studio: **Plugins > Install from File**
3. Select the downloaded `.rbxm` file

## 🛠️ Setup

1. **Install VS Code Extension**
   - Get from [VS Code Marketplace](https://marketplace.visualstudio.com/items?itemName=roblox-sync-dev.roblox-sync)
   - Search "Roblox Sync" in VS Code Extensions

2. **Install CLI Server**
   ```bash
   # Windows (PowerShell)
   irm https://raw.githubusercontent.com/your-repo/roblox-sync/master/scripts/install.ps1 | iex
   
   # macOS/Linux  
   curl -fsSL https://raw.githubusercontent.com/your-repo/roblox-sync/master/scripts/install.sh | sh
   ```

3. **Create Project**
   ```bash
   roblox-sync init MyGame
   cd MyGame
   roblox-sync serve
   ```

4. **Connect Studio**
   - Open Roblox Studio
   - Roblox Sync widget appears in Plugins panel
   - Set project path and click "Connect"

## 🎯 Quick Start

1. **Initialize Project**
   ```bash
   roblox-sync init MyAwesomeGame
   cd MyAwesomeGame
   ```

2. **Start Server**
   ```bash
   roblox-sync serve
   ```

3. **Connect Studio**
   - Open Roblox Studio
   - Enable Roblox Sync plugin
   - Set project path to your game folder
   - Click "Connect"

4. **Start Coding!**
   - Open project in VS Code
   - Edit `.luau` files
   - Changes sync automatically to Studio

## 📁 File Structure

The plugin works with these file types:

- **`.server.luau`** - Server scripts (ServerScriptService)
- **`.client.luau`** - Client scripts (StarterPlayerScripts)  
- **`.luau`** - Module scripts (ReplicatedStorage)
- **`.rbxjson`** - Instance data (Workspace, Lighting, etc.)

## 🎮 Plugin Interface

The Roblox Sync widget provides:

- **Connection Status** - Shows server connection state
- **Project Path** - Set your game project folder
- **Connect/Disconnect** - Toggle server connection
- **Extract Game** - Pull Studio instances to files
- **Sync Changes** - Manual sync of all files
- **Console Output** - Live Studio console feed

## 🔧 Configuration

### Project Settings (rbxsync.json)
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

### Studio Settings
- **Auto-connect** - Automatically connect when Studio opens
- **Auto-extract** - Extract game when connecting
- **Console capture** - Capture all print/warn/error output

##  Troubleshooting

### Can't Connect
- Ensure sync server is running (`roblox-sync serve`)
- Check port 44755 is available
- Verify project path is correct
- Check firewall settings

### Changes Not Syncing
- Check file extensions (.luau, .rbxjson)
- Verify project structure matches expected format
- Check console for error messages

### Console Not Working
- Ensure console capture is enabled
- Check server connection status
- Restart Studio if needed

## 📚 Documentation

- [Full Documentation](https://roblox-sync.dev)
- [API Reference](https://roblox-sync.dev/api)  
- [Examples](https://roblox-sync.dev/examples)
- [VS Code Extension](https://marketplace.visualstudio.com/items?itemName=roblox-sync-dev.roblox-sync)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## 📄 License

MIT License - see [LICENSE](https://github.com/your-repo/roblox-sync/blob/main/LICENSE) file for details

## 🔗 Links

- **GitHub**: https://github.com/your-repo/roblox-sync
- **Creator Store**: https://create.roblox.com/store/asset/89280418878393/RobloxSync
- **VS Code Marketplace**: https://marketplace.visualstudio.com/items?itemName=roblox-sync-dev.roblox-sync
- **Website**: https://roblox-sync.dev

## 🎯 Compatibility

- **Roblox Studio**: All recent versions
- **VS Code**: 1.85.0 and higher
- **Operating Systems**: Windows, macOS, Linux
- **Node.js**: 16.0+ for CLI server

---

**Built with ❤️ for the Roblox development community**
