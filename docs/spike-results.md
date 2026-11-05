# Aşama 0 — Adaptör deneme sonuçları

- **Tarih:** 2026-11-06
- **macOS:** 27.2 (MacBook Pro, Mac16,1)
- **Adaptör:** ungive/mediaremote-adapter v0.7.7
- **Not:** Spotify bu Mac'te kurulu değil; denemeler Chrome, Apple Music ve Safari ile yapıldı.

## Derleme

- `scripts/build-adapter.sh`: başarılı. CMake gerekmedi.
- Scriptteki `SOURCES` glob'u, `CMakeLists.txt` içindeki `ADAPTER_SOURCES` listesiyle aynı (15 dosya).
- `nm -gU … | grep adapter_` çıktısında `_adapter_get_env`, `_adapter_stream_env`, `_adapter_send_env`,
  `_adapter_seek_env`, `_adapter_repeat_env`, `_adapter_shuffle_env`, `_adapter_speed_env` ve `_adapter_test` var.

## Kaynaklara göre sonuçlar

| Kaynak | `get` başlığı doğru mu | `bundleIdentifier` / `parentApplicationBundleIdentifier` | `stream` değişiklikte satır basıyor mu | `send 2` | `send 4` | `send 5` | `seek 30000000` |
|---|---|---|---|---|---|---|---|
| Spotify | kurulu değil | — | — | — | — | — | — |
| Apple Music | evet (kapak: JPEG, ~100 KB base64) | `com.apple.Music` / yok | — (stream Chrome ile denendi) | ✅ | ✅ (ilk deneme sarmadan hemen sonra etkisiz kaldı, ikincisi çalıştı) | ✅ (şarkı başa döndü) | ✅ |
| Safari YouTube | evet | `com.apple.WebKit.GPU` / `com.apple.Safari` | — | ✅ | ✅ | ✅ | ✅ |
| Chrome YouTube | evet | `com.google.Chrome` / yok | ✅ (13 satır: duraklat, devam, sonraki) | ✅ | ✅ | ✅ | ✅ |

## Hiçbir şey çalmıyorken

- `get` → `null`
- `stream` başlarken ilk satırı her zaman boş payload olarak basıyor: `{"type":"data","diff":false,"payload":{}}`

## Örnek bir `stream` satırı (artwork olmadan; şarkı bilgileri maskelendi)

```json
{"type":"data","diff":false,"payload":{"artist":"<artist>","timestampEpochMicros":1793912637821865,"contentItemIdentifier":"<id>","title":"<title>","bundleIdentifier":"com.google.Chrome","elapsedTimeMicros":0,"album":"","durationMicros":218421000,"processIdentifier":1234,"playbackRate":1,"playing":true}}
```

JSON alan adları ve tipleri planla aynı. `playing` boolean geliyor; `album` boş string olabiliyor (parser bunu `nil` yapıyor).
`processIdentifier` ve `contentItemIdentifier` ek alanlar; parser bunları görmezden geliyor.

## Davranışla ilgili gözlemler

1. **Şarkı geçişinde boş satır:** Chrome'da bir sonraki videoya geçerken iki dolu satırın arasına
   `{"payload":{}}` satırı geldi. Bu satır olduğu gibi uygulanırsa mini görünüm ve açık panel bir anlığına
   kaybolup geri gelir. Karar: `AdapterNowPlayingService` "hiçbir şey çalmıyor" durumunu 1.5 sn bekleterek
   uygular; arada dolu bir satır gelirse bekleyen güncelleme iptal edilir (plan Task 9 buna göre güncellendi).
2. **Geçiş satırları:** Duraklatıp devam ettirirken ara satırlar geliyor:
   - `playing:false`, `elapsedTimeMicros:0`, `playbackRate:1`
   - `playing:true`, `playbackRate:0`

   `PlaybackClock` çalarken hız 0 gelirse 1 kabul ediyor, duraklatılmışken ilerlemiyor. Bu yüzden ikinci tür satır sorun
   yaratmıyor. Birinci tür satır ise ilerleme çubuğunu çok kısa bir an 0:00'a çekebilir (küçük görsel kusur; son incelemede
   değerlendirilecek).
3. **Apple Music'te "sonraki":** Sarma komutundan 1.5 sn sonra gönderilen `send 4` etkisiz kaldı; tekrar gönderilince çalıştı.
   Bu, adaptörün değil Music'in davranışı gibi görünüyor. Uygulamada bir değişiklik gerekmiyor.

## Karar

**Devam.** Adaptör macOS 27.2'de üç kaynakta da bilgi okuyor ve bütün komutları iletiyor. Parser'da değişiklik gerekmiyor.
Tek plan değişikliği, 1. gözlem için Task 9'a eklenen 1.5 sn bekleme.
