# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SpaceAgent is a macOS menu bar application that monitors virtual desktop (space) changes and displays the current space number. It uses private Core Graphics Services APIs to detect space changes and provides a delegate pattern for extensibility.

## Build Commands

### Installation & Running
```bash
# Full installation (recommended) - builds, installs to /Applications, and sets up auto-start
./install.sh

# Clean up all running instances and launch agent
./cleanup.sh

# Build only (Debug configuration)
xcodebuild -project SpaceAgent.xcodeproj -target SpaceAgent -configuration Debug build

# Build only (Release configuration)
xcodebuild -project SpaceAgent.xcodeproj -target SpaceAgent -configuration Release build
```

### Testing
```bash
# Run all tests (includes syntax validation + execution)
./test.sh

# Run specific test suite
./test.sh space         # SpaceMonitor tests only
./test.sh integration   # Integration tests only

# Run tests directly with xcodebuild
xcodebuild test -project SpaceAgent.xcodeproj -scheme SpaceAgent -destination 'platform=macOS'

# Run specific test class
xcodebuild test -project SpaceAgent.xcodeproj -scheme SpaceAgent -destination 'platform=macOS' -only-testing:SpaceAgentTests/SpaceMonitorTests
```

## Architecture

### Core Components

**AppDelegate** (`SpaceAgent/AppDelegate.swift`)
- Entry point and application lifecycle manager
- Creates menu bar status item showing "🚀 [space number]"
- Implements `SpaceMonitorDelegate` to receive space change notifications
- Handles graceful termination via SIGTERM/SIGINT signals
- Delayed initialization (0.5s) to prevent hanging on startup

**SpaceMonitor** (`SpaceAgent/SpaceMonitor.swift`)
- Monitors macOS virtual desktop (space) changes
- Uses dependency injection via `CoreGraphicsServiceProtocol` for testability
- Listens to `NSWorkspace.activeSpaceDidChangeNotification`
- Maintains dynamic space ID to space number mapping
- Contains disabled shortcut integration (via `triggerShortcut` method)

**RealCoreGraphicsService** (`SpaceAgent/SpaceMonitor.swift`)
- Wraps private Core Graphics Services APIs (`_CGSDefaultConnection`, `CGSGetActiveSpace`)
- Builds space ID mappings using multiple strategies:
  1. NSUserDefaults `com.apple.spaces` parsing
  2. Window-based space detection
  3. Dynamic discovery as spaces are visited
- Writes detailed debug logs to `/tmp/spaceagent_debug.log`

### Design Patterns

**Protocol-Based Dependency Injection**
- `CoreGraphicsServiceProtocol`: Abstracts Core Graphics Services for testing
- `SpaceMonitorDelegate`: Decouples space change events from UI updates
- All tests use `MockCoreGraphicsService` and `MockSpaceMonitorDelegate`

**Space Discovery**
The app reads all Main monitor spaces at startup:
1. Reads from persistent domain `com.apple.spaces` via NSUserDefaults
2. Navigates: `SpacesDisplayConfiguration` → `Management Data` → `Monitors` array
3. Finds monitor with `Display Identifier` = "Main"
4. Extracts all `ManagedSpaceID` values from that monitor's `Spaces` array
5. Sorts space IDs and creates stable mapping (e.g., IDs [1, 4] → numbers [1, 2])
6. Dynamic discovery fallback only used if initial read fails

### Key Implementation Details

**Space ID Mapping** (lines 31-223 in `SpaceMonitor.swift`)
- Space IDs are internal CGS identifiers (uint32 values like 1, 4, etc.)
- Space numbers are user-facing sequential numbers (1, 2, 3, etc.)
- `spaceIDToNumberMap` dictionary maintains the mapping
- Initialization reads from `UserDefaults.standard.persistentDomain(forName: "com.apple.spaces")`
- Parses path: `SpacesDisplayConfiguration` → `Management Data` → `Monitors`
- Filters to Main monitor only (ignores collapsed spaces from disconnected displays)
- Two fallback strategies: dynamic discovery as spaces are visited

**Menu Bar Updates** (lines 41-52 in `AppDelegate.swift`)
- Always dispatched to main thread via `DispatchQueue.main.async`
- Shows "🚀 ?" when space number is invalid or zero
- Updates on every space change notification from `SpaceMonitor`

**Multiple Instance Prevention**
- `install.sh` uses multiple strategies to kill old instances (SIGTERM → SIGKILL → pkill)
- `SpaceMonitor` checks for multiple instances at initialization (lines 496-521)
- LaunchAgent plist has `KeepAlive: false` to prevent respawning

**Graceful Termination** (lines 54-90 in `AppDelegate.swift`)
- Signal handlers for SIGTERM and SIGINT
- `isTerminating` flag prevents duplicate cleanup
- Cleans up `SpaceMonitor` before terminating

## Testing

**Test Structure** (`SpaceAgentTests/`)
- `SpaceMonitorTests.swift`: Unit tests with mocked Core Graphics Services
- `MockCoreGraphicsServices.swift`: Mock implementations for testing
- Tests use protocol-based dependency injection for isolation

**Test Philosophy**
- All Core Graphics Services calls are mockable via `CoreGraphicsServiceProtocol`
- Tests validate space change delegation and state management
- Integration tests can use `RealCoreGraphicsService` for real system behavior

## Troubleshooting

**Debug Logging**
All space detection and mapping operations are logged to `/tmp/spaceagent_debug.log` with timestamps.

**Common Issues**
- Menu bar not updating: Check if app is running (`ps aux | grep SpaceAgent`)
- Wrong space numbers: Review debug log for space ID mapping
- Multiple instances: Run `./cleanup.sh` before `./install.sh`
- App hanging on launch: Delayed initialization (0.5s) prevents CGS blocking

## Installation Details

**LaunchAgent** (`com.mtm.spaceagent.plist`)
- Installed to `~/Library/LaunchAgents/`
- Runs at login (`RunAtLoad: true`)
- Does not keep alive (`KeepAlive: false`)
- Launches `/Applications/SpaceAgent.app`

**Uninstallation**
```bash
launchctl unload ~/Library/LaunchAgents/com.mtm.spaceagent.plist
rm ~/Library/LaunchAgents/com.mtm.spaceagent.plist
sudo rm -rf /Applications/SpaceAgent.app
```

## Private APIs Used

This application uses undocumented Core Graphics Services APIs:
- `_CGSDefaultConnection()` - Get connection to window server
- `CGSGetActiveSpace()` - Get active space ID

These APIs have no public headers and use `@_silgen_name` for linkage. They may break in future macOS versions.

## Project Configuration

- **Language**: Swift 5.0
- **Platform**: macOS 14.0+ (deployment target can be lowered)
- **Build System**: Xcode project with two targets (SpaceAgent, SpaceAgentTests)
- **Test Framework**: XCTest
- **App Type**: Accessory (menu bar only, no Dock icon)
