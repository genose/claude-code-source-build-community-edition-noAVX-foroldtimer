#!/usr/bin/env bash
set -e

REPO_API="https://api.github.com/repos/genose/claude-code-source-build-community-edition-noAVX-foroldtimer"
INSTALL_DIR="${CLAUDIUS_INSTALL_DIR:-$HOME/.claudius}"
CMD="claudius"

# Default bin dir: ~/.local/bin on Linux, /usr/local/bin on macOS (fallback to ~/.local/bin)
if [ -z "$CLAUDIUS_BIN_DIR" ]; then
  if [ "$(uname)" = "Darwin" ] && [ -w "/usr/local/bin" ]; then
    BIN_DIR="/usr/local/bin"
  else
    BIN_DIR="$HOME/.local/bin"
  fi
else
  BIN_DIR="$CLAUDIUS_BIN_DIR"
fi

echo "==> Installing Claudius (Claude Code — Community Edition no-AVX)"
echo "    Platform    : $(uname -s) $(uname -m)"
echo "    Install dir : $INSTALL_DIR"
echo "    Command     : $BIN_DIR/$CMD"
echo ""

# Check Node.js
if ! command -v node &>/dev/null; then
  echo "Error: Node.js >= 20 is required but not found." >&2
  echo "       Install from https://nodejs.org or via your package manager." >&2
  exit 1
fi
NODE_MAJOR=$(node -e "process.stdout.write(String(process.versions.node.split('.')[0]))")
if [ "$NODE_MAJOR" -lt 20 ]; then
  echo "Error: Node.js >= 20 required (found $(node --version))." >&2
  exit 1
fi

# Fetch latest release asset URL
echo "==> Fetching latest release..."
ASSET_URL=$(curl -fsSL "$REPO_API/releases/latest" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for a in data.get('assets', []):
    if a['name'].endswith('dist.tar.gz'):
        print(a['browser_download_url'])
        break
")

if [ -z "$ASSET_URL" ]; then
  echo "Error: could not find dist tarball in latest release." >&2
  exit 1
fi

TAG=$(curl -fsSL "$REPO_API/releases/latest" | python3 -c "import json,sys; print(json.load(sys.stdin)['tag_name'])" 2>/dev/null || echo "unknown")
echo "    Release     : $TAG"
echo ""

# Download and extract
mkdir -p "$INSTALL_DIR"
TMP_TAR=$(mktemp /tmp/claudius-dist.XXXXXX.tar.gz)
echo "==> Downloading pre-built dist..."
curl -fsSL --progress-bar -o "$TMP_TAR" "$ASSET_URL"
echo "==> Extracting..."
rm -rf "$INSTALL_DIR/dist"
tar -xzf "$TMP_TAR" -C "$INSTALL_DIR"
rm -f "$TMP_TAR"

# Install wrapper
mkdir -p "$BIN_DIR"
cat > "$BIN_DIR/$CMD" <<WRAPPER
#!/usr/bin/env bash
exec node --max-old-space-size=8192 "$INSTALL_DIR/dist/cli.js" "\$@"
WRAPPER
chmod +x "$BIN_DIR/$CMD"

# Symlink 'claude' -> 'claudius' so VS Code / JetBrains extensions work without config changes.
if [ ! -e "$BIN_DIR/claude" ] || [ -L "$BIN_DIR/claude" ]; then
  ln -sf "$CMD" "$BIN_DIR/claude"
  echo "    Symlinked   : $BIN_DIR/claude -> $CMD"
else
  echo "    NOTE: $BIN_DIR/claude already exists and is not a symlink — skipping."
  echo "          VS Code extensions may use the official claude binary on that path."
fi

echo ""
echo "==> Done! Run: $CMD  (or: claude)"
echo ""

# PATH hint
if ! echo "$PATH" | grep -q "$BIN_DIR"; then
  echo "    NOTE: Add $BIN_DIR to your PATH:"
  echo "      export PATH=\"\$PATH:$BIN_DIR\""
  echo "    Add this line to your ~/.bashrc or ~/.zshrc"
  echo ""
fi

# Verify
echo "==> Verifying..."
if "$BIN_DIR/$CMD" --version 2>/dev/null; then
  echo ""
  echo "    claudius is ready."
else
  echo "    Warning: could not verify claudius. Check that $BIN_DIR is in your PATH." >&2
fi
