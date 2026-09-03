import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/video.dart';

class YouTubeService {
  // TODO: Replace with your YouTube Data API v3 key from console.cloud.google.com
  static const String _apiKey = '';
  static const String _baseUrl = 'https://www.googleapis.com/youtube/v3';

  static bool get _hasApiKey => _apiKey.isNotEmpty;

  /// Fetch popular videos by category
  static Future<List<Video>> fetchPopularVideos({String? categoryId}) async {
    if (!_hasApiKey) return Video.sampleVideos;
    try {
      final params = {
        'part': 'snippet,contentDetails,statistics',
        'chart': 'mostPopular',
        'maxResults': '20',
        'regionCode': 'IN',
        'key': _apiKey,
        if (categoryId != null) 'videoCategoryId': categoryId,
      };
      final uri = Uri.parse('$_baseUrl/videos').replace(queryParameters: params);
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['items'] as List).map((item) => _videoFromItem(item)).toList();
      }
    } catch (_) {}
    return Video.sampleVideos;
  }

  /// Search videos
  static Future<List<Video>> searchVideos(String query) async {
    if (!_hasApiKey) {
      return Video.sampleVideos
          .where((v) => v.title.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
    try {
      final params = {
        'part': 'snippet',
        'q': query,
        'type': 'video',
        'maxResults': '20',
        'key': _apiKey,
      };
      final uri =
          Uri.parse('$_baseUrl/search').replace(queryParameters: params);
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['items'] as List).map((item) {
          final snippet = item['snippet'];
          final videoId = item['id']['videoId'];
          return Video(
            id: videoId,
            title: snippet['title'] ?? '',
            thumbnailUrl: snippet['thumbnails']['high']['url'] ?? '',
            channelName: snippet['channelTitle'] ?? '',
            channelAvatarUrl:
                'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=200',
            views: 'YouTube Video',
            timestamp: _formatDate(snippet['publishedAt']),
            duration: '',
            videoUrl: 'https://www.youtube.com/watch?v=$videoId',
          );
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Fetch YouTube Shorts (short-duration videos)
  static Future<List<Video>> fetchShorts() async {
    if (!_hasApiKey) return Video.getShortsVideos();
    try {
      final params = {
        'part': 'snippet',
        'q': '#shorts',
        'type': 'video',
        'videoDuration': 'short',
        'maxResults': '15',
        'key': _apiKey,
      };
      final uri =
          Uri.parse('$_baseUrl/search').replace(queryParameters: params);
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['items'] as List).map((item) {
          final snippet = item['snippet'];
          final videoId = item['id']['videoId'];
          return Video(
            id: videoId,
            title: snippet['title'] ?? '',
            thumbnailUrl: snippet['thumbnails']['high']['url'] ?? '',
            channelName: snippet['channelTitle'] ?? '',
            channelAvatarUrl:
                'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=200',
            views: 'YouTube Short',
            timestamp: _formatDate(snippet['publishedAt']),
            duration: '< 1:00',
            videoUrl: 'https://www.youtube.com/shorts/$videoId',
          );
        }).toList();
      }
    } catch (_) {}
    return Video.getShortsVideos();
  }

  /// Generate YouTube share URL
  static String shareUrl(String videoId, {bool isShort = false}) {
    if (isShort) return 'https://youtube.com/shorts/$videoId';
    return 'https://youtu.be/$videoId';
  }

  static Video _videoFromItem(Map item) {
    final snippet = item['snippet'];
    final stats = item['statistics'];
    final details = item['contentDetails'];
    final videoId = item['id'];
    final viewCount = int.tryParse(stats?['viewCount'] ?? '0') ?? 0;
    final likeCount = int.tryParse(stats?['likeCount'] ?? '0') ?? 0;

    return Video(
      id: videoId,
      title: snippet['title'] ?? '',
      thumbnailUrl: snippet['thumbnails']['high']['url'] ?? '',
      channelName: snippet['channelTitle'] ?? '',
      channelAvatarUrl:
          'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=200',
      views: _formatCount(viewCount),
      timestamp: _formatDate(snippet['publishedAt']),
      duration: _parseDuration(details?['duration'] ?? 'PT0S'),
      likes: _formatCount(likeCount),
      description: snippet['description'],
      videoUrl: 'https://www.youtube.com/watch?v=$videoId',
    );
  }

  static String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M views';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(0)}K views';
    return '$count views';
  }

  static String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final date = DateTime.parse(iso);
      final diff = DateTime.now().difference(date);
      if (diff.inDays > 365) return '${(diff.inDays / 365).floor()} years ago';
      if (diff.inDays > 30) return '${(diff.inDays / 30).floor()} months ago';
      if (diff.inDays > 0) return '${diff.inDays} days ago';
      if (diff.inHours > 0) return '${diff.inHours} hours ago';
      return '${diff.inMinutes} minutes ago';
    } catch (_) {
      return '';
    }
  }

  static String _parseDuration(String iso) {
    final regex = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?');
    final match = regex.firstMatch(iso);
    if (match == null) return '0:00';
    final h = int.tryParse(match.group(1) ?? '0') ?? 0;
    final m = int.tryParse(match.group(2) ?? '0') ?? 0;
    final s = int.tryParse(match.group(3) ?? '0') ?? 0;
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
