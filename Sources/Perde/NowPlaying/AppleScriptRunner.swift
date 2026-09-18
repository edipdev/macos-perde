import Foundation

@MainActor
enum AppleScriptRunner {

    @discardableResult
    static func run(_ source: String) -> String? {
        guard let script = NSAppleScript(source: source) else { return nil }
        var error: NSDictionary?
        let descriptor = script.executeAndReturnError(&error)
        if error != nil { return nil }
        let output = descriptor.stringValue?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (output?.isEmpty == false) ? output : nil
    }
}
