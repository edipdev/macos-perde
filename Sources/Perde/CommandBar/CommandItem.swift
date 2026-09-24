import Foundation

struct CommandItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let action: @MainActor () -> Void
}
