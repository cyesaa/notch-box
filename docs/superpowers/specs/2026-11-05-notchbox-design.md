# NotchBox — Tasarım Dokümanı

- **Tarih:** 2026-11-05
- **Durum:** Onaylandı (2026-11-05). Uygulama planı: `docs/superpowers/plans/2026-11-05-notchbox.md`
- **Hedef cihaz (geliştirme):** MacBook Pro (Mac16,1), macOS 27.2, dahili ekranda notch var

## 1. Özet

NotchBox, MacBook'un notch'unu müzik kontrol merkezine çeviren bir menü çubuğu uygulamasıdır.
Müzik çalarken notch'un iki yanında küçük bir albüm kapağı ve ses dalgası görünür.
Fare notch'un üstüne gelince notch yaylı bir animasyonla büyür. Büyüyen panelden, Mac'te çalan
herhangi bir kaynak (Spotify, Apple Music, tarayıcıdaki YouTube vb.) kontrol edilebilir.

## 2. Hedefler ve kapsam dışı

### Hedefler (v1)

- Müzik çalarken notch yanında mini kapak + ses dalgası.
- Hover'da büyüyen panelde: kapak, şarkı adı, sanatçı, önceki / oynat-duraklat / sonraki,
  sürüklenebilir ilerleme çubuğu, sistem ses seviyesi kaydırıcısı, kaynak uygulama ikonu.
- Hiçbir şey çalmıyorken hover'da küçük bir "Şu an bir şey çalmıyor" paneli.
- Arayüz dili: İngilizce + Türkçe, sistem diline göre otomatik.
- GitHub'da açık kaynak olarak yayınlanabilir durumda bir proje (README, lisans, derleme komutları).

### Kapsam dışı (v1)

