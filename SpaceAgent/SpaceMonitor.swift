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
    
    init() {
        let debugMsg = "Initializing RealCoreGraphicsService with real Core Graphics Services\n"
        writeToDebugFile(debugMsg)
        
        // Try to get all spaces at initialization using public APIs
        if !buildInitialSpaceMapping() {
            // Fallback to dynamic discovery if initial mapping fails
            buildCompleteSpaceMapping()
        }
    }
    
    /// Attempts to build space mapping using public APIs at initialization
    /// Returns true if successful, false if we need to fall back to dynamic discovery
    private func buildInitialSpaceMapping() -> Bool {
        let msg = "Attempting to build initial space mapping using public APIs\n"
        writeToDebugFile(msg)
        
        // Method 1: Try to get spaces from NSUserDefaults
        if let spacesConfig = UserDefaults.standard.object(forKey: "com.apple.spaces") as? [String: Any] {
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
            
            // Parse the spaces configuration - the structure is:
            // SpacesDisplayConfiguration.Monitors[0].Spaces
            if let displayConfig = spacesConfig["SpacesDisplayConfiguration"] as? [String: Any] {
                let displayConfigMsg = "Found SpacesDisplayConfiguration\n"
                writeToDebugFile(displayConfigMsg)
                
                if let monitors = displayConfig["Monitors"] as? [[String: Any]] {
                    let monitorsMsg = "Found \(monitors.count) monitors\n"
                    writeToDebugFile(monitorsMsg)
                    
                    if let mainMonitor = monitors.first {
                        let mainMonitorMsg = "Main monitor keys: \(Array(mainMonitor.keys))\n"
                        writeToDebugFile(mainMonitorMsg)
                        
                        if let spaces = mainMonitor["Spaces"] as? [[String: Any]] {
                            let spacesCountMsg = "Found \(spaces.count) spaces in configuration\n"
                            writeToDebugFile(spacesCountMsg)
                            
                            var spaceIDs: [UInt32] = []
                            
                            for (index, space) in spaces.enumerated() {
                                // Try to extract space ID from various possible keys
                                var spaceID: UInt32? = nil
                                
                                if let managedSpaceID = space["ManagedSpaceID"] as? UInt32 {
                                    spaceID = managedSpaceID
                                } else if let id64 = space["id64"] as? UInt64 {
                                    spaceID = UInt32(id64)
                                } else if let uuid = space["uuid"] as? String, !uuid.isEmpty {
                                    // Convert UUID to a numeric ID (simplified approach)
                                    spaceID = UInt32(uuid.hashValue & 0xFFFFFFFF)
                                }
                                
                                if let id = spaceID {
                                    spaceIDs.append(id)
                                    let spaceMsg = "Space \(index + 1): ManagedSpaceID \(id)\n"
                                    writeToDebugFile(spaceMsg)
                                }
                            }
                            
                            if !spaceIDs.isEmpty {
                                // Sort space IDs and create mapping
                                spaceIDs.sort()
                                
                                for (index, spaceID) in spaceIDs.enumerated() {
                                    let spaceNumber = index + 1
                                    spaceIDToNumberMap[spaceID] = spaceNumber
                                    let mappingMsg = "Mapped Space ID \(spaceID) to Space Number \(spaceNumber)\n"
                                    writeToDebugFile(mappingMsg)
                                }
                                
                                let successMsg = "Successfully built initial space mapping: \(spaceIDToNumberMap)\n"
                                writeToDebugFile(successMsg)
                                return true
                            }
                        } else {
                            let noSpacesMsg = "No Spaces array found in main monitor\n"
                            writeToDebugFile(noSpacesMsg)
                        }
                    } else {
                        let noMainMonitorMsg = "No main monitor found\n"
                        writeToDebugFile(noMainMonitorMsg)
                    }
                } else {
                    let noMonitorsMsg = "No Monitors array found\n"
                    writeToDebugFile(noMonitorsMsg)
                }
            } else {
                let noDisplayConfigMsg = "No SpacesDisplayConfiguration found\n"
                writeToDebugFile(noDisplayConfigMsg)
            }
        }
        
        // Method 2: Try window-based space detection
        let windowSpaceIDs = detectSpacesUsingWindows()
        if !windowSpaceIDs.isEmpty {
            // Sort space IDs and create mapping
            for (index, spaceID) in windowSpaceIDs.enumerated() {
                let spaceNumber = index + 1
                spaceIDToNumberMap[spaceID] = spaceNumber
                let mappingMsg = "Window-based mapping: Space ID \(spaceID) -> Space Number \(spaceNumber)\n"
                writeToDebugFile(mappingMsg)
            }
            
            let successMsg = "Successfully built window-based space mapping: \(spaceIDToNumberMap)\n"
            writeToDebugFile(successMsg)
            return true
        }
        
        // Method 3: Fallback to current space only
        let connection = _CGSDefaultConnection()
        let currentSpaceID = CGSGetActiveSpace(connection)
        
        let currentSpaceMsg = "Current space ID detected: \(currentSpaceID)\n"
        writeToDebugFile(currentSpaceMsg)
        
        // At minimum, map the current space to 1
        spaceIDToNumberMap[currentSpaceID] = 1
        
        let fallbackMsg = "Built minimal mapping with current space: \(spaceIDToNumberMap)\n"
        writeToDebugFile(fallbackMsg)
        
        return true // We have at least the current space mapped
    }
    
    /// Alternative method: Use window-based space detection
    private func detectSpacesUsingWindows() -> [UInt32] {
        let msg = "Attempting window-based space detection\n"
        writeToDebugFile(msg)
        
        // Get all on-screen windows
        guard let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
            let errorMsg = "Failed to get window list\n"
            writeToDebugFile(errorMsg)
            return []
        }
        
        let windowCountMsg = "Found \(windowList.count) on-screen windows\n"
        writeToDebugFile(windowCountMsg)
        
        // Extract space IDs from windows
        var spaceIDs: Set<UInt32> = []
        
        for window in windowList {
            if let spaceID = window["kCGWindowWorkspace"] as? UInt32 {
                spaceIDs.insert(spaceID)
                let windowMsg = "Window on space ID: \(spaceID)\n"
                writeToDebugFile(windowMsg)
            }
        }
        
        let detectedSpacesMsg = "Detected spaces via windows: \(Array(spaceIDs).sorted())\n"
        writeToDebugFile(detectedSpacesMsg)
        
        return Array(spaceIDs).sorted()
    }
    
    private func buildCompleteSpaceMapping() {
        // Since we can't reliably get all spaces upfront, we'll use dynamic discovery
        // This method will be called when we encounter an unknown space ID
        let msg = "Dynamic space discovery: building mapping from discovered spaces\n"
        writeToDebugFile(msg)
        
        // Get the current space ID to start with
        let connection = _CGSDefaultConnection()
        let currentSpaceID = CGSGetActiveSpace(connection)
        
        // If we have no spaces discovered yet, start with the current one
        if spaceIDToNumberMap.isEmpty {
            spaceIDToNumberMap[currentSpaceID] = 1
            let msg = "Initial space discovered: Space ID \(currentSpaceID) -> Space Number 1\n"
            writeToDebugFile(msg)
        }
        
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
        let connection = _CGSDefaultConnection()
        let spaceID = CGSGetActiveSpace(connection)

        let debugMsg = "Real CGS Detection - Space ID: \(spaceID)\n"
        writeToDebugFile(debugMsg)

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
            return spaceNumber
        }

        // Fallback: use the space ID directly if we still can't find a match
        let spaceNumber = Int(spaceID)
        let resultMsg = "Fallback: Using Space ID \(spaceID) as Space Number \(spaceNumber)\n"
        writeToDebugFile(resultMsg)
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
        // Simplified debug logging to prevent hanging
        print("DEBUG: \(message.trimmingCharacters(in: .whitespacesAndNewlines))")
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

    init(coreGraphicsService: CoreGraphicsServiceProtocol = RealCoreGraphicsService()) {
        self.coreGraphicsService = coreGraphicsService
        
        // Check for multiple instances
        checkForMultipleInstances()
        
        setupMonitoring()
        // Detect initial space
        currentSpaceNumber = detectCurrentSpaceNumber()
        print("SpaceMonitor: Initial space detected: \(currentSpaceNumber)")
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
        // Listen for space change notifications
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSpaceChange),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
    }

    private func stopMonitoring() {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
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
        // Simplified debug logging to prevent hanging
        print("DEBUG: \(message.trimmingCharacters(in: .whitespacesAndNewlines))")
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
