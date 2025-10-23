# SpaceAgent Code Cleanup Recommendations

## High Priority - Dead Code Removal

### 1. Unused Protocol Methods (CoreGraphicsServiceProtocol)
**Location**: SpaceMonitor.swift:21-26

Remove these unused methods:
- `defaultConnection()` - never called
- `copyManagedDisplaySpaces()` - never called
- `copyActiveMenuBarDisplayIdentifier()` - never called

**Action**: Keep only `detectActualSpace()` in the protocol.

---

### 2. Unreachable Code Path (buildCompleteSpaceMapping)
**Location**: SpaceMonitor.swift:248-271, line 44

**Issue**: `buildCompleteSpaceMapping()` is called when `buildInitialSpaceMapping()` returns false, but:
- When UserDefaults parsing succeeds, it returns `true` (line 219)
- When it fails, it returns `false` (line 245) BUT the mapping is already empty
- So `buildCompleteSpaceMapping()` rebuilds an empty map

**Action**: Fix the logic - `buildInitialSpaceMapping()` should return true when successful (line 219), and remove the fallback call to `buildCompleteSpaceMapping()` in init.

---

### 3. Unused Public Method (updateCurrentSpace)
**Location**: SpaceMonitor.swift:725-739

Never called anywhere in the codebase.

**Action**: Remove unless needed for testing.

---

### 4. Unused Testing Method (setCurrentSpace)
**Location**: SpaceMonitor.swift:742-751

Appears to be for manual testing.

**Action**: Remove or wrap in `#if DEBUG`.

---

## Medium Priority - Code Simplification

### 5. Excessive Debug Logging
**Location**: SpaceMonitor.swift:66-121

Logs entire UserDefaults structure twice with verbose debugging.

**Action**: Remove lines 66-121 once the feature is stable. The essential parsing (lines 104-237) is sufficient.

---

### 6. Duplicate writeToDebugFile() Implementation
**Location**:
- RealCoreGraphicsService: lines 331-352
- SpaceMonitor: lines 702-723

Identical implementations in two classes.

**Action**: Extract to a global function or extension:
```swift
func writeToDebugLog(_ message: String) {
    DispatchQueue.global(qos: .utility).async {
        let debugFilePath = "/tmp/spaceagent_debug.log"
        let timestamp = DateFormatter().string(from: Date())
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

### 7. Inconsistent Timeout Protection
**Location**: SpaceMonitor.swift:560-586 vs 527-558

`handleSpaceChange()` calls `detectCurrentSpaceNumber()` directly, while `pollForSpaceChange()` uses `detectCurrentSpaceNumberWithTimeout()`.

**Action**: Make `handleSpaceChange()` also use timeout version for consistency:
```swift
@objc private func handleSpaceChange() {
    writeToDebugFile("NSWorkspace space change notification received!\n")

    let detectedSpace = detectCurrentSpaceNumberWithTimeout()

    if detectedSpace > 0 && detectedSpace != currentSpaceNumber {
        // ... rest of logic
    }
}
```

---

### 8. Hardcoded Shortcut Name
**Location**: SpaceMonitor.swift:592

**Action**: Make configurable:
```swift
private var shortcutName: String = "Change default browser when space changes"

// Or better: read from UserDefaults or config file
```

---

## Low Priority - Code Quality

### 9. Excessive Debug Print Statements
**Locations**: Throughout file (37, 42, 46, 163, 179, 205, 213, 218, 223, 281, 299-300, 308-310)

Many print statements with "DEBUG:" prefix.

**Action**: Once stable, remove or guard with:
```swift
#if DEBUG
print("DEBUG: ...")
#endif
```

---

### 10. Commented Out Code
**Location**: SpaceMonitor.swift:576

```swift
// triggerShortcut(for: currentSpaceNumber, from: previousSpace)
```

**Action**: Either remove the comment or document when to re-enable.

---

## Refactoring Opportunities

### 11. Extract UserDefaults Parsing
The UserDefaults parsing logic (lines 104-237) could be extracted to a separate method for clarity:

```swift
private func parseSpacesFromUserDefaults() -> (spaceMap: [UInt32: Int], currentSpaceID: UInt32?)? {
    // Extract parsing logic here
}
```

---

### 12. Simplify buildInitialSpaceMapping Return Logic
Currently confusing - returns false at line 245 even after logging "No spaces found". Should either:
- Return true on success (line 219) - ALREADY DOES THIS
- Return false only on actual failure
- Don't need to log "will detect on first poll" since we already succeeded

**Action**: Remove lines 239-245 (the fallback message and false return) since when we reach that code, we've already succeeded and returned true earlier.

---

## Summary

**Must Remove (Dead Code):**
- Unused protocol methods (3 methods)
- `buildCompleteSpaceMapping()` fallback logic
- `updateCurrentSpace()` method
- `setCurrentSpace()` method (or make DEBUG only)

**Should Simplify:**
- Remove excessive debug logging (lines 66-121)
- Extract duplicate `writeToDebugFile()` to shared utility
- Make `handleSpaceChange()` use timeout version
- Make shortcut name configurable

**Can Clean Up Later:**
- Remove/guard DEBUG print statements
- Remove commented code or document it
- Extract UserDefaults parsing to separate method
