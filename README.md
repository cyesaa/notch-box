# NotchBox

Control whatever is playing on your Mac from the MacBook notch.

- While music plays, a mini cover sits left of the notch and a small waveform moves on its right. Point at the
  waveform for a pause button; when paused, a play button takes its place.
- Change the volume (keys or anywhere else) and a rounded bar with the level slides out under the notch.
- Hover the notch and it grows into a player: artwork, title, artist and album, a draggable progress bar,
  previous / play-pause / next, a volume bar and the icon of the app that is playing.
- The player takes its colour from the cover: a small shadow around the artwork, the progress bar and the waveform.
- Watching a YouTube video in Safari, Chrome, Brave, Edge, Vivaldi or Arc? Press the picture-in-picture button in the
  player and the video moves into the notch, from the same moment, so you can put the browser away and keep watching.
  Point at the video and it fades away so you can see and click what is behind it; only its close button stays.
- Tested with Apple Music and YouTube in Safari and Chrome. Other apps that report "Now Playing" to macOS
  (such as Spotify) should work but are untested.
- English and Turkish, picked from your system language.

## Requirements

- A MacBook with a notch (Apple silicon)
- macOS 14 or later

## Install

Open Terminal and paste:

```bash
curl -fsSL https://raw.githubusercontent.com/cyesaa/notch-box/main/install.sh | bash
```

This downloads the latest release, puts `NotchBox.app` in `/Applications` (or `~/Applications` without admin
rights) and opens it. Run the same command again to update. A music note icon appears in the menu bar; use it
for "Launch at Login" and "Quit".

To remove NotchBox with its settings and permissions:

```bash
curl -fsSL https://raw.githubusercontent.com/cyesaa/notch-box/main/install.sh | bash -s -- --uninstall
```

<details>
<summary>Install by hand instead</summary>

1. Download `NotchBox.zip` from [Releases](../../releases) and unzip it.
2. Move `NotchBox.app` to `/Applications`.
3. NotchBox is not notarized, so macOS blocks a downloaded copy the first time. Remove the quarantine flag:
   ```bash
   xattr -dr com.apple.quarantine /Applications/NotchBox.app
   ```
4. Open NotchBox.

The one-line installer does not need step 3: files downloaded with `curl` are not quarantined.
</details>

## Privacy

NotchBox does not connect to the network, except to YouTube while you watch a video in the notch. Track info
stays on your Mac.

**Watching in the notch** reads the open tabs of your browser (macOS asks once for **Automation** permission) to
find the YouTube video, then plays it with YouTube's own embedded player. Some videos can only be watched on
YouTube; NotchBox then says so. The notch player is a second copy of the video, so it starts where the browser was
and the browser is moved to where you stopped when you close it.

To move the waveform with the music, NotchBox asks for **System Audio Recording** permission the first time
music plays (macOS 14.2 or later). It only measures how loud each frequency range is, many times a second;
nothing is recorded or saved. If you deny it, the waveform simply animates on its own. You can change this in
System Settings → Privacy & Security → Screen & System Audio Recording.

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
- After installing a new version, System Audio Recording permission (for the waveform) and Accessibility
  permission (only used in limited mode) must be granted again.

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
- Accessibility and System Audio Recording permissions are tied to the app's signature. Ad-hoc signed builds
  get a new signature on every build, so you may need to grant them again while developing.
- Before a release, go through [docs/manual-testing.md](docs/manual-testing.md).
- There are no Xcode previews. To look at every notch state with sample data, run
  `build/NotchBox.app/Contents/MacOS/NotchBox --render-snapshots /tmp/notch` after `make app`
  (add `-AppleLanguages '(tr)'` for Turkish); it writes PNGs and exits.
- `make icon` redraws `Resources/AppIcon.icns` from `scripts/make-icon.swift`.

### Releasing

From a clean `main` that matches `origin/main`:

```bash
make release VERSION=0.2.0            # DRY_RUN=1 make release VERSION=0.2.0 to rehearse
```

This sets the version, runs the tests, builds the zip, commits and tags `v0.2.0`, pushes, and publishes a GitHub
release with generated notes and `NotchBox.zip` attached (the file `install.sh` downloads). It uses `GITHUB_TOKEN`
if set, otherwise the github.com login git already has. Releases can be made while the repository is private;
the one-line installer works for others only while it is public.

## License

MIT, see [LICENSE](LICENSE). Third-party code: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

---

## Türkçe

NotchBox, Mac'inde çalan her şeyi MacBook'un notch'undan kontrol etmeni sağlar.

