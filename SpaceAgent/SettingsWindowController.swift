import Cocoa

class SettingsWindowController: NSWindowController {

    // MARK: - UI Elements

    private var iconTextField: NSTextField!
    private var pollingIntervalSlider: NSSlider!
    private var pollingIntervalLabel: NSTextField!
    private var logLevelPopup: NSPopUpButton!
    private var enableShortcutCheckbox: NSButton!
    private var shortcutNameTextField: NSTextField!
    private var versionLabel: NSTextField!

    // MARK: - Settings Keys

    private struct SettingsKeys {
        static let menuBarIcon = "menuBarIcon"
        static let pollingInterval = "pollingInterval"
        static let logLevel = "logLevel"
        static let enableShortcutTrigger = "enableShortcutTrigger"
        static let shortcutName = "shortcutName"
    }

    // MARK: - Default Values

    static let defaultIcon = "🚀"
    static let defaultPollingInterval: Double = 15.0
    static let defaultLogLevel = "info"
    static let defaultEnableShortcutTrigger = false
    static let defaultShortcutName = ""

    // MARK: - Initialization

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 440),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "SpaceAgent Settings"
        window.center()

        self.init(window: window)
        setupUI()
        loadSettings()
    }

    // MARK: - UI Setup

    private func setupUI() {
        guard let window = window else { return }

        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]
        window.contentView = contentView

        var yPosition: CGFloat = 300

        // Title
        let titleLabel = NSTextField(labelWithString: "SpaceAgent Settings")
        titleLabel.font = NSFont.systemFont(ofSize: 18, weight: .bold)
        titleLabel.frame = NSRect(x: 20, y: yPosition, width: 440, height: 30)
        contentView.addSubview(titleLabel)

        yPosition -= 50

        // Menu Bar Icon Setting
        let iconLabel = NSTextField(labelWithString: "Menu Bar Icon:")
        iconLabel.frame = NSRect(x: 20, y: yPosition, width: 150, height: 20)
        iconLabel.alignment = .right
        contentView.addSubview(iconLabel)

        iconTextField = NSTextField(frame: NSRect(x: 180, y: yPosition - 2, width: 60, height: 24))
        iconTextField.placeholderString = SettingsWindowController.defaultIcon
        iconTextField.alignment = .center
        iconTextField.font = NSFont.systemFont(ofSize: 18)
        iconTextField.target = self
        iconTextField.action = #selector(iconChanged(_:))
        contentView.addSubview(iconTextField)

        let iconHint = NSTextField(labelWithString: "Any emoji or text")
        iconHint.font = NSFont.systemFont(ofSize: 10)
        iconHint.textColor = .secondaryLabelColor
        iconHint.frame = NSRect(x: 250, y: yPosition + 3, width: 200, height: 16)
        contentView.addSubview(iconHint)

        yPosition -= 50

        // Polling Interval Setting
        let intervalLabel = NSTextField(labelWithString: "Polling Interval:")
        intervalLabel.frame = NSRect(x: 20, y: yPosition, width: 150, height: 20)
        intervalLabel.alignment = .right
        contentView.addSubview(intervalLabel)

        pollingIntervalSlider = NSSlider(frame: NSRect(x: 180, y: yPosition - 2, width: 200, height: 24))
        pollingIntervalSlider.minValue = 5
        pollingIntervalSlider.maxValue = 60
        pollingIntervalSlider.target = self
        pollingIntervalSlider.action = #selector(pollingIntervalChanged(_:))
        contentView.addSubview(pollingIntervalSlider)

        pollingIntervalLabel = NSTextField(labelWithString: "")
        pollingIntervalLabel.frame = NSRect(x: 390, y: yPosition, width: 70, height: 20)
        pollingIntervalLabel.isEditable = false
        pollingIntervalLabel.isBordered = false
        pollingIntervalLabel.backgroundColor = .clear
        contentView.addSubview(pollingIntervalLabel)

        let intervalHint = NSTextField(labelWithString: "How often to check for space changes (in seconds)")
        intervalHint.font = NSFont.systemFont(ofSize: 10)
        intervalHint.textColor = .secondaryLabelColor
        intervalHint.frame = NSRect(x: 180, y: yPosition - 18, width: 280, height: 16)
        contentView.addSubview(intervalHint)

        yPosition -= 60

        // Log Level Setting
        let logLevelLabel = NSTextField(labelWithString: "Log Level:")
        logLevelLabel.frame = NSRect(x: 20, y: yPosition, width: 150, height: 20)
        logLevelLabel.alignment = .right
        contentView.addSubview(logLevelLabel)

        logLevelPopup = NSPopUpButton(frame: NSRect(x: 180, y: yPosition - 4, width: 120, height: 26))
        logLevelPopup.addItems(withTitles: ["Debug", "Info", "Warning", "Error"])
        logLevelPopup.target = self
        logLevelPopup.action = #selector(logLevelChanged(_:))
        contentView.addSubview(logLevelPopup)

        let logHint = NSTextField(labelWithString: "Minimum log level for /tmp/spaceagent_debug.log")
        logHint.font = NSFont.systemFont(ofSize: 10)
        logHint.textColor = .secondaryLabelColor
        logHint.frame = NSRect(x: 180, y: yPosition - 18, width: 280, height: 16)
        contentView.addSubview(logHint)

        yPosition -= 60

        // Shortcut Trigger Setting
        enableShortcutCheckbox = NSButton(checkboxWithTitle: "Trigger Shortcut on Space Change", target: self, action: #selector(shortcutTriggerChanged(_:)))
        enableShortcutCheckbox.frame = NSRect(x: 180, y: yPosition, width: 300, height: 20)
        contentView.addSubview(enableShortcutCheckbox)

        yPosition -= 30

        let shortcutLabel = NSTextField(labelWithString: "Shortcut Name:")
        shortcutLabel.frame = NSRect(x: 20, y: yPosition, width: 150, height: 20)
        shortcutLabel.alignment = .right
        contentView.addSubview(shortcutLabel)

        shortcutNameTextField = NSTextField(frame: NSRect(x: 180, y: yPosition - 2, width: 200, height: 24))
        shortcutNameTextField.placeholderString = "Enter shortcut name"
        shortcutNameTextField.target = self
        shortcutNameTextField.action = #selector(shortcutNameChanged(_:))
        contentView.addSubview(shortcutNameTextField)

        let shortcutHint = NSTextField(labelWithString: "Name of the shortcut to run when switching spaces")
        shortcutHint.font = NSFont.systemFont(ofSize: 10)
        shortcutHint.textColor = .secondaryLabelColor
        shortcutHint.frame = NSRect(x: 180, y: yPosition - 18, width: 300, height: 16)
        contentView.addSubview(shortcutHint)

        yPosition -= 50

        // Separator
        let separator = NSBox(frame: NSRect(x: 20, y: yPosition, width: 440, height: 1))
        separator.boxType = .separator
        contentView.addSubview(separator)

        yPosition -= 30

        // Info Section
        let infoLabel = NSTextField(labelWithString: "SpaceAgent")
        infoLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        infoLabel.frame = NSRect(x: 20, y: yPosition, width: 440, height: 20)
        contentView.addSubview(infoLabel)

        yPosition -= 25

        versionLabel = NSTextField(labelWithString: "Version 1.0")
        versionLabel.font = NSFont.systemFont(ofSize: 11)
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.frame = NSRect(x: 20, y: yPosition, width: 440, height: 18)
        contentView.addSubview(versionLabel)

        yPosition -= 20

        let descLabel = NSTextField(wrappingLabelWithString: "A menu bar app that monitors macOS virtual space changes and displays the current space number.")
        descLabel.font = NSFont.systemFont(ofSize: 11)
        descLabel.textColor = .secondaryLabelColor
        descLabel.frame = NSRect(x: 20, y: yPosition - 20, width: 440, height: 40)
        contentView.addSubview(descLabel)

        yPosition -= 60

        // Buttons at bottom
        let viewLogsButton = NSButton(frame: NSRect(x: 20, y: 20, width: 120, height: 28))
        viewLogsButton.title = "View Logs"
        viewLogsButton.bezelStyle = .rounded
        viewLogsButton.target = self
        viewLogsButton.action = #selector(viewLogsClicked(_:))
        contentView.addSubview(viewLogsButton)

        let resetButton = NSButton(frame: NSRect(x: 150, y: 20, width: 120, height: 28))
        resetButton.title = "Reset to Defaults"
        resetButton.bezelStyle = .rounded
        resetButton.target = self
        resetButton.action = #selector(resetToDefaultsClicked(_:))
        contentView.addSubview(resetButton)

        let closeButton = NSButton(frame: NSRect(x: 380, y: 20, width: 80, height: 28))
        closeButton.title = "Close"
        closeButton.bezelStyle = .rounded
        closeButton.keyEquivalent = "\r" // Make it respond to Enter key
        closeButton.target = self
        closeButton.action = #selector(closeClicked(_:))
        contentView.addSubview(closeButton)
    }

    // MARK: - Settings Management

    private func loadSettings() {
        let defaults = UserDefaults.standard

        // Load icon
        let icon = defaults.string(forKey: SettingsKeys.menuBarIcon) ?? SettingsWindowController.defaultIcon
        iconTextField.stringValue = icon

        // Load polling interval
        var interval = defaults.double(forKey: SettingsKeys.pollingInterval)
        if interval == 0 {
            interval = SettingsWindowController.defaultPollingInterval
        }
        pollingIntervalSlider.doubleValue = interval
        updatePollingIntervalLabel(interval)

        // Load log level
        let logLevel = defaults.string(forKey: SettingsKeys.logLevel) ?? SettingsWindowController.defaultLogLevel
        switch logLevel.lowercased() {
        case "debug":
            logLevelPopup.selectItem(at: 0)
        case "info":
            logLevelPopup.selectItem(at: 1)
        case "warning":
            logLevelPopup.selectItem(at: 2)
        case "error":
            logLevelPopup.selectItem(at: 3)
        default:
            logLevelPopup.selectItem(at: 1) // Default to Info
        }

        // Load shortcut trigger settings
        let enableTrigger = defaults.bool(forKey: SettingsKeys.enableShortcutTrigger)
        enableShortcutCheckbox.state = enableTrigger ? .on : .off

        let shortcutName = defaults.string(forKey: SettingsKeys.shortcutName) ?? SettingsWindowController.defaultShortcutName
        shortcutNameTextField.stringValue = shortcutName
        shortcutNameTextField.isEnabled = enableTrigger
    }

    private func saveSettings() {
        let defaults = UserDefaults.standard

        // Save icon
        let icon = iconTextField.stringValue.isEmpty ? SettingsWindowController.defaultIcon : iconTextField.stringValue
        defaults.set(icon, forKey: SettingsKeys.menuBarIcon)

        // Save polling interval
        defaults.set(pollingIntervalSlider.doubleValue, forKey: SettingsKeys.pollingInterval)

        // Save log level
        let logLevelIndex = logLevelPopup.indexOfSelectedItem
        let logLevels = ["debug", "info", "warning", "error"]
        defaults.set(logLevels[logLevelIndex], forKey: SettingsKeys.logLevel)

        // Save shortcut trigger settings
        defaults.set(enableShortcutCheckbox.state == .on, forKey: SettingsKeys.enableShortcutTrigger)
        defaults.set(shortcutNameTextField.stringValue, forKey: SettingsKeys.shortcutName)

        // Notify that settings changed
        NotificationCenter.default.post(name: NSNotification.Name("SettingsChanged"), object: nil)
    }

    private func updatePollingIntervalLabel(_ value: Double) {
        pollingIntervalLabel.stringValue = String(format: "%.0f sec", value)
    }

    // MARK: - Actions

    @objc private func iconChanged(_ sender: NSTextField) {
        saveSettings()
    }

    @objc private func pollingIntervalChanged(_ sender: NSSlider) {
        updatePollingIntervalLabel(sender.doubleValue)
        saveSettings()
    }

    @objc private func logLevelChanged(_ sender: NSPopUpButton) {
        saveSettings()
    }

    @objc private func shortcutTriggerChanged(_ sender: NSButton) {
        shortcutNameTextField.isEnabled = (sender.state == .on)
        saveSettings()
    }

    @objc private func shortcutNameChanged(_ sender: NSTextField) {
        saveSettings()
    }

    @objc private func viewLogsClicked(_ sender: NSButton) {
        let logPath = "/tmp/spaceagent_debug.log"
        if FileManager.default.fileExists(atPath: logPath) {
            let logURL = URL(fileURLWithPath: logPath)
            if #available(macOS 10.15, *) {
                NSWorkspace.shared.open(logURL)
            } else {
                NSWorkspace.shared.openFile(logPath)
            }
        } else {
            let alert = NSAlert()
            alert.messageText = "No Log File Found"
            alert.informativeText = "The log file at \(logPath) does not exist yet."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    @objc private func resetToDefaultsClicked(_ sender: NSButton) {
        let alert = NSAlert()
        alert.messageText = "Reset to Defaults?"
        alert.informativeText = "This will reset all settings to their default values."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            // Reset to defaults
            iconTextField.stringValue = SettingsWindowController.defaultIcon
            pollingIntervalSlider.doubleValue = SettingsWindowController.defaultPollingInterval
            updatePollingIntervalLabel(SettingsWindowController.defaultPollingInterval)
            logLevelPopup.selectItem(at: 1) // Info
            enableShortcutCheckbox.state = SettingsWindowController.defaultEnableShortcutTrigger ? .on : .off
            shortcutNameTextField.stringValue = SettingsWindowController.defaultShortcutName
            shortcutNameTextField.isEnabled = SettingsWindowController.defaultEnableShortcutTrigger

            saveSettings()
        }
    }

    @objc private func closeClicked(_ sender: NSButton) {
        window?.close()
    }

    // MARK: - Static Helper Methods

    static func getMenuBarIcon() -> String {
        return UserDefaults.standard.string(forKey: SettingsKeys.menuBarIcon) ?? defaultIcon
    }

    static func getPollingInterval() -> Double {
        let interval = UserDefaults.standard.double(forKey: SettingsKeys.pollingInterval)
        return interval > 0 ? interval : defaultPollingInterval
    }

    static func getLogLevel() -> String {
        return UserDefaults.standard.string(forKey: SettingsKeys.logLevel) ?? defaultLogLevel
    }

    static func isShortcutTriggerEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: SettingsKeys.enableShortcutTrigger)
    }

    static func getShortcutName() -> String {
        return UserDefaults.standard.string(forKey: SettingsKeys.shortcutName) ?? defaultShortcutName
    }

    static func triggerShortcut(withSpaceNumber spaceNumber: Int) {
        writeToDebugLog("triggerShortcut: called with space number \(spaceNumber)", level: .info)

        guard isShortcutTriggerEnabled() else {
            writeToDebugLog("triggerShortcut: trigger is disabled", level: .info)
            return
        }

        let shortcutName = getShortcutName()
        writeToDebugLog("triggerShortcut: shortcut name = '\(shortcutName)'", level: .info)

        guard !shortcutName.isEmpty else {
            writeToDebugLog("triggerShortcut: shortcut name is empty", level: .info)
            return
        }

        // Encode the shortcut name for URL
        guard let encodedName = shortcutName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            writeToDebugLog("triggerShortcut: failed to encode shortcut name", level: .error)
            return
        }

        // Build the Shortcuts URL scheme with the space number as input
        // Use the text parameter to pass the space number directly to the shortcut
        let urlString = "shortcuts://run-shortcut?name=\(encodedName)&input=text&text=\(spaceNumber)"

        writeToDebugLog("triggerShortcut: URL string = '\(urlString)'", level: .info)

        guard let url = URL(string: urlString) else {
            writeToDebugLog("triggerShortcut: failed to create URL from string", level: .error)
            return
        }

        // Open the URL to trigger the shortcut
        writeToDebugLog("triggerShortcut: opening URL...", level: .info)

        let success = NSWorkspace.shared.open(url)

        writeToDebugLog("triggerShortcut: open result = \(success)", level: .info)
    }
}
