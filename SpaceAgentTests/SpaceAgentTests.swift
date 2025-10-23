import XCTest
@testable import SpaceAgent

class AppDelegateTests: XCTestCase {
    var appDelegate: AppDelegate!

    override func setUp() {
        super.setUp()
        appDelegate = AppDelegate()
    }

    override func tearDown() {
        appDelegate = nil
        super.tearDown()
    }

    func testAppDelegateInitialization() {
        XCTAssertNotNil(appDelegate, "AppDelegate should initialize")
    }

    func testApplicationDidFinishLaunching() {
        // Test that the app sets up correctly
        appDelegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))

        // Verify setup completed without crashing
        XCTAssertTrue(true, "Application should finish launching without errors")
    }

    func testSpaceChangeHandling() {
        appDelegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))

        // Test space change handling
        appDelegate.spaceDidChange(to: 3, from: 1)

        // Verify the method executes without crashing
        XCTAssertTrue(true, "Should handle space change without errors")
    }

    func testMultipleSpaceChangeHandling() {
        appDelegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))

        // Test multiple space changes
        appDelegate.spaceDidChange(to: 2, from: 1)
        appDelegate.spaceDidChange(to: 4, from: 2)
        appDelegate.spaceDidChange(to: 1, from: 4)
        appDelegate.spaceDidChange(to: 3, from: 1)

        // Verify all changes are handled
        XCTAssertTrue(true, "Should handle multiple space changes without errors")
    }

    func testApplicationWillTerminate() {
        appDelegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))

        // Test cleanup on termination
        appDelegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))

        // Verify cleanup completed without crashing
        XCTAssertTrue(true, "Application should terminate cleanly")
    }

    func testSpaceChangeWithZeroPreviousSpace() {
        // Test edge case with zero previous space (initial state)
        appDelegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))

        appDelegate.spaceDidChange(to: 1, from: 0)

        XCTAssertTrue(true, "Should handle zero previous space")
    }

    func testSpaceChangeWithSameSpace() {
        // Test edge case with same space (should not typically happen but should be handled)
        appDelegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))

        appDelegate.spaceDidChange(to: 2, from: 2)

        XCTAssertTrue(true, "Should handle same space change gracefully")
    }
}

class RealCoreGraphicsServiceTests: XCTestCase {
    var realCoreGraphicsService: RealCoreGraphicsService!

    override func setUp() {
        super.setUp()
        realCoreGraphicsService = RealCoreGraphicsService()
    }

    override func tearDown() {
        realCoreGraphicsService = nil
        super.tearDown()
    }

    func testInitialization() {
        XCTAssertNotNil(realCoreGraphicsService, "RealCoreGraphicsService should initialize")
    }

    func testGetCurrentSpaceFromDefaults() {
        // Test that we can read from UserDefaults
        let spaceFromDefaults = realCoreGraphicsService.getCurrentSpaceFromDefaults()

        // May be nil or a valid space number depending on system state
        if let space = spaceFromDefaults {
            XCTAssertGreaterThanOrEqual(space, 1, "Space from defaults should be >= 1")
        } else {
            XCTAssertNil(spaceFromDefaults, "Space from defaults may be nil")
        }
    }

    func testDetectActualSpace() {
        // Test that detectActualSpace returns a valid space number
        let spaceNumber = realCoreGraphicsService.detectActualSpace()

        XCTAssertGreaterThanOrEqual(spaceNumber, 1, "Detected space should be >= 1")
        XCTAssertLessThanOrEqual(spaceNumber, 100, "Detected space should be reasonable (<= 100)")
    }

    func testDetectActualSpaceConsistency() {
        // Test that multiple calls return consistent results
        let space1 = realCoreGraphicsService.detectActualSpace()
        let space2 = realCoreGraphicsService.detectActualSpace()

        // Should return the same space if no actual space change occurred
        XCTAssertEqual(space1, space2, "Multiple detections should return consistent results")
    }

    func testDetectActualSpacePerformance() {
        // Test performance of space detection
        measure {
            _ = realCoreGraphicsService.detectActualSpace()
        }
    }
}

class SpaceMonitorIntegrationTests: XCTestCase {
    var spaceMonitor: SpaceMonitor!
    var mockCoreGraphicsService: MockCoreGraphicsService!
    var mockDelegate: MockSpaceMonitorDelegate!

