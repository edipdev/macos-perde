import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject private var settings = SettingsStore.shared
    @ObservedObject private var mixerStore = AudioMixerStore.shared
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("Genel") {
                Toggle("Girişte başlat", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, value in setLaunchAtLogin(value) }
                Toggle("Tam ekranda gizle", isOn: $settings.autoHideFullscreen)
            }

            Section {
                Picker("Tema", selection: $settings.theme) {
                    Text("Siyah").tag(SettingsStore.Theme.black)
                    Text("Açık").tag(SettingsStore.Theme.light)
                }
                .pickerStyle(.segmented)

                if settings.theme == .light {
                    Text("Kapalıyken şeffaf, açıldığında açık (#999999) kart.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ColorPicker("Vurgu rengi", selection: $settings.accentColor, supportsOpacity: false)
            } header: {
                Text("Tema")
            }

            Section {
                ForEach(NotchTab.allCases, id: \.self) { tab in
                    Toggle(tab.title, isOn: Binding(
                        get: { settings.isEnabled(tab) },
                        set: { settings.setEnabled(tab, $0) }
                    ))
                }

                Picker("Mikser listesi", selection: $mixerStore.listSource) {
                    Text("Sadece ses çalanlar").tag(MixerListSource.playingOnly)
                    Text("Tüm uygulamalar").tag(MixerListSource.all)
                }
            } header: {
                Text("Sekmeler")
            } footer: {
                Text("En az bir sekme açık kalır.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                Picker("Perde'nin görüneceği ekran", selection: $settings.preferredScreenName) {
                    Text("Otomatik (çentikli ekran)").tag("")
                    ForEach(NSScreen.screens, id: \.localizedName) { screen in
                        Text(screen.localizedName).tag(screen.localizedName)
                    }
                }
            } header: {
                Text("Görünüm")
            } footer: {
                Text("Birden fazla monitörün varsa Perde'nin hangi ekranda çıkacağını seçer.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Kısayollar") {
                Picker("Çentiği aç/kapat", selection: $settings.toggleShortcutID) {
                    ForEach(SettingsStore.toggleOptions) { Text($0.label).tag($0.id) }
                }
                Picker("Çeviriyi aç (panodan)", selection: $settings.translateShortcutID) {
                    ForEach(SettingsStore.translateOptions) { Text($0.label).tag($0.id) }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 500)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("Perde: launch-at-login failed: \(error)")
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
