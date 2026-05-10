#!/bin/bash

# Roblox Sync Installation Script for macOS/Linux
# Run with: curl -fsSL https://raw.githubusercontent.com/your-repo/roblox-sync/master/scripts/install.sh | sh

set -e

echo "🚀 Installing Roblox Sync..."

# Check if Rust is installed
if ! command -v rustc &> /dev/null; then
    echo "📦 Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
else
    echo "✅ Rust is already installed: $(rustc --version)"
fi

# Create installation directory
INSTALL_DIR="$HOME/.local/bin"
mkdir -p "$INSTALL_DIR"

# Create temp directory for build
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

echo "📥 Cloning repository..."
git clone https://github.com/your-repo/roblox-sync.git
cd roblox-sync

echo "🔨 Building Roblox Sync..."
cargo build --release

# Copy binary to installation directory
cp "target/release/roblox-sync" "$INSTALL_DIR/roblox-sync"
chmod +x "$INSTALL_DIR/roblox-sync"

# Add to PATH if not already there
SHELL_RC=""
if [[ "$SHELL" == *"zsh"* ]]; then
    SHELL_RC="$HOME/.zshrc"
elif [[ "$SHELL" == *"bash"* ]]; then
    SHELL_RC="$HOME/.bashrc"
else
    SHELL_RC="$HOME/.profile"
fi

if ! grep -q "$INSTALL_DIR" "$SHELL_RC" 2>/dev/null; then
    echo "📝 Adding to PATH in $SHELL_RC"
    echo "export PATH=\"\$PATH:$INSTALL_DIR\"" >> "$SHELL_RC"
    echo "⚠️  Please restart your terminal or run: source $SHELL_RC"
fi

# Create desktop entry on Linux
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    DESKTOP_DIR="$HOME/.local/share/applications"
    mkdir -p "$DESKTOP_DIR"
    
    cat > "$DESKTOP_DIR/roblox-sync.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Roblox Sync
Comment=Roblox Studio synchronization server
Exec=$INSTALL_DIR/roblox-sync
Icon=applications-system
Terminal=true
Categories=Development;
EOF
    
    echo "🖥️  Desktop entry created"
fi

# Cleanup
cd /
rm -rf "$TEMP_DIR"

echo ""
echo "✅ Installation completed successfully!"
echo "🎯 Run 'roblox-sync --help' to get started"
echo "📁 Installation location: $INSTALL_DIR/roblox-sync"

# Test installation
source "$SHELL_RC" 2>/dev/null || true
if command -v roblox-sync &> /dev/null; then
    echo "🧪 Installation test passed!"
else
    echo "⚠️  Please restart your terminal and run: roblox-sync --version"
fi
