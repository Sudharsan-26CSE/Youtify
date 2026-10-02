import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide Video;
import '../models/video.dart';
import 'youtube_service.dart';

class DownloadItem {
  final Video video;
  double progress;
  bool isComplete;
  String? savePath;
  int totalBytes;
  int receivedBytes;
  double networkSpeedBps; // bytes per second
  int availableStorageMB;

  DownloadItem({
    required this.video,
    this.progress = 0.0,
    this.isComplete = false,
    this.savePath,
    this.totalBytes = 0,
    this.receivedBytes = 0,
    this.networkSpeedBps = 0,
    this.availableStorageMB = 0,
  });

  String get formattedTotalSize {
    if (totalBytes >= 1024 * 1024) return '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    if (totalBytes >= 1024) return '${(totalBytes / 1024).toStringAsFixed(0)} KB';
    return '$totalBytes B';
  }

  String get formattedReceivedSize {
    if (receivedBytes >= 1024 * 1024) return '${(receivedBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    if (receivedBytes >= 1024) return '${(receivedBytes / 1024).toStringAsFixed(0)} KB';
    return '$receivedBytes B';
  }

  String get formattedSpeed {
    if (networkSpeedBps >= 1024 * 1024) return '${(networkSpeedBps / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    if (networkSpeedBps >= 1024) return '${(networkSpeedBps / 1024).toStringAsFixed(0)} KB/s';
    return '${networkSpeedBps.toStringAsFixed(0)} B/s';
  }

  Map<String, dynamic> toJson() => {
        'id': video.id,
        'title': video.title,
        'thumbnail': video.thumbnailUrl,
        'channel': video.channelName,
        'channelAvatar': video.channelAvatarUrl,
        'views': video.views,
        'timestamp': video.timestamp,
        'duration': video.duration,
        'progress': progress,
        'isComplete': isComplete,
        'savePath': savePath,
        'totalBytes': totalBytes,
      };

  static DownloadItem fromJson(Map<String, dynamic> json) => DownloadItem(
        video: Video(
          id: json['id'],
          title: json['title'],
          thumbnailUrl: json['thumbnail'],
          channelName: json['channel'],
          channelAvatarUrl: json['channelAvatar'],
          views: json['views'],
          timestamp: json['timestamp'],
          duration: json['duration'],
        ),
        progress: (json['progress'] as num).toDouble(),
        isComplete: json['isComplete'] as bool,
        savePath: json['savePath'] as String?,
        totalBytes: json['totalBytes'] as int? ?? 0,
      );
}

class DownloadService {
  static final List<DownloadItem> _downloads = [];
  static final List<void Function()> _listeners = [];
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  static final Dio _dio = Dio();
  static bool _initialized = false;

  static List<DownloadItem> get downloads => List.unmodifiable(_downloads);
  static List<DownloadItem> get items => downloads;

  static void addListener(void Function() listener) => _listeners.add(listener);
  static void removeListener(void Function() listener) => _listeners.remove(listener);
  static void _notify() {
    for (final l in _listeners) {
      l();
    }
  }

