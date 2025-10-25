# SpaceAgent

A background macOS agent that monitors virtual space changes and displays the current space number in the menu bar.

## Features

- 🚀 Monitors macOS virtual space (desktop) changes
- 🔄 Runs automatically in the background
- 📊 Shows current space number in menu bar
- ⚙️ Simple settings window for customization
- 🎨 Customizable menu bar icon
- 🏁 Auto-starts on login
- 📝 Configurable logging levels
- 🔗 macOS Shortcuts integration (get current space)

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

## Settings

Click the menu bar icon and select "Settings..." to customize:

- **Menu Bar Icon**: Change the emoji or text shown in the menu bar (default: 🚀)
- **Polling Interval**: Adjust how often the app checks for space changes (5-60 seconds, default: 15)
- **Log Level**: Set minimum logging level for debug logs (Debug, Info, Warning, Error)
- **Trigger Shortcut on Space Change**: Enable automatic shortcut execution when switching spaces
- **Shortcut Name**: Name of the shortcut to trigger (receives space number as input)

Additional features in the Settings window:
- **View Logs**: Open the debug log file in Console.app
- **Reset to Defaults**: Restore all settings to their default values

## Shortcuts Integration

SpaceAgent integrates with macOS Shortcuts, allowing you to use the current space number in your automation workflows.

### Available Actions:

1. **Get Current Space** - Returns the current space number as an integer (e.g., `2`)
2. **Get Current Space (Text)** - Returns the current space as formatted text (e.g., `"Space 2"`)

### How to Use:

1. Open the **Shortcuts** app on macOS
2. Create a new shortcut or edit an existing one
3. Click the **+** button to add an action
4. Search for "**Space Agent**" or "**Get Current Space**"
5. Add the action to your shortcut

### Example Shortcuts:

**Simple Space Display:**
```
1. Get Current Space (Text) from SpaceAgent
2. Show Notification with result
```

**Conditional Actions by Space:**
```
1. Get Current Space from SpaceAgent
2. If [Current Space] is [2]
   - Do something specific to Space 2
3. Otherwise
   - Do something else
```

**Log Space Changes:**
```
1. Get Current Space (Text) from SpaceAgent
2. Append to File [result + timestamp]
```

### Voice Commands:

You can also use Siri to trigger shortcuts that use SpaceAgent:
- "Hey Siri, what space am I on?"
- "Hey Siri, current space number"

Just create a shortcut with the SpaceAgent action and give it a name that Siri can recognize.

## Using Space Changes as Triggers

SpaceAgent can automatically trigger a Shortcuts workflow every time you switch spaces, effectively turning space changes into automation triggers.

### How to Set Up:

1. **Create Your Shortcut**:
   - Open the **Shortcuts** app
   - Create a new shortcut with the actions you want to run
   - Give it a name (e.g., "OnSpaceChange")
   - The shortcut will receive the space number as input

2. **Enable in SpaceAgent Settings**:
   - Click the SpaceAgent menu bar icon
   - Select "Settings..."
   - Check "**Trigger Shortcut on Space Change**"
   - Enter the exact name of your shortcut
   - Click "Close"

3. **Test It**:
   - Switch to a different space
   - Your shortcut will run automatically!

### Implementation Details:

SpaceAgent uses Apple's official Shortcuts URL scheme (`shortcuts://run-shortcut`) to trigger your shortcut:
- Runs **every time** you switch spaces
- Passes the **space number** (e.g., 2) as text input to your shortcut
- Works **silently in the background** (no UI interruption)
- **No polling required** - triggers instantly on space change

### Example Use Cases:

**1. Notify on Space Change:**
```
Shortcut: "OnSpaceChange"
Actions:
1. Receive [Shortcut Input] as text
2. Show notification "Switched to Space [Shortcut Input]"
```

**2. Conditional Actions by Space:**
```
Shortcut: "SpaceAutomation"
Actions:
1. Receive [Shortcut Input] as text
2. If [Shortcut Input] equals "1"
   → Set Focus to "Work"
3. If [Shortcut Input] equals "2"
   → Set Focus to "Personal"
4. If [Shortcut Input] equals "3"
   → Launch Music app
```

**3. Log Space Activity:**
```
Shortcut: "LogSpaces"
Actions:
1. Receive [Shortcut Input] as text
2. Get current date
3. Append "[date] - Space [Shortcut Input]" to file
```

**4. Dynamic Desktop Wallpapers:**
```
Shortcut: "SpaceWallpaper"
Actions:
1. Receive [Shortcut Input] as text
2. If [Shortcut Input] equals "1"
   → Set wallpaper to "work-bg.jpg"
3. If [Shortcut Input] equals "2"
   → Set wallpaper to "personal-bg.jpg"
```

**5. Launch Apps by Space:**
```
Shortcut: "SpaceLauncher"
Actions:
1. Receive [Shortcut Input] as text
2. If [Shortcut Input] equals "2"
   → Open app "Safari"
3. If [Shortcut Input] equals "3"
   → Open app "Terminal"
```

### Tips:

- **Keep it lightweight**: Shortcuts run synchronously, so avoid long-running actions
- **Test first**: Test your shortcut manually before enabling auto-trigger
- **Debug**: Check Shortcuts app notification settings if shortcuts don't appear to run
- **Disable when not needed**: Turn off the trigger in Settings if you're not using it

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