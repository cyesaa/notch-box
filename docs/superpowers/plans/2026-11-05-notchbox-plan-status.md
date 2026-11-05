# NotchBox — Plan durumu (ara kayıt)

- **Tarih:** 2026-11-05
- **Durum:** Uygulama planı yazılıyor. Plandaki kod `verified-code/` altında önceden yazılıp doğrulandı.

## Doğrulanan kod

`verified-code/` bir Swift paketi. Komut satırı araçlarıyla (Xcode yok) şunlar doğrulandı:

- `swift build`: uygulama ve core hedefleri derleniyor (Swift 6.4, macOS 27.2 SDK, Swift 5 dil modu).
- `swift test -Xswiftc -plugin-path -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing`:
  10 suite'te 53 test geçti.
- Henüz doğrulanmadı: adaptörün derlenmesi ve çalışması (Aşama 0), `.app` paketleme, elle testler.

## Kodlama sırasında ortaya çıkan bulgular (spec'e işlenecek)

1. **`@State` kullanılamaz.** macOS 27 SDK'da SwiftUI `@State` bir makro ve `SwiftUIMacros` eklentisi
   yalnızca Xcode ile geliyor. Aynı sebeple `#Preview` de kullanılamaz. Görünüm durumu (ör. ilerleme
   çubuğunu sürükleme) `NotchViewModel` içinde tutulur.
2. **`swift test` makro eklenti yolu ister.** Swift Testing'in `TestingMacros` eklentisi bulunmuyor.
   Makefile, geliştirici dizini Command Line Tools iken
   `-Xswiftc -plugin-path -Xswiftc <CLT>/usr/lib/swift/host/plugins/testing` ekler.
3. **Açık hal yüksekliği 200pt.** 170pt'ye beş satır (başlık, sanatçı, ilerleme, kontroller, ses) sığmıyor;
   açık hal 400 × 200pt.
4. **`EmptyView` adı SwiftUI ile çakışıyor.** Görünüm `NothingPlayingView` adını alır.
5. **Bağımlılıklar opsiyonel.** `NotchViewModel` servisleri opsiyonel alır
   (`NowPlayingService?`, `VolumeControlling?`, `MediaKeySending?`); böylece servisler görevler arasında
   tek tek eklenebilir.

## Adaptör (ungive/mediaremote-adapter v0.7.7) — doğrulanmış bilgiler

- Çağrı: `/usr/bin/perl <script> <MediaRemoteAdapter.framework dizini> <komut>` (yollar mutlak).
- `stream --no-diff --micros --debounce=100` → her satır `{"type":"data","diff":false,"payload":{…}}`;
  hiçbir şey çalmıyorsa `payload` `{}`.
- Alanlar: `bundleIdentifier`, `parentApplicationBundleIdentifier`, `playing`, `title`, `artist`, `album`,
  `durationMicros`, `elapsedTimeMicros`, `timestampEpochMicros`, `playbackRate`, `artworkData` (base64).
- Komutlar: `send 2` oynat/duraklat, `send 4` sonraki, `send 5` önceki, `seek <mikrosaniye>`.
- Derleme: `src/adapter/*.m src/private/*.m src/utility/*.m`, `-fobjc-arc -fvisibility=default`,
  Foundation + AppKit + UniformTypeIdentifiers; çıktı sürümlü `.framework` dizini, ad-hoc imza.
- Lisans: BSD 3-Clause, "Copyright (c) 2025, Jonas van den Berg and contributors".

## Görev sırası (tam plan bu sırayla yazılacak)

0. Adaptör denemesi (submodule + `scripts/build-adapter.sh` + elle `get`/`stream`/`send`/`seek`) — **kapı**
1. Paket iskeleti + Makefile + Swift Testing duman testi
2. `NotchGeometry` + `NotchLayout`
3. `NotchStateMachine`
4. `PlaybackClock` + `TimeFormatter`
5. Now playing modelleri + `AdapterStreamParser` + `AdapterCommandLine` + `MediaKeyCode`
6. `AdapterSupervisor`
7. Uygulama kabuğu: Info.plist, çeviriler, `bundle.sh`, menü çubuğu ikonu
8. Panel + hover + `NotchViewModel` (servissiz) — Aşama 0 soru 4–5 burada doğrulanır
9. `AdapterNowPlayingService` + mini/açık görünümler
10. `VolumeService`
11. `MediaKeySender` + kısıtlı mod
12. README (EN+TR), LICENSE (MIT), THIRD_PARTY_NOTICES, `docs/manual-testing.md`, `make dist`

## Sıradaki adım

`verified-code/` içindeki kodu görev görev, TDD adımlarıyla `2026-11-05-notchbox.md` planına dönüştürmek.
