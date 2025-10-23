# SpaceAgent Improvement Recommendations

Based on code review and runtime analysis, here are recommended improvements:

## High Priority

### 1. Remove Unused Shortcut Integration Code
**Location**: SpaceMonitor.swift:318-405

The `triggerShortcut()` method is fully implemented but never called anywhere in the codebase.

**Recommendation**:
- Option A: Remove it entirely (saves ~90 lines)
- Option B: If planning to use it, add a config option to enable it

**Action**:
```swift
// Delete lines 318-405, or wrap in:
#if ENABLE_SHORTCUTS
    // ... shortcut code ...
#endif
```

---

### 2. Optimize Dynamic Space Discovery
**Location**: SpaceMonitor.swift:78-93 (detectActualSpace)

Currently rebuilds entire mapping when discovering a new space. This is inefficient.

**Current Logic**:
```swift
let allSpaceIDs = Array(spaceIDToNumberMap.keys) + [spaceID]
let sortedSpaceIDs = Array(Set(allSpaceIDs)).sorted()
spaceIDToNumberMap.removeAll()
for (index, id) in sortedSpaceIDs.enumerated() {
    spaceIDToNumberMap[id] = index + 1
}
```

**Recommended Optimization**:
```swift
// Just add the new space at the end
let newSpaceNumber = (spaceIDToNumberMap.values.max() ?? 0) + 1
spaceIDToNumberMap[spaceID] = newSpaceNumber

writeToDebugLog("Dynamic space discovery: added Space ID \(spaceID) as Space #\(newSpaceNumber)")
```

**Benefits**:
- O(1) instead of O(n log n)
- Preserves existing space numbers
- More predictable behavior

---

### 3. Optimize Debug Logging Performance
**Location**: SpaceMonitor.swift:7-24 (writeToDebugLog)

Creates a new DateFormatter on every log call, which is expensive.

**Current Issue**:
```swift
let timestamp = DateFormatter().string(from: Date())
```

**Recommended Fix**:
```swift
func writeToDebugLog(_ message: String) {
    DispatchQueue.global(qos: .utility).async {
        let debugFilePath = "/tmp/spaceagent_debug.log"

        // Use faster ISO8601DateFormatter
        let iso8601 = ISO8601DateFormatter()
        let timestamp = iso8601.string(from: Date())

        let logMessage = "[\(timestamp)] \(message.trimmingCharacters(in: .whitespacesAndNewlines))\n"

        guard let data = logMessage.data(using: .utf8) else { return }

        if FileManager.default.fileExists(atPath: debugFilePath),
           let fileHandle = FileHandle(forWritingAtPath: debugFilePath) {
            fileHandle.seekToEndOfFile()
            fileHandle.write(data)
            fileHandle.closeFile()
        } else {
            try? data.write(to: URL(fileURLWithPath: debugFilePath))
        }
    }
}
```

---

## Medium Priority

### 4. Reduce Polling Frequency
**Location**: SpaceMonitor.swift:224-236 (startPolling)

Currently polls every 5 seconds, which generates a lot of log entries and CGS calls.

**Current**:
```swift
pollingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true)
```

**Recommendation**:
```swift
// Increase to 10-15 seconds since we have NSWorkspace notifications as primary detection
pollingTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true)
```

**Rationale**:
- App activation events (handleAppActivation) provide immediate detection
- NSWorkspace notifications handle most space changes
- Polling is just a safety net, doesn't need to be frequent
- Reduces CPU usage and log spam

---

### 5. Add Log Levels
**Location**: Throughout SpaceMonitor.swift

Currently all logs are written at the same level. Add severity levels:

```swift
enum LogLevel: Int {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
}

private var currentLogLevel: LogLevel = .info

func writeToDebugLog(_ message: String, level: LogLevel = .debug) {
    guard level.rawValue >= currentLogLevel.rawValue else { return }

    DispatchQueue.global(qos: .utility).async {
        let debugFilePath = "/tmp/spaceagent_debug.log"
        let iso8601 = ISO8601DateFormatter()
        let timestamp = iso8601.string(from: Date())
        let levelStr = String(describing: level).uppercased()
        let logMessage = "[\(timestamp)] [\(levelStr)] \(message.trimmingCharacters(in: .whitespacesAndNewlines))\n"

        guard let data = logMessage.data(using: .utf8) else { return }

        if FileManager.default.fileExists(atPath: debugFilePath),
           let fileHandle = FileHandle(forWritingAtPath: debugFilePath) {
            fileHandle.seekToEndOfFile()
            fileHandle.write(data)
            fileHandle.closeFile()
        } else {
            try? data.write(to: URL(fileURLWithPath: debugFilePath))
        }
    }
}
```

