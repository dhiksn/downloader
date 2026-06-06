import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

// ─── Palette (matching website CSS variables) ─────────────────────────────────
const _bg        = Color(0xFF0A0A0A);
const _surface   = Color(0xFF1A1A1A);
const _surface2  = Color(0xFF222222);
const _border    = Color(0x14FFFFFF); // rgba(255,255,255,0.08)
const _border2   = Color(0x24FFFFFF); // rgba(255,255,255,0.14)
const _muted     = Color(0x66FFFFFF); // rgba(255,255,255,0.4)
const _errorRed  = Color(0xFFFF5050);

void main() {
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: _bg,
  ));
  runApp(const MyApp());
}

// ─── App ──────────────────────────────────────────────────────────────────────
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RaiSaver',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: _bg,
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          surface: _surface,
        ),
        textTheme: GoogleFonts.dmSansTextTheme(ThemeData.dark().textTheme),
        dividerColor: _border,
        dialogTheme: const DialogThemeData(backgroundColor: _surface),
      ),
      home: const HomeScreen(),
    );
  }
}

// ─── Home Screen ──────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _urlController = TextEditingController();
  final _scrollController = ScrollController();

  String _backendUrl = AppConfig.defaultBackendUrl;
  String _platform   = 'youtube'; // youtube | tiktok | instagram

  bool _loadingInfo  = false;
  Map<String, dynamic>? _videoInfo;
  String? _selectedFormatId;
  bool _downloading  = false;
  String? _customSavePath;

  // ── Download progress ────────────────────────────────────────────────────
  bool   _showProgress    = false;
  double _progressValue   = 0;        // 0..1; -1 = indeterminate
  String _progressStatus  = '';
  String _progressSpeed   = '';       // e.g. "2.4 MB/s"
  String _progressTotal   = '';       // e.g. "128.3 MB"

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final url  = await AppConfig.getBackendUrl();
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _backendUrl     = url;
      _customSavePath = prefs.getString('custom_save_path');
    });
  }

  // ── Platform helpers ──────────────────────────────────────────────────────
  static const _platformLabels = {
    'youtube':   'YouTube',
    'tiktok':    'TikTok',
    'instagram': 'Instagram',
  };

  static const _placeholders = {
    'youtube':   'Paste link YouTube di sini...',
    'tiktok':    'Paste link TikTok di sini...',
    'instagram': 'Paste link Instagram di sini...',
  };

  void _switchPlatform(String p) {
    if (_platform == p) return;
    setState(() {
      _platform   = p;
      _videoInfo  = null;
      _selectedFormatId = null;
      _showProgress = false;
    });
  }

  // ── Fetch info ────────────────────────────────────────────────────────────
  Future<void> _fetchInfo() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    FocusScope.of(context).unfocus();

    final isYT = url.contains('youtube.com') || url.contains('youtu.be');
    final isTT = url.contains('tiktok.com')  || url.contains('vt.tiktok.com');
    final isIG = url.contains('instagram.com');

    if (_platform == 'youtube'   && !isYT) { _showError(isTT ? 'Ini link TikTok! Ganti ke tab TikTok.' : isIG ? 'Ini link Instagram! Ganti ke tab Instagram.' : 'Paste link YouTube yang valid.'); return; }
    if (_platform == 'tiktok'    && !isTT) { _showError(isYT ? 'Ini link YouTube! Ganti ke tab YouTube.' : isIG ? 'Ini link Instagram! Ganti ke tab Instagram.' : 'Paste link TikTok yang valid.'); return; }
    if (_platform == 'instagram' && !isIG) { _showError('Paste link Instagram yang valid (Reels, post, dll.).'); return; }

    setState(() { _loadingInfo = true; _videoInfo = null; _selectedFormatId = null; _showProgress = false; });

    try {
      final String ep;
      if (_platform == 'tiktok')         { ep = '$_backendUrl/tiktok/info?url=${Uri.encodeComponent(url)}'; }
      else if (_platform == 'instagram') { ep = '$_backendUrl/instagram/info?url=${Uri.encodeComponent(url)}'; }
      else                               { ep = '$_backendUrl/info?url=${Uri.encodeComponent(url)}'; }

      final res = await http.get(Uri.parse(ep)).timeout(const Duration(seconds: 30));
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        setState(() {
          _videoInfo = data;
          final fmts = data['video_formats'] as List?;
          if (fmts != null && fmts.isNotEmpty) {
            _selectedFormatId = fmts[0]['format_id'].toString();
          }
        });
        // Scroll down to show results
        await Future.delayed(const Duration(milliseconds: 100));
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      } else {
        final body = json.decode(res.body);
        _showError(body['detail']?.toString() ?? 'Server error ${res.statusCode}');
      }
    } catch (e) {
      _showError('Gagal konek ke backend: $e');
    } finally {
      setState(() => _loadingInfo = false);
    }
  }

  // ── Download ──────────────────────────────────────────────────────────────
  String? _parseFilename(String? cd) {
    if (cd == null) return null;
    final rfc = RegExp(r"filename\*\s*=\s*UTF-8''([^;\s]+)", caseSensitive: false).firstMatch(cd);
    if (rfc != null) { try { return Uri.decodeComponent(rfc.group(1)!); } catch (_) {} }
    final plain = RegExp(r'filename\s*=\s*"?([^";\s]+)"?', caseSensitive: false).firstMatch(cd);
    return plain?.group(1);
  }

  Future<Directory> _getSaveDir() async {
    if (_customSavePath != null && _customSavePath!.isNotEmpty) {
      final d = Directory(_customSavePath!);
      if (await d.exists()) return d;
    }
    if (Platform.isAndroid) {
      final dl = Directory('/storage/emulated/0/Download');
      if (await dl.exists()) return dl;
      return (await getExternalStorageDirectory())!;
    }
    if (Platform.isIOS) return getApplicationDocumentsDirectory();
    return (await getDownloadsDirectory())!;
  }

  Future<void> _download({required bool isAudio, bool tiktokMp3 = false}) async {
    final url = _urlController.text.trim();
    if (url.isEmpty || _videoInfo == null) return;

    if (Platform.isAndroid) {
      var st = await Permission.manageExternalStorage.request();
      if (!st.isGranted) await Permission.storage.request();
    }

    setState(() { _downloading = true; _showProgress = true; _progressValue = 0; _progressStatus = 'Menyiapkan...'; _progressSpeed = ''; _progressTotal = ''; });

    Timer? pollTimer;
    try {
      final dir      = await _getSaveDir();
      final taskId   = DateTime.now().millisecondsSinceEpoch.toString();
      final safeTitle = (_videoInfo!['title'] ?? 'download')
          .toString()
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
          .trim();

      String savePath, endpoint;

      final fmts = _videoInfo!['video_formats'] as List;
      final validFormatIds = fmts.map((f) => f['format_id'].toString()).toList();
      final currentFormatId = (_selectedFormatId != null && validFormatIds.contains(_selectedFormatId)) 
          ? _selectedFormatId! 
          : (fmts.isNotEmpty ? fmts[0]['format_id'].toString() : '');

      if (isAudio) {
        savePath = '${dir.path}/$safeTitle.mp3';
        endpoint = '$_backendUrl/download/audio?url=${Uri.encodeComponent(url)}&task_id=$taskId';
      } else if (_platform == 'tiktok') {
        if (tiktokMp3) {
          savePath = '${dir.path}/$safeTitle.mp3';
          endpoint = '$_backendUrl/tiktok/download/mp3?url=${Uri.encodeComponent(url)}&task_id=$taskId';
        } else {
          savePath = '${dir.path}/temp_$taskId.tmp';
          endpoint = '$_backendUrl/tiktok/download?url=${Uri.encodeComponent(url)}&format_id=$currentFormatId&task_id=$taskId';
        }
      } else if (_platform == 'instagram') {
        savePath = '${dir.path}/temp_ig_$taskId.tmp';
        endpoint = '$_backendUrl/instagram/download?url=${Uri.encodeComponent(url)}&format_id=$currentFormatId&task_id=$taskId';
      } else {
        String res = '';
        try {
          final fmt  = fmts.firstWhere((f) => f['format_id'].toString() == currentFormatId, orElse: () => fmts[0]);
          res = fmt['resolution'] != null ? ' [${fmt['resolution']}]' : '';
        } catch (_) {}
        savePath = '${dir.path}/$safeTitle$res.mp4';
        endpoint = '$_backendUrl/download/video?url=${Uri.encodeComponent(url)}&format_id=$currentFormatId&task_id=$taskId';
      }

      int lastMs = DateTime.now().millisecondsSinceEpoch;
      int lastBytes = 0;
      pollTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
        try {
          final r = await http.get(Uri.parse('$_backendUrl/progress?task_id=$taskId')).timeout(const Duration(seconds: 4));
          if (r.statusCode == 200) {
            final d    = json.decode(r.body);
            final st   = d['status'] ?? 'starting';
            final prog = (d['progress'] ?? 0.0).toDouble();
            final spd  = d['speed']?.toString() ?? '';   // e.g. "2.66MiB/s"
            final tot  = d['total']?.toString() ?? '';   // e.g. "128.50MiB"
            if (st == 'downloading') {
              setState(() {
                _progressValue  = prog;
                _progressStatus = 'Mengunduh';
                _progressSpeed  = spd;
                _progressTotal  = tot;
              });
            } else if (st == 'processing') {
              setState(() {
                _progressValue  = -1;
                _progressStatus = 'Menggabungkan video & audio...';
                _progressSpeed  = '';
                _progressTotal  = '';
              });
            }
          }
        } catch (_) {}
      });

      final dio = Dio()
        ..options.connectTimeout = const Duration(minutes: 5)
        ..options.receiveTimeout = const Duration(minutes: 15);

      final resp = await dio.download(
        endpoint, savePath,
        deleteOnError: false,
        options: Options(responseType: ResponseType.bytes, followRedirects: true),
        onReceiveProgress: (recv, total) {
          pollTimer?.cancel();
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - lastMs > 300 || recv == total) {
            // Hitung speed dari delta bytes / delta time
            final deltaSec = (now - lastMs) / 1000.0;
            final deltaBytes = recv - lastBytes;
            final speedBps = deltaSec > 0 ? deltaBytes / deltaSec : 0.0;
            lastMs    = now;
            lastBytes = recv;
            setState(() {
              if (total > 0) {
                _progressValue = recv / total;
                _progressTotal = _fmtBytes(total.toDouble());
              } else {
                _progressValue = -1;
                _progressTotal = '';
              }
              _progressStatus = 'Menyimpan';
              _progressSpeed  = speedBps > 0 ? '${_fmtBytes(speedBps)}/s' : '';
            });
          }
        },
      );

      pollTimer.cancel();

      // Rename using Content-Disposition
      try {
        final cd   = resp.headers.value('content-disposition');
        final name = _parseFilename(cd);
        if (name != null && name.isNotEmpty) {
          final clean = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
          if (clean.isNotEmpty) {
            final newPath = '${dir.path}/$clean';
            final f = File(savePath);
            if (await f.exists() && newPath != savePath) {
              await f.rename(newPath);
              savePath = newPath;
            }
          }
        }
      } catch (_) {}

      setState(() { _showProgress = false; });
      _showSuccess(savePath);
    } catch (e) {
      pollTimer?.cancel();
      setState(() { _showProgress = false; });
      _showError('Download gagal: $e');
    } finally {
      setState(() => _downloading = false);
    }
  }

  Future<void> _downloadAll({required String endpoint, required String label}) async {
    final url = _urlController.text.trim();
    if (url.isEmpty || _videoInfo == null) return;

    setState(() { _downloading = true; _showProgress = true; _progressValue = 0; _progressStatus = 'Menyiapkan ZIP...'; _progressSpeed = ''; _progressTotal = ''; });

    Timer? pollTimer;
    try {
      final dir    = await _getSaveDir();
      final taskId = DateTime.now().millisecondsSinceEpoch.toString();
      final safeTitle = (_videoInfo!['title'] ?? label)
          .toString()
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
          .trim();
      final savePath    = '${dir.path}/$safeTitle.zip';
      final fmtCount    = (_videoInfo!['video_formats'] as List?)?.length ?? 0;
      final fullEndpoint = '$_backendUrl$endpoint?url=${Uri.encodeComponent(url)}&task_id=$taskId';

      pollTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
        try {
          final r = await http.get(Uri.parse('$_backendUrl/progress?task_id=$taskId')).timeout(const Duration(seconds: 4));
          if (r.statusCode == 200) {
            final d = json.decode(r.body);
            final prog = (d['progress'] ?? 0.0).toDouble();
            final done = (prog * fmtCount).round();
            setState(() { _progressValue = prog; _progressStatus = 'Mengunduh $done/$fmtCount...'; });
          }
        } catch (_) {}
      });

      final dio = Dio()
        ..options.connectTimeout = const Duration(minutes: 5)
        ..options.receiveTimeout = const Duration(minutes: 15);

      String finalPath = savePath;
      final resp = await dio.download(
        fullEndpoint, savePath,
        deleteOnError: false,
        onReceiveProgress: (recv, total) {
          if (total > 0) setState(() { _progressValue = recv / total; _progressStatus = 'Menyimpan ZIP: ${(recv / 1048576).toStringAsFixed(1)}MB / ${(total / 1048576).toStringAsFixed(1)}MB'; });
        },
      );

      pollTimer.cancel();

      try {
        final cd   = resp.headers.value('content-disposition');
        final name = _parseFilename(cd);
        if (name != null && name.isNotEmpty) {
          final clean = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
          if (clean.isNotEmpty) {
            final newPath = '${dir.path}/$clean';
            final f = File(savePath);
            if (await f.exists() && newPath != savePath) { await f.rename(newPath); finalPath = newPath; }
          }
        }
      } catch (_) {}

      setState(() { _showProgress = false; });
      _showSuccess(finalPath);
    } catch (e) {
      pollTimer?.cancel();
      setState(() { _showProgress = false; });
      _showError('Download ZIP gagal: $e');
    } finally {
      setState(() => _downloading = false);
    }
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────
  void _showError(String msg) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: _errorRed.withValues(alpha: 0.3)),
        ),
        title: Row(children: [
          Icon(Icons.error_outline, color: _errorRed, size: 22),
          const SizedBox(width: 10),
          const Text('Error', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        ]),
        content: Text(msg, style: const TextStyle(color: _muted, fontSize: 14, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showSuccess(String path, {bool openBtn = true}) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0x3300CC66)),
        ),
        title: Row(children: [
          const Icon(Icons.check_circle_outline, color: Color(0xFF66CC88), size: 22),
          const SizedBox(width: 10),
          const Text('Selesai', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        ]),
        content: Text(openBtn ? 'Tersimpan ke:\n$path' : path, style: const TextStyle(color: _muted, fontSize: 13, height: 1.5)),
        actions: [
          if (openBtn)
            TextButton(
              onPressed: () { Navigator.of(ctx).pop(); OpenFilex.open(path); },
              child: const Text('Buka File', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK', style: TextStyle(color: _muted)),
          ),
        ],
      ),
    );
  }

  // Helper: deteksi mode backend saat ini
  String _backendMode() {
    if (_backendUrl == AppConfig.localBackendUrlDesktop || _backendUrl == AppConfig.localBackendUrl) {
      return 'local';
    }
    if (_backendUrl == AppConfig.defaultBackendUrl) return 'remote';
    return 'custom';
  }

  Future<void> _showBackendSettings() async {
    final ctrl = TextEditingController(text: _backendUrl);
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          // Determine selected mode
          String selectedMode;
          if (ctrl.text == AppConfig.localBackendUrlDesktop) {
            selectedMode = 'local';
          } else if (ctrl.text == AppConfig.defaultBackendUrl) {
            selectedMode = 'remote';
          } else {
            selectedMode = 'custom';
          }
          
          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: AlertDialog(
              backgroundColor: _surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: _border2),
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            title: Row(children: [
              const Text('Backend', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.of(ctx).pop(),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(9), border: Border.all(color: _border2)),
                  child: const Icon(Icons.close_rounded, size: 18, color: _muted),
                ),
              ),
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Pilih server atau masukkan URL custom.', style: TextStyle(color: _muted, fontSize: 15, height: 1.6)),
                const SizedBox(height: 16),
                // Toggle switch
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0x0AFFFFFF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _border2),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            ctrl.text = AppConfig.localBackendUrlDesktop;
                            setLocal(() {});
                            setState(() {});
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            decoration: BoxDecoration(
                              color: selectedMode == 'local' ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.computer_rounded, size: 18, color: selectedMode == 'local' ? _bg : _muted),
                                const SizedBox(width: 8),
                                Text('Local', style: TextStyle(color: selectedMode == 'local' ? _bg : _muted, fontSize: 14, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            ctrl.text = AppConfig.defaultBackendUrl;
                            setLocal(() {});
                            setState(() {});
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            decoration: BoxDecoration(
                              color: selectedMode == 'remote' ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.cloud_rounded, size: 18, color: selectedMode == 'remote' ? _bg : _muted),
                                const SizedBox(width: 8),
                                Text('Remote', style: TextStyle(color: selectedMode == 'remote' ? _bg : _muted, fontSize: 14, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Custom URL field
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('CUSTOM URL', style: TextStyle(color: _muted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: ctrl,
                      onChanged: (_) { setLocal(() {}); setState(() {}); },
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        hintText: 'http://127.0.0.1:8000',
                        hintStyle: const TextStyle(color: _muted),
                        filled: true,
                        fillColor: const Color(0x0AFFFFFF),
                        prefixIcon: const Icon(Icons.link_rounded, size: 20, color: _muted),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _border2)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _border2)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white38)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Save button
                GestureDetector(
                  onTap: () async {
                    final val = ctrl.text.trim();
                    if (val.isEmpty) return;
                    await AppConfig.setBackendUrl(val);
                    setState(() => _backendUrl = val);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _border2),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.check_rounded, size: 20, color: _bg),
                      const SizedBox(width: 8),
                      Text('Simpan', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: _bg)),
                    ]),
                  ),
                ),
              ],
            ),
            ),
          );
        },
      ),
    );
  }



  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          _buildNavbar(),
          // Konten scrollable (hero + hasil download)
          Expanded(
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(child: _buildHero()),
                if (_loadingInfo)
                  SliverToBoxAdapter(child: _buildLoadingState()),
                if (!_loadingInfo && _videoInfo != null) ...[
                  SliverToBoxAdapter(child: _buildVideoCard()),
                  if (_showProgress)
                    SliverToBoxAdapter(child: _buildProgressCard()),
                ],
                // Push creator card + footer ke bawah
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _buildCreatorCard(),
                      _buildFooter(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Navbar ────────────────────────────────────────────────────────────────
  Widget _buildNavbar() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xE60A0A0A), // rgba(10,10,10,0.9)
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                // Logo
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('RaiSaver',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(children: [
                      Text('Build by Andhika Rafi',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: _muted,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Badge Local / Remote / Custom
                      GestureDetector(
                        onTap: _showBackendSettings,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _backendMode() == 'local'
                                ? const Color(0x2200CC66)
                                : _backendMode() == 'remote'
                                    ? const Color(0x220099FF)
                                    : const Color(0x22FFFFFF),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: _backendMode() == 'local'
                                  ? const Color(0x5500CC66)
                                  : _backendMode() == 'remote'
                                      ? const Color(0x550099FF)
                                      : _border2,
                              width: 0.8,
                            ),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                              width: 5, height: 5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _backendMode() == 'local'
                                    ? const Color(0xFF00CC66)
                                    : _backendMode() == 'remote'
                                        ? const Color(0xFF0099FF)
                                        : Colors.white54,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _backendMode() == 'local' ? 'LOCAL' : _backendMode() == 'remote' ? 'REMOTE' : 'CUSTOM',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: _backendMode() == 'local'
                                    ? const Color(0xFF00CC66)
                                    : _backendMode() == 'remote'
                                        ? const Color(0xFF0099FF)
                                        : Colors.white54,
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ]),
                  ],
                ),
                const Spacer(),
                // Platform tabs — settings button on mobile
                if (MediaQuery.of(context).size.width > 500) ...[
                  _navTab('youtube',   _ytIcon()),
                  const SizedBox(width: 6),
                  _navTab('tiktok',    _ttIcon()),
                  const SizedBox(width: 6),
                  _navTab('instagram', _igIcon()),
                ] else ...[
                  _navTab('youtube',   _ytIcon(), labelOnly: false),
                  const SizedBox(width: 4),
                  _navTab('tiktok',    _ttIcon(), labelOnly: false),
                  const SizedBox(width: 4),
                  _navTab('instagram', _igIcon(), labelOnly: false),
                ],
                const SizedBox(width: 10),
                // Settings FAB
                _fabSettingsBtn(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navTab(String platform, Widget icon, {bool labelOnly = true}) {
    final active = _platform == platform;
    return GestureDetector(
      onTap: () => _switchPlatform(platform),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color:  active ? const Color(0x1AFFFFFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? const Color(0x40FFFFFF) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 6),
            Text(
              _platformLabels[platform]!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: active ? Colors.white : _muted,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fabSettingsBtn() {
    final mode = _backendMode();
    final badgeColor = mode == 'local'
        ? const Color(0xFF00CC66)
        : mode == 'remote'
            ? const Color(0xFF0099FF)
            : Colors.white54;

    return GestureDetector(
      onTap: () => _showMoreMenu(),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: _border2),
              color: const Color(0xD90A0A0A),
            ),
            child: const Icon(Icons.tune_rounded, size: 16, color: _muted),
          ),
          // Badge mode indicator
          Positioned(
            top: -3, right: -3,
            child: Container(
              width: 9, height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: badgeColor,
                border: Border.all(color: _bg, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMoreMenu() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim1, anim2) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(ctx).size.width * 0.85,
              constraints: const BoxConstraints(maxWidth: 360),
              height: double.infinity,
              decoration: BoxDecoration(
                color: _surface,
                border: Border(left: BorderSide(color: _border2)),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('Pengaturan', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => Navigator.pop(ctx),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(color: _border2),
                              ),
                              child: const Icon(Icons.close_rounded, size: 18, color: _muted),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _menuItem(Icons.dns_rounded, 'Backend URL', '${_backendMode() == 'local' ? '● Local' : _backendMode() == 'remote' ? '● Remote' : '● Custom'} — $_backendUrl', () { Navigator.pop(ctx); _showBackendSettings(); }),
                      const SizedBox(height: 12),
                      _menuItem(Icons.folder_open_rounded, 'Folder Simpan', _customSavePath ?? 'Default (Downloads)', () async {
                        Navigator.pop(ctx);
                        final result = await FilePicker.platform.getDirectoryPath();
                        if (result != null) {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('custom_save_path', result);
                          setState(() => _customSavePath = result);
                        }
                      }),
                      const SizedBox(height: 12),
                      _menuItem(Icons.refresh_rounded, 'Reset', 'Bersihkan input & hasil', () { Navigator.pop(ctx); setState(() { _urlController.clear(); _videoInfo = null; _showProgress = false; }); }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(anim1),
          child: child,
        );
      },
    );
  }

  Widget _menuItem(IconData icon, String title, String sub, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
          color: const Color(0x0AFFFFFF),
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: _muted),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
              Text(sub, style: const TextStyle(color: _muted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          )),
          const Icon(Icons.chevron_right, size: 16, color: _muted),
        ]),
      ),
    );
  }

  // ── Hero + Search ─────────────────────────────────────────────────────────
  Widget _buildHero() {
    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: _GridPainter())),
        // Radial glow
          Positioned.fill(child: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -1),
                radius: 1.2,
                colors: [Color(0x0AFFFFFF), Colors.transparent],
              ),
            ),
          )),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  children: [
                    // Headline
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: GoogleFonts.inter(
                          fontSize: _heroFontSize(context),
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                          letterSpacing: -2,
                        ),
                        children: [
                          TextSpan(text: _heroTitle(), style: const TextStyle(color: Colors.white)),
                          const TextSpan(text: '\n'),
                          const TextSpan(text: 'No Watermark', style: TextStyle(color: Color(0x38FFFFFF))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(_heroDesc(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: _muted, height: 1.7)),
                    const SizedBox(height: 32),
                    // Search bar
                    _buildSearchBar(),
                  ],
                ),
              ),
            ),
          ),
        ],
    );
  }

  double _heroFontSize(BuildContext ctx) {
    final w = MediaQuery.of(ctx).size.width;
    if (w < 400) return 40;
    if (w < 600) return 52;
    return 68;
  }

  String _heroTitle() {
    switch (_platform) {
      case 'tiktok':    return 'Unduh TikTok';
      case 'instagram': return 'Unduh Instagram';
      default:          return 'Unduh YouTube';
    }
  }

  String _heroDesc() {
    switch (_platform) {
      case 'tiktok':    return 'Download video TikTok tanpa watermark, langsung ke perangkat kamu.';
      case 'instagram': return 'Download Reels & foto Instagram dengan mudah dan cepat.';
      default:          return 'Download video YouTube dalam kualitas terbaik, gratis dan cepat.';
    }
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x0AFFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Row(children: [
        const SizedBox(width: 18),
        const Icon(Icons.link_rounded, size: 17, color: _muted),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: _urlController,
            onSubmitted: (_) => _fetchInfo(),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: _placeholders[_platform],
              hintStyle: const TextStyle(color: _muted, fontSize: 14),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(6),
          child: _loadingInfo
            ? const SizedBox(
                width: 38, height: 38,
                child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
              )
            : GestureDetector(
                onTap: _fetchInfo,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.search_rounded, size: 15, color: _bg),
                    const SizedBox(width: 6),
                    Text('Unduh', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: _bg)),
                  ]),
                ),
              ),
        ),
      ]),
    );
  }

  // ── Loading state ─────────────────────────────────────────────────────────
  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          const SizedBox(width: 12),
          const Text('Mengambil info video...', style: TextStyle(color: _muted, fontSize: 14)),
        ]),
      ),
    );
  }

  // ── Video card ────────────────────────────────────────────────────────────
  Widget _buildVideoCard() {
    final info  = _videoInfo!;
    final fmts  = (info['video_formats'] as List?) ?? [];
    final thumb = info['thumbnail'] as String? ?? '';
    final title = info['title'] as String? ?? 'Unknown';
    final chan   = info['channel'] as String? ?? '';
    final dur    = info['duration'];

    // Format label
    String fmtSectionLabel = 'Video';
    if (_platform == 'instagram') {
      final hasPhoto = fmts.any((f) => (f['format_id'] as String? ?? '').startsWith('api_') && (f['ext'] as String? ?? '') != 'mp4');
      final hasVid   = fmts.any((f) => (f['ext'] as String? ?? '') == 'mp4');
      if (hasPhoto && hasVid) { fmtSectionLabel = 'Media'; }
      else if (hasPhoto) { fmtSectionLabel = 'Foto'; }
    }

    // Low-res warning (YouTube)
    final showLowRes = _platform == 'youtube' && fmts.isNotEmpty &&
        !fmts.any((f) { final r = int.tryParse((f['resolution'] as String? ?? '').replaceAll('p', '')) ?? 0; return r >= 480; });

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Container(
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Thumbnail
                if (thumb.isNotEmpty) _buildThumbnail(thumb, dur),

                // Info
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.45), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      Row(children: [
                        const Icon(Icons.person_outline, size: 14, color: _muted),
                        const SizedBox(width: 5),
                        Expanded(child: Text(chan, style: const TextStyle(color: _muted, fontSize: 13), overflow: TextOverflow.ellipsis)),
                      ]),
                      // Caption/description (Instagram)
                      if (_platform == 'instagram') ...[
                        Builder(builder: (ctx) {
                          final desc = (info['description'] as String? ?? '').trim();
                          if (desc.isEmpty) return const SizedBox.shrink();

                          // Hilangkan baris pertama kalau sama persis dengan title
                          String display = desc;
                          final firstLine = desc.split('\n').first.trim();
                          if (firstLine == title.trim()) {
                            display = desc.substring(firstLine.length).trimLeft();
                          }
                          if (display.isEmpty) return const SizedBox.shrink();

                          return Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: _ExpandableCaption(text: display),
                          );
                        }),
                      ],
                    ],
                  ),
                ),

                // Low res warning
                if (showLowRes)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: const Color(0x0AFFFFFF),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: const Color(0x1AFFFFFF)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.warning_amber_rounded, size: 15, color: _muted),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          'YouTube memblokir resolusi lebih tinggi untuk video ini.',
                          style: const TextStyle(color: _muted, fontSize: 13, height: 1.5),
                        )),
                      ]),
                    ),
                  ),

                // Divider
                const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Divider(height: 1, color: _border)),

                // Download section — Video/Photo
                if (fmts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(fmtSectionLabel.toUpperCase(),
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0x59FFFFFF), letterSpacing: 1.5)),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(child: _buildFormatSelect(fmts)),
                          const SizedBox(width: 10),
                          _primaryBtn(_formatExt(fmts), () => _download(isAudio: false), width: null),
                        ]),
                      ],
                    ),
                  ),

                // Audio only (YouTube & TikTok)
                if (_platform == 'youtube' || (_platform == 'tiktok' && !(info['is_photo'] ?? false))) ...[
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Divider(height: 1, color: _border)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('AUDIO ONLY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0x59FFFFFF), letterSpacing: 1.5)),
                        const SizedBox(height: 10),
                        _outlineBtn('Download MP3', () {
                          if (_platform == 'tiktok') {
                            _download(isAudio: false, tiktokMp3: true);
                          } else {
                            _download(isAudio: true);
                          }
                        }),
                      ],
                    ),
                  ),
                ],

                // Download all (carousel)
                if ((_platform == 'instagram' || _platform == 'tiktok') && fmts.length > 1)
                  Builder(builder: (ctx) {
                    final hasMultiple = _platform == 'instagram'
                        ? fmts.any((f) => (f['format_id'] as String? ?? '').startsWith('api_'))
                        : (info['is_photo'] == true && fmts.any((f) => (f['format_id'] as String? ?? '').startsWith('img_')));
                    if (!hasMultiple) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Divider(height: 1, color: _border)),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('SEMUA FOTO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0x59FFFFFF), letterSpacing: 1.5)),
                              const SizedBox(height: 6),
                              Text('${fmts.length} item akan diunduh sebagai ZIP', style: const TextStyle(color: _muted, fontSize: 13)),
                              const SizedBox(height: 10),
                              _outlineBtn('Download Semua (ZIP)', () => _downloadAll(
                                endpoint: _platform == 'instagram' ? '/instagram/download/all' : '/tiktok/download/all',
                                label: _platform == 'instagram' ? 'Instagram' : 'TikTok',
                              )),
                            ],
                          ),
                        ),
                      ],
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(String thumb, dynamic dur) {
    final needsProxy = _platform == 'instagram' || _platform == 'tiktok';
    final src = needsProxy ? '$_backendUrl/proxy-image?url=${Uri.encodeComponent(thumb)}' : thumb;
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Image.network(
            src,
            fit: BoxFit.cover,
            errorBuilder: (_, a, b) => Container(color: _surface2, child: const Center(child: Icon(Icons.image_not_supported, color: _muted, size: 40))),
            loadingBuilder: (_, child, progress) => progress == null ? child : Container(color: _surface2, child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38)))),
          ),
        ),
        // Gradient overlay
        Positioned.fill(child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.transparent, Color(0xEB1A1A1A)], stops: [0.5, 1.0]),
          ),
        )),
        // Duration badge
        if (dur != null)
          Positioned(
            bottom: 10, right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.72), borderRadius: BorderRadius.circular(5)),
              child: Text(_fmtDuration(dur), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            ),
          ),
      ],
    );
  }

  Widget _buildFormatSelect(List fmts) {
    // Determine a valid dropdown value without modifying state
    final validFormatIds = fmts.map((f) => f['format_id'].toString()).toList();
    String? validValue;
    if (_selectedFormatId != null && validFormatIds.contains(_selectedFormatId)) {
      validValue = _selectedFormatId;
    } else if (fmts.isNotEmpty) {
      validValue = fmts[0]['format_id'].toString();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0x0AFFFFFF),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: _border2),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: validValue,
          dropdownColor: _surface2,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 17, color: _muted),
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
          items: fmts.map<DropdownMenuItem<String>>((f) {
            final ext = (f['ext']?.toString().toUpperCase() ?? 'MP4');
            return DropdownMenuItem<String>(
              value: f['format_id'].toString(),
              child: Text('${f['resolution']} — $ext'),
            );
          }).toList(),
          onChanged: (v) => setState(() => _selectedFormatId = v),
        ),
      ),
    );
  }

  String _formatExt(List fmts) {
    if (fmts.isEmpty) return 'MP4';
    try {
      final validFormatIds = fmts.map((f) => f['format_id'].toString()).toList();
      final f = (_selectedFormatId != null && validFormatIds.contains(_selectedFormatId)) 
          ? fmts.firstWhere((f) => f['format_id'].toString() == _selectedFormatId) 
          : fmts[0];
      return (f['ext']?.toString().toUpperCase() ?? 'MP4');
    } catch (_) { return 'MP4'; }
  }

  // ── Progress card ─────────────────────────────────────────────────────────
  Widget _buildProgressCard() {
    final indeterminate = _progressValue < 0;
    final pct = indeterminate ? '—' : '${(_progressValue * 100).round()}%';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status row: spinner + label + total + speed
                Row(children: [
                  const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Text(_progressStatus, style: const TextStyle(color: _muted, fontSize: 13, fontWeight: FontWeight.w500)),
                  if (_progressTotal.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(_progressTotal, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                  const Spacer(),
                  if (_progressSpeed.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0x0AFFFFFF),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _border2),
                      ),
                      child: Text(_progressSpeed, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
                    ),
                ]),
                const SizedBox(height: 14),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: indeterminate ? null : _progressValue.clamp(0.0, 1.0),
                    minHeight: 4,
                    backgroundColor: const Color(0x0FFFFFFF),
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                // Percentage aligned right
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    pct,
                    style: const TextStyle(fontSize: 12, color: Color(0x80FFFFFF), fontWeight: FontWeight.w600, letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Creator card ──────────────────────────────────────────────────────────
  Widget _buildCreatorCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border2),
            ),
            child: Row(children: [
              // Avatar — pakai foto asset, fallback ke inisial "AR"
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _border2, width: 2),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/avatar.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (_, e, s) => Container(
                      color: Colors.white,
                      alignment: Alignment.center,
                      child: Text('AR', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: _bg)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('dhiksn', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: 2),
                  const Text('Developer & Creator of RaiSaver', style: TextStyle(fontSize: 12, color: _muted)),
                ],
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Footer ─────────────────────────────────────────────────────────────────
  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _border)),
      ),
      child: const Text(
        '© 2026 RaiSaver — Download YouTube, TikTok & Instagram tanpa watermark',
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(0x33FFFFFF), fontSize: 12, letterSpacing: 0.3),
      ),
    );
  }

  // ── Shared button widgets ─────────────────────────────────────────────────
  Widget _primaryBtn(String label, VoidCallback? onTap, {double? width}) {
    return GestureDetector(
      onTap: _downloading ? null : onTap,
      child: AnimatedOpacity(
        opacity: _downloading ? 0.35 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          width: width,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.download_rounded, size: 15, color: _bg),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: _bg)),
          ]),
        ),
      ),
    );
  }

  Widget _outlineBtn(String label, VoidCallback? onTap) {
    return GestureDetector(
      onTap: _downloading ? null : onTap,
      child: AnimatedOpacity(
        opacity: _downloading ? 0.35 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: const Color(0x33FFFFFF)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.music_note_rounded, size: 15, color: Colors.white),
            const SizedBox(width: 7),
            Text(label, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
          ]),
        ),
      ),
    );
  }

  // ── Util ──────────────────────────────────────────────────────────────────
  String _fmtBytes(double bytes) {
    if (bytes < 1024) return '${bytes.toStringAsFixed(0)} B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1073741824) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    return '${(bytes / 1073741824).toStringAsFixed(2)} GB';
  }

  String _fmtDuration(dynamic sec) {
    final s = (sec is int) ? sec : (sec as num).toInt();
    final h = s ~/ 3600, m = (s % 3600) ~/ 60, ss = s % 60;
    if (h > 0) return '$h:${m.toString().padLeft(2,'0')}:${ss.toString().padLeft(2,'0')}';
    return '$m:${ss.toString().padLeft(2,'0')}';
  }

  // ── SVG icons (platform tabs) ─────────────────────────────────────────────
  Widget _ytIcon() => SizedBox(width: 15, height: 15, child: CustomPaint(painter: _YtPainter()));
  Widget _ttIcon() => SizedBox(width: 15, height: 15, child: CustomPaint(painter: _TtPainter()));
  Widget _igIcon() => SizedBox(width: 15, height: 15, child: CustomPaint(painter: _IgPainter()));
}

