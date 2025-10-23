import Foundation
@testable import SpaceAgent

/// Mock implementation of CoreGraphicsServiceProtocol for testing
class MockCoreGraphicsService: CoreGraphicsServiceProtocol {
    var spaceToReturn: Int = 1
    var detectActualSpaceCallCount: Int = 0
    var getCurrentSpaceFromDefaultsCallCount: Int = 0
    var currentSpaceFromDefaults: Int? = 1

    func detectActualSpace() -> Int {
        detectActualSpaceCallCount += 1
        return spaceToReturn
    }

    func getCurrentSpaceFromDefaults() -> Int? {
        getCurrentSpaceFromDefaultsCallCount += 1
        return currentSpaceFromDefaults
    }

    func reset() {
        spaceToReturn = 1
        detectActualSpaceCallCount = 0
        getCurrentSpaceFromDefaultsCallCount = 0
        currentSpaceFromDefaults = 1
    }
}

/// Mock implementation of SpaceMonitorDelegate for testing
class MockSpaceMonitorDelegate: SpaceMonitorDelegate {
    var spaceChangeCallCount: Int = 0
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