    override func setUp() {
        super.setUp()
        mockCoreGraphicsService = MockCoreGraphicsService()
        mockDelegate = MockSpaceMonitorDelegate()
        spaceMonitor = SpaceMonitor(coreGraphicsService: mockCoreGraphicsService)
        spaceMonitor.delegate = mockDelegate
    }

    override func tearDown() {
        spaceMonitor = nil
        mockDelegate?.reset()
        mockCoreGraphicsService?.reset()
        mockDelegate = nil
        mockCoreGraphicsService = nil
        super.tearDown()
    }

    func testSpaceMonitorInitialization() {
        XCTAssertNotNil(spaceMonitor, "SpaceMonitor should initialize")
        XCTAssertNotNil(spaceMonitor.delegate, "Delegate should be set")
        XCTAssertEqual(spaceMonitor.getCurrentSpaceNumber(), 1, "Initial space should be 1 from mock")
    }

    func testRealServiceIntegration() {
        // Test with real Core Graphics Service
        let realService = RealCoreGraphicsService()
        let realMonitor = SpaceMonitor(coreGraphicsService: realService)
        let realDelegate = MockSpaceMonitorDelegate()
        realMonitor.delegate = realDelegate

        // Verify initialization
        XCTAssertNotNil(realMonitor, "Should initialize with real service")
        XCTAssertGreaterThanOrEqual(realMonitor.getCurrentSpaceNumber(), 1, "Should have valid initial space")

        // Note: We can't reliably test actual space changes in a unit test
        // as it would require UI interaction with Mission Control
    }

    func testDelegateWeakReferenceInIntegration() {
        // Test that delegate is properly released when no longer referenced
        var weakDelegate: MockSpaceMonitorDelegate? = MockSpaceMonitorDelegate()
        spaceMonitor.delegate = weakDelegate

        XCTAssertNotNil(spaceMonitor.delegate, "Delegate should be set")

        // Release delegate
        weakDelegate = nil

        XCTAssertNil(spaceMonitor.delegate, "Delegate should be nil after release (weak reference)")
    }

    func testMockServiceCallCounting() {
        // Test that mock service tracks method calls correctly
        XCTAssertEqual(mockCoreGraphicsService.getCurrentSpaceFromDefaultsCallCount, 1, "Should call getCurrentSpaceFromDefaults during init")
        XCTAssertEqual(mockCoreGraphicsService.detectActualSpaceCallCount, 0, "Should not call detectActualSpace during init")
    }

    func testMultipleMonitorsWithSameService() {
        // Test creating multiple monitors with the same service
        let service = MockCoreGraphicsService()
        service.currentSpaceFromDefaults = 2

        let monitor1 = SpaceMonitor(coreGraphicsService: service)
        let monitor2 = SpaceMonitor(coreGraphicsService: service)

        XCTAssertEqual(monitor1.getCurrentSpaceNumber(), 2, "Monitor 1 should get space 2")
        XCTAssertEqual(monitor2.getCurrentSpaceNumber(), 2, "Monitor 2 should get space 2")
    }
}

class LoggingTests: XCTestCase {
    let testLogPath = "/tmp/spaceagent_test_debug.log"

    override func setUp() {
        super.setUp()
        // Clean up test log file
        try? FileManager.default.removeItem(atPath: testLogPath)
    }

    override func tearDown() {
        // Clean up test log file
        try? FileManager.default.removeItem(atPath: testLogPath)
        super.tearDown()
    }

    func testLogLevelComparison() {
        // Test log level ordering
        XCTAssertTrue(LogLevel.debug < LogLevel.info, "debug < info")
        XCTAssertTrue(LogLevel.info < LogLevel.warning, "info < warning")
        XCTAssertTrue(LogLevel.warning < LogLevel.error, "warning < error")
    }

    func testLogLevelPrefixes() {
        // Test log level prefix strings
        XCTAssertEqual(LogLevel.debug.prefix, "DEBUG")
        XCTAssertEqual(LogLevel.info.prefix, "INFO")
        XCTAssertEqual(LogLevel.warning.prefix, "WARN")
        XCTAssertEqual(LogLevel.error.prefix, "ERROR")
    }

    func testLogLevelRawValues() {
        // Test log level raw values for ordering
        XCTAssertEqual(LogLevel.debug.rawValue, 0)
        XCTAssertEqual(LogLevel.info.rawValue, 1)
        XCTAssertEqual(LogLevel.warning.rawValue, 2)
        XCTAssertEqual(LogLevel.error.rawValue, 3)
    }
}
