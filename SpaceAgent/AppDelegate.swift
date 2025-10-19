import Cocoa
import Foundation

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, SpaceMonitorDelegate {

    @IBOutlet weak var statusMenu: NSMenu!

    private let statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var spaceMonitor: SpaceMonitor!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupApplication()
        setupStatusItem()
        setupSpaceMonitoring()
    }

    private func setupApplication() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    private func setupStatusItem() {
        statusBarItem.button?.title = "🚀"
        statusBarItem.menu = statusMenu
        updateStatusBarTitle(with: 0)
    }

    private func setupSpaceMonitoring() {
        spaceMonitor = SpaceMonitor()
        spaceMonitor.delegate = self
        updateStatusBarTitle(with: spaceMonitor.getCurrentSpaceNumber())
    }

    private func updateStatusBarTitle(with spaceNumber: Int) {
        DispatchQueue.main.async {
            if spaceNumber > 0 {
                self.statusBarItem.button?.title = "🚀 \(spaceNumber)"
            } else {
                self.statusBarItem.button?.title = "🚀 ?"
            }
        }
    }

    @IBAction func quitClicked(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(self)
    }

    @IBAction func resetToSpace1(_ sender: NSMenuItem) {
        spaceMonitor.setCurrentSpace(1)
        updateStatusBarTitle(with: 1)
    }

    @IBAction func resetToSpace2(_ sender: NSMenuItem) {
        spaceMonitor.setCurrentSpace(2)
        updateStatusBarTitle(with: 2)
    }

    @IBAction func resetToSpace3(_ sender: NSMenuItem) {
        spaceMonitor.setCurrentSpace(3)
        updateStatusBarTitle(with: 3)
    }

    @IBAction func resetToSpace4(_ sender: NSMenuItem) {
        spaceMonitor.setCurrentSpace(4)
        updateStatusBarTitle(with: 4)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        spaceMonitor = nil
    }

    func spaceDidChange(to spaceNumber: Int, from previousSpace: Int) {
        updateStatusBarTitle(with: spaceNumber)
        print("Space changed from \(previousSpace) to \(spaceNumber)")
    }
}