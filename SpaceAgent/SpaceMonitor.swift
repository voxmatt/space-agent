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
        
        // Build the complete space mapping during initialization
        buildCompleteSpaceMapping()
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
        let fileURL = URL(fileURLWithPath: "/tmp/spaceagent_debug.log")
        if let data = message.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: fileURL)
            }
        }
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

            // Trigger shortcut for space change
            triggerShortcut(for: currentSpaceNumber, from: previousSpace)

            DispatchQueue.main.async {
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
                let startTime = Date()
                
                while process.isRunning {
                    if Date().timeIntervalSince(startTime) > timeout {
                        print("⏰ Shortcut execution timed out after \(timeout) seconds")
                        process.terminate()
                        break
                    }
                    usleep(100000) // Sleep for 0.1 seconds
                }
                
                if process.isRunning {
                    process.terminate()
                    let timeoutMsg = "⏰ Shortcut '\(shortcutName)' timed out and was terminated\n"
                    self?.writeToDebugFile(timeoutMsg)
                    print("⏰ Shortcut '\(shortcutName)' timed out and was terminated")
                } else {
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    
                    let successMsg = "✅ Shortcut '\(shortcutName)' completed. Exit code: \(process.terminationStatus). Output: \(output)\n"
                    self?.writeToDebugFile(successMsg)
                    print("✅ Shortcut '\(shortcutName)' completed. Exit code: \(process.terminationStatus). Output: \(output)")
                }
                
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
    
    private func writeToDebugFile(_ message: String) {
        let fileURL = URL(fileURLWithPath: "/tmp/spaceagent_debug.log")
        if let data = message.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: fileURL)
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

protocol SpaceChangeNotifierProtocol {
    func notifySpaceChange(to spaceNumber: Int, from previousSpace: Int) -> Bool
}

class FileBasedSpaceNotifier: SpaceChangeNotifierProtocol {
    private let triggerFileURL: URL

    init() {
        // Create trigger file in user's home directory
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        self.triggerFileURL = homeURL.appendingPathComponent(".space-agent-trigger")

        // Create the file if it doesn't exist
        if !FileManager.default.fileExists(atPath: triggerFileURL.path) {
            FileManager.default.createFile(atPath: triggerFileURL.path, contents: nil, attributes: nil)
        }
    }

    func notifySpaceChange(to spaceNumber: Int, from previousSpace: Int) -> Bool {
        let timestamp = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        let spaceChangeInfo = """
        {
            "timestamp": "\(formatter.string(from: timestamp))",
            "currentSpace": \(spaceNumber),
            "previousSpace": \(previousSpace),
            "unixTimestamp": \(timestamp.timeIntervalSince1970)
        }
        """

        do {
            try spaceChangeInfo.write(to: triggerFileURL, atomically: true, encoding: .utf8)
            print("Space change written to trigger file: \(previousSpace) -> \(spaceNumber)")
            return true
        } catch {
            print("Failed to write space change to trigger file: \(error)")
            return false
        }
    }
}