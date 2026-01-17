# Claude Profile Manager: Go CLI Implementation Plan

## Overview

A cross-platform CLI tool written in Go to manage multiple Claude Desktop profiles, replacing the current bash script with a more robust, extensible solution.

## Goals

1. **Feature parity** with current shell script
2. **Cross-platform** support (macOS, Windows, Linux)
3. **Extensible** for background sync, file watching, periodic operations
4. **Non-disruptive** - intelligent about Claude's running state
5. **CLI-first** - usable standalone, from Alfred/Raycast, or as backend for GUI

---

## Platform Analysis

### macOS
- **Config path**: `~/Library/Application Support/Claude/`
- **App location**: `/Applications/Claude.app`
- **Process name**: `Claude`
- **Copy optimization**: APFS clonefile (`clonefile()` syscall or `cp -c`)
- **File watching**: FSEvents (native) or fsnotify (Go library)
- **Notes**: Best supported, APFS clones provide instant copy-on-write

### Windows
- **Config path**: `%APPDATA%\Claude\` (likely, needs verification)
  - Alternative: `%LOCALAPPDATA%\Claude\`
- **App location**: `%LOCALAPPDATA%\Programs\Claude\` or `%ProgramFiles%\Claude\`
- **Process name**: `Claude.exe`
- **Copy optimization**:
  - ReFS supports block cloning (rare on consumer systems)
  - Dev Drive with CoW support (Windows 11)
  - Fallback: robocopy for efficient copying
- **File watching**: ReadDirectoryChangesW (via fsnotify)
- **Notes**: Need to verify exact paths; no universal CoW support

### Linux
- **Config path**: `~/.config/Claude/` (XDG_CONFIG_HOME)
  - Alternative: `~/.local/share/Claude/` (XDG_DATA_HOME)
- **App location**: `/opt/Claude/`, `~/.local/share/applications/`, AppImage, or Snap
- **Process name**: `claude` or `Claude`
- **Copy optimization**:
  - Btrfs: `cp --reflink=auto` (instant CoW clones)
  - XFS: reflink support (v4.9+)
  - ZFS: block cloning (OpenZFS 2.2+)
  - ext4: No CoW, fallback to regular copy
- **File watching**: inotify (via fsnotify)
- **Notes**: CoW depends on filesystem; detect and use when available

### Path Discovery Strategy

```go
type Platform interface {
    ConfigDir() string           // Claude's config directory
    ProfilesDir() string         // Where we store profiles
    StateFile() string           // Active profile tracking
    AppPath() string             // Claude application path
    ProcessName() string         // Process name for detection
    SupportsCoW() bool           // Can use copy-on-write
    Clone(src, dst string) error // Platform-optimized copy
}
```

---

## Architecture

### Project Structure

```
claude-profile-manager/
├── cmd/
│   └── cpm/
│       └── main.go              # Entry point
├── internal/
│   ├── cli/
│   │   ├── root.go              # Root command (Cobra)
│   │   ├── switch.go            # Switch profile
│   │   ├── list.go              # List profiles
│   │   ├── status.go            # Show status
│   │   ├── sync.go              # Manual sync
│   │   ├── create.go            # Create profile
│   │   ├── delete.go            # Delete profile
│   │   ├── restore.go           # Restore original config
│   │   └── daemon.go            # Background sync daemon
│   ├── platform/
│   │   ├── platform.go          # Platform interface
│   │   ├── darwin.go            # macOS implementation
│   │   ├── windows.go           # Windows implementation
│   │   └── linux.go             # Linux implementation
│   ├── profile/
│   │   ├── manager.go           # Profile management logic
│   │   ├── sync.go              # Sync operations
│   │   └── state.go             # State file management
│   ├── process/
│   │   ├── detect.go            # Claude process detection
│   │   └── watch.go             # Process lifecycle watching
│   └── config/
│       └── config.go            # User configuration
├── go.mod
├── go.sum
└── README.md
```

### Key Dependencies

```go
require (
    github.com/spf13/cobra v1.8.0      // CLI framework
    github.com/spf13/viper v1.18.0     // Configuration
    github.com/fsnotify/fsnotify v1.7.0 // File watching
    github.com/shirou/gopsutil/v3      // Process detection
    github.com/rs/zerolog v1.31.0      // Structured logging
)
```

---

## Core Features (Phase 1: Parity)

### Commands

| Command | Description |
|---------|-------------|
| `cpm switch <profile>` | Switch to profile (sync + clone) |
| `cpm list` | List all profiles |
| `cpm status` | Show active profile and state |
| `cpm sync` | Manually sync to active profile |
| `cpm create <profile>` | Create new profile |
| `cpm delete <profile>` | Delete profile |
| `cpm restore` | Restore original config, exit multi-profile mode |
| `cpm wrapper <profile>` | (macOS) Create app wrapper |

### Profile Switch Flow

```
cpm switch work
  │
  ├─► Check if Claude is running
  │     └─► Warn if running, prompt to continue or abort
  │
  ├─► Sync current working dir → previous profile
  │     └─► rsync -a --delete (or platform equivalent)
  │
  ├─► Remove working directory
  │
  ├─► Clone new profile → working directory
  │     ├─► macOS: clonefile() syscall
  │     ├─► Linux/Btrfs: cp --reflink=auto
  │     └─► Fallback: recursive copy
  │
  ├─► Update state file
  │
  └─► (Optional) Launch Claude
