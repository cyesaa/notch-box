# NotchBox

Control whatever is playing on your Mac from the MacBook notch.

![NotchBox](docs/screenshot.png)

- While music plays, a mini cover sits left of the notch and a small waveform moves on its right.
- Hover the notch and it grows into a player: artwork, title, artist, previous / play-pause / next,
  a draggable progress bar, a volume slider and the icon of the app that is playing.
- Works with any app that reports "Now Playing" to macOS: Spotify, Apple Music, YouTube in your browser and more.
- English and Turkish, picked from your system language.

## Requirements

- A MacBook with a notch (Apple silicon)
- macOS 14 or later

## Install

1. Download `NotchBox-<version>.zip` from [Releases](../../releases) and unzip it.
2. Move `NotchBox.app` to `/Applications`.
3. NotchBox is not notarized, so macOS blocks it the first time. Remove the quarantine flag:
   ```bash
   xattr -dr com.apple.quarantine /Applications/NotchBox.app
   ```
4. Open NotchBox. A music note icon appears in the menu bar; use it for "Launch at Login" and "Quit".

## Privacy

NotchBox never connects to the network. Track info stays on your Mac.

## How it works

Since macOS 15.4, apps cannot read "Now Playing" info directly. NotchBox bundles
[mediaremote-adapter](https://github.com/ungive/mediaremote-adapter), which reads it through the
system's Apple-signed `/usr/bin/perl`. This is not an official Apple API, and a future macOS update may break it.
If that happens, NotchBox switches to a limited mode: it can no longer show the track, but the buttons
keep working through media keys (this needs Accessibility permission, asked only then).

## Known limitations

- Commands go to the player macOS considers active; you cannot pick a specific app.
- The volume slider controls the system volume, not per-app volume.
- Only the built-in display is used.

## Development

Needs only the Xcode Command Line Tools (`xcode-select --install`); Xcode itself is optional.

```bash
git clone --recursive <this repo>
make test   # unit tests (Swift Testing)
make run    # build build/NotchBox.app and open it
make dist   # dist/NotchBox-<version>.zip
```

- Do not use `@State` or `#Preview`: with only the Command Line Tools, the SwiftUI macro plugin is missing.
  Keep view state in `NotchViewModel`.
- Accessibility permission is tied to the app's signature. Ad-hoc signed builds get a new signature on
  every build, so you may need to grant it again while developing.
- Before a release, go through [docs/manual-testing.md](docs/manual-testing.md).

## License

MIT, see [LICENSE](LICENSE). Third-party code: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

---

## Türkçe

NotchBox, Mac'inde çalan her şeyi MacBook'un notch'undan kontrol etmeni sağlar.

- Müzik çalarken notch'un solunda küçük bir kapak, sağında oynayan bir ses dalgası görünür.
- Fareyi notch'a getirince notch büyür: kapak, şarkı adı, sanatçı, önceki / oynat-duraklat / sonraki,
  sürüklenebilir ilerleme çubuğu, ses seviyesi ve müziğin çaldığı uygulamanın ikonu.
- macOS'a "Şu An Çalıyor" bilgisi veren her uygulamayla çalışır: Spotify, Apple Music, tarayıcıda YouTube ve diğerleri.
- Arayüz Türkçe ve İngilizce; sistem diline göre seçilir.

### Gereksinimler

- Notch'lu bir MacBook (Apple silicon)
- macOS 14 veya sonrası

### Kurulum

1. [Releases](../../releases) sayfasından `NotchBox-<sürüm>.zip` dosyasını indirip aç.
2. `NotchBox.app`'i `/Applications` klasörüne taşı.
3. NotchBox Apple tarafından onaylı (notarize) olmadığı için macOS ilk açılışta engeller. Karantina işaretini kaldır:
   ```bash
   xattr -dr com.apple.quarantine /Applications/NotchBox.app
   ```
4. NotchBox'ı aç. Menü çubuğunda bir müzik notası ikonu çıkar; "Açılışta başlat" ve "Çık" oradadır.

### Gizlilik

NotchBox internete hiç bağlanmaz. Şarkı bilgileri Mac'inde kalır.

### Nasıl çalışır

macOS 15.4'ten beri uygulamalar "Şu An Çalıyor" bilgisini doğrudan okuyamıyor. NotchBox, bu bilgiyi Apple imzalı
`/usr/bin/perl` üzerinden okuyan [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter)'ı içinde taşır.
Bu resmi bir Apple arayüzü değildir; ileride bir macOS güncellemesi bozabilir. O durumda NotchBox kısıtlı moda geçer:
şarkıyı gösteremez ama butonlar medya tuşlarıyla çalışmaya devam eder (bunun için yalnızca o zaman Erişilebilirlik izni ister).

### Bilinen sınırlar

- Komutlar macOS'un aktif saydığı çalara gider; belirli bir uygulama seçilemez.
- Ses kaydırıcısı uygulama bazında değil, sistem sesini değiştirir.
- Yalnızca dahili ekran kullanılır.
