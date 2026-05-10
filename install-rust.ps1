# Install Rust on Windows
Invoke-WebRequest -Uri "https://win.rustup.rs/x86_64" -OutFile "rustup-init.exe"
Start-Process -FilePath ".\rustup-init.exe" -ArgumentList "-y" -Wait
Remove-Item "rustup-init.exe"

# Add Rust to PATH for current session
$env:Path += ";$env:USERPROFILE\.cargo\bin"

# Refresh PATH
$env:Path = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH","User")

Write-Host "Rust installed successfully!" -ForegroundColor Green
