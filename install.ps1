# Claudius installer for Windows (PowerShell)
# Usage: irm https://raw.githubusercontent.com/genose/claude-code-source-build-community-edition-noAVX-foroldtimer/noavx_esbuild/install.ps1 | iex

$ErrorActionPreference = 'Stop'

$REPO_API   = "https://api.github.com/repos/genose/claude-code-source-build-community-edition-noAVX-foroldtimer"
$InstallDir = if ($env:CLAUDIUS_INSTALL_DIR) { $env:CLAUDIUS_INSTALL_DIR } else { "$HOME\.claudius" }
$BinDir     = if ($env:CLAUDIUS_BIN_DIR)     { $env:CLAUDIUS_BIN_DIR }     else { "$HOME\.local\bin" }
$CMD        = "claudius"

Write-Host "==> Installing Claudius (Claude Code - Community Edition no-AVX)"
Write-Host "    Install dir : $InstallDir"
Write-Host "    Command     : $BinDir\$CMD.cmd"
Write-Host ""

# Check Node.js
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Error "Node.js >= 20 is required but not found. Install from https://nodejs.org"
    exit 1
}
$nodeMajor = [int](node -e "process.stdout.write(String(process.versions.node.split('.')[0]))")
if ($nodeMajor -lt 20) {
    Write-Error "Node.js >= 20 required (found $(node --version))."
    exit 1
}

# Fetch latest release
Write-Host "==> Fetching latest release..."
$release  = Invoke-RestMethod "$REPO_API/releases/latest"
$asset    = $release.assets | Where-Object { $_.name -like "*dist.tar.gz" } | Select-Object -First 1

if (-not $asset) {
    Write-Error "Could not find dist tarball in latest release."
    exit 1
}

Write-Host "    Release     : $($release.tag_name)"
Write-Host ""

# Download and extract
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
$TmpTar = [System.IO.Path]::GetTempFileName() + ".tar.gz"

Write-Host "==> Downloading pre-built dist..."
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $TmpTar

Write-Host "==> Extracting..."
if (Test-Path "$InstallDir\dist") { Remove-Item -Recurse -Force "$InstallDir\dist" }
tar -xzf $TmpTar -C $InstallDir
Remove-Item -Force $TmpTar

# Install wrapper
New-Item -ItemType Directory -Force -Path $BinDir | Out-Null
$wrapper = "$BinDir\$CMD.cmd"
Set-Content -Path $wrapper -Value "@echo off`r`nnode `"$InstallDir\dist\cli.js`" %*"

# Create claude.cmd -> claudius so VS Code / JetBrains extensions work without config changes.
$claudeWrapper = "$BinDir\claude.cmd"
$ourContent = "@echo off`r`nnode `"$InstallDir\dist\cli.js`" %*"
if (-not (Test-Path $claudeWrapper) -or (Get-Content $claudeWrapper -Raw) -eq $ourContent) {
    Set-Content -Path $claudeWrapper -Value $ourContent
    Write-Host "    Also created: $claudeWrapper (claude -> claudius)"
} else {
    Write-Host "    NOTE: $claudeWrapper already exists with different content — skipping."
    Write-Host "          VS Code extensions may use the official claude binary on that path."
}

Write-Host ""
Write-Host "==> Done! Run: $CMD  (or: claude)"
Write-Host ""

# PATH hint
$userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($userPath -notlike "*$BinDir*") {
    Write-Host "    NOTE: Add $BinDir to your PATH:"
    Write-Host "      [Environment]::SetEnvironmentVariable('PATH', `$env:PATH + ';$BinDir', 'User')"
    Write-Host "    Or run the above in PowerShell to set it permanently."
    Write-Host ""
}

# Verify
Write-Host "==> Verifying..."
try {
    & "$BinDir\$CMD.cmd" --version
    Write-Host ""
    Write-Host "    claudius is ready."
} catch {
    Write-Warning "Could not verify claudius. Check that $BinDir is in your PATH."
}