- Müzik çalarken notch'un solunda küçük bir kapak, sağında oynayan bir ses dalgası görünür. Fareyle dalganın
  üzerine gelince duraklat düğmesi çıkar; duraklatınca yerinde oynat düğmesi durur.
- Sesi değiştirdiğinde (tuşlarla ya da başka bir yerden) notch'un altından seviyeyi gösteren yuvarlak bir çubuk iner.
- Fareyi notch'a getirince notch büyür: kapak, şarkı adı, sanatçı ve albüm, sürüklenebilir ilerleme çubuğu,
  önceki / oynat-duraklat / sonraki, ses çubuğu ve müziğin çaldığı uygulamanın ikonu.
- Safari, Chrome, Brave, Edge, Vivaldi ya da Arc'ta YouTube videosu mu izliyorsun? Oynatıcıdaki "resim içinde resim"
  düğmesine bas; video kaldığı yerden notch'a taşınır, tarayıcıyı arkaya alıp izlemeye devam edebilirsin.
  Fareyle videonun üzerine gelince video saydamlaşır; arkasını görüp tıklayabilirsin, yalnızca kapatma düğmesi kalır.
- Oynatıcı rengini kapaktan alır: kapağın etrafında ince bir gölge, ilerleme çubuğu ve ses dalgası.
- Apple Music ve Safari/Chrome'da YouTube ile test edildi. macOS'a "Şu An Çalıyor" bilgisi veren diğer uygulamalar
  (Spotify gibi) çalışmalı ama test edilmedi.
- Arayüz Türkçe ve İngilizce; sistem diline göre seçilir.

### Gereksinimler

- Notch'lu bir MacBook (Apple silicon)
- macOS 14 veya sonrası

### Kurulum

Terminal'i aç ve şunu yapıştır:

```bash
curl -fsSL https://raw.githubusercontent.com/cyesaa/notch-box/main/install.sh | bash
```

Bu komut son sürümü indirir, `NotchBox.app`'i `/Applications` klasörüne (yönetici izni yoksa `~/Applications`)
koyar ve açar. Güncellemek için aynı komutu tekrar çalıştır. Menü çubuğunda bir müzik notası ikonu çıkar;
"Açılışta başlat" ve "Çık" oradadır.

NotchBox'ı ayarları ve izinleriyle birlikte kaldırmak için:

```bash
curl -fsSL https://raw.githubusercontent.com/cyesaa/notch-box/main/install.sh | bash -s -- --uninstall
```

<details>
<summary>Elle kurmak istersen</summary>

1. [Releases](../../releases) sayfasından `NotchBox.zip` dosyasını indirip aç.
2. `NotchBox.app`'i `/Applications` klasörüne taşı.
3. NotchBox Apple tarafından onaylı (notarize) olmadığı için macOS indirilen kopyayı ilk açılışta engeller.
   Karantina işaretini kaldır:
   ```bash
   xattr -dr com.apple.quarantine /Applications/NotchBox.app
   ```
4. NotchBox'ı aç.

Tek satırlık kurulumda 3. adıma gerek yoktur: `curl` ile indirilen dosyalar karantinaya alınmaz.
</details>

### Gizlilik

NotchBox, notch'ta video izlerken YouTube'a bağlanmak dışında internete bağlanmaz. Şarkı bilgileri Mac'inde kalır.

**Notch'ta izleme**, YouTube videosunu bulmak için tarayıcındaki açık sekmeleri okur (macOS bir kez **Otomasyon**
izni ister) ve videoyu YouTube'un kendi gömülü oynatıcısıyla oynatır. Bazı videolar yalnızca YouTube'da
izlenebilir; NotchBox bunu söyler. Notch'taki oynatıcı videonun ikinci bir kopyasıdır: tarayıcının kaldığı yerden
başlar, kapatınca tarayıcı senin durduğun yere alınır.

Ses dalgasının müziğe göre oynaması için NotchBox, ilk kez müzik çaldığında **Sistem Sesi Kaydı** izni ister
(macOS 14.2 ve sonrası). Yalnızca her frekans aralığının ne kadar yüksek çaldığını saniyede birçok kez ölçer;
hiçbir şey kaydedilmez ya da saklanmaz. İzin vermezsen dalga kendi kendine oynar. Bu ayarı Sistem Ayarları →
Gizlilik ve Güvenlik → Ekran ve Sistem Sesi Kaydı altında değiştirebilirsin.

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
- Yeni sürüm kurulduktan sonra Sistem Sesi Kaydı izni (ses dalgası için) ve Erişilebilirlik izni (yalnızca kısıtlı
  modda kullanılır) yeniden verilmelidir.

Geliştirme ve lisans bilgileri için yukarıdaki İngilizce "Development" ve "License" bölümlerine bakın.
