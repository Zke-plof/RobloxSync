# Roblox Sync Installation Script for Windows
# Run this in PowerShell as Administrator

Write-Host "Installing Roblox Sync..." -ForegroundColor Green

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "Please run this script as Administrator"
    exit 1
}

# Install Rust if not present
try {
    $rustc = Get-Command rustc -ErrorAction Stop
    Write-Host "Rust is already installed: $($rustc.Version)" -ForegroundColor Green
} catch {
    Write-Host "Installing Rust..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri "https://win.rustup.rs/x86_64" -OutFile "rustup-init.exe"
    Start-Process -FilePath ".\rustup-init.exe" -ArgumentList "-y" -Wait
    Remove-Item "rustup-init.exe"
    $env:Path += ";$env:USERPROFILE\.cargo\bin"
}

# Create installation directory
$installDir = "$env:LOCALAPPDATA\RobloxSync"
New-Item -ItemType Directory -Force -Path $installDir | Out-Null

# Download or build roblox-sync
if (Test-Path "$installDir\roblox-sync.exe") {
    Write-Host "Removing existing installation..." -ForegroundColor Yellow
    Remove-Item "$installDir\roblox-sync.exe"
}

Write-Host "Building Roblox Sync from source..." -ForegroundColor Yellow
Set-Location $installDir

# Clone repository
if (Test-Path "$installDir\roblox-sync") {
    Remove-Item -Recurse -Force "$installDir\roblox-sync"
}

git clone https://github.com/your-repo/roblox-sync.git
Set-Location "$installDir\roblox-sync"

# Build the project
& "$env:USERPROFILE\.cargo\bin\cargo.exe" build --release

# Copy binary to installation directory
Copy-Item "target\release\roblox-sync.exe" "$installDir\roblox-sync.exe"

# Add to PATH
$currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($currentPath -notlike "*$installDir*") {
    [Environment]::SetEnvironmentVariable("PATH", $currentPath + ";$installDir", "User")
    Write-Host "Added to PATH. Please restart your terminal." -ForegroundColor Green
}

# Create desktop shortcut
$desktopPath = [Environment]::GetFolderPath("Desktop")
$shortcutPath = "$desktopPath\Roblox Sync.lnk"
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = "$installDir\roblox-sync.exe"
$shortcut.WorkingDirectory = $installDir
$shortcut.Description = "Roblox Sync Server"
$shortcut.Save()

Write-Host "Installation completed successfully!" -ForegroundColor Green
Write-Host "Run 'roblox-sync --help' to get started" -ForegroundColor Cyan
Write-Host "Desktop shortcut created: $shortcutPath" -ForegroundColor Cyan
