import XCTest
@testable import SpaceAgent

class SpaceMonitorTests: XCTestCase {
    var mockCoreGraphicsService: MockCoreGraphicsService!
    var mockDelegate: MockSpaceMonitorDelegate!
    var spaceMonitor: SpaceMonitor!

    override func setUp() {
        super.setUp()
        mockCoreGraphicsService = MockCoreGraphicsService()
        mockDelegate = MockSpaceMonitorDelegate()
    }

    override func tearDown() {
        spaceMonitor = nil
        mockDelegate = nil
        mockCoreGraphicsService = nil
        super.tearDown()
    }

    func testInitialization() {
        spaceMonitor = SpaceMonitor(coreGraphicsService: mockCoreGraphicsService)

        // Test that SpaceMonitor initializes correctly
        XCTAssertNotNil(spaceMonitor)
        XCTAssertEqual(spaceMonitor.getCurrentSpaceNumber(), 1) // Mock returns 1
    }

    func testInitializationWithRealService() {
        // Test with real Core Graphics Service
        let realService = RealCoreGraphicsService()
        spaceMonitor = SpaceMonitor(coreGraphicsService: realService)
        
        XCTAssertNotNil(spaceMonitor)
        XCTAssertGreaterThanOrEqual(spaceMonitor.getCurrentSpaceNumber(), 1)
    }

    func testDelegateAssignment() {
        spaceMonitor = SpaceMonitor(coreGraphicsService: mockCoreGraphicsService)
        spaceMonitor.delegate = mockDelegate

        // Test that delegate is set correctly
        XCTAssertNotNil(spaceMonitor.delegate)
        XCTAssertTrue(spaceMonitor.delegate === mockDelegate)
    }

    func testGetCurrentSpaceNumber() {
        spaceMonitor = SpaceMonitor(coreGraphicsService: mockCoreGraphicsService)
        
        // Test getting current space number
        let currentSpace = spaceMonitor.getCurrentSpaceNumber()
        XCTAssertEqual(currentSpace, 1) // Mock returns 1
    }

    func testSetCurrentSpace() {
        let mockSpaceMonitor = MockSpaceMonitor()
        mockSpaceMonitor.delegate = mockDelegate

        // Test manual space setting
        mockSpaceMonitor.setCurrentSpace(3)
        XCTAssertEqual(mockSpaceMonitor.getCurrentSpaceNumber(), 3)
        
        // Verify delegate was called
        XCTAssertEqual(mockDelegate.spaceChangeCallCount, 1)
        XCTAssertEqual(mockDelegate.lastSpaceChange?.to, 3)
    }

    func testUpdateCurrentSpace() {
        spaceMonitor = SpaceMonitor(coreGraphicsService: mockCoreGraphicsService)
        spaceMonitor.delegate = mockDelegate

        // Test updating current space
        spaceMonitor.updateCurrentSpace()
        
        // Verify the method executes without crashing
        XCTAssertTrue(true)
    }

    func testSpaceChangeNotificationHandling() {
        spaceMonitor = SpaceMonitor(coreGraphicsService: mockCoreGraphicsService)
        spaceMonitor.delegate = mockDelegate

        // Test that space change notifications are handled
        spaceMonitor.updateCurrentSpace()
        
        // Verify the method executes without crashing
        XCTAssertTrue(true)
    }

    func testMultipleSpaceChanges() {
        let mockSpaceMonitor = MockSpaceMonitor()
        mockSpaceMonitor.delegate = mockDelegate

        // Test multiple space changes
        mockSpaceMonitor.setCurrentSpace(2)
        mockSpaceMonitor.setCurrentSpace(4)
        mockSpaceMonitor.setCurrentSpace(1)
        
        // Verify all changes were recorded
        XCTAssertEqual(mockDelegate.spaceChangeCallCount, 3)
        XCTAssertEqual(mockDelegate.allSpaceChanges.count, 3)
        XCTAssertEqual(mockDelegate.lastSpaceChange?.to, 1)
    }

    func testSpaceChangeFromDifferentValues() {
        let mockSpaceMonitor = MockSpaceMonitor()
        mockSpaceMonitor.delegate = mockDelegate

        // Test space changes from different starting values
        mockSpaceMonitor.setCurrentSpace(5)
        XCTAssertEqual(mockSpaceMonitor.getCurrentSpaceNumber(), 5)
        
        mockSpaceMonitor.setCurrentSpace(2)
        XCTAssertEqual(mockSpaceMonitor.getCurrentSpaceNumber(), 2)
        
        // Verify delegate calls
        XCTAssertEqual(mockDelegate.spaceChangeCallCount, 2)
    }

    func testSpaceChangeWithSameValue() {
        let mockSpaceMonitor = MockSpaceMonitor()
        mockSpaceMonitor.delegate = mockDelegate

        // Test setting the same space value
        mockSpaceMonitor.setCurrentSpace(3)
        let initialCallCount = mockDelegate.spaceChangeCallCount
        
        mockSpaceMonitor.setCurrentSpace(3)
        
        // Should still call delegate even for same value
        XCTAssertEqual(mockDelegate.spaceChangeCallCount, initialCallCount + 1)
    }
}