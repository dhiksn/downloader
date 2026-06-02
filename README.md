# LiquiTube - YouTube Downloader

Aplikasi Flutter modern untuk download video dan audio dari YouTube dengan UI glassmorphism yang elegan.

## ✨ Features

- 🎥 Download video dalam berbagai resolusi (144p - 4K)
- 🎵 Download audio only (MP3 format)
- 📊 Real-time download progress tracking
- 🎨 Modern glassmorphism UI design
- 📱 Support Android & iOS
- 🌐 Backend deployment ke PythonAnywhere (Free!)
- 🔄 Automatic video + audio merging
- 🖼️ Embed thumbnail dan metadata

## 🏗️ Architecture

Project ini terdiri dari 2 bagian:

### Frontend (Flutter)
- Modern UI dengan glassmorphism design
- Real-time progress tracking
- Custom download location
- File management

### Backend (FastAPI + Python)
- RESTful API dengan FastAPI
- yt-dlp untuk download YouTube
- FFmpeg untuk video/audio processing
- Deploy ke PythonAnywhere (Free tier available!)

## 🚀 Quick Start

### 1. Setup Backend (5 menit)

Backend perlu di-deploy dulu sebelum menjalankan Flutter app.

**Recommended: Deploy ke PythonAnywhere (Free)**

```bash
cd backend
# Ikuti panduan di PYTHONANYWHERE_QUICKSTART.md
```

📚 **Backend Documentation:**
- [Quick Start (5 menit)](./backend/PYTHONANYWHERE_QUICKSTART.md) ⭐
- [Full Deployment Guide](./backend/DEPLOY_PYTHONANYWHERE.md)
- [Deployment Checklist](./backend/DEPLOYMENT_CHECKLIST.md)
- [Troubleshooting](./backend/TROUBLESHOOTING.md)
- [Platform Comparison](./backend/DEPLOYMENT_COMPARISON.md)
- [Documentation Index](./backend/DOCS_INDEX.md)

**Alternative: Local Development**

```bash
cd backend
pip install -r requirements.txt
python main.py
# Backend akan berjalan di http://localhost:8000
```

### 2. Configure Flutter App

Edit `lib/config.dart`:

```dart
class AppConfig {
  // Ganti dengan URL PythonAnywhere Anda
  static const String backendUrl = 'https://YOUR_USERNAME.pythonanywhere.com';
}
```

### 3. Run Flutter App

```bash
flutter pub get
flutter run
```

## 📱 Screenshots

[Tambahkan screenshots di sini]

## 🛠️ Tech Stack

### Frontend
- **Flutter** - Cross-platform mobile framework
- **Dart** - Programming language
- **Google Fonts** - Custom fonts (Outfit)
- **Dio** - HTTP client untuk download
- **Path Provider** - File system access
- **Permission Handler** - Storage permissions

### Backend
- **FastAPI** - Modern Python web framework
- **yt-dlp** - YouTube downloader library
- **FFmpeg** - Video/audio processing
- **Uvicorn** - ASGI server
- **PythonAnywhere** - Free hosting platform

## 📦 Installation

### Prerequisites

- Flutter SDK (3.0+)
- Dart SDK (3.0+)
- Android Studio / Xcode (untuk build)
- Python 3.8+ (untuk backend development)

### Clone Repository

```bash
git clone https://github.com/YOUR_USERNAME/yt_downloader.git
cd yt_downloader
```

### Install Dependencies

```bash
# Flutter dependencies
flutter pub get

# Backend dependencies (jika run local)
cd backend
pip install -r requirements.txt
```

## 🔧 Configuration

### Backend URL

Edit `lib/config.dart` untuk set backend URL:

```dart
// Production (PythonAnywhere)
static const String backendUrl = 'https://username.pythonanywhere.com';

// Development (Local)
static const String backendUrl = 'http://localhost:8000';

// Testing (Ngrok)
static const String backendUrl = 'https://your-url.ngrok-free.app';
```

### Download Location

