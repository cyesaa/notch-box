# NotchBox

Control whatever is playing on your Mac from the MacBook notch.

- While music plays, a mini cover sits left of the notch and a small waveform moves on its right. Point at the
  waveform for a pause button; when paused, a play button takes its place.
- Change the volume (keys or anywhere else) and a rounded bar with the level slides out under the notch.
- Hover the notch and it grows into a player: artwork, title, artist and album, a draggable progress bar,
  previous / play-pause / next, a volume bar and the icon of the app that is playing.
- The player takes its colour from the cover: a small shadow around the artwork, the progress bar and the waveform.
- Left of the player sits your clipboard: the last 20 texts and images you copied, newest first. Click one to copy
  it again, remove it with its ×, or clear the whole list with the bin. The eye on an image shows it large in
  place of the player. The pin keeps an item at the top, past the 20-item limit and across restarts (up to 10
  pins); the bin leaves pinned items alone.
- Right of the player, as wide as the clipboard, sits your calendar: this week as a strip of days (a dot marks days
  with events) and the picked day's events below, with a green Join button for Zoom, Meet, Teams, Webex and
  FaceTime calls. Click a day to see its events, or an event to open Calendar.
- Watching a YouTube video in Safari, Chrome, Brave, Edge, Vivaldi or Arc? Press the picture-in-picture button in the
  player and the video moves into the notch, from the same moment, so you can put the browser away and keep watching.
  Pass over the video and it fades away so you can see and click what is behind it; only its close button stays.
  Come down onto it from the menu bar instead and it stays solid, so YouTube's own controls work.
- Tested with Apple Music and YouTube in Safari and Chrome. Other apps that report "Now Playing" to macOS
  (such as Spotify) should work but are untested.
- English and Turkish, picked from your system language.

## Requirements

- A Mac with Apple silicon (M1 or later)
- macOS 14 or later

On a MacBook with a notch NotchBox lives in the notch. On a Mac without one (MacBook Air M1, iMac, Mac mini,
Mac Studio or an external display) it draws its own small black notch at the top centre of the menu bar and works the same way, with the
title in the middle of the mini notch. In Settings, "Hide When Idle" hides it while nothing plays (pointing
there still opens it), and "Show on Screens Without a Notch" turns it off.

## Install

Open Terminal and paste:

```bash
curl -fsSL https://raw.githubusercontent.com/cyesaa/notch-box/main/install.sh | bash
```

This downloads the latest release, puts `NotchBox.app` in `/Applications` (or `~/Applications` without admin
rights) and opens it. A music note icon appears in the menu bar with Settings (⌘,), Check for Updates and Quit.

**Settings** decides what sits left and right of the player when you hover the notch (Clipboard, Calendar, VPN or
nothing; more widgets will follow), and holds the notch, launch-at-login and update options.

**VPN** shows whether your VPNs are connected and for how long, with a Disconnect button: FortiClient's VPN (or
otherwise one from System Settings) and OpenVPN Connect, a row each when both are installed. OpenVPN profiles
connect right from the notch (a menu picks the profile when there are several). FortiClient's VPN connects only
from FortiClient (it asks for your password or single sign-on), so its button opens FortiClient.

**Updating:** NotchBox looks for a new release soon after it starts and twice a day. When there is one, a dot
appears on the music note and the menu starts with "Update available"; click it, then Update, and NotchBox
quits, installs the new version and opens again. "Check for Updates…" checks right away, and checking can be
turned off in Settings. Running the install command again also updates.

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

NotchBox does not connect to the network, except to YouTube while you watch a video in the notch and to GitHub
(api.github.com) to look for a newer release. The update check sends nothing about you; turn it off with
"Check for Updates Automatically" in Settings. Track info stays on your Mac.

**The clipboard list** lives in memory only and is gone when NotchBox quits, except the items you pin: those are
saved in `~/Library/Application Support/NotchBox/pinned-clipboard.json`, readable only by you, until you unpin
or remove them.
Items that password managers mark as private (nspasteboard.org markers) and copied files are never kept, and
images larger than 25 MB are skipped. macOS may ask once whether NotchBox may paste from other apps; say Allow,
or the list stays empty.

**The calendar** asks for access only when you press "Show my calendar". NotchBox only reads this week's events
with EventKit; it never changes them and they stay on your Mac.

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
  Fareyle videonun üzerine yandan ya da alttan gelince video saydamlaşır; arkasını görüp tıklayabilirsin, yalnızca
  kapatma düğmesi kalır. Menü çubuğundan aşağı inerek gelirsen video saydamlaşmaz ve YouTube'un kendi düğmeleri çalışır.
- Oynatıcı rengini kapaktan alır: kapağın etrafında ince bir gölge, ilerleme çubuğu ve ses dalgası.
- Oynatıcının solunda panon durur: kopyaladığın son 20 yazı ve görsel, en yenisi en üstte. Birine tıklayınca
  tekrar kopyalanır; yanındaki × ile tek tek silebilir ya da çöp kutusuyla listenin tamamını temizleyebilirsin.
  Görsellerdeki göz düğmesi görseli oynatıcının yerinde büyük gösterir. Raptiye bir öğeyi sabitler: en üstte
  kalır, 20 sınırına takılmaz ve NotchBox yeniden açılınca da durur (en fazla 10 öğe). Çöp kutusu sabitlenenlere
  dokunmaz.