  static Future<void> init() async {
    if (_initialized) return;
    try {
      if (!kIsWeb && Platform.isAndroid) {
        const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
        const initSettings = InitializationSettings(android: androidInit);
        await _notificationsPlugin.initialize(
          settings: initSettings,
          onDidReceiveNotificationResponse: (details) {
            if (details.payload != null && details.payload!.startsWith('undo_')) {
              final videoId = details.payload!.replaceFirst('undo_', '');
              removeDownload(videoId);
            }
          },
        );
      }
    } catch (e) {
      debugPrint('Notification init skipped or failed: $e');
    }
    _initialized = true;
    await load();
  }

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('downloads') ?? '[]';
    final list = jsonDecode(raw) as List;
    _downloads.clear();
    _downloads.addAll(list.map((e) => DownloadItem.fromJson(e)));
    _notify();
  }

  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('downloads', jsonEncode(_downloads.map((d) => d.toJson()).toList()));
  }

  static bool isDownloading(String videoId) => _downloads.any(
        (d) => d.video.id == videoId && !d.isComplete,
      );

  static bool isDownloaded(String videoId) => _downloads.any(
        (d) => d.video.id == videoId && d.isComplete,
      );

  static Future<int> _getAvailableStorageMB() async {
    try {
      final stat = await Process.run('df', ['/storage/emulated/0']);
      final lines = stat.stdout.toString().split('\n');
      if (lines.length > 1) {
        final parts = lines[1].split(RegExp(r'\s+'));
        if (parts.length >= 4) {
          final availKB = int.tryParse(parts[3]) ?? 0;
          return (availKB / 1024).round();
        }
      }
    } catch (_) {}
    return -1;
  }

  static Future<void> startDownload(Video video) async {
    if (isDownloading(video.id) || isDownloaded(video.id)) return;

    if (!kIsWeb && Platform.isAndroid) {
      try {
        await Permission.notification.request();
      } catch (_) {}

      try {
        final vStatus = await Permission.videos.request();
        if (!vStatus.isGranted) {
          await Permission.storage.request();
        }
      } catch (_) {}
    }

    final item = DownloadItem(video: video);
    
    // Get available storage
    item.availableStorageMB = await _getAvailableStorageMB();

    _downloads.insert(0, item);
    _notify();
    await _save();

    try {
      final yt = YouTubeService.yt;
      final manifest = await yt.videos.streamsClient.getManifest(video.resolvedYoutubeId ?? video.id);
      final streamInfo = manifest.muxed.bestQuality;

      item.totalBytes = streamInfo.size.totalBytes;

      String dir = '';
      if (!kIsWeb && Platform.isAndroid) {
        // Dedicated separate folder for all downloaded videos in system Download directory
        final primaryDir = Directory('/storage/emulated/0/Download/Youtify');
        bool canWritePrimary = false;
        try {
          if (!await primaryDir.exists()) {
            await primaryDir.create(recursive: true);
          }
          final testFile = File('${primaryDir.path}/.test_probe');
          await testFile.writeAsString('ok');
          await testFile.delete();
          canWritePrimary = true;
          dir = primaryDir.path;
        } catch (e) {
          debugPrint('Primary Download/Youtify folder write failed: $e');
        }

        if (!canWritePrimary) {
          final extDir = await getExternalStorageDirectory();
          if (extDir != null) {
            final fallbackDir = Directory('${extDir.path}/Youtify');
            if (!await fallbackDir.exists()) {
              await fallbackDir.create(recursive: true);
            }
            dir = fallbackDir.path;
          } else {
            final appDocDir = await getApplicationDocumentsDirectory();
            final fallbackDir = Directory('${appDocDir.path}/Youtify');
            if (!await fallbackDir.exists()) {
              await fallbackDir.create(recursive: true);
            }
            dir = fallbackDir.path;
          }
        }
      } else {
        final directory = await getApplicationDocumentsDirectory();
        dir = '${directory.path}/Youtify';
        final directoryObj = Directory(dir);
        if (!await directoryObj.exists()) {
          await directoryObj.create(recursive: true);
        }
      }

      String cleanTitle = video.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim();
      if (cleanTitle.isEmpty) {
        cleanTitle = 'video_${video.id}';
      } else if (cleanTitle.length > 60) {
        cleanTitle = cleanTitle.substring(0, 60);
      }
      final savePath = '$dir/$cleanTitle.mp4';
      item.savePath = savePath;

      DateTime lastUpdate = DateTime.now();
      int lastBytes = 0;

      await _dio.download(
        streamInfo.url.toString(),
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            item.progress = received / total;
            item.receivedBytes = received;
            item.totalBytes = total;

            // Calculate network speed
            final now = DateTime.now();
            final elapsed = now.difference(lastUpdate).inMilliseconds;
            if (elapsed > 500) {
              final bytesDelta = received - lastBytes;
              item.networkSpeedBps = (bytesDelta / (elapsed / 1000));
              lastUpdate = now;
              lastBytes = received;
            }
            _notify();
          }
        },
      );

      item.isComplete = true;
      item.progress = 1.0;
      item.networkSpeedBps = 0;
      await _save();
      _notify();

      _showNotification(video.title, video.id);
    } catch (e) {
      debugPrint('Download failed: $e');
      _downloads.removeWhere((d) => d.video.id == video.id);
      await _save();
      _notify();
    }
  }

  static Future<void> _showNotification(String title, String videoId) async {
    const androidDetails = AndroidNotificationDetails(
      'youtify_downloads',
      'Downloads',
      channelDescription: 'Download completion notifications',
      importance: Importance.high,
      priority: Priority.high,
      actions: [
        AndroidNotificationAction('undo_btn', 'Undo (Delete)', showsUserInterface: true),
      ],
    );
    const details = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(
      id: videoId.hashCode,
      title: 'Download Complete',
      body: title,
      notificationDetails: details,
      payload: 'undo_$videoId',
    );
  }

  static Future<void> removeDownload(String videoId) async {
    final index = _downloads.indexWhere((d) => d.video.id == videoId);
    if (index != -1) {
      final item = _downloads[index];
      if (item.savePath != null) {
        final file = File(item.savePath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
      _downloads.removeAt(index);
      await _save();
      _notify();
    }
  }
}
