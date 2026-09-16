# Search sources: module two

Verified on Windows on 2026-09-14, using the application's Dart HTTP client,
parsers, image decoder and file downloader. Proxy was disabled. These results
describe this machine's network, not a guarantee of availability across China.

| Source | Search endpoint | First / second page | Thumbnail | Original saved and decoded |
| --- | --- | --- | --- | --- |
| Safebooru | safebooru.org DAPI | 2 / 2, distinct results | 188 x 250 | 1536 x 2048, 438362 bytes |
| Danbooru (Safe) | safebooru.donmai.us/posts.json | 2 / 2, distinct results | 135 x 180 | 1536 x 2048, 438362 bytes |
| Zerochan | www.zerochan.net/Scenery?json | 24 / 24, distinct results | 600 x 337 | 1800 x 1012, 2255279 bytes |
| TBIB (Safe) | tbib.org DAPI | 2 / 2, distinct results | 102 x 150 | 812 x 1200, 163244 bytes |

Search keyword: `scenery` (`Scenery` for Zerochan). TBIB queries include
`rating:safe`. Safebooru and Danbooru Safe may contain overlapping artworks;
they are separate sites, not four disjoint image collections.

Zerochan's first full-image download exceeded the old 60-second limit. The
successful rerun took approximately 4 minutes 33 seconds including search and
thumbnail requests. Downloads and original previews now use a 20-second response
header deadline and a 30-second idle-data timeout instead of a total-transfer
deadline. Large files remain slow on this connection. Zerochan search supplies
a detail endpoint; the app resolves its actual original URL before navigating
to preview, collecting history, favoriting or downloading. JPEG previews avoid
depending on platform AVIF decoding.

## Replaced sources

- Konachan.net returned a Cloudflare browser challenge for HTML and JSON searches.
- yande.re and the primary danbooru.donmai.us host timed out on this connection.
  Danbooru's official Safe host passed the full test and is used instead.
- Realbooru's old Moebooru configuration and the third-party Baidu/Bing aggregate
  configurations were removed from the built-in catalog. This is a configuration
  replacement, not a claim that each upstream website is permanently offline.
- The `alcy_recommend` recommendation configuration is unchanged. Existing
  favorites, history, downloaded files and custom sources are not removed.

## Proxy and platform coverage

- Native search, thumbnails, original previews, detail resolution and downloads
  use the same HTTP-client factory. Every request snapshots the latest proxy
  settings; prior requests retain their route. Failed requests do not silently
  fall back to direct connections.
- Startup restores persisted proxy settings before the app starts requests.
  The settings page saves host, HTTP/mixed port and enable state together.
- Local proxy tests cover HTTP routing, switching two proxies, switching back
  to direct, search parsing, saved download bytes and HTTPS CONNECT rejection.
- No working external proxy was available; overseas proxy reachability has not
  been verified. No Android device was connected; Windows-hosted Flutter tests
  do not substitute for Android device acceptance.
- Android loopback refers to the phone itself. To use a desktop proxy, configure
  its reachable LAN address and HTTP/mixed port, with LAN connections enabled in
  that proxy. SOCKS-only ports are not supported.
- Web retains the existing CORS mechanism and is not certified by this module.

## Reproduction

Normal regression suite (live tests are skipped):

```powershell
flutter test --no-pub
flutter analyze --no-pub
```

Explicit network acceptance:

```powershell
flutter test --no-pub test/live/source_live_test.dart --dart-define=RUN_SOURCE_LIVE=true --concurrency=1
```

Results and sample files are written under `build/source-checks/<source>/`.
`result.json` includes UTC timestamps, dimensions, downloaded size and failures.
Running this test does not modify the user's app records or download directory.

Official API references:

- https://safebooru.org/index.php?page=help&topic=dapi
- https://safebooru.donmai.us/wiki_pages/help:api
- https://tbib.org/index.php?page=help&topic=dapi
- Zerochan list/detail JSON responses were verified directly on www.zerochan.net.

Danbooru accepts tag searches subject to its anonymous-account restrictions;
HTTP 422 prompts the user to simplify the query. Automatic translation of
Chinese keywords into site tags is not implemented.
