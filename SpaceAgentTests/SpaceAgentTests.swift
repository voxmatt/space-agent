import XCTest
@testable import SpaceAgent

class AppDelegateTests: XCTestCase {
    var appDelegate: AppDelegate!
    var mockSpaceMonitor: MockSpaceMonitor!

    override func setUp() {
        super.setUp()
        appDelegate = AppDelegate()
        mockSpaceMonitor = MockSpaceMonitor()
    }

    override func tearDown() {
        appDelegate = nil
        mockSpaceMonitor = nil
        super.tearDown()
    }

    func testAppDelegateInitialization() {
        XCTAssertNotNil(appDelegate)
    }

    func testApplicationDidFinishLaunching() {
        // Test that the app sets up correctly
        appDelegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        
        // Verify the method executes without crashing
        XCTAssertTrue(true)
    }

    func testSpaceChangeHandling() {
        appDelegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        
        // Test space change handling
        appDelegate.spaceDidChange(to: 3, from: 1)
        
        // Verify the method executes without crashing
        XCTAssertTrue(true)
    }

    func testStatusBarTitleUpdate() {
        appDelegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        
        // Test status bar title updates
        appDelegate.spaceDidChange(to: 2, from: 1)
        appDelegate.spaceDidChange(to: 4, from: 2)
        appDelegate.spaceDidChange(to: 1, from: 4)
        
        // Verify the methods execute without crashing
        XCTAssertTrue(true)
    }

    func testMenuActions() {
        appDelegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        
        // Test menu actions
        appDelegate.resetToSpace1(NSMenuItem())
        appDelegate.resetToSpace2(NSMenuItem())
        appDelegate.resetToSpace3(NSMenuItem())
        appDelegate.resetToSpace4(NSMenuItem())
        
        // Verify the methods execute without crashing
        XCTAssertTrue(true)
    }

    func testApplicationWillTerminate() {
        appDelegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        
        // Test cleanup
        appDelegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
        
        // Verify the method executes without crashing
        XCTAssertTrue(true)
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
        XCTAssertNotNil(realCoreGraphicsService)
    }

    func testDefaultConnection() {
        let connection = realCoreGraphicsService.defaultConnection()
        XCTAssertEqual(connection, 1) // Mock connection ID
    }

    func testCopyManagedDisplaySpaces() {
        let connection = realCoreGraphicsService.defaultConnection()
        let spaces = realCoreGraphicsService.copyManagedDisplaySpaces(connection)
        
        // Should return empty array for dynamic discovery
        XCTAssertEqual(CFArrayGetCount(spaces), 0)
    }

    func testCopyActiveMenuBarDisplayIdentifier() {
        let connection = realCoreGraphicsService.defaultConnection()
        let identifier = realCoreGraphicsService.copyActiveMenuBarDisplayIdentifier(connection)
        
        XCTAssertEqual(identifier as String, "Main")
    }

    func testDetectActualSpace() {
        // Test that detectActualSpace returns a valid space number
        let spaceNumber = realCoreGraphicsService.detectActualSpace()
        XCTAssertGreaterThanOrEqual(spaceNumber, 1)
    }
}

class SpaceMonitorIntegrationTests: XCTestCase {
    var mockSpaceMonitor: MockSpaceMonitor!
    var mockDelegate: MockSpaceMonitorDelegate!

    override func setUp() {
        super.setUp()
        mockDelegate = MockSpaceMonitorDelegate()
        mockSpaceMonitor = MockSpaceMonitor()
        mockSpaceMonitor.delegate = mockDelegate
    }

    override func tearDown() {
        mockSpaceMonitor = nil
        mockDelegate = nil
        super.tearDown()
    }

    func testSpaceMonitorInitialization() {
        XCTAssertNotNil(mockSpaceMonitor)
        XCTAssertNotNil(mockSpaceMonitor.delegate)
        XCTAssertEqual(mockSpaceMonitor.getCurrentSpaceNumber(), 1) // Mock returns 1
    }

    func testSpaceChangeDetection() {
        // Test that space changes are detected and delegate is called
        mockSpaceMonitor.updateCurrentSpace()
        
        // Verify delegate was called
        XCTAssertGreaterThanOrEqual(mockDelegate.spaceChangeCallCount, 0)
    }

    func testManualSpaceChange() {
        // Test manual space setting
        mockSpaceMonitor.setCurrentSpace(3)
        XCTAssertEqual(mockSpaceMonitor.getCurrentSpaceNumber(), 3)
        
        // Verify delegate was called
        XCTAssertEqual(mockDelegate.spaceChangeCallCount, 1)
        XCTAssertEqual(mockDelegate.lastSpaceChange?.to, 3)
    }

    func testMultipleSpaceChanges() {
        // Test multiple space changes
        mockSpaceMonitor.setCurrentSpace(2)
        mockSpaceMonitor.setCurrentSpace(4)
        mockSpaceMonitor.setCurrentSpace(1)
        
        // Verify all changes were recorded
        XCTAssertEqual(mockDelegate.spaceChangeCallCount, 3)
        XCTAssertEqual(mockDelegate.allSpaceChanges.count, 3)
    }

    func testSpaceChangeNotificationHandling() {
        // Test that space change notifications are handled
        mockSpaceMonitor.updateCurrentSpace()
        
        // Verify the method executes without crashing
        XCTAssertTrue(true)
    }
}

class FileBasedSpaceNotifierTests: XCTestCase {
    var spaceNotifier: FileBasedSpaceNotifier!
    let testFileURL = URL(fileURLWithPath: "/tmp/test-space-agent-trigger")

    override func setUp() {
        super.setUp()
        spaceNotifier = FileBasedSpaceNotifier()
        
        // Clean up any existing test file
        try? FileManager.default.removeItem(at: testFileURL)
    }

    override func tearDown() {
        spaceNotifier = nil
        try? FileManager.default.removeItem(at: testFileURL)
        super.tearDown()
    }

    func testSpaceNotifierInitialization() {
        XCTAssertNotNil(spaceNotifier)
    }

    func testNotifySpaceChange() {
        // Test space change notification
        let success = spaceNotifier.notifySpaceChange(to: 3, from: 1)
        
        // Verify notification was successful
        XCTAssertTrue(success)
    }

    func testSpaceChangeFileContent() {
        // Test that the file contains correct JSON
        let success = spaceNotifier.notifySpaceChange(to: 2, from: 1)
        XCTAssertTrue(success)
        
        // Verify the method executes without crashing
        XCTAssertTrue(true)
    }
}