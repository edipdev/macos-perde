<div align="center">

<img src="docs/perde-icon.png" width="120" alt="Perde" />

# Perde

**macOS için çentik (notch) tabanlı, çok amaçlı bir yardımcı.**
_A notch‑based multi‑tool for macOS._

![Platform](https://img.shields.io/badge/macOS-15%2B-black?logo=apple)
![Swift](https://img.shields.io/badge/Swift-6-orange?logo=swift)
![License](https://img.shields.io/badge/License-MIT-blue)

[![Download](https://img.shields.io/badge/⬇%20İndir-Perde%20v0.1.0%20(.dmg)-brightgreen)](https://github.com/edipdev/macos-perde/releases/download/0.1.0/Perde-0.1.0.dmg)

[Türkçe](#türkçe) · [English](#english)

</div>

---

## Türkçe

Fareyi ekranın üst‑orta **çentik** bölgesine götürünce açılan; müzik, çeviri,
zamanlayıcı ve pano yöneticisini tek yerde toplayan bir menü‑çubuğu uygulaması.
Dock'ta ikonu yoktur.

### ✨ Özellikler

- 🎵 **Müzik** — Apple Music & Spotify: albüm kapağı, kayan başlık, sürüklenebilir
  ilerleme (seek), oynat/duraklat/ileri/geri, karıştır/tekrar, ses, favori (Apple
  Music) ve **şarkı sözleri** (lrclib.net). Kapalıyken çentiğin kenarlarında mini
  kapak + canlı ekolayzer.
- 💬 **Çeviri** — Apple'ın **cihaz‑üstü** Translation motoru (ücretsiz, internetsiz,
  API anahtarsız): 19 dil, kaynak/hedef değiştirme, dil algılama, sesli okuma,
  sözlük, pano otomatik doldurma ve geçmiş.
- ⏱ **Zamanlayıcı** — halka göstergeli geri sayım, özel süre ve **Pomodoro**
  (çalış/mola otomatik döngü + seans sayacı). Kapalıyken çentikte mini halka.
- 📋 **Pano** — kopyalananların aranabilir geçmişi; **sabitleme**, link ve görsel
  önizleme.
- 🎨 **Tema** — Siyah veya Açık; seçilebilir **vurgu rengi**.
- ⌨️ **Global kısayollar**, girişte otomatik başlatma, çoklu monitör, tam ekranda
  gizlenme.

### 📸 Ekran görüntüleri

| Müzik | Çeviri |
|:---:|:---:|
| ![](docs/screenshots/player.png) | ![](docs/screenshots/translate.png) |
| **Zamanlayıcı** | **Pano** |
| ![](docs/screenshots/timer.png) | ![](docs/screenshots/clipboard.png) |

### ⬇️ Kurulum

**Hazır uygulama:** [**Perde-0.1.0.dmg indir**](https://github.com/edipdev/macos-perde/releases/download/0.1.0/Perde-0.1.0.dmg) →
aç ve **Perde**'yi `Applications` klasörüne sürükle. (Tüm sürümler için [Releases](https://github.com/edipdev/macos-perde/releases).)

> İlk açılışta uygulama imzasız olduğu için macOS uyarabilir: **Sistem Ayarları →
> Gizlilik ve Güvenlik**'ten "Yine de Aç" deyin.

**Kaynaktan derleme:**

```bash
git clone https://github.com/edipdev/macos-perde.git
cd macos-perde
make run
```

### ⌨️ Kısayollar

| İşlem | Varsayılan |
|---|---|
| Çentiği aç/kapat | `⌥⌘P` |
| Çeviriyi aç (panodan) | `⌥⌘T` |

Kısayollar menü çubuğu → **Ayarlar…**'dan değiştirilebilir.

### 🔒 İzinler

- **Otomasyon** — Apple Music/Spotify'ı okumak ve kontrol etmek için (ilk kullanımda sorulur).

### 🛠 Gereksinimler

macOS 15+ · Xcode / Swift 6 (derleme için).

---

## English

A menu‑bar app that lives in your Mac's **notch**: hover to reveal a music player,
translator, timer and clipboard manager — all in one place. No Dock icon.

### ✨ Features

- 🎵 **Music** — Apple Music & Spotify: artwork, marquee title, draggable seek,
  transport, shuffle/repeat, volume, favorite (Apple Music) and **lyrics**
  (lrclib.net). Mini artwork + live equalizer in the collapsed notch.
- 💬 **Translate** — Apple's **on‑device** Translation (free, offline, no API key):
  19 languages, swap, language detection, text‑to‑speech, dictionary, clipboard
  autofill and history.
- ⏱ **Timer** — ring countdown, custom duration and **Pomodoro** (auto work/break
  cycle + session counter). Mini ring in the collapsed notch.
- 📋 **Clipboard** — searchable history with **pinning**, link and image previews.
- 🎨 **Themes** — Black or Light; selectable **accent color**.
- ⌨️ **Global shortcuts**, launch at login, multi‑monitor, hide in fullscreen.

### 📸 Screenshots

See the table above.

### ⬇️ Install

**Prebuilt app:** download `Perde.app` from
[Releases](https://github.com/edipdev/macos-perde/releases), move it to `/Applications`
and open it.

> On first launch macOS may warn because the app is unsigned — allow it via
> **System Settings → Privacy & Security → Open Anyway**.

**Build from source:**

```bash
git clone https://github.com/edipdev/macos-perde.git
cd macos-perde
make run
```

### ⌨️ Shortcuts

| Action | Default |
|---|---|
| Toggle notch | `⌥⌘P` |
| Open translate (from clipboard) | `⌥⌘T` |

Change them in the menu bar → **Settings…**

### 🔒 Permissions

- **Automation** — to read and control Apple Music / Spotify (asked on first use).

### 🛠 Requirements

macOS 15+ · Xcode / Swift 6 (to build).

---

## Proje yapısı / Project layout

```
Sources/Perde/
  main.swift, AppDelegate.swift   # giriş, menü çubuğu, kısayollar, ayarlar
  Notch/                          # pencere, geometri, controller
  Input/                          # global fare izleme
  NowPlaying/                     # AppleScript kaynakları, servis, sözler
  Translation/                    # çeviri geçmişi + TTS
  System/                         # zamanlayıcı, pano, kısayol, ayarlar
  Views/                          # SwiftUI arayüz
Tests/PerdeTests/                 # birim testler
```

## Lisans / License

[MIT](LICENSE)
