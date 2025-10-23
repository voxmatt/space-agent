import Foundation
import Cocoa

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
    func defaultConnection() -> UInt32
    func copyManagedDisplaySpaces(_ connection: UInt32) -> CFArray
    func copyActiveMenuBarDisplayIdentifier(_ connection: UInt32) -> CFString
    func detectActualSpace() -> Int
}

// MARK: - Real Core Graphics Service Implementation

class RealCoreGraphicsService: CoreGraphicsServiceProtocol {
    private var spaceIDToNumberMap: [UInt32: Int] = [:]
    private var currentSpaceIDFromDefaults: UInt32?

    init() {
        let debugMsg = "Initializing RealCoreGraphicsService with real Core Graphics Services\n"
        writeToDebugFile(debugMsg)
        print("DEBUG: Initializing RealCoreGraphicsService")

        // Try to get all spaces at initialization using public APIs
        // This will also set currentSpaceIDFromDefaults
        if !buildInitialSpaceMapping() {
            print("DEBUG: buildInitialSpaceMapping failed, falling back to buildCompleteSpaceMapping")
            // Fallback to dynamic discovery if initial mapping fails
            buildCompleteSpaceMapping()
        } else {
            print("DEBUG: buildInitialSpaceMapping succeeded")
        }
    }

    func getCurrentSpaceFromDefaults() -> Int? {
        // Return the current space number based on UserDefaults, without calling CGS
        if let spaceID = currentSpaceIDFromDefaults, let spaceNumber = spaceIDToNumberMap[spaceID] {
            return spaceNumber
        }
        return nil
    }
    