// ─── Expandable caption widget ───────────────────────────────────────────────
class _ExpandableCaption extends StatefulWidget {
  final String text;
  const _ExpandableCaption({required this.text});

  @override
  State<_ExpandableCaption> createState() => _ExpandableCaptionState();
}

class _ExpandableCaptionState extends State<_ExpandableCaption> {
  bool _expanded = false;
  static const int _collapsedLines = 4;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x0AFFFFFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: Text(
              widget.text,
              maxLines: _collapsedLines,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted, fontSize: 13, height: 1.6),
            ),
            secondChild: Text(
              widget.text,
              style: const TextStyle(color: _muted, fontSize: 13, height: 1.6),
            ),
          ),
          // Tombol selengkapnya — tampil hanya kalau teks panjang
          LayoutBuilder(builder: (ctx, constraints) {
            final tp = TextPainter(
              text: TextSpan(text: widget.text, style: const TextStyle(fontSize: 13, height: 1.6)),
              maxLines: _collapsedLines,
              textDirection: TextDirection.ltr,
            )..layout(maxWidth: constraints.maxWidth);

            final needsToggle = tp.didExceedMaxLines;
            if (!needsToggle) return const SizedBox.shrink();

            return GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _expanded ? 'Lebih sedikit' : 'Selengkapnya',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Grid painter ─────────────────────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x06FFFFFF)
      ..strokeWidth = 1;
    const step = 60.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }
  @override
  bool shouldRepaint(_) => false;
}

