import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

void main() {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RaiSaver',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF6C63FF),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
        scaffoldBackgroundColor: const Color(0xFF13131F),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6C63FF),
          secondary: Color(0xFF00FFC6),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadiusGeometry? borderRadius;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(24);
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 40,
            offset: const Offset(0, 15),
          ),
        ],
        borderRadius: br,
      ),
      child: ClipRRect(
        borderRadius: br,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            padding: padding ?? const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: br,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.08),
                  Colors.white.withValues(alpha: 0.02),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class BackgroundBlobs extends StatelessWidget {
  const BackgroundBlobs({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -100,
          left: -50,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF6C63FF).withValues(alpha: 0.4),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(color: Colors.transparent),
            ),
          ),
        ),
        Positioned(
          bottom: -50,
          right: -100,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF00FFC6).withValues(alpha: 0.25),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
              child: Container(color: Colors.transparent),
            ),
          ),
        ),
        Positioned(
          top: 300,
          right: -50,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFF2A5F).withValues(alpha: 0.2),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
              child: Container(color: Colors.transparent),
            ),
          ),
        ),
      ],
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _urlController = TextEditingController();
  // Backend URL — loaded async from SharedPreferences
  String _backendUrl = AppConfig.defaultBackendUrl;

  bool _isLoadingInfo = false;
  Map<String, dynamic>? _videoInfo;
  String? _selectedFormatId;

  bool _isDownloading = false;
  String? _customSavePath;
  
  // Platform selection
  String _selectedPlatform = 'youtube'; // 'youtube', 'tiktok', 'instagram'

  @override
  void initState() {
    super.initState();
    _loadCustomSavePath();
    _loadBackendUrl();
  }

  Future<void> _loadBackendUrl() async {
    final url = await AppConfig.getBackendUrl();
    setState(() {
      _backendUrl = url;
    });
  }

  Future<void> _loadCustomSavePath() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _customSavePath = prefs.getString('custom_save_path');
    });
  }

  Future<void> _showBackendSettings() async {
    final controller = TextEditingController(text: _backendUrl);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Backend Settings',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Set backend URL:',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 12),
            // Quick presets
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF00FFC6),
                      side: const BorderSide(color: Color(0xFF00FFC6)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      controller.text = AppConfig.localBackendUrlDesktop;
                    },
                    child: const Text('⚡ Local', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6C63FF),
                      side: const BorderSide(color: Color(0xFF6C63FF)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      controller.text = AppConfig.defaultBackendUrl;
                    },
                    child: const Text('☁️ Remote', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'http://127.0.0.1:8000',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: Color(0xFF6C63FF)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save'),
            onPressed: () async {
              final newUrl = controller.text.trim();
              if (newUrl.isEmpty) return;
              await AppConfig.setBackendUrl(newUrl);
              setState(() => _backendUrl = newUrl);
              if (ctx.mounted) Navigator.of(ctx).pop();
              _showSuccess(
                'Backend URL saved:\n$newUrl',
                openBtn: false,
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickDownloadPath() async {
    String? result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('custom_save_path', result);
      setState(() {
        _customSavePath = result;
      });
      _showSuccess('Download location updated to:\n$result', openBtn: false);
    }
  }

  void _resetApp() {
    setState(() {
      _urlController.clear();
      _videoInfo = null;
      _isLoadingInfo = false;
    });
    FocusScope.of(context).unfocus();
  }

  IconData _getFormatIcon() {
    if (_videoInfo == null || _selectedFormatId == null) {
      return Icons.video_library;
    }
    
    try {
      final formats = _videoInfo!['video_formats'] as List;
      final selectedFormat = formats.firstWhere(
        (f) => f['format_id'].toString() == _selectedFormatId,
        orElse: () => formats[0],
      );
      
      String ext = selectedFormat['ext']?.toString().toLowerCase() ?? 'mp4';
      
      if (ext == 'jpg' || ext == 'jpeg' || ext == 'png') {
        return Icons.image;
      } else {
        return Icons.video_library;
      }
    } catch (e) {
      return Icons.video_library;
    }
  }

  String _getFormatLabel() {
    if (_videoInfo == null || _selectedFormatId == null) {
      return 'Download';
    }
    
    try {
      final formats = _videoInfo!['video_formats'] as List;
      final selectedFormat = formats.firstWhere(
        (f) => f['format_id'].toString() == _selectedFormatId,
        orElse: () => formats[0],
      );
      
      String ext = selectedFormat['ext']?.toString().toUpperCase() ?? 'MP4';
      return ext;
    } catch (e) {
      return 'Download';
    }
  }

  /// Parse filename from Content-Disposition header.
  /// Supports both plain `filename="..."` and RFC 5987 `filename*=UTF-8''...`
  String? _parseFilename(String? contentDisposition) {
    if (contentDisposition == null) return null;

    // RFC 5987: filename*=UTF-8''encoded%20name.mp3  (takes priority)
    final rfc5987 = RegExp(r"filename\*\s*=\s*UTF-8''([^;\s]+)", caseSensitive: false)
        .firstMatch(contentDisposition);
    if (rfc5987 != null) {
      try {
        return Uri.decodeComponent(rfc5987.group(1)!);
      } catch (_) {}
    }

    // Fallback: filename="name.mp3" or filename=name.mp3
    final plain = RegExp(r'filename\s*=\s*"?([^";\s]+)"?', caseSensitive: false)
        .firstMatch(contentDisposition);
    if (plain != null) {
      return plain.group(1);
    }

    return null;
  }

  Widget _buildDownloadAllButton({required int count, required VoidCallback onTap}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        const Text(
          'Download Semua',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF00FFC6)),
        ),
        const SizedBox(height: 8),
        Text(
          '$count foto akan di-download sebagai file ZIP',
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isDownloading ? null : onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FFC6).withValues(alpha: 0.6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.2), width: 1),
                  ),
                ),
                icon: const Icon(Icons.download_for_offline, size: 18),
                label: Text('Download Semua ($count foto)'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _downloadAllMedia({required String endpoint, required String label}) async {
    String url = _urlController.text.trim();
    if (url.isEmpty || _videoInfo == null) return;

    setState(() => _isDownloading = true);

    final progressNotifier = ValueNotifier<double?>(0.0);
    final statusNotifier = ValueNotifier<String>('Menyiapkan download...');

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: GlassContainer(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF00FFC6)),
                  const SizedBox(height: 20),
                  ValueListenableBuilder<String>(
                    valueListenable: statusNotifier,
                    builder: (_, status, a) => Text(
                      status,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<double?>(
                    valueListenable: progressNotifier,
                    builder: (_, progress, b) => ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 10,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        color: const Color(0xFF00FFC6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      Directory? dir;
      if (_customSavePath != null && _customSavePath!.isNotEmpty) {
        dir = Directory(_customSavePath!);
        if (!await dir.exists()) dir = null;
      }
      if (dir == null) {
        if (Platform.isAndroid) {
          final customDir = Directory('/storage/emulated/0/Download');
          dir = await customDir.exists() ? customDir : await getExternalStorageDirectory();
        } else if (Platform.isIOS) {
          dir = await getApplicationDocumentsDirectory();
        } else {
          dir = await getDownloadsDirectory();
        }
      }
      if (dir == null) throw Exception("Could not find downloads directory.");

      final taskId = DateTime.now().millisecondsSinceEpoch.toString();
      final fullEndpoint = '$_backendUrl$endpoint?url=${Uri.encodeComponent(url)}&task_id=$taskId';
      final formats = _videoInfo!['video_formats'] as List;

      statusNotifier.value = 'Mengunduh semua foto...';

      final progressTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        try {
          final res = await http.get(Uri.parse('$_backendUrl/progress?task_id=$taskId'));
          if (res.statusCode == 200) {
            final data = json.decode(res.body);
            final prog = (data['progress'] ?? 0.0).toDouble();
            progressNotifier.value = prog;
            final done = (prog * formats.length).round();
            statusNotifier.value = 'Mengunduh $done/${formats.length} foto...';
          }
        } catch (_) {}
      });

      final safeTitle = (_videoInfo!['title'] ?? label)
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
      final savePath = '${dir.path}/$safeTitle.zip';

      final dio = Dio();
      dio.options.connectTimeout = const Duration(minutes: 5);
      dio.options.receiveTimeout = const Duration(minutes: 15);

      final response = await dio.download(
        fullEndpoint, savePath,
        deleteOnError: false,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            progressNotifier.value = received / total;
            statusNotifier.value =
                'Menyimpan ZIP: ${(received / 1024 / 1024).toStringAsFixed(1)}MB / ${(total / 1024 / 1024).toStringAsFixed(1)}MB';
          }
        },
      );

      progressTimer.cancel();

      String finalPath = savePath;
      try {
        final cd = response.headers.value('content-disposition');
        final backendFilename = _parseFilename(cd);
        if (backendFilename != null && backendFilename.isNotEmpty) {
          final cleanName = backendFilename.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
          if (cleanName.isNotEmpty) {
            final newPath = '${dir.path}/$cleanName';
            final f = File(savePath);
            if (await f.exists() && newPath != savePath) {
              await f.rename(newPath);
              finalPath = newPath;
            }
          }
        }
      } catch (_) {}

      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showSuccess(finalPath);
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showError('Download semua gagal: $e');
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _fetchInfo() async {
    String url = _urlController.text.trim();
    if (url.isEmpty) return;

    FocusScope.of(context).unfocus();

    // Validate URL matches selected platform
    bool isYouTubeUrl = url.contains('youtube.com') || url.contains('youtu.be');
    bool isTikTokUrl = url.contains('tiktok.com') || url.contains('vt.tiktok.com');
    bool isInstagramUrl = url.contains('instagram.com');

    // Check if URL matches selected platform
    if (_selectedPlatform == 'youtube' && !isYouTubeUrl) {
      if (isTikTokUrl) {
        _showError('This is a TikTok link! Please switch to TikTok platform from the menu button.');
      } else if (isInstagramUrl) {
        _showError('This is an Instagram link! Switch to Instagram platform from the menu to download.');
      } else {
        _showError('Please paste a valid YouTube link or switch platform from the menu button.');
      }
      return;
    }

    if (_selectedPlatform == 'tiktok' && !isTikTokUrl) {
      if (isYouTubeUrl) {
        _showError('This is a YouTube link! Please switch to YouTube platform from the menu button.');
      } else if (isInstagramUrl) {
        _showError('This is an Instagram link! Switch to Instagram platform from the menu to download.');
      } else {
        _showError('Please paste a valid TikTok link or switch platform from the menu button.');
      }
      return;
    }

    if (_selectedPlatform == 'instagram' && !isInstagramUrl) {
      _showError('Please paste a valid Instagram link (reels, post, etc.) or switch platform from the menu.');
      return;
    }

    // Auto-detect platform from URL (backup, should not reach here if validation works)
    if (isTikTokUrl) {
      _selectedPlatform = 'tiktok';
    } else if (isInstagramUrl) {
      _selectedPlatform = 'instagram';
    } else {
      _selectedPlatform = 'youtube';
    }

    setState(() {
      _isLoadingInfo = true;
      _videoInfo = null;
      _selectedFormatId = null;
    });

    try {
      // Choose endpoint based on platform
      String endpoint;
      if (_selectedPlatform == 'tiktok') {
        endpoint = '$_backendUrl/tiktok/info?url=${Uri.encodeComponent(url)}';
      } else if (_selectedPlatform == 'instagram') {
        endpoint = '$_backendUrl/instagram/info?url=${Uri.encodeComponent(url)}';
      } else {
        endpoint = '$_backendUrl/info?url=${Uri.encodeComponent(url)}';
      }
      
      final response = await http.get(Uri.parse(endpoint));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _videoInfo = data;
          if (data['video_formats'] != null &&
              data['video_formats'].isNotEmpty) {
            _selectedFormatId = data['video_formats'][0]['format_id'];
          }
        });
      } else {
        _showError('Failed to fetch info: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Error connecting to backend: $e');
    } finally {
      setState(() {
        _isLoadingInfo = false;
      });
    }
  }

  Future<void> _download(bool isAudio) async {
    String url = _urlController.text.trim();
    if (url.isEmpty || _videoInfo == null) return;

    // Check permission for external storage if needed
    if (Platform.isAndroid) {
      // For Android 11+ (API 30+), need MANAGE_EXTERNAL_STORAGE
      var status = await Permission.manageExternalStorage.request();
      if (!status.isGranted) {
        // Fallback to storage permission for older Android
        status = await Permission.storage.request();
        if (!status.isGranted) {
          // If still denied, try photos permission
          await Permission.photos.request();
        }
      }
    }

    setState(() {
      _isDownloading = true;
    });

    ValueNotifier<double?> progressNotifier = ValueNotifier(0.0);
    ValueNotifier<String> statusNotifier = ValueNotifier(
      'Starting download...',
    );

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: GlassContainer(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFF00FFC6)),
                    const SizedBox(height: 20),
                    ValueListenableBuilder<String>(
                      valueListenable: statusNotifier,
                      builder: (context, status, child) {
                        return Text(
                          status,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    ValueListenableBuilder<double?>(
                      valueListenable: progressNotifier,
                      builder: (context, progress, child) {
                        if (progress != null) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 10,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.1,
                              ),
                              color: const Color(0xFF00FFC6),
                            ),
                          );
                        } else {
                          return const LinearProgressIndicator(
                            minHeight: 10,
                            backgroundColor: Colors.transparent,
                            color: Color(0xFF00FFC6),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    Timer? progressTimer;

    try {
      Directory? dir;
      if (_customSavePath != null && _customSavePath!.isNotEmpty) {
        dir = Directory(_customSavePath!);
        if (!await dir.exists()) {
          dir = null; // fallback if path doesn't exist anymore
        }
      }

      if (dir == null) {
        if (Platform.isAndroid) {
          dir = await getExternalStorageDirectory();
          final customDir = Directory('/storage/emulated/0/Download');
          if (await customDir.exists()) {
            dir = customDir;
          }
        } else if (Platform.isIOS) {
          dir = await getApplicationDocumentsDirectory();
        } else {
          dir = await getDownloadsDirectory();
        }
      }

      if (dir == null) {
        throw Exception("Could not find downloads directory.");
      }

      // Make a neat safe title
      String safeTitle = (_videoInfo!['title'] ?? 'downloaded_file')
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
          .trim();

      if (safeTitle.isEmpty) {
        safeTitle = DateTime.now().millisecondsSinceEpoch.toString();
      }

      String savePath = '';
      String endpoint = '';
      String taskId = DateTime.now().millisecondsSinceEpoch.toString();

      if (isAudio) {
        // Audio only for YouTube
        if (_selectedPlatform == 'youtube') {
          savePath = '${dir.path}/$safeTitle.mp3';
          endpoint = '$_backendUrl/download/audio?url=${Uri.encodeComponent(url)}&task_id=$taskId';
        } else {
          throw Exception('Audio download only supported for YouTube');
        }
      } else {
        // For TikTok, use temporary filename - backend will provide the real filename
        if (_selectedPlatform == 'tiktok') {
          savePath = '${dir.path}/temp_$taskId.tmp';
          endpoint = '$_backendUrl/tiktok/download?url=${Uri.encodeComponent(url)}&format_id=$_selectedFormatId&task_id=$taskId';
        } else if (_selectedPlatform == 'instagram') {
          savePath = '${dir.path}/temp_ig_$taskId.tmp';
          endpoint = '$_backendUrl/instagram/download?url=${Uri.encodeComponent(url)}&format_id=$_selectedFormatId&task_id=$taskId';
        } else {
          // For YouTube, use title with resolution
          String resolutionStr = '';
          try {
            final formats = _videoInfo!['video_formats'] as List;
            final selectedFormat = formats.firstWhere(
              (f) => f['format_id'].toString() == _selectedFormatId,
              orElse: () => null,
            );
            if (selectedFormat != null && selectedFormat['resolution'] != null) {
              resolutionStr = ' [${selectedFormat['resolution']}]';
            }
          } catch (_) {}

          savePath = '${dir.path}/$safeTitle$resolutionStr.mp4';
          endpoint = '$_backendUrl/download/video?url=${Uri.encodeComponent(url)}&format_id=$_selectedFormatId&task_id=$taskId';
        }
      }

      int lastUpdateTime = DateTime.now().millisecondsSinceEpoch;

      // Poll the server's dt-dlp download progress
      progressTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        try {
          final res = await http.get(
            Uri.parse('$_backendUrl/progress?task_id=$taskId'),
          );
          if (res.statusCode == 200) {
            final data = json.decode(res.body);
            String status = data['status'] ?? 'starting';
            double prog = (data['progress'] ?? 0.0).toDouble();

            if (status == 'downloading') {
              progressNotifier.value = prog;
              statusNotifier.value =
                  'Downloading: ${(prog * 100).toStringAsFixed(1)}%';
            } else if (status == 'processing') {
              progressNotifier.value = null; // indeterminate
              statusNotifier.value = 'Merging Video & Audio with FFmpeg...';
            }
          }
        } catch (_) {}
      });

      Dio dio = Dio();
      dio.options.connectTimeout = const Duration(minutes: 5);
      dio.options.receiveTimeout = const Duration(minutes: 10);
      
      Response response = await dio.download(
        endpoint,
        savePath,
        deleteOnError: false,  // keep partial file for debugging; we validate after
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
        ),
        onReceiveProgress: (received, total) {
          progressTimer?.cancel();
          int currentTime = DateTime.now().millisecondsSinceEpoch;

          // Update less frequently e.g. every 1000 ms to avoid 'real-time' lag
          if (currentTime - lastUpdateTime > 1000 || received == total) {
            lastUpdateTime = currentTime;
            if (total != -1) {
              progressNotifier.value = received / total;
              statusNotifier.value =
                  'Saving File: ${(received / 1024 / 1024).toStringAsFixed(2)}MB / ${(total / 1024 / 1024).toStringAsFixed(2)}MB';
            } else {
              statusNotifier.value =
                  'Saving File: ${(received / 1024 / 1024).toStringAsFixed(2)}MB... (merging might take time)';
              progressNotifier.value = null;
            }
          }
        },
      );

      progressTimer.cancel();

      // Rename saved file using the actual filename from backend Content-Disposition
      // This handles Unicode titles (RFC 5987) and all platforms
      try {
        final contentDisposition = response.headers.value('content-disposition');
        final backendFilename = _parseFilename(contentDisposition);

        if (backendFilename != null && backendFilename.isNotEmpty) {
          // Sanitize for filesystem
          final cleanName = backendFilename.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
          if (cleanName.isNotEmpty) {
            final newPath = '${dir.path}/$cleanName';
            final tempFile = File(savePath);
            if (await tempFile.exists() && newPath != savePath) {
              await tempFile.rename(newPath);
              savePath = newPath;
            }
          }
        }
      } catch (_) {
        // Keep original savePath if rename fails
      }
      
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Close dialog
      }
      _showSuccess(savePath);
    } catch (e) {
      progressTimer?.cancel();
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Close dialog
      }
      _showError('Download error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  void _showError(String text) {
    if (!mounted) return;
    
    // Show dialog at top/center instead of snackbar at bottom
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 28),
            const SizedBox(width: 12),
            const Text('Oops!', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          text,
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
        actions: [
          TextButton(
            child: const Text('OK', style: TextStyle(color: Color(0xFF00FFC6))),
            onPressed: () => Navigator.of(ctx).pop(),
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
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Success!'),
        content: Text(openBtn ? 'File saved to:\n$path' : path),
        actions: [
          if (openBtn)
            TextButton(
              child: const Text('Open File'),
              onPressed: () {
                Navigator.of(ctx).pop();
                OpenFilex.open(path);
              },
            ),
          TextButton(
            child: const Text('OK'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('RaiSaver'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      body: Stack(
        children: [
          const BackgroundBlobs(),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  children: [
                    _buildSearchBar(),
                    const SizedBox(height: 30),
                    if (_isLoadingInfo)
                      const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF00FFC6),
                        ),
                      )
                    else if (_videoInfo != null)
                      _buildVideoCard(),

                    const SizedBox(height: 100), // padding for FAB
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: SpeedDial(
        animatedIcon: AnimatedIcons.menu_close,
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        overlayColor: Colors.black,
        overlayOpacity: 0.5,
        spacing: 12,
        spaceBetweenChildren: 12,
        children: [
          SpeedDialChild(
            child: const Icon(Icons.apps),
            backgroundColor: const Color(0xFF00FFC6),
            foregroundColor: Colors.black,
            label: 'Platform',
            onTap: () {
              // Show platform options
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (context) => Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E2C),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 20),
                      const Text(
                        'Select Platform',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ListTile(
                        leading: const Icon(
                          Icons.video_library,
                          color: Color(0xFFFF0000),
                        ),
                        title: const Text(
                          'YouTube',
                          style: TextStyle(color: Colors.white),
                        ),
                        trailing: _selectedPlatform == 'youtube'
                            ? const Icon(
                                Icons.check,
                                color: Color(0xFF00FFC6),
                              )
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedPlatform = 'youtube';
                          });
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('YouTube downloader activated!'),
                              backgroundColor: Color(0xFF00FFC6),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.camera_alt,
                          color: Color(0xFFE1306C),
                        ),
                        title: const Text(
                          'Instagram',
                          style: TextStyle(color: Colors.white),
                        ),
                        trailing: _selectedPlatform == 'instagram'
                            ? const Icon(
                                Icons.check,
                                color: Color(0xFF00FFC6),
                              )
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedPlatform = 'instagram';
                          });
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Instagram downloader activated! Paste Reels/post URL to start.'),
                              backgroundColor: Color(0xFF00FFC6),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.music_note,
                          color: Colors.black,
                        ),
                        title: const Text(
                          'TikTok',
                          style: TextStyle(color: Colors.white),
                        ),
                        trailing: _selectedPlatform == 'tiktok'
                            ? const Icon(
                                Icons.check,
                                color: Color(0xFF00FFC6),
                              )
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedPlatform = 'tiktok';
                          });
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('TikTok downloader activated! Paste TikTok URL to start.'),
                              backgroundColor: Color(0xFF00FFC6),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              );
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.settings),
            backgroundColor: const Color(0xFF00FFC6),
            foregroundColor: Colors.black,
            label: 'Settings (Save Path)',
            onTap: _pickDownloadPath,
          ),
          SpeedDialChild(
            child: const Icon(Icons.dns_rounded),
            backgroundColor: const Color(0xFF6C63FF),
            foregroundColor: Colors.white,
            label: 'Backend URL',
            onTap: _showBackendSettings,
          ),
          SpeedDialChild(
            child: const Icon(Icons.refresh),
            backgroundColor: const Color(0xFFFF2A5F),
            foregroundColor: Colors.white,
            label: 'Reset',
            onTap: _resetApp,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    // Dynamic placeholder based on selected platform
    String placeholder = 'Paste YouTube Link here...';
    if (_selectedPlatform == 'tiktok') {
      placeholder = 'Paste TikTok Link here...';
    } else if (_selectedPlatform == 'instagram') {
      placeholder = 'Paste Instagram Link here...';
    }
    
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _urlController,
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle: const TextStyle(color: Colors.white54),
                border: InputBorder.none,
                icon: const Icon(Icons.link, color: Colors.white70),
              ),
              style: const TextStyle(color: Colors.white),
              onSubmitted: (_) => _fetchInfo(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search, color: Color(0xFF00FFC6)),
            onPressed: _fetchInfo,
          ),
        ],
      ),
    );
  }

  Widget _buildVideoCard() {
    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Thumbnail
          if (_videoInfo!['thumbnail'] != null && (_videoInfo!['thumbnail'] as String).isNotEmpty)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Builder(
                  builder: (context) {
                    final thumb = _videoInfo!['thumbnail'] as String;
                    final imageUrl = _selectedPlatform == 'instagram'
                        ? '$_backendUrl/proxy-image?url=${Uri.encodeComponent(thumb)}'
                        : thumb;
                    return Image.network(
                      imageUrl,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.white10,
                        child: const Center(
                          child: Icon(Icons.image_not_supported, color: Colors.white30, size: 48),
                        ),
                      ),
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: Colors.white10,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF00FFC6),
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          const SizedBox(height: 20),
          // Title
          Text(
            _videoInfo!['title'] ?? 'Unknown Title',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          // Channel
          Row(
            children: [
              const Icon(Icons.person, size: 16, color: Colors.white70),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _videoInfo!['channel'] ?? 'Unknown Channel',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
          // Description/caption — shown for Instagram posts
          if (_selectedPlatform == 'instagram') ...[
            Builder(builder: (context) {
              final title = (_videoInfo!['title'] as String? ?? '').trim();
              final desc = (_videoInfo!['description'] as String? ?? '').trim();
              // Remove first line from description if it matches the title (avoid duplicate)
              String displayDesc = desc;
              if (desc.isNotEmpty && title.isNotEmpty) {
                final firstLine = desc.split('\n').first.trim();
                if (firstLine == title) {
                  displayDesc = desc.substring(firstLine.length).trimLeft();
                }
              }
              if (displayDesc.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Text(
                      displayDesc,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.5,
                      ),
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );
            }),
          ],
          const SizedBox(height: 16),
          // Warning if only 360p or lower is available
          if (_videoInfo!['video_formats'] != null && 
              (_videoInfo!['video_formats'] as List).isNotEmpty &&
              _selectedPlatform == 'youtube') ...[
            Builder(
              builder: (context) {
                final formats = _videoInfo!['video_formats'] as List;
                // Check if highest resolution is 360p or lower
                bool onlyLowRes = true;
                for (var format in formats) {
                  String res = format['resolution']?.toString() ?? '';
                  if (res.contains('720p') || res.contains('1080p') || 
                      res.contains('1440p') || res.contains('2160p') ||
                      res.contains('480p')) {
                    onlyLowRes = false;
                    break;
                  }
                }
                
                if (onlyLowRes) {
                  return Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.orange,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'YouTube is blocking higher resolutions for this video. Only ${formats[0]['resolution']} available.',
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
          Text(
            () {
              if (_selectedPlatform != 'instagram') return 'Video';
              final formats = _videoInfo!['video_formats'] as List? ?? [];
              final hasPhoto = formats.any((f) => (f['format_id'] as String? ?? '').startsWith('api_') && (f['ext'] as String? ?? '') != 'mp4');
              final hasVideo = formats.any((f) => (f['ext'] as String? ?? '') == 'mp4');
              if (hasPhoto && hasVideo) return 'Media (Foto & Video)';
              if (hasPhoto) return 'Foto';
              return 'Video';
            }(),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6C63FF),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedFormatId,
                      dropdownColor: const Color(0xFF1E1E2C),
                      isExpanded: true,
                      icon: const Icon(
                        Icons.keyboard_arrow_down,
                        color: Color(0xFF00FFC6),
                      ),
                      items: (_videoInfo!['video_formats'] as List).map((
                        format,
                      ) {
                        String ext = format['ext']?.toString().toUpperCase() ?? 'MP4';
                        return DropdownMenuItem<String>(
                          value: format['format_id'].toString(),
                          child: Text('${format['resolution']} - $ext'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedFormatId = val;
                        });
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: ElevatedButton.icon(
                      onPressed: _isDownloading ? null : () => _download(false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(
                          0xFF6C63FF,
                        ).withValues(alpha: 0.6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                      ),
                      icon: Icon(
                        _getFormatIcon(),
                        size: 18,
                      ),
                      label: Text(_getFormatLabel()),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Only show Audio download for YouTube
          if (_selectedPlatform == 'youtube') ...[
            const SizedBox(height: 24),
            const Text(
              'Audio Only',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00FFC6),
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isDownloading ? null : () => _download(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(
                        0xFF00FFC6,
                      ).withValues(alpha: 0.6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.audiotrack, size: 18),
                    label: const Text('Download MP3'),
                  ),
                ),
              ),
            ),
          ],
          // Download All button for Instagram carousel/photo posts
          if (_selectedPlatform == 'instagram') ...[
            Builder(builder: (context) {
              final formats = _videoInfo!['video_formats'] as List? ?? [];
              final hasApiFormats = formats.any(
                (f) => (f['format_id'] as String? ?? '').startsWith('api_'),
              );
              if (!hasApiFormats || formats.length <= 1) return const SizedBox.shrink();
              return _buildDownloadAllButton(
                count: formats.length,
                onTap: () => _downloadAllMedia(
                  endpoint: '/instagram/download/all',
                  label: 'Instagram',
                ),
              );
            }),
          ],
          // Download All button for TikTok photo/slideshow posts
          if (_selectedPlatform == 'tiktok') ...[
            Builder(builder: (context) {
              final isPhoto = _videoInfo!['is_photo'] == true;
              final formats = _videoInfo!['video_formats'] as List? ?? [];
              final photoCount = formats.where((f) =>
                (f['format_id'] as String? ?? '').startsWith('img_')).length;
              if (!isPhoto || photoCount <= 1) return const SizedBox.shrink();
              return _buildDownloadAllButton(
                count: photoCount,
                onTap: () => _downloadAllMedia(
                  endpoint: '/tiktok/download/all',
                  label: 'TikTok',
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
