import Cocoa
import Foundation

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, SpaceMonitorDelegate {

    @IBOutlet weak var statusMenu: NSMenu!

    private let statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var spaceMonitor: SpaceMonitor!
    private var isTerminating = false

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupApplication()
        setupStatusItem()
        setupSpaceMonitoring()
        setupSignalHandling()
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
        // Update menubar immediately with a default value
        updateStatusBarTitle(with: 1)

        print("AppDelegate: Will initialize SpaceMonitor in 0.5 seconds")

        // Initialize space monitoring after a delay to prevent hanging
        // Do the initialization on a background thread to avoid blocking
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("AppDelegate: Creating SpaceMonitor on background thread")
            DispatchQueue.global(qos: .userInitiated).async {
                let monitor = SpaceMonitor()

                DispatchQueue.main.async {
                    self.spaceMonitor = monitor
                    self.spaceMonitor.delegate = self

                    // Update menu bar with the actual detected space
                    let currentSpace = self.spaceMonitor.getCurrentSpaceNumber()
                    self.updateStatusBarTitle(with: currentSpace)
                    print("AppDelegate: Initial space from monitor: \(currentSpace)")
                }
            }
        }
    }

    func updateStatusBarTitle(with spaceNumber: Int) {
        DispatchQueue.main.async {
            print("Updating menubar title to: \(spaceNumber)")
            if spaceNumber > 0 {
                self.statusBarItem.button?.title = "🚀 \(spaceNumber)"
                print("Set menubar title to: 🚀 \(spaceNumber)")
            } else {
                self.statusBarItem.button?.title = "🚀 ?"
                print("Set menubar title to: 🚀 ?")
            }
        }
    }

    private func setupSignalHandling() {
        // Set up signal handlers for graceful termination
        signal(SIGTERM) { _ in
            DispatchQueue.main.async {
                NSApplication.shared.terminate(nil)
            }
        }
        
        signal(SIGINT) { _ in
            DispatchQueue.main.async {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    @IBAction func quitClicked(_ sender: NSMenuItem) {
        gracefulTermination()
    }
    
    private func gracefulTermination() {
        guard !isTerminating else { return }
        isTerminating = true
        
        print("SpaceAgent: Initiating graceful termination...")
        
        // Clean up space monitor
        spaceMonitor = nil
        
        // Terminate the application
        NSApplication.shared.terminate(self)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        print("SpaceAgent: Application will terminate")
        isTerminating = true
        spaceMonitor = nil
    }

    func spaceDidChange(to spaceNumber: Int, from previousSpace: Int) {
        updateStatusBarTitle(with: spaceNumber)
        print("Space changed from \(previousSpace) to \(spaceNumber)")
    }
}