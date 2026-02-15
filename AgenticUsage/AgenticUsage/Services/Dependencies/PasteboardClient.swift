import AppKit
import Dependencies

// MARK: - PasteboardClient

/// A simple dependency for clipboard operations.
struct PasteboardClient: Sendable {
    var setString: @Sendable (_ string: String) -> Void
}

extension PasteboardClient: TestDependencyKey {
    static let testValue = PasteboardClient(setString: { _ in })
}

extension PasteboardClient {
    static let live = PasteboardClient(
        setString: { string in
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(string, forType: .string)
        }
    )
}

extension DependencyValues {
    var pasteboard: PasteboardClient {
        get { self[PasteboardClient.self] }
        set { self[PasteboardClient.self] = newValue }
    }
}
