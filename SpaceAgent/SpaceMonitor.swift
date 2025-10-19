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
        setupMonitoring()
        // Detect initial space
        currentSpaceNumber = detectCurrentSpaceNumber()
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

            DispatchQueue.main.async {
                self.delegate?.spaceDidChange(to: self.currentSpaceNumber, from: previousSpace)
            }
        } else {
            let debugMsg = "Space change notification received but no actual change detected (detected: \(detectedSpace), current: \(currentSpaceNumber))\n"
            writeToDebugFile(debugMsg)
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