    /// Attempts to build space mapping using public APIs at initialization
    /// Returns true if successful, false if we need to fall back to dynamic discovery
    private func buildInitialSpaceMapping() -> Bool {
        let msg = "Attempting to build initial space mapping using public APIs\n"
        writeToDebugFile(msg)
        
        // Method 1: Try to get spaces from NSUserDefaults
        // com.apple.spaces is a persistent domain, not a suite
        let spacesInfoMsg = "=== com.apple.spaces Information ===\n"
        writeToDebugFile(spacesInfoMsg)

        // Access the persistent domain "com.apple.spaces"
        let spacesInfo = UserDefaults.standard.persistentDomain(forName: "com.apple.spaces")

        if let spacesInfo = spacesInfo, !spacesInfo.isEmpty {
            let dataTypeMsg = "com.apple.spaces data type: \(type(of: spacesInfo))\n"
            writeToDebugFile(dataTypeMsg)
            
            let rawDataMsg = "com.apple.spaces raw data: \(spacesInfo)\n"
            writeToDebugFile(rawDataMsg)
            
            // Try to extract more detailed information
            if let spacesDict = spacesInfo as? [String: Any] {
                let keysMsg = "com.apple.spaces dictionary keys: \(Array(spacesDict.keys))\n"
                writeToDebugFile(keysMsg)
                for (key, value) in spacesDict {
                    let keyValueMsg = "  \(key): \(value) (type: \(type(of: value)))\n"
                    writeToDebugFile(keyValueMsg)
                }
            } else if let spacesArray = spacesInfo as? [Any] {
                let arrayMsg = "com.apple.spaces array with \(spacesArray.count) items:\n"
                writeToDebugFile(arrayMsg)
                for (index, item) in spacesArray.enumerated() {
                    let itemMsg = "  [\(index)]: \(item) (type: \(type(of: item)))\n"
                    writeToDebugFile(itemMsg)
                }
            }
        } else {
            let notFoundMsg = "com.apple.spaces data not found in UserDefaults\n"
            writeToDebugFile(notFoundMsg)
        }
        
        let endSpacesInfoMsg = "=== End com.apple.spaces Information ===\n"
        writeToDebugFile(endSpacesInfoMsg)

        // Try again to get the spaces configuration from persistent domain
        if let spacesConfig = UserDefaults.standard.persistentDomain(forName: "com.apple.spaces") {
            let configMsg = "Found spaces configuration in NSUserDefaults\n"
            writeToDebugFile(configMsg)

            // Print the complete structure for debugging
            let fullStructureMsg = "=== COMPLETE com.apple.spaces STRUCTURE ===\n"
            writeToDebugFile(fullStructureMsg)

            // Print top-level keys
            let topLevelKeysMsg = "Top-level keys: \(Array(spacesConfig.keys))\n"
            writeToDebugFile(topLevelKeysMsg)

            // Print the entire structure recursively
            let structureDump = dumpStructure(spacesConfig, indent: 0)
            writeToDebugFile(structureDump)

            let endStructureMsg = "=== END com.apple.spaces STRUCTURE ===\n"
            writeToDebugFile(endStructureMsg)

            let debugConfigMsg = "Spaces config keys: \(Array(spacesConfig.keys))\n"
            writeToDebugFile(debugConfigMsg)

            // Parse the spaces configuration - the correct structure is:
            // SpacesDisplayConfiguration -> "Management Data" -> Monitors[0].Spaces (for main monitor)
            if let displayConfig = spacesConfig["SpacesDisplayConfiguration"] as? [String: Any] {
                let displayConfigMsg = "Found SpacesDisplayConfiguration\n"
                writeToDebugFile(displayConfigMsg)

                // Access the "Management Data" level
                if let managementData = displayConfig["Management Data"] as? [String: Any] {
                    let managementDataMsg = "Found Management Data\n"
                    writeToDebugFile(managementDataMsg)

                    if let monitors = managementData["Monitors"] as? [[String: Any]] {
                        let monitorsMsg = "Found \(monitors.count) monitors\n"
                        writeToDebugFile(monitorsMsg)

                        // Look for the Main monitor only (ignore secondary monitors and collapsed spaces)
                        var allSpaceIDs: [UInt32] = []

                        for (monitorIndex, monitor) in monitors.enumerated() {
                            let monitorKeysMsg = "Monitor \(monitorIndex) keys: \(Array(monitor.keys))\n"
                            writeToDebugFile(monitorKeysMsg)

                            // Check if this is the Main monitor
                            let displayIdentifier = monitor["Display Identifier"] as? String
                            let isMainMonitor = displayIdentifier == "Main"

                            let displayMsg = "Monitor \(monitorIndex) Display Identifier: \(displayIdentifier ?? "nil"), isMain: \(isMainMonitor)\n"
                            writeToDebugFile(displayMsg)

                            // Only process Main monitor spaces, skip collapsed spaces from other monitors
                            if isMainMonitor {
                                // Extract current space ID
                                if let currentSpace = monitor["Current Space"] as? [String: Any] {
                                    if let currentSpaceID = currentSpace["ManagedSpaceID"] as? UInt32 {
                                        currentSpaceIDFromDefaults = currentSpaceID
                                        let currentMsg = "Current space ID from UserDefaults: \(currentSpaceID)\n"
                                        writeToDebugFile(currentMsg)
                                        print("DEBUG: Current space ID from UserDefaults: \(currentSpaceID)")
                                    } else if let id64 = currentSpace["id64"] as? UInt64 {
                                        currentSpaceIDFromDefaults = UInt32(id64)
                                    } else if let id64Int = currentSpace["id64"] as? Int {
                                        currentSpaceIDFromDefaults = UInt32(id64Int)
                                    }
                                }

                                if let spaces = monitor["Spaces"] as? [[String: Any]] {
                                    let spacesCountMsg = "Found \(spaces.count) spaces in Main monitor\n"
                                    writeToDebugFile(spacesCountMsg)

                                    for (index, space) in spaces.enumerated() {
                                        // Extract space ID - prefer ManagedSpaceID, fallback to id64
                                        var spaceID: UInt32? = nil

                                        if let managedSpaceID = space["ManagedSpaceID"] as? UInt32 {
                                            spaceID = managedSpaceID
                                        } else if let id64 = space["id64"] as? UInt64 {
                                            spaceID = UInt32(id64)
                                        } else if let id64Int = space["id64"] as? Int {
                                            spaceID = UInt32(id64Int)
                                        }

                                        if let id = spaceID {
                                            allSpaceIDs.append(id)
                                            let spaceMsg = "Main monitor space \(index + 1): ManagedSpaceID \(id)\n"
                                            writeToDebugFile(spaceMsg)
                                        } else {
                                            let noIDMsg = "Warning: Space at index \(index) has no parseable ID: \(space)\n"
                                            writeToDebugFile(noIDMsg)
                                        }
                                    }
                                }
                            }
                        }

                        if !allSpaceIDs.isEmpty {
                            // Remove duplicates and sort space IDs
                            let uniqueSpaceIDs = Array(Set(allSpaceIDs)).sorted()
                            let uniqueSpaceIDsMsg = "All unique space IDs found: \(uniqueSpaceIDs)\n"
                            writeToDebugFile(uniqueSpaceIDsMsg)
                            print("DEBUG: All unique space IDs found: \(uniqueSpaceIDs)")

                            // Create mapping based on sorted order
                            for (index, spaceID) in uniqueSpaceIDs.enumerated() {
                                let spaceNumber = index + 1
                                spaceIDToNumberMap[spaceID] = spaceNumber
                                let mappingMsg = "Mapped Space ID \(spaceID) to Space Number \(spaceNumber)\n"
                                writeToDebugFile(mappingMsg)
                                print("DEBUG: Mapped Space ID \(spaceID) to Space Number \(spaceNumber)")
                            }

                            let successMsg = "Successfully built initial space mapping: \(spaceIDToNumberMap)\n"
                            writeToDebugFile(successMsg)
                            print("DEBUG: Successfully built initial space mapping: \(spaceIDToNumberMap)")
                            return true
                        } else {
                            let noSpacesMsg = "No spaces found in Main monitor\n"
                            writeToDebugFile(noSpacesMsg)
                            print("DEBUG: No spaces found in Main monitor")
                        }
                    } else {
                        let noMonitorsMsg = "No Monitors array found in Management Data\n"
                        writeToDebugFile(noMonitorsMsg)
                    }
                } else {
                    let noManagementDataMsg = "No Management Data found in SpacesDisplayConfiguration\n"
                    writeToDebugFile(noManagementDataMsg)
                }
            } else {
                let noDisplayConfigMsg = "No SpacesDisplayConfiguration found\n"
                writeToDebugFile(noDisplayConfigMsg)
            }
        }

        // Don't call CGS here - it will freeze during init
        // Instead, rely on the spaces we found in UserDefaults
        // If we didn't find any spaces, we'll detect them lazily on first poll
        let fallbackMsg = "No spaces found in UserDefaults, will detect on first poll\n"
        writeToDebugFile(fallbackMsg)

        return false // Will use dynamic discovery
    }