```

### State File Format

```json
{
  "active_profile": "work",
  "activated_at": "2025-01-16T20:30:00-08:00",
  "last_sync": "2025-01-16T21:15:00-08:00",
  "claude_running_at_switch": false
}
```

---

## Extended Features (Phase 2: Background Sync)

### Daemon Mode

```bash
cpm daemon start    # Start background sync daemon
cpm daemon stop     # Stop daemon
cpm daemon status   # Check daemon status
```

### Sync Strategies

1. **Periodic sync**: Every N minutes (configurable, default 5)
2. **On-idle sync**: When Claude CPU usage drops below threshold
3. **On-quit sync**: Detect Claude exit, sync immediately
4. **File-watch sync**: Sync on significant file changes (debounced)

### Intelligent Non-Disruption

```go
type SyncStrategy interface {
    ShouldSync() bool
    WaitForSafeWindow() <-chan struct{}
}

// Factors to consider:
// - Is Claude running?
// - Is Claude actively using CPU? (writing files)
// - How long since last sync?
// - Are there actually changes to sync?
```

### Process Monitoring

```go
func WatchClaudeProcess(ctx context.Context) <-chan ProcessEvent {
    // Emit events:
    // - ProcessStarted
    // - ProcessStopped
    // - ProcessIdle (CPU < threshold for N seconds)
    // - ProcessBusy
}
```

### Configuration File

Location: `~/.config/cpm/config.yaml` (or platform equivalent)

```yaml
sync:
  strategy: periodic  # periodic, on-idle, on-quit, manual
  interval: 5m        # for periodic
  idle_threshold: 5%  # CPU % for on-idle
  idle_duration: 10s  # How long idle before sync

daemon:
  enabled: false
  log_file: ~/.local/share/cpm/daemon.log

profiles:
  directory: ~/.claude-profiles  # Override default location

ui:
  color: true
  verbose: false
```

---

## Platform-Specific Implementation Notes

### macOS: APFS Clonefile

```go
// +build darwin

import "golang.org/x/sys/unix"

func (d *Darwin) Clone(src, dst string) error {
    // Use clonefile syscall for instant CoW copy
    err := unix.Clonefile(src, dst, unix.CLONE_NOFOLLOW)
    if err != nil {
        // Fallback to regular copy if clonefile fails
        return copyRecursive(src, dst)
    }
    return nil
}
```

### Linux: Reflink Detection

```go
// +build linux

