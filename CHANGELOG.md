# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Fixed
- **APFS clone compatibility with GNU coreutils**: Changed `cp -cR` to `/bin/cp -cR` throughout the script and embedded launcher. Systems with GNU coreutils installed (common for developers coming from Linux) would shadow macOS's native `cp`, causing APFS clones to fail silently and fall back to slow full copies. Now explicitly calls macOS's `/bin/cp` which supports the `-c` flag for copy-on-write clones.

- **Cowork/virtiofs compatibility**: Fixed issue where working directory was created as a symlink instead of an APFS clone. Virtiofs (used by Cowork's VM) cannot traverse symlinks pointing outside the mounted directory tree, causing "SDK version not verified" errors. The working directory (`~/Library/Application Support/Claude`) is now always a real directory cloned from the profile.

- **Profile switching with Claude running**: App wrappers now automatically quit Claude Desktop before switching profiles. Previously, switching profiles while Claude was running could leave the app in an inconsistent state or fail silently.

- **Launcher script cleanup**: Added explicit `exit 0` at the end of app wrapper launcher scripts to ensure the shell process terminates after launching Claude.

### Changed
- App wrappers are now re-signed after any modification to prevent Launch Services errors and Rosetta prompts on Apple Silicon.

## [1.0.0] - 2024-12-01

### Added
- Initial APFS clone implementation replacing symlinks for Cowork compatibility
- Profile state tracking via `~/.claude-instances/.active-profile`
- `status` command to show active profile and state
- `sync` command for manual sync of working directory to active profile
- Auto-sync on profile switch (syncs previous profile before cloning new one)

### Architecture
- Profiles stored in `~/.claude-instances/[profile_name]/`
- Working directory `~/Library/Application Support/Claude` is an APFS clone (not symlink)
- App wrappers in `/Applications/Claude-[profile].app` with custom bundle IDs and display names

---

## Future Improvements

### Smarter Sync Strategy
Current approach copies entire profile on switch. As Claude Desktop grows (Cowork VM alone is ~2GB), this becomes slower. Potential improvements:
- **Incremental sync**: Only sync changed files using rsync checksums
- **Persistent clone with selective sync**: Keep APFS clone persistent, only sync config files and critical state on switch
- **Background sync**: Sync in background while Claude is running (with file locking awareness)
- **Exclude large static files**: VM bundles and SDK binaries rarely change between profiles; could share them or exclude from per-profile storage

### Spotlight/Alfred Integration
- Apps may not appear in Spotlight/Alfred immediately after creation
- Need to investigate `mdimport` timing or alternative registration methods
- Consider adding a post-creation step to force Spotlight indexing
