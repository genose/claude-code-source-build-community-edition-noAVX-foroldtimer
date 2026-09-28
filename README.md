# Claude Code — Community Edition (no-AVX / old-timer build)

![](<img/2026-03-31 14-58-01-combined.gif>)

Community-maintained build of Claude Code with **Bun replaced by esbuild** — runs on CPUs without AVX/AVX2 (Intel Westmere/Nehalem, AMD pre-Bulldozer, Hyper-V/VirtualBox/KVM VMs, old-timer hardware).

**Current version: v2.1.283-rel.1**

See: [anthropics/claude-code#33153](https://github.com/anthropics/claude-code/issues/33153) · [anthropics/claude-code#55520](https://github.com/anthropics/claude-code/issues/55520)

## What this is (and isn't)

This fork rebuilds Claude Code from source using Node.js + esbuild instead of Bun, so it runs on any x86 CPU regardless of AVX support.

**Honest note on the code base:** The version number tracks upstream so the API gate passes. The underlying application code is frozen at the **v2.1.88 era** — upstream switched to a Bun-compiled binary at v2.1.126, which uses compiled JavaScriptCore bytecode. There is no way to extract TypeScript source from that binary, and npm has never shipped source maps. Upstream fixes from v2.1.126–v2.1.283 are not present in the application logic of this build. What you do get: a working Node.js build that runs on your hardware, with fresh npm dependency packages at build time, plus the memory management and branding overlay on top.

## Install

Downloads a pre-built release and installs the `claudius` command. Requires **Node.js >= 20** only — no git, no build step.

**macOS / Linux:**
```bash
curl -fsSL https://raw.githubusercontent.com/genose/claude-code-source-build-community-edition-noAVX-foroldtimer/master/install.sh | bash
```

**Windows (PowerShell):**
```powershell
irm https://raw.githubusercontent.com/genose/claude-code-source-build-community-edition-noAVX-foroldtimer/master/install.ps1 | iex
```

After install, run `claudius` instead of `claude`.

Default install locations:

| Platform | Install dir | Command |
|----------|-------------|---------|
| macOS | `~/.claudius` | `/usr/local/bin/claudius` (if writable, else `~/.local/bin/claudius`) |
| Linux | `~/.claudius` | `~/.local/bin/claudius` |
| Windows | `%USERPROFILE%\.claudius` | `%USERPROFILE%\.local\bin\claudius.cmd` |

To customize:
```bash
# macOS / Linux
CLAUDIUS_INSTALL_DIR=~/tools/claudius CLAUDIUS_BIN_DIR=~/bin bash install.sh

# Windows
$env:CLAUDIUS_INSTALL_DIR="C:\tools\claudius"; $env:CLAUDIUS_BIN_DIR="C:\tools\bin"; irm ... | iex
```

## Update / Reinstall

Re-run the same install command — it downloads the latest pre-built release and replaces the existing install.

## Prerequisites

- Node.js >= 20

> **To build from source** (developers only): also requires `git` and `npm`.

## Build from source

```bash
# 1. Clone
git clone --branch master \
  https://github.com/genose/claude-code-source-build-community-edition-noAVX-foroldtimer.git
cd claude-code-source-build-community-edition-noAVX-foroldtimer

# 2. Install esbuild and dependencies
npm install

# 3. Build (production, minified)
npm run build
# equivalent: node scripts/build-cli.mjs

# Development build (unminified, faster)
node scripts/build-cli.mjs --no-minify

# Custom output path
node scripts/build-cli.mjs --outfile /path/to/cli.js
```

Output: `dist/cli.js` (entry point) + `dist/cli.bundle/` (bundle directory).

The first build auto-installs ~80 overlay npm packages into `.cache/workspace/`. Subsequent builds skip this step automatically.

> **Note:** The build parses a 57 MB source map (`source/cli.js.map`) once and caches it in memory for the duration of the build. On machines with < 2 GB of free RAM, Node.js may run out of heap. If you see an OOM crash, increase the heap limit:
> ```bash
> NODE_OPTIONS=--max-old-space-size=4096 npm run build
> ```

### Verify

```bash
node dist/cli.js --version
```

## Run

```bash
node dist/cli.js
```

Or use the installed `claudius` command if you ran `install.sh` / `install.ps1`.

## Memory

The `claudius` wrapper automatically limits the Node.js heap to a fair share of available RAM so it stays safe on small machines and doesn't hog resources when multiple instances run simultaneously:

- **Budget:** 25% of available RAM at launch time
- **Per-instance cap:** budget ÷ number of already-running `claudius` processes (so N instances share the budget evenly)
- **Hard cap:** 16384 MB (even if budget would allow more)
- **Floor:** 512 MB (minimum usable heap)
- **Detection fallback:** 2048 MB if RAM detection fails

Example: 4 GB free RAM → 1024 MB budget. One instance gets 1024 MB; if a second launches it gets 512 MB (floor).

**Override** — set before launching:
```bash
CLAUDIUS_MAX_HEAP_MB=4096 claudius
```

Memory pressure warnings are printed to stderr at escalating thresholds:

| Threshold | Message |
|-----------|---------|
| 65% | Warning + `/compact` advice |
| 80% | Stronger warning |
| 90% | Critical — diagnostic report written |
| 95% | Graceful shutdown initiated |

**Session crash log** — every session appends lifecycle events to `~/.claudius/crash-<PID>.log`:

```
[2026-09-28T00:00:00.000Z] [START] pid=24842 heap_limit=4144MB v=2.1.283-rel.1
[2026-09-28T00:00:01.000Z] [MEM_WARN_65] heap 2694MB / 4144MB — consider /compact
[2026-09-28T00:00:02.000Z] [MEM_WARN_80] heap 3320MB / 4144MB
[2026-09-28T00:00:03.000Z] [MEM_WARN_90] heap 3730MB / 4144MB — crash imminent, writing diagnostic report
[2026-09-28T00:00:04.000Z] [EXIT] code=1
```

**Diagnostic report** — if heap reaches 90%, or on any fatal OOM/SIGABRT, a full Node.js diagnostic report is written to `~/.claudius/crash-report-<PID>.json`. It includes JS stack trace, native backtrace, heap statistics, and environment.

A missing `EXIT` entry in the log means the process was killed hard (OOM/SIGKILL) before the exit handler could run — check for a `crash-report-<PID>.json` in that case.

### Computer Use (macOS)

Computer use activates automatically when the `CHICAGO_MCP` feature flag is enabled. Native addons are resolved from `source/native-addons/`. Override paths if needed:

```bash
COMPUTER_USE_SWIFT_NODE_PATH="/path/to/computer-use-swift.node" \
COMPUTER_USE_INPUT_NODE_PATH="/path/to/computer-use-input.node" \
node dist/cli.js
```

## VS Code / IDE extensions

The official Claude Code VS Code and JetBrains extensions internally invoke the `claude` CLI binary — which ships with **Bun**, and Bun requires AVX. On old-timer CPUs the extension will crash on startup.

### Automatic fix (install.sh / install.ps1)

The installer automatically creates a `claude` symlink (macOS/Linux) or `claude.cmd` wrapper (Windows) alongside `claudius` in the same bin directory. VS Code extensions find it with **no configuration change needed**.

- If a real `claude` binary already exists at that path, the installer skips it and prints a notice.

### Manual fix

If you need to point the extension explicitly:

1. Open **Settings** → search for `claude code executable`
2. Set **Claude Code › Executable Path** to:

| Platform | Path |
|----------|------|
| macOS (default) | `/usr/local/bin/claudius` |
| macOS / Linux (fallback) | `~/.local/bin/claudius` |
| Windows | `%USERPROFILE%\.local\bin\claudius.cmd` |

Or in `settings.json`:
```json
{
  "claude.executablePath": "/usr/local/bin/claudius"
}
```

> **Why this works:** `claudius` is the same Claude Code codebase rebuilt with **esbuild instead of Bun** — no AVX instructions, runs on any x86 CPU from Westmere/Nehalem onwards.

## Clean rebuild

```bash
rm -f .cache/workspace/.prepared.json
npm run build
```

## Feature flags

Toggle in `enabledBundleFeatures` inside `scripts/build-cli.mjs`. ~90 flags available — search `feature('` in source.

| Flag | What it does |
|------|-------------|
| `BUILDING_CLAUDE_APPS` | Skill content for building Claude apps |
| `BASH_CLASSIFIER` | Bash command safety classifier |
| `TRANSCRIPT_CLASSIFIER` | Transcript-level auto-mode classifier |
| `CHICAGO_MCP` | Computer use via MCP (screenshot, click, type, etc.) |

## Native addons

Pre-built macOS binaries in `source/native-addons/`:

| File | Purpose |
|------|---------|
| `computer-use-swift.node` | Screen capture, app management |
| `computer-use-input.node` | Mouse/keyboard input |
| `image-processor.node` | Sharp image processing |
| `audio-capture.node` | Audio capture |

## Structure

```
install.sh               — macOS/Linux installer (sets up claudius command)
install.ps1              — Windows installer (sets up claudius command)
scripts/build-cli.mjs    — Build script (source map extraction + esbuild bundling)
scripts/esbuild-runner.mjs — esbuild plugins (CJS/ESM shims, exports fix)
source/cli.js.map         — Original source map (4756 modules, v2.1.88 era)
source/native-addons/     — Pre-built .node binaries (macOS)
source/src/               — Overlay source files (boot screen, version display, etc.)
.cache/workspace/         — Extracted workspace (generated, gitignored)
dist/                     — Build output (generated)
```