    private func buildCompleteSpaceMapping() {
        // This method rebuilds the mapping when a new space is discovered
        // It should NOT call any CGS functions
        let msg = "Dynamic space discovery: rebuilding mapping from discovered spaces\n"
        writeToDebugFile(msg)

        // Sort the discovered space IDs and rebuild the mapping
        let discoveredSpaceIDs = Array(spaceIDToNumberMap.keys).sorted()

        let sortedSpaceIDsMsg = "Discovered space IDs: \(discoveredSpaceIDs)\n"
        writeToDebugFile(sortedSpaceIDsMsg)

        // Rebuild mapping based on sorted order
        spaceIDToNumberMap.removeAll()
        for (index, spaceID) in discoveredSpaceIDs.enumerated() {
            let spaceNumber = index + 1
            spaceIDToNumberMap[spaceID] = spaceNumber
            let mappingMsg = "Mapped Space ID \(spaceID) to Space Number \(spaceNumber) (index \(index))\n"
            writeToDebugFile(mappingMsg)
        }

        let completeMappingMsg = "Dynamic mapping built: \(spaceIDToNumberMap)\n"
        writeToDebugFile(completeMappingMsg)
    }
    
    func detectActualSpace() -> Int {
        // Use real Core Graphics Services to detect the current space
        // This is a simple, non-blocking version
        let connection = _CGSDefaultConnection()
        let spaceID = CGSGetActiveSpace(connection)

        let debugMsg = "Real CGS Detection - Space ID: \(spaceID)\n"
        writeToDebugFile(debugMsg)
        print("DEBUG: detectActualSpace - Space ID: \(spaceID)")

        // If we don't have a mapping for this space ID, add it to our discovered spaces
        if spaceIDToNumberMap[spaceID] == nil {
            let discoverMsg = "New space discovered: Space ID \(spaceID)\n"
            writeToDebugFile(discoverMsg)

            // Add the new space to our discovered spaces
            spaceIDToNumberMap[spaceID] = 0 // Temporary placeholder

            // Rebuild the complete mapping with all discovered spaces
            buildCompleteSpaceMapping()
        }

        // Use the mapping to get the space number
        if let spaceNumber = spaceIDToNumberMap[spaceID] {
            let resultMsg = "Found mapping: Space ID \(spaceID) -> Space Number \(spaceNumber)\n"
            writeToDebugFile(resultMsg)
            print("DEBUG: Found mapping: Space ID \(spaceID) -> Space Number \(spaceNumber)")
            print("DEBUG: FINAL RESULT: Returning space number \(spaceNumber)")
            return spaceNumber
        }

        // Fallback: use the space ID directly if we still can't find a match
        let spaceNumber = Int(spaceID)
        let resultMsg = "Fallback: Using Space ID \(spaceID) as Space Number \(spaceNumber)\n"
        writeToDebugFile(resultMsg)
        print("DEBUG: No mapping found for Space ID \(spaceID), current mapping: \(spaceIDToNumberMap)")
        print("DEBUG: Fallback: Using Space ID \(spaceID) as Space Number \(spaceNumber)")
        print("DEBUG: FINAL RESULT: Returning space number \(spaceNumber)")
        return spaceNumber
    }
    
