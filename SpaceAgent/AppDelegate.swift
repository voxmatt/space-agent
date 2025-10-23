import Cocoa
import Foundation

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, SpaceMonitorDelegate {

    @IBOutlet weak var statusMenu: NSMenu!

    private let statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var spaceMonitor: SpaceMonitor!
    private var isTerminating = false
    private var settingsWindowController: SettingsWindowController?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupApplication()
        setupStatusItem()
        setupSpaceMonitoring()
        setupSignalHandling()
        setupSettingsObserver()
    }

    private func setupApplication() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    private func setupStatusItem() {
        let icon = SettingsWindowController.getMenuBarIcon()
        statusBarItem.button?.title = icon
        statusBarItem.menu = statusMenu
        updateStatusBarTitle(with: 0)
    }

    private func setupSpaceMonitoring() {
        // Update menubar immediately with a default value
        updateStatusBarTitle(with: 1)

        #if DEBUG
        print("AppDelegate: Will initialize SpaceMonitor in 0.5 seconds")
        #endif

        // Initialize space monitoring after a delay to prevent hanging
        // Do the initialization on a background thread to avoid blocking
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            #if DEBUG
            print("AppDelegate: Creating SpaceMonitor on background thread")
            #endif
            DispatchQueue.global(qos: .userInitiated).async {
                let monitor = SpaceMonitor()

                DispatchQueue.main.async {
                    self.spaceMonitor = monitor
                    self.spaceMonitor.delegate = self

                    // Update menu bar with the actual detected space
                    let currentSpace = self.spaceMonitor.getCurrentSpaceNumber()
                    self.updateStatusBarTitle(with: currentSpace)
                    #if DEBUG
                    print("AppDelegate: Initial space from monitor: \(currentSpace)")
                    #endif
                }
            }
        }
    }

    func updateStatusBarTitle(with spaceNumber: Int) {
        DispatchQueue.main.async {
            let icon = SettingsWindowController.getMenuBarIcon()
            #if DEBUG
            print("Updating menubar title to: \(spaceNumber)")
            #endif
            if spaceNumber > 0 {
                self.statusBarItem.button?.title = "\(icon) \(spaceNumber)"
                #if DEBUG
                print("Set menubar title to: \(icon) \(spaceNumber)")
                #endif
            } else {
                self.statusBarItem.button?.title = "\(icon) ?"
                #if DEBUG
                print("Set menubar title to: \(icon) ?")
                #endif
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

    private func setupSettingsObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsChanged(_:)),
            name: NSNotification.Name("SettingsChanged"),
            object: nil
        )
    }

    @objc private func settingsChanged(_ notification: Notification) {
        // Update the menu bar icon when settings change
        if let currentSpace = spaceMonitor?.getCurrentSpaceNumber() {
            updateStatusBarTitle(with: currentSpace)
        }
    }

    @IBAction func settingsClicked(_ sender: NSMenuItem) {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }

        settingsWindowController?.showWindow(self)
        NSApp.activate(ignoringOtherApps: true)
    }

    @IBAction func quitClicked(_ sender: NSMenuItem) {
        gracefulTermination()
    }
    
    private func gracefulTermination() {
        guard !isTerminating else { return }
        isTerminating = true

        #if DEBUG
        print("SpaceAgent: Initiating graceful termination...")
        #endif

        // Clean up space monitor
        spaceMonitor = nil

        // Terminate the application
        NSApplication.shared.terminate(self)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        #if DEBUG
        print("SpaceAgent: Application will terminate")
        #endif
        isTerminating = true
        spaceMonitor = nil
    }

    func spaceDidChange(to spaceNumber: Int, from previousSpace: Int) {
        updateStatusBarTitle(with: spaceNumber)
        #if DEBUG
        print("Space changed from \(previousSpace) to \(spaceNumber)")
        #endif
    }
}