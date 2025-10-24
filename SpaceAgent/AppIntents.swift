import AppIntents
import Foundation

/// App Intent to get the current space number
@available(macOS 13.0, *)
struct GetCurrentSpaceIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Current Space"
    static var description = IntentDescription("Returns the number of the currently active macOS space (desktop).")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<Int> {
        // Read the current space from UserDefaults (shared with the main app)
        let currentSpace = getCurrentSpaceFromSharedDefaults()

        return .result(value: currentSpace)
    }

    private func getCurrentSpaceFromSharedDefaults() -> Int {
        // Try to get the current space from the shared state
        let defaults = UserDefaults.standard
        let currentSpace = defaults.integer(forKey: "currentSpaceNumber")

        // If we got a valid space number, return it
        if currentSpace > 0 {
            return currentSpace
        }

        // Fallback: try to detect it directly using Core Graphics
        return detectCurrentSpaceDirectly()
    }

    private func detectCurrentSpaceDirectly() -> Int {
        // Use the same detection logic as the app
        let service = RealCoreGraphicsService()
        return service.detectActualSpace()
    }
}

/// App Intent to get space info as text
@available(macOS 13.0, *)
struct GetCurrentSpaceTextIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Current Space (Text)"
    static var description = IntentDescription("Returns the current space number as text, e.g. 'Space 2'.")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let defaults = UserDefaults.standard
        let currentSpace = defaults.integer(forKey: "currentSpaceNumber")

        let spaceNumber = currentSpace > 0 ? currentSpace : detectCurrentSpaceDirectly()
        let result = "Space \(spaceNumber)"

        return .result(value: result)
    }

    private func detectCurrentSpaceDirectly() -> Int {
        let service = RealCoreGraphicsService()
        return service.detectActualSpace()
    }
}

/// App Shortcuts Provider
@available(macOS 13.0, *)
struct SpaceAgentShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetCurrentSpaceIntent(),
            phrases: [
                "Get current space in \(.applicationName)",
                "What space am I on in \(.applicationName)",
                "Current space number in \(.applicationName)"
            ],
            shortTitle: "Current Space",
            systemImageName: "square.grid.3x3"
        )
    }
}
