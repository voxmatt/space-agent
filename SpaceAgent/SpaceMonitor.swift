import Foundation
import Cocoa

// MARK: - Shared Utilities

/// Log levels for filtering debug output
enum LogLevel: Int, Comparable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3

    var prefix: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARN"
        case .error: return "ERROR"
        }
    }

    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

/// Current minimum log level - only logs at this level or higher will be written
private let currentLogLevel: LogLevel = .info

/// Writes a debug message to /tmp/spaceagent_debug.log asynchronously
func writeToDebugLog(_ message: String, level: LogLevel = .debug) {
    // Filter based on log level
    guard level >= currentLogLevel else { return }

    DispatchQueue.global(qos: .utility).async {
        let debugFilePath = "/tmp/spaceagent_debug.log"

        // Use faster ISO8601DateFormatter instead of creating new DateFormatter each time
        let iso8601 = ISO8601DateFormatter()
        let timestamp = iso8601.string(from: Date())

        let logMessage = "[\(timestamp)] [\(level.prefix)] \(message.trimmingCharacters(in: .whitespacesAndNewlines))\n"

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

// MARK: - Core Graphics Services Types

typealias CGSConnection = UInt32
typealias CGSSpaceID = UInt32

// Core Graphics Services function declarations
@_silgen_name("_CGSDefaultConnection")
func _CGSDefaultConnection() -> CGSConnection

@_silgen_name("CGSGetActiveSpace")
func CGSGetActiveSpace(_ connection: CGSConnection) -> CGSSpaceID

// Note: CGSManagedDisplaySpaces may not be available or may have different signature
// We'll use a different approach to get space information

// MARK: - Core Graphics Services Protocol

protocol CoreGraphicsServiceProtocol {
    func detectActualSpace() -> Int
    func getCurrentSpaceFromDefaults() -> Int?
}

// MARK: - Real Core Graphics Service Implementation

class RealCoreGraphicsService: CoreGraphicsServiceProtocol {
    private var spaceIDToNumberMap: [UInt32: Int] = [:]
    private var currentSpaceIDFromDefaults: UInt32?

    init() {
        writeToDebugLog("Initializing RealCoreGraphicsService", level: .info)

        // Build space mapping from UserDefaults at initialization
        buildInitialSpaceMapping()
    }

    func getCurrentSpaceFromDefaults() -> Int? {
        // Return the current space number based on UserDefaults, without calling CGS
        if let spaceID = currentSpaceIDFromDefaults, let spaceNumber = spaceIDToNumberMap[spaceID] {
            return spaceNumber
        }
        return nil
    }
    
    /// Builds space mapping from UserDefaults at initialization
    private func buildInitialSpaceMapping() {
        writeToDebugLog("Building space mapping from UserDefaults", level: .info)

        // Access the com.apple.spaces persistent domain
        guard let spacesConfig = UserDefaults.standard.persistentDomain(forName: "com.apple.spaces") else {
            writeToDebugLog("Could not access com.apple.spaces persistent domain", level: .warning)
            return
        }

        // Parse: SpacesDisplayConfiguration -> Management Data -> Monitors
        guard let displayConfig = spacesConfig["SpacesDisplayConfiguration"] as? [String: Any],
              let managementData = displayConfig["Management Data"] as? [String: Any],
              let monitors = managementData["Monitors"] as? [[String: Any]] else {
            writeToDebugLog("Could not parse space configuration structure", level: .warning)
            return
        }

        // Find the Main monitor and extract spaces
        var allSpaceIDs: [UInt32] = []

        for monitor in monitors {
            guard let displayIdentifier = monitor["Display Identifier"] as? String,
                  displayIdentifier == "Main" else {
                continue // Skip non-main monitors
            }

            // Extract current space ID
            if let currentSpace = monitor["Current Space"] as? [String: Any] {
                if let currentSpaceID = currentSpace["ManagedSpaceID"] as? UInt32 {
                    currentSpaceIDFromDefaults = currentSpaceID
                } else if let id64 = currentSpace["id64"] as? UInt64 {
                    currentSpaceIDFromDefaults = UInt32(id64)
                } else if let id64Int = currentSpace["id64"] as? Int {
                    currentSpaceIDFromDefaults = UInt32(id64Int)
                }
            }

            // Extract all space IDs
            if let spaces = monitor["Spaces"] as? [[String: Any]] {
                for space in spaces {
                    if let managedSpaceID = space["ManagedSpaceID"] as? UInt32 {
                        allSpaceIDs.append(managedSpaceID)
                    } else if let id64 = space["id64"] as? UInt64 {
                        allSpaceIDs.append(UInt32(id64))
                    } else if let id64Int = space["id64"] as? Int {
                        allSpaceIDs.append(UInt32(id64Int))
                    }
                }
            }
            break // Found main monitor, stop searching
        }

        // Build mapping from sorted unique space IDs
        guard !allSpaceIDs.isEmpty else {
            writeToDebugLog("No spaces found in Main monitor", level: .warning)
            return
        }

        let uniqueSpaceIDs = Array(Set(allSpaceIDs)).sorted()
        for (index, spaceID) in uniqueSpaceIDs.enumerated() {
            spaceIDToNumberMap[spaceID] = index + 1
        }

        writeToDebugLog("Built space mapping: \(spaceIDToNumberMap)", level: .info)
    }
    
    func detectActualSpace() -> Int {
        // Use real Core Graphics Services to detect the current space
        // This is a simple, non-blocking version
        let connection = _CGSDefaultConnection()
        let spaceID = CGSGetActiveSpace(connection)

        let debugMsg = "Real CGS Detection - Space ID: \(spaceID)\n"
        writeToDebugLog(debugMsg)

        // If we don't have a mapping for this space ID, add it dynamically
        if spaceIDToNumberMap[spaceID] == nil {
            // Add new space with next available number (O(1) operation)
            let newSpaceNumber = (spaceIDToNumberMap.values.max() ?? 0) + 1
            spaceIDToNumberMap[spaceID] = newSpaceNumber

            let discoverMsg = "New space discovered: Space ID \(spaceID) assigned Space #\(newSpaceNumber)\n"
            writeToDebugLog(discoverMsg, level: .info)
        }

        // Use the mapping to get the space number
        if let spaceNumber = spaceIDToNumberMap[spaceID] {
            let resultMsg = "Found mapping: Space ID \(spaceID) -> Space Number \(spaceNumber)\n"
            writeToDebugLog(resultMsg)
            return spaceNumber
        }

        // Fallback: use the space ID directly if we still can't find a match
        let spaceNumber = Int(spaceID)
        let resultMsg = "Fallback: Using Space ID \(spaceID) as Space Number \(spaceNumber)\n"
        writeToDebugLog(resultMsg)
        return spaceNumber
    }
}


// MARK: - Space Monitor Delegate Protocol

protocol SpaceMonitorDelegate: AnyObject {
    func spaceDidChange(to spaceNumber: Int, from previousSpace: Int)
}

class SpaceMonitor {
    weak var delegate: SpaceMonitorDelegate?

    private let coreGraphicsService: CoreGraphicsServiceProtocol
    private var currentSpaceNumber: Int = 1
    private var pollingTimer: Timer?
    private var isChecking = false // Prevent overlapping checks
    private let checkQueue = DispatchQueue(label: "com.mtm.spaceagent.checkqueue", qos: .utility)

    init(coreGraphicsService: CoreGraphicsServiceProtocol = RealCoreGraphicsService()) {
        self.coreGraphicsService = coreGraphicsService

        // Check for multiple instances in background to avoid blocking init
        DispatchQueue.global(qos: .utility).async {
            self.checkForMultipleInstances()
        }

        setupMonitoring()

        // Get initial space from UserDefaults (no CGS call needed)
        if let initialSpace = coreGraphicsService.getCurrentSpaceFromDefaults() {
            currentSpaceNumber = initialSpace
            #if DEBUG
            print("SpaceMonitor: Initial space from UserDefaults: \(initialSpace)")
            #endif

            // Notify delegate of initial space
            DispatchQueue.main.async {
                self.delegate?.spaceDidChange(to: initialSpace, from: 0)
            }
        } else {
            // Fallback: start with space 1
            currentSpaceNumber = 1
            #if DEBUG
            print("SpaceMonitor: Could not determine initial space, defaulting to 1")
            #endif
        }

        #if DEBUG
        print("SpaceMonitor: Init complete, will start polling in 3 seconds")
        #endif

        // Start polling for space changes as fallback (delayed to avoid immediate CGS call)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            #if DEBUG
            print("SpaceMonitor: Starting polling now")
            #endif
            self.startPolling()
        }
    }
    
    private func checkForMultipleInstances() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["aux"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            let spaceAgentLines = output.components(separatedBy: .newlines)
                .filter { $0.contains("SpaceAgent") && !$0.contains("grep") }
            
            if spaceAgentLines.count > 1 {
                let warningMsg = "⚠️  WARNING: Multiple SpaceAgent instances detected (\(spaceAgentLines.count)). This may cause conflicts.\n"
                writeToDebugLog(warningMsg, level: .warning)
                #if DEBUG
                print(warningMsg)
                #endif
            }
        } catch {
            // If we can't check, just continue
        }
    }

    deinit {
        stopMonitoring()
    }

    func getCurrentSpaceNumber() -> Int {
        return currentSpaceNumber
    }

    private func setupMonitoring() {
        // Listen for space change notifications (may not work reliably)
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSpaceChange),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )

        // Also listen for application activation which might indicate space change
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleAppActivation),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    private func startPolling() {
        // Use long interval (15 seconds) since this is just a safety net
        // We rely primarily on app activation events and NSWorkspace notifications
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            // Only poll if we're not already checking
            DispatchQueue.global(qos: .utility).async { [weak self] in
                self?.pollForSpaceChange()
            }
        }
        #if DEBUG
        print("SpaceMonitor: Polling started with 15s interval (safety net)")
        #endif
    }

    @objc private func handleAppActivation() {
        // When app activates, check if space changed
        // Use utility queue to avoid blocking
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.pollForSpaceChange()
        }
    }

    private func stopMonitoring() {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    private func pollForSpaceChange() {
        // Prevent overlapping checks
        checkQueue.async { [weak self] in
            guard let self = self else { return }

            // Skip if already checking
            if self.isChecking {
                #if DEBUG
                print("SpaceMonitor: Already checking for space change, skipping...")
                #endif
                return
            }

            self.isChecking = true
            defer { self.isChecking = false }

            // Use timeout version to prevent hanging
            let detectedSpace = self.detectCurrentSpaceNumberWithTimeout()

            if detectedSpace > 0 && detectedSpace != self.currentSpaceNumber {
                let previousSpace = self.currentSpaceNumber
                self.currentSpaceNumber = detectedSpace

                let debugMsg = "Polling detected space change: \(previousSpace) -> \(detectedSpace)\n"
                writeToDebugLog(debugMsg, level: .info)
                #if DEBUG
                print("Polling: Space change detected: \(previousSpace) -> \(detectedSpace)")
                #endif

                DispatchQueue.main.async {
                    #if DEBUG
                    print("SpaceMonitor: Calling delegate with space \(self.currentSpaceNumber)")
                    #endif
                    self.delegate?.spaceDidChange(to: self.currentSpaceNumber, from: previousSpace)
                }
            }
        }
    }

    @objc private func handleSpaceChange() {
        writeToDebugLog("NSWorkspace space change notification received!", level: .info)

        // Detect the actual current space using Core Graphics Services with timeout protection
        let detectedSpace = detectCurrentSpaceNumberWithTimeout()

        // Only update if we detected a valid space and it's different from current
        if detectedSpace > 0 && detectedSpace != currentSpaceNumber {
            let previousSpace = currentSpaceNumber
            currentSpaceNumber = detectedSpace

            writeToDebugLog("Space change detected: \(previousSpace) -> \(currentSpaceNumber)", level: .info)
            #if DEBUG
            print("Space change detected: \(previousSpace) -> \(currentSpaceNumber)")
            #endif

            DispatchQueue.main.async {
                #if DEBUG
                print("SpaceMonitor: Calling delegate with space \(self.currentSpaceNumber)")
                #endif
                self.delegate?.spaceDidChange(to: self.currentSpaceNumber, from: previousSpace)
            }
        } else {
            writeToDebugLog("Space change notification received but no actual change detected (detected: \(detectedSpace), current: \(currentSpaceNumber))")
        }
    }

    private func detectCurrentSpaceNumber() -> Int {
        let logMessage = "🔍 Detecting current space using Core Graphics Services...\n"
        writeToDebugLog(logMessage)
        
        // Use the RealCoreGraphicsService to detect the actual space
        let detectedSpace = coreGraphicsService.detectActualSpace()
        
        let resultMsg = "Real CGS space detection: returning space \(detectedSpace)\n"
        writeToDebugLog(resultMsg)
        
        return detectedSpace
    }
    
    private func detectCurrentSpaceNumberWithTimeout() -> Int {
        let timeout: TimeInterval = 2.0 // 2 second timeout
        let semaphore = DispatchSemaphore(value: 0)
        var result: Int = 0
        
        DispatchQueue.global(qos: .userInitiated).async {
            result = self.detectCurrentSpaceNumber()
            semaphore.signal()
        }
        
        let timeoutResult = semaphore.wait(timeout: .now() + timeout)
        if timeoutResult == .timedOut {
            writeToDebugLog("Space detection timed out after \(timeout) seconds", level: .warning)
            #if DEBUG
            print("⚠️ Space detection timed out, using current space: \(currentSpaceNumber)")
            #endif
            return currentSpaceNumber // Return current space as fallback
        }
        
        return result
    }
    

}