func (l *Linux) SupportsCoW() bool {
    // Check if profiles directory is on Btrfs/XFS/ZFS
    var stat unix.Statfs_t
    unix.Statfs(l.ProfilesDir(), &stat)

    switch stat.Type {
    case 0x9123683E: // Btrfs
        return true
    case 0x58465342: // XFS (check version for reflink)
        return l.checkXFSReflink()
    case 0x2FC12FC1: // ZFS
        return l.checkZFSVersion() // 2.2+ supports block cloning
    default:
        return false
    }
}

func (l *Linux) Clone(src, dst string) error {
    if l.SupportsCoW() {
        // Use cp --reflink=auto
        return exec.Command("cp", "-a", "--reflink=auto", src, dst).Run()
    }
    return copyRecursive(src, dst)
}
```

### Windows: Robocopy Fallback

```go
// +build windows

func (w *Windows) Clone(src, dst string) error {
    // Check for ReFS/Dev Drive CoW support (rare)
    if w.SupportsCoW() {
        return w.blockClone(src, dst)
    }

    // Fallback to robocopy for efficient mirroring
    return exec.Command("robocopy", src, dst, "/MIR", "/NFL", "/NDL").Run()
}
```

---

## Testing Strategy

### Unit Tests
- Profile manager logic
- State file operations
- Platform detection

### Integration Tests
- Full switch cycle
- Sync operations
- Process detection

### Platform-Specific Tests
- APFS clone verification (macOS)
- Reflink verification (Linux/Btrfs)
- Path resolution (all platforms)

### Test Fixtures
- Sample Claude config directories
- Mock process detection

---

## Build & Distribution

### Build Matrix

```yaml
# .goreleaser.yml
builds:
  - id: cpm
    binary: cpm
    goos:
      - darwin
      - linux
      - windows
    goarch:
      - amd64
      - arm64
```

### Distribution Channels

- **GitHub Releases**: Pre-built binaries
- **Homebrew**: `brew install kendocode/tap/cpm` (macOS/Linux)
- **Scoop**: Windows package manager
- **Go install**: `go install github.com/kendocode/claude-profile-manager/cmd/cpm@latest`

---

## Implementation Phases

### Phase 1: Feature Parity (MVP)
- [ ] Project setup with Cobra CLI
- [ ] Platform abstraction layer
- [ ] macOS implementation (APFS clones)
- [ ] Core commands: switch, list, status, sync, create, delete
- [ ] State management
- [ ] Process detection (is Claude running?)

### Phase 2: Cross-Platform
- [ ] Linux implementation (reflink detection)
- [ ] Windows implementation (path discovery, robocopy)
- [ ] Platform-specific testing
- [ ] CI/CD for multi-platform builds

### Phase 3: Background Sync
- [ ] Daemon mode infrastructure
- [ ] Periodic sync strategy
- [ ] Process lifecycle watching
- [ ] On-quit sync detection
- [ ] Configuration file support

### Phase 4: Polish
- [ ] Comprehensive error handling
- [ ] Progress indicators for long operations
- [ ] Shell completions (bash, zsh, fish, powershell)
- [ ] Man pages / documentation
- [ ] Homebrew formula

---

## Open Questions

1. **Windows/Linux Claude paths**: Need to verify exact config locations on these platforms. May require community testing.

2. **Windows CoW**: Is ReFS/Dev Drive common enough to optimize for? Probably just use robocopy fallback initially.

3. **Linux AppImage/Snap**: How do sandboxed Claude installations affect config paths?

4. **Daemon lifecycle**: Should daemon be a system service (launchd/systemd) or user-space process?

5. **Sync conflict resolution**: What if Claude writes while we're syncing? Need atomic swap or lock file?

---

## References

- [Cobra CLI Framework](https://github.com/spf13/cobra)
- [fsnotify - Cross-platform file watching](https://github.com/fsnotify/fsnotify)
- [gopsutil - Process utilities](https://github.com/shirou/gopsutil)
- [APFS clonefile](https://developer.apple.com/documentation/foundation/filemanager/2293212-copyitem)
- [Btrfs reflinks](https://btrfs.readthedocs.io/en/latest/Reflink.html)
- [GoReleaser](https://goreleaser.com/)