- Oynatıcının sağında, panoyla aynı genişlikte takvimin durur: üstte bu haftanın günleri (etkinliği olan günlerde
  nokta), altında seçili günün etkinlikleri. Bir güne tıklayınca o günün etkinlikleri gelir. Zoom, Meet, Teams, Webex
  ve FaceTime görüşmelerinde yeşil bir Katıl düğmesi çıkar; etkinliğe tıklayınca Takvim açılır.
- Apple Music ve Safari/Chrome'da YouTube ile test edildi. macOS'a "Şu An Çalıyor" bilgisi veren diğer uygulamalar
  (Spotify gibi) çalışmalı ama test edilmedi.
- Arayüz Türkçe ve İngilizce; sistem diline göre seçilir.

### Gereksinimler

- Apple silicon bir Mac (M1 veya sonrası)
- macOS 14 veya sonrası

Çentikli MacBook'larda NotchBox çentiğin içinde durur. Çentiği olmayan Mac'lerde (M1 MacBook Air, iMac, Mac mini,
Mac Studio ya da harici ekran) menü çubuğunun ortasına kendi küçük siyah çentiğini çizer ve aynı şekilde çalışır;
küçük notch'un ortasında şarkının adı yazar. Ayarlar'daki "Boştayken gizle" müzik çalmıyorken çentiği gizler (fareyi
oraya getirince yine açılır); "Çentiksiz ekranlarda göster" ise tamamen kapatır.

### Kurulum

Terminal'i aç ve şunu yapıştır:

```bash
curl -fsSL https://raw.githubusercontent.com/cyesaa/notch-box/main/install.sh | bash
```

Bu komut son sürümü indirir, `NotchBox.app`'i `/Applications` klasörüne (yönetici izni yoksa `~/Applications`)
koyar ve açar. Menü çubuğunda bir müzik notası ikonu çıkar; Ayarlar (⌘,), Güncellemeleri denetle ve Çık oradadır.

**Ayarlar**, notch'un üzerine geldiğinde oynatıcının solunda ve sağında ne duracağını seçtiğin yerdir (Pano, Takvim,
VPN ya da boş; zamanla yeni bileşenler eklenecek).

**VPN** bileşeni VPN'lerinin bağlı olup olmadığını ve ne kadar süredir bağlı olduklarını gösterir; "Bağlantıyı kes"
düğmesi vardır: FortiClient'ın VPN'i (yoksa Sistem Ayarları'ndaki bir VPN) ve OpenVPN Connect; ikisi de kuruluysa
her biri bir satırda. OpenVPN profillerine doğrudan notch'tan bağlanılır (birden fazla profil varsa menüden seçilir).
FortiClient'ın VPN'i yalnızca FortiClient'tan bağlanır (şifre ya da SSO ister); bu yüzden onun düğmesi FortiClient'ı açar. Çentik, açılışta başlatma ve güncelleme seçenekleri de buradadır.

**Güncelleme:** NotchBox açıldıktan kısa süre sonra ve günde iki kez yeni sürüm olup olmadığına bakar. Yeni sürüm
varsa müzik notasının yanında bir nokta çıkar ve menünün en üstünde "Güncelleme var" yazar; tıklayıp Güncelle'ye
basınca NotchBox kapanır, yeni sürümü kurar ve yeniden açılır. "Güncellemeleri denetle…" hemen bakar; otomatik
denetimi Ayarlar'dan kapatabilirsin. Kurulum komutunu tekrar çalıştırmak da günceller.

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

NotchBox, notch'ta video izlerken YouTube'a ve yeni sürüm olup olmadığına bakmak için GitHub'a (api.github.com)
bağlanmak dışında internete bağlanmaz. Güncelleme denetimi seninle ilgili hiçbir şey göndermez; Ayarlar'daki
"Güncellemeleri otomatik denetle" ile kapatabilirsin. Şarkı bilgileri Mac'inde kalır.

**Pano listesi** yalnızca bellekte tutulur ve NotchBox kapanınca silinir; tek istisna sabitlediğin öğelerdir. Onlar
sabitlemeyi kaldırana ya da silene kadar yalnızca senin okuyabildiğin
`~/Library/Application Support/NotchBox/pinned-clipboard.json` dosyasında saklanır. Şifre
yöneticilerinin gizli diye işaretlediği öğeler (nspasteboard.org işaretleri) ve kopyalanan dosyalar hiç tutulmaz,
25 MB'tan büyük görseller atlanır. macOS bir kez NotchBox'ın diğer uygulamalardan yapıştırmasına izin verip
vermeyeceğini sorabilir; İzin Ver demezsen liste boş kalır.

**Takvim**, yalnızca "Takvimi göster" düğmesine bastığında izin ister. NotchBox bu haftanın etkinliklerini EventKit
ile yalnızca okur; hiçbir şeyi değiştirmez ve bilgiler Mac'inde kalır.

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
