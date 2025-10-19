# SpaceAgent

A background macOS agent that monitors virtual space changes and displays the current space number in the menu bar.

## Features

- 🚀 Monitors macOS virtual space (desktop) changes
- 🔄 Runs automatically in the background
- 📊 Shows current space number in menu bar
- 🏁 Auto-starts on login

## Installation

1. Clone or download this project
2. Run the installation script:
   ```bash
   ./install.sh
   ```

## Setup

After installation, SpaceAgent will automatically start monitoring your spaces and display the current space number in the menu bar.

## How It Works

SpaceAgent uses Core Graphics Services APIs to monitor space changes:

- Monitors `NSWorkspace.activeSpaceDidChangeNotification`
- Uses `CGSGetActiveSpace` to detect current space
- Dynamically discovers and maps space IDs to sequential numbers
- Displays current space number in menu bar with 🚀 icon

## Uninstalling

To remove SpaceAgent:

```bash
launchctl unload ~/Library/LaunchAgents/com.mtm.spaceagent.plist
rm ~/Library/LaunchAgents/com.mtm.spaceagent.plist
sudo rm -rf /Applications/SpaceAgent.app
```

## Troubleshooting

- **Permission issues**: SpaceAgent may need Accessibility permissions in System Settings
- **Menu bar icon not showing**: Check that the app is running with `ps aux | grep SpaceAgent`
- **Space number not updating**: Check debug logs at `/tmp/spaceagent_debug.log`

## Development

### Testing

The project includes comprehensive tests covering all critical code paths:

```bash
# Run all tests
./test.sh

# Run specific test suites
./test.sh space      # SpaceMonitor tests only
./test.sh integration # End-to-end integration tests
```

### Test Coverage

- **SpaceMonitor**: Core space detection logic, space change notifications, dynamic space discovery
- **Application Lifecycle**: Initialization, delegation patterns, memory management
- **Integration**: End-to-end workflows, failure scenarios, edge cases

### Architecture

The codebase is designed for testability with:
- Protocol-based dependency injection
- Mock objects for Core Graphics Services
- Separate concerns (monitoring vs. UI vs. integrations)
- Delegate pattern for loose coupling

## Technical Details

This application is built with:
- Swift 5.0
- macOS 14.0+ (can be lowered if needed)
- Core Graphics Services (CGS) APIs
- NSWorkspace notifications
- LaunchAgent for auto-start
- XCTest framework for comprehensive testing