**Usage**:
```swift
writeToDebugLog("Building space mapping from UserDefaults", level: .info)
writeToDebugLog("Real CGS Detection - Space ID: \(spaceID)", level: .debug)
writeToDebugLog("⚠️ Multiple instances detected", level: .warning)
```

---

### 6. Add Configuration File Support
Create a simple configuration system:

**Create**: `SpaceAgentConfig.plist`
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>PollingInterval</key>
    <real>15.0</real>
    <key>CGSTimeout</key>
    <real>2.0</real>
    <key>LogLevel</key>
    <string>info</string>
    <key>EnableDebugLog</key>
    <true/>
</dict>
</plist>
```

**Add Configuration Struct**:
```swift
struct SpaceAgentConfig {
    let pollingInterval: TimeInterval
    let cgsTimeout: TimeInterval
    let logLevel: LogLevel
    let enableDebugLog: Bool

    static let `default` = SpaceAgentConfig(
        pollingInterval: 15.0,
        cgsTimeout: 2.0,
        logLevel: .info,
        enableDebugLog: true
    )

    static func load() -> SpaceAgentConfig {
        guard let configPath = Bundle.main.path(forResource: "SpaceAgentConfig", ofType: "plist"),
              let configDict = NSDictionary(contentsOfFile: configPath) as? [String: Any] else {
            return .default
        }

        return SpaceAgentConfig(
            pollingInterval: configDict["PollingInterval"] as? TimeInterval ?? 15.0,
            cgsTimeout: configDict["CGSTimeout"] as? TimeInterval ?? 2.0,
            logLevel: LogLevel(rawValue: configDict["LogLevel"] as? String ?? "info") ?? .info,
            enableDebugLog: configDict["EnableDebugLog"] as? Bool ?? true
        )
    }
}
```

---

## Low Priority

### 7. Improve Dynamic Discovery Logging
Make it clearer what changed when a new space is discovered:

```swift
if spaceIDToNumberMap[spaceID] == nil {
    let oldMapping = spaceIDToNumberMap
    let discoverMsg = "New space discovered: Space ID \(spaceID)"
    writeToDebugLog(discoverMsg, level: .info)

    // Add to mapping
    let newSpaceNumber = (spaceIDToNumberMap.values.max() ?? 0) + 1
    spaceIDToNumberMap[spaceID] = newSpaceNumber

    let changeMsg = "Mapping updated: \(oldMapping) -> \(spaceIDToNumberMap)"
    writeToDebugLog(changeMsg, level: .debug)
}
```

---

### 8. Add Telemetry/Metrics (Optional)
Consider adding basic metrics to track:
- Number of space changes per session
- Average time between space changes
- CGS call latency
- Timeout occurrences

Store in UserDefaults and optionally display in menu or log on exit.

---

### 9. Consider Log Rotation
The debug log at `/tmp/spaceagent_debug.log` will grow indefinitely.

**Add log rotation**:
```swift
func rotateLogIfNeeded() {
    let debugFilePath = "/tmp/spaceagent_debug.log"
    let maxSize: UInt64 = 10_000_000 // 10MB

    guard let attrs = try? FileManager.default.attributesOfItem(atPath: debugFilePath),
          let fileSize = attrs[.size] as? UInt64,
          fileSize > maxSize else {
        return
    }

    // Rotate: rename current to .old, start fresh
    let oldPath = "\(debugFilePath).old"
    try? FileManager.default.removeItem(atPath: oldPath)
    try? FileManager.default.moveItem(atPath: debugFilePath, toPath: oldPath)
}
```

Call this at app startup in `init()`.

---

## Summary of Benefits

**Performance**:
- Faster logging (ISO8601DateFormatter)
- Less frequent polling (15s vs 5s)
- Optimized space discovery (O(1) vs O(n log n))

**Maintainability**:
- Configuration file for easy tuning
- Log levels for better debugging
- Cleaner code (remove unused shortcuts)

**Reliability**:
- Log rotation prevents disk space issues
- Better error visibility with log levels

**Resource Usage**:
- Reduced CPU from less frequent polling
- Reduced disk I/O from log levels
- Smaller log files from filtering
