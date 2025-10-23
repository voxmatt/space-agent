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
        mockDelegate?.reset()
        mockCoreGraphicsService?.reset()
        mockDelegate = nil
        mockCoreGraphicsService = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitializationWithMockService() {
        // Test that SpaceMonitor initializes correctly with mock service
        spaceMonitor = SpaceMonitor(coreGraphicsService: mockCoreGraphicsService)

        XCTAssertNotNil(spaceMonitor, "SpaceMonitor should initialize")
        XCTAssertEqual(spaceMonitor.getCurrentSpaceNumber(), 1, "Should initialize with space 1 from mock defaults")
    }

    func testInitializationWithRealService() {
        // Test with real Core Graphics Service
        let realService = RealCoreGraphicsService()
        spaceMonitor = SpaceMonitor(coreGraphicsService: realService)

        XCTAssertNotNil(spaceMonitor, "SpaceMonitor should initialize with real service")
        XCTAssertGreaterThanOrEqual(spaceMonitor.getCurrentSpaceNumber(), 1, "Should have a valid space number")
    }

    func testInitialSpaceFromDefaults() {
        // Test that initial space is read from UserDefaults (not CGS)
        mockCoreGraphicsService.currentSpaceFromDefaults = 3

        spaceMonitor = SpaceMonitor(coreGraphicsService: mockCoreGraphicsService)

        XCTAssertEqual(spaceMonitor.getCurrentSpaceNumber(), 3, "Should use space from defaults")
        XCTAssertEqual(mockCoreGraphicsService.getCurrentSpaceFromDefaultsCallCount, 1, "Should call getCurrentSpaceFromDefaults once during init")
    }

    func testInitialSpaceDefaultsWhenNoDefaults() {
        // Test fallback to space 1 when defaults return nil
        mockCoreGraphicsService.currentSpaceFromDefaults = nil

        spaceMonitor = SpaceMonitor(coreGraphicsService: mockCoreGraphicsService)

        XCTAssertEqual(spaceMonitor.getCurrentSpaceNumber(), 1, "Should default to space 1 when no defaults available")
    }

    func testInitialSpaceFromDifferentDefaults() {
        // Test initialization with various default space values
        let testSpaces = [1, 2, 5, 10]

        for testSpace in testSpaces {
            let mockService = MockCoreGraphicsService()
            mockService.currentSpaceFromDefaults = testSpace

            let monitor = SpaceMonitor(coreGraphicsService: mockService)

            XCTAssertEqual(monitor.getCurrentSpaceNumber(), testSpace, "Should initialize with space \(testSpace) from defaults")
        }
    }

    // MARK: - Delegate Tests

    func testDelegateAssignment() {
        spaceMonitor = SpaceMonitor(coreGraphicsService: mockCoreGraphicsService)
        spaceMonitor.delegate = mockDelegate

        XCTAssertNotNil(spaceMonitor.delegate, "Delegate should be set")
        XCTAssertTrue(spaceMonitor.delegate === mockDelegate, "Delegate should be the same instance")
    }

    func testDelegateWeakReference() {
        spaceMonitor = SpaceMonitor(coreGraphicsService: mockCoreGraphicsService)
        var weakDelegate: MockSpaceMonitorDelegate? = MockSpaceMonitorDelegate()
        spaceMonitor.delegate = weakDelegate

        XCTAssertNotNil(spaceMonitor.delegate, "Delegate should initially be set")

        // Release the delegate
        weakDelegate = nil

        // Delegate should be nil (weak reference)
        XCTAssertNil(spaceMonitor.delegate, "Delegate should be weak and nil after release")
    }

    func testMultipleDelegateReassignments() {
        spaceMonitor = SpaceMonitor(coreGraphicsService: mockCoreGraphicsService)

        let delegate1 = MockSpaceMonitorDelegate()
        let delegate2 = MockSpaceMonitorDelegate()

        spaceMonitor.delegate = delegate1
        XCTAssertTrue(spaceMonitor.delegate === delegate1, "Should assign first delegate")

        spaceMonitor.delegate = delegate2
        XCTAssertTrue(spaceMonitor.delegate === delegate2, "Should reassign to second delegate")

        spaceMonitor.delegate = nil
        XCTAssertNil(spaceMonitor.delegate, "Should be able to set delegate to nil")
    }

    // MARK: - getCurrentSpaceNumber Tests

    func testGetCurrentSpaceNumber() {
        mockCoreGraphicsService.currentSpaceFromDefaults = 4
        spaceMonitor = SpaceMonitor(coreGraphicsService: mockCoreGraphicsService)

        let currentSpace = spaceMonitor.getCurrentSpaceNumber()
        XCTAssertEqual(currentSpace, 4, "Should return current space number")
    }

    func testGetCurrentSpaceNumberConsistency() {
        mockCoreGraphicsService.currentSpaceFromDefaults = 2
        spaceMonitor = SpaceMonitor(coreGraphicsService: mockCoreGraphicsService)

        let space1 = spaceMonitor.getCurrentSpaceNumber()
        let space2 = spaceMonitor.getCurrentSpaceNumber()

        XCTAssertEqual(space1, space2, "Multiple calls should return same space number")
        XCTAssertEqual(space1, 2, "Should maintain space number of 2")
    }

    // MARK: - Mock Service Interaction Tests

    func testMockServiceIsUsedDuringInit() {
        // Verify that the mock service is actually used
        XCTAssertEqual(mockCoreGraphicsService.getCurrentSpaceFromDefaultsCallCount, 0, "Should start with 0 calls")

        spaceMonitor = SpaceMonitor(coreGraphicsService: mockCoreGraphicsService)

        XCTAssertEqual(mockCoreGraphicsService.getCurrentSpaceFromDefaultsCallCount, 1, "Should call getCurrentSpaceFromDefaults during init")
    }

    func testMockServiceDetectNotCalledDuringInit() {
        // Verify that detectActualSpace is NOT called during initialization
        XCTAssertEqual(mockCoreGraphicsService.detectActualSpaceCallCount, 0, "Should start with 0 detect calls")

        spaceMonitor = SpaceMonitor(coreGraphicsService: mockCoreGraphicsService)

        XCTAssertEqual(mockCoreGraphicsService.detectActualSpaceCallCount, 0, "Should NOT call detectActualSpace during init (reads from defaults)")
    }

    // MARK: - Edge Cases

    func testNilDelegateDoesNotCrash() {
        spaceMonitor = SpaceMonitor(coreGraphicsService: mockCoreGraphicsService)
        spaceMonitor.delegate = nil

        // Operations should work without delegate
        let space = spaceMonitor.getCurrentSpaceNumber()
        XCTAssertEqual(space, 1, "Should still return space number without delegate")
    }

    func testSpaceNumberBoundaries() {
        // Test with various space numbers
        let testSpaces = [1, 10, 50, 100, 999]

        for testSpace in testSpaces {
            let mockService = MockCoreGraphicsService()
            mockService.currentSpaceFromDefaults = testSpace
            let monitor = SpaceMonitor(coreGraphicsService: mockService)

            XCTAssertEqual(monitor.getCurrentSpaceNumber(), testSpace, "Should handle space number \(testSpace)")
        }
    }

    func testZeroSpaceFallback() {
        // Test edge case: if defaults somehow return 0 or negative
        // Note: This tests the mock behavior, real system would never return 0
        mockCoreGraphicsService.currentSpaceFromDefaults = 0

        spaceMonitor = SpaceMonitor(coreGraphicsService: mockCoreGraphicsService)

        // Should still initialize (space 0 is technically valid in the mock)
        XCTAssertEqual(spaceMonitor.getCurrentSpaceNumber(), 0, "Should accept space 0 from mock (edge case)")
    }

    // MARK: - Background Thread Safety Tests

    func testConcurrentGetCurrentSpaceNumber() {
        // Test that getCurrentSpaceNumber can be called from multiple threads
        spaceMonitor = SpaceMonitor(coreGraphicsService: mockCoreGraphicsService)

        let expectation = XCTestExpectation(description: "Concurrent access")
        expectation.expectedFulfillmentCount = 10

        let queue = DispatchQueue.global(qos: .userInitiated)

        for _ in 0..<10 {
            queue.async {
                let space = self.spaceMonitor.getCurrentSpaceNumber()
                XCTAssertGreaterThanOrEqual(space, 0, "Should return valid space number")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testInitializationDoesNotBlockMainThread() {
        // Test that initialization completes quickly (doesn't hang)
        let startTime = Date()

        spaceMonitor = SpaceMonitor(coreGraphicsService: mockCoreGraphicsService)

        let duration = Date().timeIntervalSince(startTime)

        XCTAssertLessThan(duration, 1.0, "Initialization should complete in less than 1 second")
        XCTAssertNotNil(spaceMonitor, "SpaceMonitor should initialize successfully")
    }

    // MARK: - Real Service Tests

    func testRealServiceInitialization() {
        // Test actual Core Graphics Service integration
        let realService = RealCoreGraphicsService()
        spaceMonitor = SpaceMonitor(coreGraphicsService: realService)

        XCTAssertNotNil(spaceMonitor, "Should initialize with real service")

        let currentSpace = spaceMonitor.getCurrentSpaceNumber()
        XCTAssertGreaterThanOrEqual(currentSpace, 1, "Real service should return valid space number")
        XCTAssertLessThanOrEqual(currentSpace, 100, "Real service space number should be reasonable")
    }

    func testRealServiceConsistency() {
        // Test that real service returns consistent results
        let realService = RealCoreGraphicsService()
        spaceMonitor = SpaceMonitor(coreGraphicsService: realService)

        let space1 = spaceMonitor.getCurrentSpaceNumber()
        let space2 = spaceMonitor.getCurrentSpaceNumber()

        XCTAssertEqual(space1, space2, "Real service should return consistent space number")
    }

    // MARK: - Protocol Conformance Tests

    func testMockConformsToProtocol() {
        // Verify mock conforms to protocol
        let service: CoreGraphicsServiceProtocol = mockCoreGraphicsService

        let space = service.detectActualSpace()
        XCTAssertEqual(space, 1, "Mock should return default space 1")

        let defaultsSpace = service.getCurrentSpaceFromDefaults()
        XCTAssertEqual(defaultsSpace, 1, "Mock should return default space 1 from defaults")
    }

    func testRealServiceConformsToProtocol() {
        // Verify real service conforms to protocol
        let service: CoreGraphicsServiceProtocol = RealCoreGraphicsService()

        let space = service.detectActualSpace()
        XCTAssertGreaterThanOrEqual(space, 1, "Real service should return valid space")

        // getCurrentSpaceFromDefaults may return nil
        if let defaultsSpace = service.getCurrentSpaceFromDefaults() {
            XCTAssertGreaterThanOrEqual(defaultsSpace, 1, "Space from defaults should be valid")
        }
    }
}
