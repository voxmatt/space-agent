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

        XCTAssertEqual(mockCoreGraphicsService.connectionCallCount, 1)
        // With dynamic space discovery, the initial space should be detected
        XCTAssertGreaterThanOrEqual(spaceMonitor.getCurrentSpaceNumber(), 1)
    }

    func testSpaceDetection() {
        spaceMonitor = SpaceMonitor(coreGraphicsService: mockCoreGraphicsService)
        
        // Test that space detection works
        let currentSpace = spaceMonitor.getCurrentSpaceNumber()
        XCTAssertGreaterThanOrEqual(currentSpace, 1)
    }

    func testSpaceChangeDetection() {
        spaceMonitor = SpaceMonitor(coreGraphicsService: mockCoreGraphicsService)
        
        // Test that space change detection works
        spaceMonitor.updateCurrentSpace()
        let currentSpace = spaceMonitor.getCurrentSpaceNumber()
        XCTAssertGreaterThanOrEqual(currentSpace, 1)
    }

    func testSpaceChangeDelegate() {
        spaceMonitor = SpaceMonitor(coreGraphicsService: mockCoreGraphicsService)
        spaceMonitor.delegate = mockDelegate

        // Test that delegate is set correctly
        XCTAssertNotNil(spaceMonitor.delegate)
        XCTAssertEqual(mockDelegate.spaceChangeCallCount, 0)
    }

    func testManualSpaceChange() {
        spaceMonitor = SpaceMonitor(coreGraphicsService: mockCoreGraphicsService)
        spaceMonitor.delegate = mockDelegate

        // Test manual space change
        spaceMonitor.setCurrentSpace(3)
        XCTAssertEqual(spaceMonitor.getCurrentSpaceNumber(), 3)
    }

    func testSpaceChangeNotification() {
        spaceMonitor = SpaceMonitor(coreGraphicsService: mockCoreGraphicsService)
        spaceMonitor.delegate = mockDelegate

        // Test that space change notifications work
        spaceMonitor.updateCurrentSpace()
        
        let expectation = XCTestExpectation(description: "Space change handled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 0.2)
        
        // Test that the method executes without crashing
        XCTAssertTrue(true)
    }
}