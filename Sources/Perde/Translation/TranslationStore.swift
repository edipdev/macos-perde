import AVFoundation
import Foundation

struct TranslationRecord: Codable, Identifiable, Equatable {
    var id = UUID()
    let source: String
    let result: String
    let targetCode: String
}

@MainActor
final class TranslationStore: ObservableObject {
    @Published private(set) var history: [TranslationRecord] = []

    private let synthesizer = AVSpeechSynthesizer()
    private let defaultsKey = "perde.translation.history"
    private let maxItems = 20

    init() { load() }

    func record(source: String, result: String, targetCode: String) {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !result.isEmpty else { return }
        history.removeAll { $0.source == trimmed && $0.targetCode == targetCode }
        history.insert(TranslationRecord(source: trimmed, result: result, targetCode: targetCode), at: 0)
        if history.count > maxItems { history.removeLast(history.count - maxItems) }
        save()
    }

    func clearHistory() {
        history.removeAll()
        save()
    }

    func speak(_ text: String, languageCode: String) {
        guard !text.isEmpty else { return }
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: bcp47(languageCode))
        synthesizer.speak(utterance)
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    private func bcp47(_ code: String) -> String {
        switch code {
        case "en": return "en-US"
        case "tr": return "tr-TR"
        case "de": return "de-DE"
        case "es": return "es-ES"
        case "fr": return "fr-FR"
        case "it": return "it-IT"
        case "ar": return "ar-SA"
        case "ru": return "ru-RU"
        default: return code
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([TranslationRecord].self, from: data) else { return }
        history = decoded
    }
}
