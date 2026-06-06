# RaiSaver

Aplikasi desktop Windows untuk download video dan audio dari YouTube, TikTok, dan Instagram — tanpa watermark.

Dibangun dengan Flutter (frontend) dan FastAPI + Python (backend).

---

## Fitur

- **YouTube** — download video (144p–2160p) atau audio MP3
- **TikTok** — download video tanpa watermark, foto/slideshow sebagai ZIP, merge audio otomatis via FFmpeg
- **Instagram** — download Reels, foto, carousel (ZIP), caption lengkap
- Progress bar real-time dengan speed dan total size
- Desain minimalis hitam-putih — konsisten dengan versi website
- Badge indikator Local/Remote di navbar
- Pilih folder simpan custom
- Windows desktop app (1100×720, terpusat di layar)

---

## Tech Stack

| Layer | Stack |
|---|---|
| Frontend | Flutter (Windows), Dart, Google Fonts (DM Sans + Inter) |
| Backend | FastAPI, Python 3.11+ |
| Download | yt-dlp (YouTube), TikWM API (TikTok), Sankavollerei (Instagram) |
| Processing | FFmpeg (merge video+audio TikTok) |
| HTTP | Dio, requests |

---

## Struktur Project

```
raisaver/
├── lib/
│   ├── main.dart          # Flutter app — UI + download logic
│   └── config.dart        # Backend URL config
├── backend/
│   └── main.py            # FastAPI server
├── website/               # Web version (HTML/CSS/JS)
│   ├── index.html
│   ├── style.css
│   └── app.js
├── assets/
│   └── images/
│       └── avatar.jpg     # Foto profil creator card
└── windows/               # Windows runner config
```

---

## Setup

### 1. Backend (lokal)

```bash
cd backend
pip install fastapi uvicorn yt-dlp requests python-dotenv
uvicorn main:app --host 0.0.0.0 --port 8000
```

Pastikan **FFmpeg** sudah ada di PATH:
```bash
ffmpeg -version
```

### 2. Flutter App

```bash
flutter pub get
flutter run -d windows
```

Backend URL default ke Railway. Ganti lewat dialog settings di app (badge di navbar) atau edit `lib/config.dart`:

```dart
class AppConfig {
  static const String defaultBackendUrl = 'https://your-railway-url.up.railway.app';
  static const String localBackendUrlDesktop = 'http://127.0.0.1:8000';
}
```

### 3. Build Release

```bash
flutter build windows --release
```

Output: `build/windows/x64/runner/Release/`

---

## API Endpoints

| Method | Endpoint | Keterangan |
|---|---|---|
| GET | `/info?url=` | Info video YouTube |
| GET | `/download/video?url=&format_id=&task_id=` | Download video YouTube |
| GET | `/download/audio?url=&task_id=` | Download MP3 YouTube |
| GET | `/tiktok/info?url=` | Info video/foto TikTok |
| GET | `/tiktok/download?url=&format_id=&task_id=` | Download TikTok (auto merge audio) |
| GET | `/tiktok/download/all?url=&task_id=` | Download semua foto TikTok (ZIP) |
| GET | `/instagram/info?url=` | Info post Instagram |
| GET | `/instagram/download?url=&format_id=&task_id=` | Download Instagram |
| GET | `/instagram/download/all?url=&task_id=` | Download carousel Instagram (ZIP) |
| GET | `/progress?task_id=` | Status & progress download |
| GET | `/proxy-image?url=` | Proxy thumbnail (hindari CORS) |

---

## Backend Mode

App mendukung 3 mode backend yang bisa diganti langsung dari navbar:

- 🟢 **Local** — `http://127.0.0.1:8000` (backend jalan di mesin sendiri)
- 🔵 **Remote** — Cloud Server
- ⚪ **Custom** — URL apapun

Badge mode aktif tampil di sebelah logo di navbar.

---

## TikTok — Audio Merge

Beberapa video TikTok (terutama yang pakai musik Spotify) memiliki audio terpisah dari stream video. Backend secara otomatis:

1. Download video dari TikWM (`play` URL)
2. Download audio dari `music` URL (audio_mpeg)
3. Merge keduanya dengan FFmpeg (`-c:v copy -c:a aac -b:a 192k`)
4. Fallback ke video-only jika FFmpeg gagal

---

## Website

Versi web tersedia di folder `website/` — bisa dibuka langsung di browser atau di-deploy ke static hosting. Mendukung platform yang sama dengan app Flutter.

---

## Credits

- [yt-dlp](https://github.com/yt-dlp/yt-dlp) — YouTube downloader
- [TikWM](https://www.tikwm.com) — TikTok API
- [FastAPI](https://fastapi.tiangolo.com) — Python web framework
- [Flutter](https://flutter.dev) — Cross-platform UI framework

---

**Build by Andhika Rafi (dhiksn)**
