# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A macOS tool for running multiple independent Claude Desktop instances with separate configurations, login states, and MCP server settings. Uses APFS clones for instant profile switching with full Cowork/virtiofs compatibility.

## Commands

```bash
# Launch/switch to a profile
./claude_quick.sh [profile_name]

# Interactive menu
./claude_quick.sh

# Management commands
./claude_quick.sh status             # Show active profile and state
./claude_quick.sh sync               # Manually sync working dir to active profile
./claude_quick.sh list               # List all profiles
./claude_quick.sh delete [profile]   # Delete a profile
./claude_quick.sh wrapper [profile]  # Create app wrapper (independent Launchpad icon)
./claude_quick.sh diagnose           # Diagnose issues
./claude_quick.sh fix                # Fix app wrappers (permissions, signing)
./claude_quick.sh restore            # Exit multi-instance mode, restore original config
```

## Architecture

### Profile Switching Mechanism

The tool uses APFS clones (`cp -cR`) instead of symlinks for Cowork compatibility:

1. **On every launch**: rsync current working dir back to active profile (preserving auth tokens and runtime changes), then APFS clone target profile to working directory
2. **State tracking**: `~/.claude-instances/.active-profile` stores the active profile name and timestamp
3. **Working directory**: `~/Library/Application Support/Claude` is a real directory (cloned from profile), not a symlink

### Directory Structure

```
~/.claude-instances/
├── [profile_name]/
│   └── Application Support/Claude/
│       └── claude_desktop_config.json
├── scripts/                    # Auto-generated helper scripts
└── .active-profile             # State file (ACTIVE_PROFILE, ACTIVATED_AT)

/Applications/
├── Claude.app                  # Original app
└── Claude-[profile].app        # App wrappers with custom names
```

### App Wrappers

Each wrapper in `/Applications/Claude-[profile].app` contains:
- `Contents/MacOS/claude-launcher`: Shell script that syncs profiles and launches Claude
- `Contents/Info.plist`: Custom bundle ID (`com.anthropic.claude.[profile]`) and display name
- `Contents/Resources/claude-icon.icns`: Copied from original Claude.app

Wrappers are ad-hoc code signed to prevent Launch Services errors and Rosetta prompts on Apple Silicon.

## Handling Claude Desktop Updates

Claude Desktop uses Squirrel.Mac (via ShipIt) for auto-updates. Updates apply to `/Applications/Claude.app` directly, so all profiles benefit from a single update — no per-profile action needed.

### How updates work with multi-instance

1. Claude downloads the update and stages it in `~/Library/Caches/com.anthropic.claudefordesktop.ShipIt/`
2. ShipIt is launched to install it, but **waits for all Claude processes to fully quit**
3. Once Claude is quit, ShipIt swaps the bundle contents and relaunches `/Applications/Claude.app`
4. The relaunch bypasses the wrapper (goes straight to Claude.app), but this is fine — the working directory still has the APFS clone of the last active profile. The next wrapper launch will sync any changes (including new auth tokens) back to the profile before re-cloning

### Known issue: "Restart to update" often fails

ShipIt requires zero running Claude instances to proceed. The "Restart to update" button frequently fails to fully quit Claude before ShipIt checks. When this happens, ShipIt logs "App Still Running Error" and the update stays pending indefinitely.

**Workaround**: Fully quit Claude (Cmd+Q, or force-quit via Activity Monitor / `pkill Claude`), wait a few seconds for ShipIt to complete, then relaunch through your profile wrapper.

### Diagnostic commands

```bash
# Check for pending updates (ShipIt state)
cat ~/Library/Caches/com.anthropic.claudefordesktop.ShipIt/ShipItState.plist

# Check ShipIt log for errors (recent entries)
tail -30 ~/Library/Caches/com.anthropic.claudefordesktop.ShipIt/ShipIt_stderr.log

# Check for running ShipIt/Claude processes
pgrep -la Claude; pgrep -la ShipIt

# Check current update version (if staged)
ls ~/Library/Caches/com.anthropic.claudefordesktop.ShipIt/update.*/
```

## Development Notes

- The script originally used symlinks but was rewritten to use APFS clones for virtiofs/Cowork compatibility
- **Important**: Always use `/bin/cp` (not `cp`) for APFS clones. Many developers have GNU coreutils installed which shadows macOS's native `cp` and doesn't support the `-c` flag for copy-on-write clones.
- App wrappers must be code-signed after creation/modification to avoid Launch Services errors on Apple Silicon
- **Critical**: Wrapper launcher scripts must always sync the working directory back to the active profile before deleting/re-cloning — even when relaunching the same profile. Claude Desktop writes auth tokens (`oauth:tokenCache` in `config.json`) and other runtime state to the working directory; skipping sync loses this data.
- **After updating existing wrappers**: If wrapper launcher scripts are modified, the wrappers must be re-signed (`codesign --force --deep --sign - /Applications/Claude-[profile].app`) and the existing deployed launchers in `/Applications/` must be updated too (the template in `claude_quick.sh` only affects newly created wrappers).
- Future plans: hard fork into a standalone OSS tool for multi-account Claude Desktop on macOS