- Uygulama bazında ses kontrolü (sadece sistem ses seviyesi var).
- Hangi çaların kontrol edileceğini elle seçmek (komutlar macOS'un aktif saydığı çalara gider).
- Kayan (marquee) uzun şarkı adı — v1'de "…" ile kesilir.
- Tam ekran uygulamalarda gizlenme seçeneği.
- Harici monitörlerde görünme.
- Takvim, dosya rafı, kamera gibi müzik dışı özellikler.
- Apple notarization, otomatik güncelleme, App Store.

## 3. Platform kısıtları ve kararlar

| Konu | Karar |
|---|---|
| Dil / UI | Swift 6 + SwiftUI, pencere tarafı AppKit (`NSPanel`) |
| Minimum macOS | 14 (Sonoma) — `@Observable` için |
| Derleme | Swift Package Manager. Xcode gerekmez, Command Line Tools yeterli |
| Şarkı bilgisi | [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) (BSD-3) — Apple imzalı `/usr/bin/perl` üzerinden MediaRemote erişimi |
| Test | Swift Testing (`import Testing`). XCTest Command Line Tools'ta yok. `swift test`, CLT'nin `TestingMacros` eklentisini kendisi bulamıyor; Makefile `-Xswiftc -plugin-path -Xswiftc <CLT>/usr/lib/swift/host/plugins/testing` ekler |
| SwiftUI makroları | `@State`, `#Preview` vb. kullanılmaz: macOS 27 SDK'da makro oldular ve `SwiftUIMacros` eklentisi yalnızca Xcode ile geliyor. Görünüm durumu `NotchViewModel`'de tutulur. `@Observable` kullanılabilir |
| Çeviri | Klasik `Localizable.strings` (`.xcstrings` derlemesi Xcode istiyor) |
| Adaptör derleme | CMake yok; adaptör kendi scriptimizle doğrudan `clang` ile derlenir |
| Dağıtım | Ad-hoc imzalı `.app`, GitHub Releases'ta zip |
| Bundle ID | `com.notchbox.NotchBox` |
| Lisans | MIT. Adaptörün BSD-3 lisansı `THIRD_PARTY_NOTICES.md` içinde |

**Neden mediaremote-adapter:** macOS 15.4'ten beri MediaRemote, Apple imzalı olmayan süreçlere
şu an çalan bilgisini vermiyor. Adaptör, Apple imzalı perl yorumlayıcısı üzerinden bu kısıtı aşıyor.
Bu resmi bir yol değil; Apple ileride kapatabilir. Bu yüzden müzik kaynağı bir protokolün arkasında
duruyor ve bozulursa kısıtlı moda geçiliyor (bkz. §7).

## 4. Mimari

İki hedef (target):

- **`NotchBoxCore`** — ekrandan bağımsız, test edilebilir mantık. AppKit'e bağımlı değil.
- **`NotchBox`** — uygulama: panel, SwiftUI görünümleri, AppKit/CoreAudio bağlantıları.

### Parçalar

| Parça | Hedef | Görev |
|---|---|---|
| `NotchGeometry` | Core | Ekran çerçevesi, `safeAreaInsets.top` ve `auxiliaryTopLeftArea` / `auxiliaryTopRightArea` değerlerinden notch dikdörtgenini hesaplayan saf fonksiyon. Notch genişliği = ekran genişliği − sol alan − sağ alan; yükseklik = `safeAreaInsets.top`. |
| `ScreenWatcher` | App | Notch'lu dahili ekranı bulur (`safeAreaInsets.top > 0`). `NSApplication.didChangeScreenParametersNotification` geldiğinde yeniden hesaplar. Notch'lu ekran yoksa paneli gizler. |
| `NotchPanel` | App | `NSPanel`: `[.borderless, .nonactivatingPanel]`, seviye menü çubuğunun üstünde, `collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]`, şeffaf arka plan, gölge yok. Notch'un ortasına, ekranın en üstüne hizalı. |
| `HoverTracker` | App | Global + yerel `mouseMoved` izleyicileriyle imlecin "sıcak bölge" (o an görünen siyah şekil) içinde olup olmadığını bildirir. `mouseMoved` için izin gerekmez. |
| `NotchStateMachine` | Core | Hover, müzik durumu ve zamana göre 4 hal arasında geçişi yöneten saf durum makinesi. Saat dışarıdan verilir (testte taklit edilir). |
| `NowPlayingService` (protokol) | Core | Şarkı durumunu yayınlar; komut alır: `togglePlayPause`, `next`, `previous`, `seek(to:)`. |
| `AdapterNowPlayingService` | App | Protokolün adaptörlü uygulaması. Perl sürecini başlatır, JSON satırlarını okur, komutları gönderir. Saf mantık (`AdapterStreamParser`, `AdapterCommandLine`, `AdapterSupervisor`) Core'dadır. |
| `NowPlayingPayload` | Core | Adaptörün JSON çıktısının `Decodable` modeli. |
| `PlaybackClock` | Core | Geçen süreyi hesaplar: çalıyorsa `elapsed + (şimdi − timestamp) × playbackRate`. |
| `AdapterSupervisor` | Core | Yeniden deneme süreleri (1, 2, 5, 10, 30 sn; 30'da sabitlenir) ve kısıtlı moda geçiş kararı. |
| `MediaKeySender` | App | Kısıtlı mod için medya tuşu (oynat/duraklat, ileri, geri) olayı gönderir. Erişilebilirlik izni ister. |
| `VolumeService` | App | CoreAudio ile varsayılan çıkış cihazının ses seviyesini okur/ayarlar; cihaz ve ses değişikliklerini dinler. |
| `NotchViewModel` | App | Servisleri ve durum makinesini birleştirip görünümlere tek bir durum verir. Servisleri opsiyonel alır (`NowPlayingService?`, `VolumeControlling?`, `MediaKeySending?`). |
| Görünümler | App | `NotchShape`, `NotchRootView`, `CollapsedView`, `ExpandedView`, `NothingPlayingView` (`EmptyView` adı SwiftUI'de var), `ArtworkView`, `WaveformView`, `ProgressRow`, `ControlsRow`, `VolumeRow`. |
| `StatusItemController` | App | Menü çubuğu ikonu ve menüsü: "Açılışta başlat" (`SMAppService.mainApp`), "Çık". |

### Bilgi akışı

```
AdapterNowPlayingService ─┐
VolumeService ────────────┼─→ NotchViewModel ─→ Görünümler (NotchPanel içinde)
HoverTracker ─────────────┤          ↑
ScreenWatcher ────────────┘   NotchStateMachine
```

Görünümler kullanıcı eylemlerini (`play`, `seek`, ses değişimi, ikona tıklama) `NotchViewModel`'e
iletir; view model ilgili servise gönderir.

## 5. Haller ve davranış

### 5.1 Dört hal

| Hal | Koşul | Görünüm |
|---|---|---|
| **Boşta** | Müzik yok (veya 5 dk'dan uzun duraklatılmış), fare sıcak bölgede değil | Panel notch'la aynı boyut ve siyah — görünmez |
| **Mini** | Müzik var (çalıyor veya 5 dk'dan kısa süredir duraklatılmış), fare yok | Yükseklik notch yüksekliği; her iki yana `notch yüksekliği + 12pt` kadar genişler. Solda kare kapak (kenar = notch yüksekliği − 8pt, köşe yarıçapı 6pt). Sağda 5 çubuklu dalga: çalarken oynar, duraklatılınca düz |
| **Açık** | Fare sıcak bölgede ≥ 0.1 sn ve müzik bilgisi var | 400 × 200pt (notch yüksekliği dahil; 170pt beş satıra yetmedi). Bkz. §5.2 |
| **Açık-boş** | Fare sıcak bölgede ≥ 0.1 sn ve müzik bilgisi yok | 300 × 80pt; müzik notası ikonu + "Şu an bir şey çalmıyor" |

Kısıtlı modda (§7) şarkı bilgisi olmadığı için Mini hal gösterilmez (fare yokken Boşta).
Hover'da **Açık** hal, şarkı bilgisi yerine "Şarkı bilgisi alınamıyor" yazısı ve
yalnızca önceki / oynat-duraklat / sonraki butonlarıyla gösterilir.

### 5.2 Açık hal yerleşimi

```
┌────────────── notch ──────────────┐
│ [kapak]  Şarkı adı          [app] │
│          Sanatçı                  │
│ 1:12 ━━━━━━━●─────────────  -2:31 │
│          ⏮      ⏯      ⏭          │
│ 🔈 ━━━━━━━━━━━●──────────  🔊      │
└───────────────────────────────────┘
```

- Kapak 64 × 64pt, köşe yarıçapı 10pt.
- Şarkı adı ve sanatçı tek satır, sığmazsa "…" ile kesilir.
- `[app]`: kaynak uygulamanın ikonu (`NSWorkspace`). Tıklanınca o uygulama öne gelir.
  Tarayıcıdan çalıyorsa tarayıcının ikonu görünür.
- İlerleme çubuğu: sürüklerken yerel değer gösterilir, bırakınca `seek` gönderilir.
  Süre bilinmiyorsa (ör. canlı yayın) çubuk gizlenir.
- Ses kaydırıcısı: sistem ses seviyesi. Cihaz desteklemiyorsa soluk ve devre dışı.

### 5.3 Hover kuralları

- **Sıcak bölge:** O an görünen siyah şekil (Boşta'da notch, Mini'de genişlemiş şekil, Açık'ta panel).
- **Açılma:** İmleç sıcak bölgede 0.1 sn kalınca.
- **Kapanma:** İmleç sıcak bölgeden çıktıktan 0.3 sn sonra (geri gelirse iptal).
- **Tıklama geçirgenliği:** Panel Açık değilken `ignoresMouseEvents = true` — menü çubuğu
  tıklamaları engellenmez. Açık halde fare olaylarını alır.
- **Odak:** Panel `nonactivating`; tıklamak öndeki uygulamanın odağını almaz.

### 5.4 Animasyon

- Boyut geçişleri: SwiftUI spring (`response: 0.35`, `dampingFraction: 0.8`).
- Köşe yarıçapı boyutla birlikte büyür (Boşta/Mini: alt köşeler ~8pt, Açık: ~20pt).
- İçerik, şekil büyümeye başladıktan 0.08 sn sonra opaklıkla belirir; kapanırken önce içerik kaybolur.
- Şarkı değişiminde kapak çapraz geçişle (crossfade) değişir.

### 5.5 Duraklatma zaman aşımı

Müzik 5 dakika boyunca duraklatılmış kalırsa Mini → Boşta. Hover edilince Açık hal yine son
şarkıyla açılır ve oynat butonu çalışır. Müzik yeniden başlayınca Mini'ye dönülür.

## 6. Müzik kaynağı (adaptör)

- Adaptör `Vendor/mediaremote-adapter` altında **git submodule** olarak, son sürüm etiketine sabitlenir.
- `scripts/build-adapter.sh`, adaptörün framework'ünü `clang` ile derler.
- Paketlemede framework `NotchBox.app/Contents/Frameworks/` içine, perl scripti
  `NotchBox.app/Contents/Resources/` içine kopyalanır.
- `AdapterNowPlayingService`, `/usr/bin/perl <script> <framework> stream` sürecini uygulama açıkken
  sürekli çalıştırır; stdout'tan gelen JSON satırlarını `NowPlayingPayload` olarak çözer.
- Komutlar ayrı, kısa ömürlü perl süreçleriyle gönderilir (`send <komut>`, `seek <süre>`).
  Kesin komut adları ve parametreler Aşama 0'da (§10) adaptörün belgelerinden doğrulanır.
- Kapak verisi JSON içinde base64 gelir. Görüntüye (`NSImage`) yalnızca kapak değiştiğinde çevrilir.
- İlerleme, adaptöre sorulmadan `PlaybackClock` ile saniyede bir yerel olarak güncellenir.
- Komutlar macOS'un aktif saydığı çalara gider (adaptörün sınırı).

## 7. Hata durumları

| Durum | Davranış |
|---|---|
| Adaptör süreci kapandı / çöktü | `AdapterSupervisor` sürelerine göre yeniden başlatılır. Bu sırada son bilinen şarkı ekranda kalır. |
| Adaptör üst üste 3 kez, başladıktan sonraki 5 sn içinde kapandı | **Kısıtlı mod.** Panelde "Şarkı bilgisi alınamıyor"; butonlar `MediaKeySender` ile çalışır. Arka planda her 60 sn'de bir adaptör yeniden denenir; çalışırsa normal moda dönülür. |
| Kısıtlı modda ilk buton basışı | Erişilebilirlik izni yoksa macOS izin penceresi istenir. İzin normal modda hiç istenmez. |
| JSON satırı çözülemedi | Satır atlanır ve loglanır; süreç çalışmaya devam eder. |
| Şarkı geçişinde adaptör kısa bir an "hiçbir şey çalmıyor" bildirdi | Bu durum 1.5 sn bekletilir; arada şarkı bilgisi gelirse uygulanmaz. Böylece mini görünüm titremez (bkz. `docs/spike-results.md`). |
| Kapak yok / çözülemedi | Gradyan zemin üzerinde müzik notası. |
| Ses cihazı ses kontrolünü desteklemiyor | Kaydırıcı soluk ve devre dışı. |
| Mac uykudan uyandı | Adaptör süreci kontrol edilir; çalışmıyorsa yeniden başlatılır. |
| Notch'lu ekran yok (ör. kapak kapalı, harici monitör) | Panel gizlenir; uygulama bekler, menü çubuğu ikonu çalışır. Ekran geri gelince panel geri gelir. |

Loglar `os.Logger` ile, alt sistem `com.notchbox.NotchBox`.

**Gizlilik:** Uygulama ağ bağlantısı yapmaz; tüm veriler yerelde kalır.

## 8. Derleme ve paketleme

```
notch-box/
├── Package.swift
├── Makefile
├── Sources/
│   ├── NotchBox/
│   └── NotchBoxCore/
├── Tests/NotchBoxCoreTests/
├── Resources/
│   ├── Info.plist
│   ├── en.lproj/Localizable.strings
│   └── tr.lproj/Localizable.strings
├── Vendor/mediaremote-adapter/      (git submodule)
├── scripts/
│   ├── build-adapter.sh
│   ├── bundle.sh
│   └── dist.sh
├── docs/
│   ├── manual-testing.md
│   └── superpowers/specs/
├── README.md
├── LICENSE
├── THIRD_PARTY_NOTICES.md
└── .gitignore
```

- **Çeviriler SwiftPM kaynağı olarak kullanılmaz.** SwiftPM'in kaynak paketi elle oluşturulan
  `.app` içinde imzalamayı bozan bir yere konuyor. Bu yüzden `bundle.sh`, `.lproj` klasörlerini
  doğrudan `Contents/Resources/` içine kopyalar; kod `Bundle.main` kullanır.
- `Info.plist`: `LSUIElement = true` (Dock ikonu yok), `CFBundleIdentifier = com.notchbox.NotchBox`,
  `LSMinimumSystemVersion = 14.0`, `CFBundleDevelopmentRegion = en`, `CFBundleLocalizations = [en, tr]`,
  `CFBundleShortVersionString = 0.1.0` (ilk sürüm; `make dist` dosya adındaki sürümü buradan okur).
- İmza: `codesign --force --deep --sign -` (ad-hoc).

| Komut | İş |
|---|---|
| `make build` | `swift build` |
| `make test` | `swift test` (+ CLT'de Testing eklenti yolu; `FILTER=<Suite>` ile tek suite) |
| `make app` | Release derleme + adaptör + `build/NotchBox.app` |
| `make run` | `make app` ardından uygulamayı açar (çeviriler yalnızca `.app` içinden yüklendiği için ham ikili çalıştırılmaz) |
| `make dist` | `dist/NotchBox-<sürüm>.zip` |

"Açılışta başlat" en güvenilir şekilde uygulama `/Applications` içindeyken çalışır; README'de belirtilir.

## 9. Test

### Otomatik (Swift Testing, `NotchBoxCoreTests`)

- `NotchGeometry`: örnek ekran değerleriyle notch dikdörtgeni; notch'suz ekranda `nil`.
- `NotchStateMachine`: 4 hal arası geçişler, 0.1 sn açılma ve 0.3 sn kapanma gecikmeleri,
  kapanma sırasında geri gelince iptal, 5 dk duraklatma zaman aşımı, kısıtlı mod.
  Saat taklit edilir; testler gerçekten beklemez.
- `NowPlayingPayload`: örnek adaptör JSON'larının çözülmesi (tam, eksik alanlı, bozuk).
- `PlaybackClock`: çalarken / duraklatılmışken / farklı hızlarda geçen süre.
- `AdapterSupervisor`: bekleme sırası ve 3 hızlı çöküşte kısıtlı moda geçiş.

### Elle (`docs/manual-testing.md`, README'den bağlantılı)

- Spotify, Apple Music, Safari'de YouTube, Chrome'da YouTube: bilgi, kapak, kontroller, sarma.
- Duraklat → 5 dk bekle → Boşta'ya dönüş.
- Menü çubuğunda notch yanındaki öğelere tıklama (panel engellemiyor mu).
- Harici monitör tak/çıkar; kapak kapat/aç.
- Uyku → uyanma.
- Klavyeden ses değiştirme → kaydırıcı güncelleniyor mu.
- Sistem dili İngilizce / Türkçe.

## 10. Riskler ve Aşama 0 (kodlamadan önce doğrulama)

Uygulama kodu yazılmadan önce şu sorular küçük bir deneme ile yanıtlanır:

1. Adaptör framework'ü CMake olmadan `clang` ile derlenebiliyor mu?
2. `stream` macOS 27.2'de Spotify, Apple Music ve tarayıcı YouTube bilgisini veriyor mu?
3. Oynat/duraklat, ileri/geri ve `seek` komutları çalışıyor mu?
4. Global `mouseMoved` izleyicisi izin istemeden çalışıyor mu?
5. Panel notch'un üstünde, menü çubuğunun üstünde görünüyor ve `ignoresMouseEvents` ile
   menü çubuğu tıklamalarını geçiriyor mu?

Soru 1–3 planın Task 0'ında (adaptör denemesi) yanıtlanır. Soru 4–5 çalışan bir panel gerektirdiği için
Task 8'de, panel yazılır yazılmaz kontrol edilir; başarısız olursa planda yedek çözümler var.

**2 başarısız olursa** kodlamaya geçilmez; kullanıcıyla birlikte plan yeniden ele alınır
(seçenekler: yalnızca Spotify/Apple Music için AppleScript, ya da baştan kısıtlı mod).

## 11. GitHub

- README: İngilizce, altında Türkçe bölüm. İçerik: ne yapar, ekran görüntüsü, kurulum,
  "tanınmayan geliştirici" uyarısının nasıl geçileceği, gizlilik notu, bilinen sınırlar,
  geliştirme komutları, elle test listesine bağlantı.
- `.gitignore`: `.build/`, `build/`, `dist/`, `.swiftpm/`, `.DS_Store`.
- Uzak repo henüz yok. `gh` ve Homebrew kurulu değil. Repo açılmadan önce kullanıcıya
  public/private sorulur; kullanıcı `gh auth login` ile kendi girişini yapar ya da boş repo linkini verir.

## 12. Kullanıcı kararları

| Soru | Karar |
|---|---|
| Kapalıyken müzik çalarken gösterge | Evet: mini kapak + dalga |
| Açık panel içeriği | Kontroller + ilerleme/sarma + ses seviyesi + kaynak uygulama ikonu |
| Hiçbir şey çalmıyorken hover | Hafif büyür, "Şu an bir şey çalmıyor" |
| Arayüz dili | İngilizce + Türkçe, otomatik |
| Yaklaşım | Sıfırdan Swift/SwiftUI + mediaremote-adapter |
| Lisans | MIT |
