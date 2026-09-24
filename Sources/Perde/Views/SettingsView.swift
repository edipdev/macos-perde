import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject private var settings = SettingsStore.shared
    @ObservedObject private var mixerStore = AudioMixerStore.shared
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("Genel") {
                Toggle(isOn: $launchAtLogin) {
                    SettingLabel("Girişte başlat", "Mac'i açtığında Perde otomatik başlar")
                }
                .onChange(of: launchAtLogin) { _, value in setLaunchAtLogin(value) }
                Toggle(isOn: $settings.autoHideFullscreen) {
                    SettingLabel("Tam ekranda gizle", "Bir uygulama tam ekrandayken çentik gizlenir")
                }
                Toggle(isOn: $settings.commandBarEnabled) {
                    SettingLabel("Komut çubuğu (⌥Space)", "⌥Space ile Spotlight tarzı hızlı komut penceresi açar")
                }
            }

            Section {
                Picker(selection: $settings.theme) {
                    Text("Siyah").tag(SettingsStore.Theme.black)
                    Text("Açık").tag(SettingsStore.Theme.light)
                } label: {
                    SettingLabel("Tema", "Çentik teması: Siyah veya Açık")
                }
                .pickerStyle(.segmented)

                if settings.theme == .light {
                    Text("Kapalıyken şeffaf, açıldığında açık (#999999) kart.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ColorPicker(selection: $settings.accentColor, supportsOpacity: false) {
                    SettingLabel("Vurgu rengi", "Vurgular, göstergeler ve seçili öğeler için renk")
                }
            } header: {
                Text("Tema")
            }

            Section {
                ForEach(NotchTab.allCases, id: \.self) { tab in
                    Toggle(isOn: Binding(
                        get: { settings.isEnabled(tab) },
                        set: { settings.setEnabled(tab, $0) }
                    )) {
                        SettingLabel(tab.title, tab.help)
                    }
                }

                Picker(selection: $mixerStore.listSource) {
                    Text("Sadece ses çalanlar").tag(MixerListSource.playingOnly)
                    Text("Tüm uygulamalar").tag(MixerListSource.all)
                } label: {
                    SettingLabel("Mikser listesi", "Ses mikserinde hangi uygulamalar listelensin")
                }
            } header: {
                Text("Sekmeler")
            } footer: {
                Text("En az bir sekme açık kalır.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                Picker(selection: $settings.preferredScreenName) {
                    Text("Otomatik (çentikli ekran)").tag("")
                    ForEach(NSScreen.screens, id: \.localizedName) { screen in
                        Text(screen.localizedName).tag(screen.localizedName)
                    }
                } label: {
                    SettingLabel("Perde'nin görüneceği ekran", "Birden fazla monitörde Perde'nin çıkacağı ekran")
                }
            } header: {
                Text("Görünüm")
            } footer: {
                Text("Birden fazla monitörün varsa Perde'nin hangi ekranda çıkacağını seçer.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Kısayollar") {
                Picker(selection: $settings.toggleShortcutID) {
                    ForEach(SettingsStore.toggleOptions) { Text($0.label).tag($0.id) }
                } label: {
                    SettingLabel("Çentiği aç/kapat", "Çentiği açıp kapatan klavye kısayolu")
                }
                Picker(selection: $settings.translateShortcutID) {
                    ForEach(SettingsStore.translateOptions) { Text($0.label).tag($0.id) }
                } label: {
                    SettingLabel("Çeviriyi aç (panodan)", "Panodaki metni çeviri sekmesinde açan kısayol")
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
