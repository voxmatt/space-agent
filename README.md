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

The installation script will:
- Stop any running SpaceAgent instances
- Remove old versions from Applications
- Build the app in Release configuration
- Install to `/Applications/SpaceAgent.app`
- Set up auto-start via LaunchAgent
- Launch the app immediately

## Setup

After installation, SpaceAgent will automatically start monitoring your spaces and display the current space number in the menu bar.

## How It Works

SpaceAgent uses Core Graphics Services APIs to monitor space changes:

- Monitors `NSWorkspace.activeSpaceDidChangeNotification` for real-time space changes
- Monitors application activation events for immediate space detection
- Uses `CGSGetActiveSpace` to detect current space with timeout protection
- Reads `com.apple.spaces` UserDefaults for initial space mapping
- Dynamically discovers and maps new space IDs (O(1) operation)
- Falls back to periodic polling (15s interval) as a safety net
- Displays current space number in menu bar with 🚀 icon
- Logs important events with ISO8601 timestamps and log levels (debug, info, warning, error)

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
- **Multiple instances running**: Run `./cleanup.sh` to stop all instances before reinstalling
- **Debug logging**: Logs are written with ISO8601 timestamps and include log levels (INFO, WARN, ERROR)

## Development

### Available Scripts

- **`./install.sh`** - Complete installation with force cleanup and setup
- **`./cleanup.sh`** - Stop all SpaceAgent instances and unload launch agent
- **`./test.sh`** - Run tests with syntax validation
- **`./test.sh space`** - Run only SpaceMonitor tests
- **`./test.sh integration`** - Run only integration tests

### Testing

The project includes comprehensive testing with syntax validation and test execution:

```bash
# Run all tests (includes syntax validation + test execution)
./test.sh

# Run specific test suites
./test.sh space      # SpaceMonitor tests only
./test.sh integration # End-to-end integration tests
```

### Test Features

- **Syntax Validation**: Swift compiler checks all source files before testing
- **Test Structure Validation**: Ensures proper XCTest setup and imports
- **Test Metrics**: Counts test methods and validates test structure
- **Comprehensive Coverage**: SpaceMonitor, Application Lifecycle, and Integration tests

### Architecture

The codebase is designed for testability and performance with:
- Protocol-based dependency injection for Core Graphics Services
- Mock objects for testing without system dependencies
- Separate concerns (monitoring vs. UI vs. integrations)
- Delegate pattern for loose coupling
- Efficient O(1) dynamic space discovery
- Configurable log levels for production vs. development
- Timeout protection for all CGS API calls
- Background thread initialization to prevent UI blocking

## Technical Details

This application is built with:
- Swift 5.0
- macOS 13.0+ (minimum deployment target)
- Core Graphics Services (CGS) private APIs
- NSWorkspace notifications for space change detection
- UserDefaults persistent domain reading for initial space mapping
- LaunchAgent for auto-start on login
- XCTest framework for comprehensive testing
- ISO8601DateFormatter for efficient timestamp logging
- Log level filtering (debug, info, warning, error)