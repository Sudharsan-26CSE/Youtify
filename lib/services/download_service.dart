import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/video.dart';

class DownloadItem {
  final Video video;
  double progress; // 0.0 to 1.0
  bool isComplete;

  DownloadItem({
    required this.video,
    this.progress = 0.0,
    this.isComplete = false,
  });

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
      );
}

class DownloadService {
  static final List<DownloadItem> _downloads = [];
  static final List<void Function()> _listeners = [];

  static List<DownloadItem> get downloads => List.unmodifiable(_downloads);

  static void addListener(void Function() listener) =>
      _listeners.add(listener);
  static void removeListener(void Function() listener) =>
      _listeners.remove(listener);
  static void _notify() {
    for (final l in _listeners) {
      l();
    }
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
    await prefs.setString(
        'downloads', jsonEncode(_downloads.map((d) => d.toJson()).toList()));
  }

  static bool isDownloading(String videoId) =>
      _downloads.any((d) => d.video.id == videoId);

  static Future<void> startDownload(Video video) async {
    if (isDownloading(video.id)) return;
    final item = DownloadItem(video: video);
    _downloads.insert(0, item);
    _notify();

    // Simulate download progress
    for (int i = 1; i <= 20; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      item.progress = i / 20.0;
      if (i == 20) item.isComplete = true;
      _notify();
    }
    await _save();
  }

  static Future<void> removeDownload(String videoId) async {
    _downloads.removeWhere((d) => d.video.id == videoId);
    await _save();
    _notify();
  }
}
