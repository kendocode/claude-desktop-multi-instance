# Claude Desktop Multi-Instance: APFS Clone Implementation

## Problem Summary

Claude Desktop's "Cowork" feature failed with the error:

```
Failed to start Claude's workspace
RPC error: SDK version 2.1.8 not verified at /mnt/.virtiofs-root/shared/Library/Application Support/Claude/claude-code-vm/2.1.8/.verified
```

This occurred when using the `claude_quick.sh` multi-instance profile switcher, which originally used symlinks to point `~/Library/Application Support/Claude` to profile-specific directories.

## Root Cause

Cowork uses Apple's Virtualization Framework with **virtiofs** to share host directories with a Linux VM. When virtiofs mounts `~/Library/Application Support/Claude`, it cannot follow symlinks that point outside the mounted filesystem tree. The VM sees the symlink but cannot traverse to the actual target directory.

## Approaches Considered

### 1. Explicit Cowork Mode (Initially Planned)
- Add `cowork` / `cowork-restore` commands to manually switch between symlink and materialized directory modes
- **Pros**: Fine-grained control, minimal disk usage
- **Cons**: Requires user to remember to switch modes, error-prone

### 2. APFS Clone Approach (Implemented)
- Replace symlinks entirely with APFS clones (`cp -c`)
- Auto-sync changes back to profile on switch
- **Pros**: Always works with Cowork, simpler mental model, instant cloning via copy-on-write
- **Cons**: Changes not immediately reflected in profile store (mitigated by manual sync)

### 3. Hybrid Auto-Detection
- Detect Cowork usage and auto-switch modes
- **Pros**: Automatic
- **Cons**: Complex, fragile, hard to implement reliably

**Decision**: Implemented APFS Clone approach for robustness and simplicity.

## Implementation Details

### Core Mechanism

1. **Profile Switching**:
   ```
   Switch to profile "foo":
     1. rsync current working dir back to previous profile (if any)
     2. rm -rf working directory
     3. cp -cR (APFS clone) from foo's profile dir to working directory
     4. Update state file with active profile
   ```

2. **APFS Clone Benefits**:
   - Near-instant copying (shares disk blocks until modified)
   - Real directory that virtiofs can traverse
   - No symlink resolution issues

3. **State Tracking** (`~/.claude-instances/.active-profile`):
   ```
   ACTIVE_PROFILE=kdc-ken
   ACTIVATED_AT=2025-01-16T20:30:00-08:00
   ```

### Commands

| Command | Description |
|---------|-------------|
| `./claude_quick.sh [profile]` | Switch to profile (syncs previous, clones new) |
| `./claude_quick.sh status` | Show current active profile and status |
| `./claude_quick.sh sync` | Manually sync working dir to active profile |
| `./claude_quick.sh list` | List all available profiles |
| `./claude_quick.sh restore` | Exit multi-instance mode, restore original config |

### Manual Sync Feature

The `sync` command allows preserving current state without switching profiles:

```bash
./claude_quick.sh sync
```

- Can be run while Claude is running (best-effort, some files may be locked)
- Shows what changes will be synced before syncing
- Warns if Claude is running

**Use Case**: After activating Cowork in a profile, run sync to preserve that state before testing other profiles.

### App Wrappers

The launcher script in app wrappers (`/Applications/Claude-*.app`) is updated to:
1. Sync previous profile if switching
2. Clone new profile using APFS
3. Update state file
4. Launch Claude Desktop

## Trade-offs vs Symlinks

| Aspect | Symlinks (old) | APFS Clones (new) |
|--------|---------------|-------------------|
| Cowork compatibility | No | Yes |
| Instant state reflection | Yes | No (requires sync) |
| Profile switching speed | Instant | Near-instant (APFS clone) |
| Disk usage | Minimal | Copy-on-write (efficient) |
| Complexity | Simple | Slightly more complex |

## Future Enhancements

### Periodic Auto-Sync (Potential)

To regain some of the "always up-to-date" benefits of symlinks:

1. **launchd periodic task**: Sync every N minutes when Claude is not running
   ```xml
   <!-- ~/Library/LaunchAgents/com.claude.profile-sync.plist -->
   <key>StartInterval</key>
   <integer>300</integer>  <!-- Every 5 minutes -->
   ```

2. **fswatch file watcher**: Sync on file changes (more responsive but complex)
   ```bash
   fswatch -o "$ORIGINAL_CLAUDE_DIR" | while read; do
       ./claude_quick.sh sync
   done
   ```

3. **Claude quit hook**: Sync automatically when Claude Desktop quits

### Incremental Backups

Could extend to maintain versioned backups:
```
~/.claude-instances/kdc-ken/
  Application Support/Claude/        # Current profile
  .snapshots/
    2025-01-16T20:30:00/             # Timestamped snapshots
    2025-01-16T21:00:00/
```

## Testing Checklist

- [ ] Switch profiles works (syncs old, clones new)
- [ ] Manual sync works while Claude running
- [ ] Status command shows correct active profile
- [ ] App wrappers work with new launcher
- [ ] Cowork feature works after profile activation
- [ ] Cowork state preserved after sync + profile switch + switch back
- [ ] Profile without Cowork unaffected by switching
- [ ] Restore command properly exits multi-instance mode

## Files Modified

- `claude_quick.sh`: Complete rewrite of profile switching logic
- App wrapper launcher scripts: Updated to use APFS clones

## Wrapper Backups

Before recreating wrappers, backups stored at:
```
~/.local/share/claude-desktop-multi-instance/wrapper-backups/
  Claude-braincheck.app/
  Claude-default.app/
  Claude-kdc-ken.app/
```
