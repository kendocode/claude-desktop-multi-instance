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

1. **On profile switch**: rsync current working dir back to previous profile, then APFS clone new profile to working directory
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

## Development Notes

- The script originally used symlinks but was rewritten to use APFS clones for virtiofs/Cowork compatibility
- **Important**: Always use `/bin/cp` (not `cp`) for APFS clones. Many developers have GNU coreutils installed which shadows macOS's native `cp` and doesn't support the `-c` flag for copy-on-write clones.
- App wrappers must be code-signed after creation/modification to avoid Launch Services errors on Apple Silicon