// ─── Simple icon painters ─────────────────────────────────────────────────────
class _YtPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = const Color(0xCCFFFFFF)..style = PaintingStyle.fill;
    // Rounded rect background
    final rr = RRect.fromRectAndRadius(Rect.fromLTWH(0, 1.5, s.width, s.height - 3), const Radius.circular(3));
    canvas.drawRRect(rr, p);
    // Play triangle
    final tp = Paint()..color = const Color(0xFF0A0A0A)..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(s.width * 0.4, s.height * 0.32)
      ..lineTo(s.width * 0.76, s.height * 0.5)
      ..lineTo(s.width * 0.4, s.height * 0.68)
      ..close();
    canvas.drawPath(path, tp);
  }
  @override
  bool shouldRepaint(_) => false;
}

class _TtPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = const Color(0xCCFFFFFF)..style = PaintingStyle.fill..strokeWidth = 1.8..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    // Simplified TikTok "note" shape
    final path = Path()
      ..moveTo(s.width * 0.55, 0)
      ..lineTo(s.width, 0)
      ..lineTo(s.width, s.height * 0.38)
      ..moveTo(s.width * 0.55, 0)
      ..lineTo(s.width * 0.55, s.height * 0.72)
      ..addOval(Rect.fromCenter(center: Offset(s.width * 0.35, s.height * 0.78), width: s.width * 0.38, height: s.height * 0.38));
    canvas.drawPath(path, p);
  }
  @override
  bool shouldRepaint(_) => false;
}

class _IgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = const Color(0xCCFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    // Rounded square
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0.5, 0.5, s.width - 1, s.height - 1), Radius.circular(s.width * 0.28)), p);
    // Inner circle
    canvas.drawCircle(Offset(s.width / 2, s.height / 2), s.width * 0.26, p);
    // Dot
    canvas.drawCircle(Offset(s.width * 0.76, s.height * 0.24), 1.5, Paint()..color = const Color(0xCCFFFFFF)..style = PaintingStyle.fill);
  }
  @override
  bool shouldRepaint(_) => false;
}
