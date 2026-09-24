import SwiftUI
import AppKit
import Translation
import NaturalLanguage

struct TranslationView: View {
    @StateObject private var store = TranslationStore()

    @State private var input = ""
    @State private var output = ""
    @State private var source = "tr"
    @State private var target = "en"
    @State private var configuration: TranslationSession.Configuration?
    @State private var isTranslating = false
    @State private var pendingText = ""
    @State private var lastConfigKey = ""
    @State private var detectedName = ""
    @FocusState private var inputFocused: Bool
    @ObservedObject private var settings = SettingsStore.shared

    private let languages: [(code: String, name: String)] = [
        ("tr", "Türkçe"), ("en", "İngilizce"), ("de", "Almanca"),
        ("fr", "Fransızca"), ("es", "İspanyolca"), ("it", "İtalyanca"),
        ("pt", "Portekizce"), ("ru", "Rusça"), ("ar", "Arapça"),
        ("nl", "Felemenkçe"), ("zh", "Çince"), ("ja", "Japonca"),
        ("ko", "Korece"), ("hi", "Hintçe"), ("id", "Endonezce"),
        ("pl", "Lehçe"), ("th", "Tayca"), ("uk", "Ukraynaca"),
        ("vi", "Vietnamca")
    ]

    var body: some View {
        VStack(spacing: 9) {
            SectionHeader(title: "ÇEVİRİ", help: "Apple çeviri — 19 dil, panodan otomatik doldurma")
            languageRow
            if source == "auto", !detectedName.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "sparkle.magnifyingglass")
                        .font(.system(size: 9))
                    Text("Algılanan dil: \(detectedName)")
                        .font(.system(size: 10, weight: .medium))
                    Spacer()
                }
                .foregroundStyle(Theme.tertiaryText)
            }
            inputField
            actionRow
            outputBox
        }
        .translationTask(configuration, action: performTranslation)
        .onAppear(perform: autofillFromClipboard)
        .onChange(of: input) { _, _ in updateDetected() }
    }

    private func updateDetected() {
        guard source == "auto", !input.isEmpty else { detectedName = ""; return }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(input)
        if let code = recognizer.dominantLanguage?.rawValue {
            detectedName = languages.first { $0.code == code }?.name
                ?? Locale.current.localizedString(forLanguageCode: code)
                ?? code
        } else {
            detectedName = ""
        }
    }

    private var languageRow: some View {
        HStack(spacing: 6) {
            langMenu(selection: $source, includeAuto: true)
            Button(action: swapLanguages) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(source == "auto" ? Theme.tertiaryText : Theme.secondaryText)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .disabled(source == "auto")
            langMenu(selection: $target, includeAuto: false, recents: settings.recentTargets)
            Spacer()
            historyMenu
        }
    }

    private func langMenu(selection: Binding<String>, includeAuto: Bool, recents: [String] = []) -> some View {
        Menu {
            if includeAuto {
                Button { selection.wrappedValue = "auto" } label: {
                    if selection.wrappedValue == "auto" { Label("Otomatik", systemImage: "checkmark") }
                    else { Text("Otomatik") }
                }
            }
            let recentLangs = recents.compactMap { code in languages.first { $0.code == code } }
            if !recentLangs.isEmpty {
                Section("Son kullanılan") {
                    ForEach(recentLangs, id: \.code) { lang in
                        Button { selection.wrappedValue = lang.code } label: {
                            if selection.wrappedValue == lang.code { Label(lang.name, systemImage: "checkmark") }
                            else { Text(lang.name) }
                        }
                    }
                }
            }
            ForEach(languages, id: \.code) { lang in
                Button { selection.wrappedValue = lang.code } label: {
                    if selection.wrappedValue == lang.code { Label(lang.name, systemImage: "checkmark") }
                    else { Text(lang.name) }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Text(name(for: selection.wrappedValue))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.primaryText)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Theme.secondaryText)
            }
            .padding(.horizontal, 11).padding(.vertical, 6)
            .background(Capsule().fill(Color.primary.opacity(0.09)).overlay(Capsule().stroke(Theme.hairline, lineWidth: 1)))
        }
        .menuStyle(.button).menuIndicator(.hidden).buttonStyle(.plain).fixedSize()
    }

    private var historyMenu: some View {
        Menu {
            if store.history.isEmpty {
                Text("Geçmiş boş")
            } else {
                ForEach(store.history) { record in
                    Button {
                        input = record.source
                        target = record.targetCode
                        output = record.result
                    } label: {
                        Text(record.source.prefix(40) + (record.source.count > 40 ? "…" : ""))
                    }
                }
                Divider()
                Button("Geçmişi temizle", role: .destructive) { store.clearHistory() }
            }
        } label: {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.secondaryText)
                .frame(width: 26, height: 24)
        }
        .menuStyle(.button).menuIndicator(.hidden).buttonStyle(.plain).fixedSize()
    }

    private var inputField: some View {
        ZStack(alignment: .topTrailing) {
            TextField("Metin girin…", text: $input, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.primaryText)
                .lineLimit(2...3)
                .padding(10)
                .padding(.trailing, 18)
                .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .focused($inputFocused)
                .simultaneousGesture(TapGesture().onEnded {
                    NSApp.makeNotchWindowKey()
                    inputFocused = true
                })
                .onSubmit(translate)
            if !input.isEmpty {
                Button { input = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.tertiaryText)
                }
                .buttonStyle(.plain)
                .padding(7)
            }
        }
    }

    private var actionRow: some View {
        HStack(spacing: 8) {
            Button(action: translate) {
                HStack(spacing: 6) {
                    if isTranslating { ProgressView().controlSize(.mini).tint(.black) }
                    Text("Çevir").font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 16).padding(.vertical, 7)
                .background(Theme.accent.opacity(input.isEmpty ? 0.4 : 1), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(input.isEmpty || isTranslating)

            Button(action: { input = clipboardString() ?? input }) {
                actionIcon("doc.on.clipboard")
            }
            .buttonStyle(.plain)
            .help("Panodan yapıştır")

            Button(action: speakInput) { actionIcon("speaker.wave.2.fill") }
                .buttonStyle(.plain)
                .disabled(input.isEmpty)
                .help("Girişi seslendir")

            Button(action: openDictionary) { actionIcon("character.book.closed") }
                .buttonStyle(.plain)
                .disabled(input.isEmpty)
                .help("Sözlükte ara")

            Spacer()
        }
    }

    private func actionIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.secondaryText)
            .frame(width: 28, height: 28)
    }

    private func speakInput() {
        let code = source == "auto"
            ? (NLLanguageRecognizer.dominantLanguage(for: input)?.rawValue ?? "en")
            : source
        store.speak(input, languageCode: code)
    }

    private func openDictionary() {
        let term = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty,
              let encoded = term.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "dict://\(encoded)") else { return }
        NSWorkspace.shared.open(url)
    }

    private var outputBox: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                Text(output.isEmpty ? "Çeviri burada görünecek" : output)
                    .font(.system(size: 12.5))
                    .foregroundStyle(output.isEmpty ? Theme.tertiaryText : Theme.primaryText.opacity(0.95))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(.trailing, 44)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(10)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            if !output.isEmpty {
                HStack(spacing: 2) {
                    Button { store.speak(output, languageCode: target) } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.secondaryText)
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.plain)
                    Button { copyOutput() } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.secondaryText)
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.plain)
                }
                .padding(6)
            }
        }
    }

    private func name(for code: String) -> String {
        if code == "auto" { return "Otomatik" }
        return languages.first { $0.code == code }?.name ?? code
    }

    private func swapLanguages() {
        guard source != "auto" else { return }
        swap(&source, &target)
        swap(&input, &output)
    }

    private func autofillFromClipboard() {
        guard input.isEmpty, let clip = clipboardString() else { return }
        input = clip
    }

    private func clipboardString() -> String? {
        NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }

    private func copyOutput() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(output, forType: .string)
    }

    nonisolated private func performTranslation(_ session: TranslationSession) async {
        let text = await MainActor.run { pendingText }
        do {
            let translated = try await session.translate(text).targetText
            await MainActor.run {
                output = translated
                isTranslating = false
                store.record(source: text, result: translated, targetCode: target)
            }
        } catch {
            await MainActor.run {
                output = "Çeviri yapılamadı. Dil paketi indirilmemiş olabilir."
                isTranslating = false
            }
        }
    }

    private func translate() {
        guard !input.isEmpty else { return }
        pendingText = input
        isTranslating = true
        settings.noteUsedTarget(target)

        let key = "\(source)->\(target)"
        if configuration != nil, key == lastConfigKey {
            configuration?.invalidate()
        } else {
            configuration = TranslationSession.Configuration(
                source: source == "auto" ? nil : Locale.Language(identifier: source),
                target: Locale.Language(identifier: target)
            )
            lastConfigKey = key
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
