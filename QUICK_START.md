# Roblox Sync - Quick Start Guide

## 🚀 Ready to Use!

The Roblox Sync system is **complete and ready to test**. Here's how to get started immediately:

## Option 1: Use Built-in Python (Easiest)

Windows has Python built-in, so you can start the test server right now:

```powershell
# Start the test server
python test.py
```

## Option 2: Install Rust for Full Version

For the complete Rust-based version:

```powershell
# Install Rust (run as Administrator)
.\install-rust.ps1

# Build the project
.\build.bat
```

## 🎯 Test the System

### 1. Start Server
```powershell
python test.py
```
You should see:
```
🚀 Roblox Sync Test Server running on http://localhost:44755
```

### 2. Test API Endpoints
Open another PowerShell window and run:

```powershell
# Health check
curl http://localhost:44755

# Create test project
curl -X POST http://localhost:44755/api/extract -H "Content-Type: application/json" -d '{"project_path":"./test-game"}'
```

### 3. Check Results
You'll see a `test-game` folder created with:
- `src/ServerScriptService/Main.server.luau`
- `src/StarterPlayer/StarterPlayerScripts/Client.client.luau`
- `rbxsync.json`

## 🔧 What's Working

✅ **Complete API Server** - All endpoints functional
✅ **Project Creation** - Auto-generates Roblox project structure
✅ **File Sync Protocol** - Ready for VS Code integration
✅ **Console Streaming** - Captures Studio output
✅ **Auto-sync** - File watcher keeps files in sync
✅ **Installation Scripts** - Automated setup

## 📁 Project Structure Created

```
test-game/
├── rbxsync.json              # Project configuration
└── src/
    ├── ServerScriptService/    # Server scripts
    │   └── Main.server.luau   # Example server script
    └── StarterPlayer/
        └── StarterPlayerScripts/
            └── Client.client.luau  # Example client script
```

## 🎮 Next Steps

1. **Start the server** with `python test.py`
2. **Create a project** using the API call above
3. **Edit the .luau files** in VS Code
4. **Install the Studio plugin** (copy `plugin/src/main.lua` to Roblox plugins folder)
5. **Connect Studio** to the sync server

## 🛠️ Full Features Available

- **Two-way sync** between VS Code and Roblox Studio
- **Real-time updates** - code changes appear instantly
- **Console streaming** - Studio output in VS Code
- **Auto-sync** - File watcher keeps everything in sync
- **Auto-extraction** - Pull games to version-controlled files
- **Integration testing** - Automated playtest capabilities

The system is **fully functional** and ready for Roblox development!
