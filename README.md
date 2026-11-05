# NotchBox

Control whatever is playing on your Mac from the MacBook notch.

- While music plays, a mini cover sits left of the notch and a small waveform moves on its right.
- Hover the notch and it grows into a player: artwork, title, artist, previous / play-pause / next,
  a draggable progress bar, a volume slider and the icon of the app that is playing.
- Tested with Apple Music and YouTube in Safari and Chrome. Other apps that report "Now Playing" to macOS
  (such as Spotify) should work but are untested.
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
4. Open NotchBox. A music note icon appears in the menu bar; use it for "Launch at Login" (works best when the app is in `/Applications`) and "Quit".

## Privacy

NotchBox never connects to the network. Track info stays on your Mac.

## How it works

Since macOS 15.4, apps cannot read "Now Playing" info directly. NotchBox bundles
[mediaremote-adapter](https://github.com/ungive/mediaremote-adapter), which reads it through the
system's Apple-signed `/usr/bin/perl`. This is not an official Apple API, and a future macOS update may break it.
If the adapter fails to start or keeps crashing, NotchBox switches to a limited mode: it can no longer show
the track, but the buttons keep working through media keys (this needs Accessibility permission, asked only then).
A macOS update could also block the data silently while the adapter keeps running. To catch that, NotchBox runs
the adapter's own test at launch, after waking from sleep and every 30 minutes, and switches to the same limited mode
if the test fails. Track info from a player, or a later passing test, switches it back.
When nothing is playing, the test briefly publishes a placeholder track ("Is It Broken Yet?") so that it has something
to read. It may flash in Control Center or other "Now Playing" widgets; NotchBox does not show it.

## Known limitations

- Commands go to the player macOS considers active; you cannot pick a specific app.
- The volume slider controls the system volume, not per-app volume.
- Only the built-in display is used.
- Tested only on macOS 27.2.
- While music plays, the area right beside the notch (about the notch height + 12 pt on each side) opens the
  panel on hover, so menu bar items right next to the notch are harder to reach.
- After installing a new version, Accessibility permission (only used in limited mode) must be granted again.

## Development

Needs only the Xcode Command Line Tools with Swift 6 or later (Xcode 16 tools; `xcode-select --install`); Xcode itself is optional.

```bash
git clone --recursive https://github.com/cyesaa/notch-box.git
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
- Apple Music ve Safari/Chrome'da YouTube ile test edildi. macOS'a "Şu An Çalıyor" bilgisi veren diğer uygulamalar
  (Spotify gibi) çalışmalı ama test edilmedi.
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
4. NotchBox'ı aç. Menü çubuğunda bir müzik notası ikonu çıkar; "Açılışta başlat" (uygulama `/Applications` içindeyken en iyi çalışır) ve "Çık" oradadır.

### Gizlilik

NotchBox internete hiç bağlanmaz. Şarkı bilgileri Mac'inde kalır.

### Nasıl çalışır

macOS 15.4'ten beri uygulamalar "Şu An Çalıyor" bilgisini doğrudan okuyamıyor. NotchBox, bu bilgiyi Apple imzalı
`/usr/bin/perl` üzerinden okuyan [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter)'ı içinde taşır.
Bu resmi bir Apple arayüzü değildir; ileride bir macOS güncellemesi bozabilir. Adaptör başlamazsa ya da sürekli çökerse NotchBox kısıtlı moda geçer:
şarkıyı gösteremez ama butonlar medya tuşlarıyla çalışmaya devam eder (bunun için yalnızca o zaman Erişilebilirlik izni ister).
Bir macOS güncellemesi, adaptör çalışmaya devam ederken veriyi sessizce de engelleyebilir. Bunu yakalamak için NotchBox açılışta,
uykudan uyanınca ve 30 dakikada bir adaptörün kendi testini çalıştırır; test başarısız olursa aynı kısıtlı moda geçer.
Bir çalardan şarkı bilgisi gelince ya da sonraki test geçince normal moda döner.
Hiçbir şey çalmıyorken test, okuyacak bir şey olsun diye kısa bir süre "Is It Broken Yet?" adlı yer tutucu bir parça yayınlar.
Bu parça Denetim Merkezi'nde ya da başka "Şu An Çalıyor" araçlarında bir anlığına görünebilir; NotchBox onu göstermez.

### Bilinen sınırlar

- Komutlar macOS'un aktif saydığı çalara gider; belirli bir uygulama seçilemez.
- Ses kaydırıcısı uygulama bazında değil, sistem sesini değiştirir.
- Yalnızca dahili ekran kullanılır.
- Yalnızca macOS 27.2'de test edildi.
- Müzik çalarken notch'un hemen yanındaki alan (her yanda yaklaşık notch yüksekliği + 12 pt) fareyle üzerine gelince
  paneli açar; bu yüzden notch'un hemen yanındaki menü çubuğu öğelerine ulaşmak zorlaşır.
- Yeni sürüm kurulduktan sonra Erişilebilirlik izni (yalnızca kısıtlı modda kullanılır) yeniden verilmelidir.

Geliştirme ve lisans bilgileri için yukarıdaki İngilizce "Development" ve "License" bölümlerine bakın.
