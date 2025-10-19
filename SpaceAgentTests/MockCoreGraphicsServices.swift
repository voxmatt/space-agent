import Foundation
@testable import SpaceAgent

class MockCoreGraphicsService: CoreGraphicsServiceProtocol {
    private var _mockDisplaySpaces: NSArray = []
    private var _mockActiveDisplayIdentifier: NSString = "Main"
    var mockConnection: UInt32 = 12345

    var displaySpaceCallCount = 0
    var activeDisplayCallCount = 0
    var connectionCallCount = 0

    func defaultConnection() -> UInt32 {
        connectionCallCount += 1
        return mockConnection
    }

    func copyManagedDisplaySpaces(_ connection: UInt32) -> CFArray {
        displaySpaceCallCount += 1
        return _mockDisplaySpaces
    }

    func copyActiveMenuBarDisplayIdentifier(_ connection: UInt32) -> CFString {
        activeDisplayCallCount += 1
        return _mockActiveDisplayIdentifier
    }

    func setupMockSpaces(currentSpaceID: Int, totalSpaces: Int = 3, displayIdentifier: String = "Main") {
        var spaces: [[String: Any]] = []

        for i in 1...totalSpaces {
            spaces.append([
                "ManagedSpaceID": i * 100,
                "uuid": "space-\(i)-uuid"
            ])
        }

        let mockDisplay: [String: Any] = [
            "Display Identifier": displayIdentifier,
            "Current Space": [
                "ManagedSpaceID": currentSpaceID,
                "uuid": "current-space-uuid"
            ],
            "Spaces": spaces
        ]

        _mockDisplaySpaces = [mockDisplay] as NSArray
        _mockActiveDisplayIdentifier = displayIdentifier as NSString
    }

    func setupMockSpacesWithFullscreen(currentSpaceID: Int, totalSpaces: Int = 3, fullscreenSpaceID: Int? = nil) {
        var spaces: [[String: Any]] = []

        for i in 1...totalSpaces {
            var space: [String: Any] = [
                "ManagedSpaceID": i * 100,
                "uuid": "space-\(i)-uuid"
            ]

            if let fullscreenID = fullscreenSpaceID, i * 100 == fullscreenID {
                space["TileLayoutManager"] = ["someKey": "someValue"]
            }

            spaces.append(space)
        }

        let mockDisplay: [String: Any] = [
            "Display Identifier": "Main",
            "Current Space": [
                "ManagedSpaceID": currentSpaceID,
                "uuid": "current-space-uuid"
            ],
            "Spaces": spaces
        ]

        _mockDisplaySpaces = [mockDisplay] as NSArray
    }

    func reset() {
        displaySpaceCallCount = 0
        activeDisplayCallCount = 0
        connectionCallCount = 0
        _mockDisplaySpaces = []
        _mockActiveDisplayIdentifier = "Main"
        mockConnection = 12345
    }
}


class MockSpaceMonitorDelegate: SpaceMonitorDelegate {
    var spaceChangeCallCount = 0
    var lastSpaceChange: (to: Int, from: Int)?
    var allSpaceChanges: [(to: Int, from: Int)] = []

    func spaceDidChange(to spaceNumber: Int, from previousSpace: Int) {
        spaceChangeCallCount += 1
        lastSpaceChange = (to: spaceNumber, from: previousSpace)
        allSpaceChanges.append((to: spaceNumber, from: previousSpace))
    }

    func reset() {
        spaceChangeCallCount = 0
        lastSpaceChange = nil
        allSpaceChanges.removeAll()
    }
}