    func defaultConnection() -> UInt32 {
        return 1 // Mock connection ID
    }
    
    func copyManagedDisplaySpaces(_ connection: UInt32) -> CFArray {
        // Since CGSManagedDisplaySpaces may not be available, we'll use a different approach
        // We'll discover spaces dynamically by monitoring space changes
        // For now, return an empty array to indicate we need to use dynamic discovery
        let msg = "Using dynamic space discovery instead of CGSManagedDisplaySpaces\n"
        writeToDebugFile(msg)
        return [] as CFArray
    }
    
    func copyActiveMenuBarDisplayIdentifier(_ connection: UInt32) -> CFString {
        return "Main" as CFString
    }
    
    private func writeToDebugFile(_ message: String) {
        // Asynchronously write to debug file to prevent blocking
        DispatchQueue.global(qos: .utility).async {
            let debugFilePath = "/tmp/spaceagent_debug.log"
            let timestamp = DateFormatter().string(from: Date())
            let logMessage = "[\(timestamp)] \(message.trimmingCharacters(in: .whitespacesAndNewlines))\n"
            
            if let data = logMessage.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: debugFilePath) {
                    // Append to existing file
                    if let fileHandle = FileHandle(forWritingAtPath: debugFilePath) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                    // Create new file
                    try? data.write(to: URL(fileURLWithPath: debugFilePath))
                }
            }
        }
    }
    
    /// Helper function to recursively dump the structure of a dictionary/array for debugging
    private func dumpStructure(_ object: Any, indent: Int) -> String {
        let indentString = String(repeating: "  ", count: indent)
        var result = ""
        
        if let dictionary = object as? [String: Any] {
            for (key, value) in dictionary {
                if let nestedDict = value as? [String: Any] {
                    result += "\(indentString)\(key): [Dictionary]\n"
                    result += dumpStructure(nestedDict, indent: indent + 1)
                } else if let nestedArray = value as? [Any] {
                    result += "\(indentString)\(key): [Array with \(nestedArray.count) items]\n"
                    for (index, item) in nestedArray.enumerated() {
                        result += "\(indentString)  [\(index)]: "
                        if let itemDict = item as? [String: Any] {
                            result += "[Dictionary]\n"
                            result += dumpStructure(itemDict, indent: indent + 2)
                        } else {
                            result += "\(item)\n"
                        }
                    }
                } else {
                    result += "\(indentString)\(key): \(value)\n"
                }
            }
        } else if let array = object as? [Any] {
            for (index, item) in array.enumerated() {
                result += "\(indentString)[\(index)]: "
                if let itemDict = item as? [String: Any] {
                    result += "[Dictionary]\n"
                    result += dumpStructure(itemDict, indent: indent + 1)
            } else {
                    result += "\(item)\n"
                }
            }
        } else {
            result += "\(indentString)\(object)\n"
        }
        
        return result
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
        if let realCGS = coreGraphicsService as? RealCoreGraphicsService,
           let initialSpace = realCGS.getCurrentSpaceFromDefaults() {
            currentSpaceNumber = initialSpace
            print("SpaceMonitor: Initial space from UserDefaults: \(initialSpace)")

            // Notify delegate of initial space
            DispatchQueue.main.async {
                self.delegate?.spaceDidChange(to: initialSpace, from: 0)
            }
        } else {
            // Fallback: start with space 1
            currentSpaceNumber = 1
            print("SpaceMonitor: Could not determine initial space, defaulting to 1")
        }

        print("SpaceMonitor: Init complete, will start polling in 3 seconds")

        // Start polling for space changes as fallback (delayed to avoid immediate CGS call)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            print("SpaceMonitor: Starting polling now")
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
                print(warningMsg)
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
        // Use much longer interval (5 seconds) to avoid blocking CGS calls
        // This is just a safety net - we rely primarily on app activation events
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            // Only poll if we're not already checking
            DispatchQueue.global(qos: .utility).async { [weak self] in
                self?.pollForSpaceChange()
            }
        }
        print("SpaceMonitor: Polling started with 5s interval (safety net)")
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
                print("SpaceMonitor: Already checking for space change, skipping...")
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
                self.writeToDebugFile(debugMsg)
                print("Polling: Space change detected: \(previousSpace) -> \(detectedSpace)")

                DispatchQueue.main.async {
                    print("SpaceMonitor: Calling delegate with space \(self.currentSpaceNumber)")
                    self.delegate?.spaceDidChange(to: self.currentSpaceNumber, from: previousSpace)
                }
            }
        }
    }

    @objc private func handleSpaceChange() {
        writeToDebugFile("NSWorkspace space change notification received!\n")
        
        // Detect the actual current space using Core Graphics Services
        let detectedSpace = detectCurrentSpaceNumber()
        
        // Only update if we detected a valid space and it's different from current
        if detectedSpace > 0 && detectedSpace != currentSpaceNumber {
        let previousSpace = currentSpaceNumber
            currentSpaceNumber = detectedSpace

            let debugMsg = "Real space change detected: \(previousSpace) -> \(currentSpaceNumber)\n"
        writeToDebugFile(debugMsg)
        print("Space change detected: \(previousSpace) -> \(currentSpaceNumber)")

            // Trigger shortcut for space change (temporarily disabled to prevent hanging)
            // triggerShortcut(for: currentSpaceNumber, from: previousSpace)

        DispatchQueue.main.async {
            print("SpaceMonitor: Calling delegate with space \(self.currentSpaceNumber)")
            self.delegate?.spaceDidChange(to: self.currentSpaceNumber, from: previousSpace)
        }
        } else {
            let debugMsg = "Space change notification received but no actual change detected (detected: \(detectedSpace), current: \(currentSpaceNumber))\n"
            writeToDebugFile(debugMsg)
        }
    }
    
    /// Triggers a shortcut using the command line tool when space changes
    private func triggerShortcut(for spaceNumber: Int, from previousSpace: Int) {
        // You can configure which shortcut to run here
        // For now, we'll use a placeholder - you can change this to any shortcut name
        let shortcutName = "Change default browser when space changes" // Change this to your desired shortcut name
        
        // Run shortcut execution asynchronously to prevent hanging
        DispatchQueue.global(qos: .background).async { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            
            // Pass the space number as simple text input
            let spaceNumberText = String(spaceNumber)
            
            do {
                // Create a temporary file with just the space number
                let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("space_number.txt")
                try spaceNumberText.write(to: tempFile, atomically: true, encoding: .utf8)
                
                let debugMsg = "📤 Sending space number to shortcut: \(spaceNumberText)\n"
                self?.writeToDebugFile(debugMsg)
                print("📤 Sending space number to shortcut: \(spaceNumberText)")
                
                process.arguments = ["run", shortcutName, "--input-path", tempFile.path]
                
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe
                
                let startMsg = "🚀 Starting shortcut execution: \(shortcutName)\n"
                self?.writeToDebugFile(startMsg)
                print("🚀 Starting shortcut execution: \(shortcutName)")
                
                try process.run()
                
                // Set a timeout to prevent hanging
                let timeout: TimeInterval = 10.0 // 10 second timeout
                let processCompleted = NSLock()
                var isCompleted = false
                
                // Set up timeout
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                    processCompleted.lock()
                    let completed = isCompleted
                    processCompleted.unlock()
                    
                    if !completed && process.isRunning {
                        print("⏰ Shortcut execution timed out after \(timeout) seconds")
                        process.terminate()
                        let timeoutMsg = "⏰ Shortcut '\(shortcutName)' timed out and was terminated\n"
                        self?.writeToDebugFile(timeoutMsg)
                    }
                }
                
                // Wait for process to complete
                process.waitUntilExit()
                
                processCompleted.lock()
                isCompleted = true
                processCompleted.unlock()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                
                let successMsg = "✅ Shortcut '\(shortcutName)' completed. Exit code: \(process.terminationStatus). Output: \(output)\n"
                self?.writeToDebugFile(successMsg)
                print("✅ Shortcut '\(shortcutName)' completed. Exit code: \(process.terminationStatus). Output: \(output)")
                
                // Clean up temp file
                try? FileManager.default.removeItem(at: tempFile)
                
            } catch {
                let errorMsg = "❌ Failed to execute shortcut '\(shortcutName)': \(error)\n"
                self?.writeToDebugFile(errorMsg)
                print("❌ Shortcut execution failed: \(error)")
            }
        }
    }
    
    

    private func detectCurrentSpaceNumber() -> Int {
        let logMessage = "🔍 Detecting current space using Core Graphics Services...\n"
        writeToDebugFile(logMessage)
        
        // Use the RealCoreGraphicsService to detect the actual space
        let detectedSpace = coreGraphicsService.detectActualSpace()
        
        let resultMsg = "Real CGS space detection: returning space \(detectedSpace)\n"
        writeToDebugFile(resultMsg)
        
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
            writeToDebugFile("Space detection timed out after \(timeout) seconds\n")
            print("⚠️ Space detection timed out, using current space: \(currentSpaceNumber)")
            return currentSpaceNumber // Return current space as fallback
        }
        
        return result
    }
    
    private func writeToDebugFile(_ message: String) {
        // Asynchronously write to debug file to prevent blocking
        DispatchQueue.global(qos: .utility).async {
            let debugFilePath = "/tmp/spaceagent_debug.log"
            let timestamp = DateFormatter().string(from: Date())
            let logMessage = "[\(timestamp)] \(message.trimmingCharacters(in: .whitespacesAndNewlines))\n"
            
            if let data = logMessage.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: debugFilePath) {
                    // Append to existing file
                    if let fileHandle = FileHandle(forWritingAtPath: debugFilePath) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                    // Create new file
                    try? data.write(to: URL(fileURLWithPath: debugFilePath))
                }
            }
        }
    }

    func updateCurrentSpace() {
        let detectedSpace = detectCurrentSpaceNumber()
        
        // Only trigger delegate if space actually changed
        if detectedSpace != currentSpaceNumber && detectedSpace > 0 {
            let previousSpace = currentSpaceNumber
            currentSpaceNumber = detectedSpace
            
            print("Space change detected: \(previousSpace) -> \(detectedSpace)")
            
            DispatchQueue.main.async {
                self.delegate?.spaceDidChange(to: detectedSpace, from: previousSpace)
            }
        }
    }

    // Method to manually set the current space (for testing or manual correction)
    func setCurrentSpace(_ spaceNumber: Int) {
        let previousSpace = currentSpaceNumber
        currentSpaceNumber = spaceNumber

        print("Manually set space to: \(spaceNumber)")

        DispatchQueue.main.async {
            self.delegate?.spaceDidChange(to: spaceNumber, from: previousSpace)
        }
    }
}