Aplikasi akan otomatis save ke:
- **Android**: `/storage/emulated/0/Download`
- **iOS**: App Documents directory

User bisa ubah lokasi via Settings (FAB menu).

## 🚀 Deployment

### Backend Deployment

**Option 1: PythonAnywhere (Recommended - Free)**

Lihat panduan lengkap: [backend/PYTHONANYWHERE_QUICKSTART.md](./backend/PYTHONANYWHERE_QUICKSTART.md)

**Option 2: Railway / Render / VPS**

Lihat comparison: [backend/DEPLOYMENT_COMPARISON.md](./backend/DEPLOYMENT_COMPARISON.md)

### Flutter App Deployment

**Android:**
```bash
flutter build apk --release
# APK ada di: build/app/outputs/flutter-apk/app-release.apk
```

**iOS:**
```bash
flutter build ios --release
# Buka Xcode untuk archive dan upload ke App Store
```

## 📖 API Documentation

Backend menyediakan REST API:

### GET /info
Get video information
```bash
GET /info?url=https://www.youtube.com/watch?v=VIDEO_ID
```

### GET /download/video
Download video
```bash
GET /download/video?url=VIDEO_URL&format_id=FORMAT_ID&task_id=TASK_ID
```

### GET /download/audio
Download audio only
```bash
GET /download/audio?url=VIDEO_URL&task_id=TASK_ID
```

### GET /progress
Get download progress
```bash
GET /progress?task_id=TASK_ID
```

Lihat detail lengkap: [backend/README.md](./backend/README.md)

## 🐛 Troubleshooting

### Backend Issues
Lihat: [backend/TROUBLESHOOTING.md](./backend/TROUBLESHOOTING.md)

### Flutter Issues

**Permission Denied (Android)**
```bash
# Tambahkan di AndroidManifest.xml
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
```

**CORS Error**
- Pastikan backend URL benar di `lib/config.dart`
- Pastikan tidak ada trailing slash di URL
- Test backend di browser dulu

**Download Timeout**
- Increase timeout di code
- Test dengan video lebih pendek
- Check internet connection

## 🧪 Testing

### Test Backend
```bash
cd backend
python test_connection.py https://username.pythonanywhere.com
```

### Test Flutter
```bash
flutter test
```

## 📝 Project Structure

```
yt_downloader/
├── lib/
│   ├── main.dart              # Main Flutter app
│   └── config.dart            # Backend URL configuration
├── backend/
│   ├── main.py                # FastAPI application
│   ├── wsgi.py                # WSGI config untuk PythonAnywhere
│   ├── requirements.txt       # Python dependencies
│   ├── generate_wsgi.py       # WSGI config generator
│   ├── test_connection.py     # Connection test script
│   └── *.md                   # Documentation files
├── android/                   # Android specific files
├── ios/                       # iOS specific files
└── README.md                  # This file
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- [yt-dlp](https://github.com/yt-dlp/yt-dlp) - YouTube downloader
- [FastAPI](https://fastapi.tiangolo.com/) - Modern Python web framework
- [Flutter](https://flutter.dev/) - Cross-platform framework
- [PythonAnywhere](https://www.pythonanywhere.com/) - Free Python hosting

## 📞 Support

- Backend Documentation: [backend/DOCS_INDEX.md](./backend/DOCS_INDEX.md)
- Troubleshooting: [backend/TROUBLESHOOTING.md](./backend/TROUBLESHOOTING.md)
- Issues: [GitHub Issues](https://github.com/YOUR_USERNAME/yt_downloader/issues)

## 🎯 Roadmap

- [ ] Playlist download support
- [ ] Download queue management
- [ ] Video preview before download
- [ ] Download history
- [ ] Dark/Light theme toggle
- [ ] Multiple language support
- [ ] Subtitle download

---

**Made with ❤️ using Flutter and FastAPI**

Start deploying: [backend/PYTHONANYWHERE_QUICKSTART.md](./backend/PYTHONANYWHERE_QUICKSTART.md) 🚀
