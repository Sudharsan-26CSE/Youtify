import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide Video;
import '../models/video.dart';

class VideoPage {
  final List<Video> videos;
  final String? nextPageToken;
  VideoPage(this.videos, this.nextPageToken);
}

class ChannelPage {
  final List<Map<String, dynamic>> channels;
  final String? nextPageToken;

  ChannelPage(this.channels, this.nextPageToken);
}

class YouTubeService {
  static final yt = YoutubeExplode();
  static String get _apiKey => dotenv.env['YOUTUBE_API_KEY'] ?? '';
  static const String _baseUrl = 'https://www.googleapis.com/youtube/v3';
  static String? _accessToken;

  static bool get _hasApiKey => _apiKey.isNotEmpty;
  static bool get isAccountConnected => _accessToken != null;

  static void setAccessToken(String? token) => _accessToken = token;

  static Map<String, String> get _headers => {
        'Accept': 'application/json',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  static Future<http.Response> _get(Uri uri) =>
      http.get(uri, headers: _headers);

  /// Fetch popular videos by category
  static Future<VideoPage> fetchPopularVideos(
      {String? categoryId, String? pageToken}) async {
    if (!_hasApiKey) return VideoPage(Video.sampleVideos, null);
    try {
      final params = {
        'part': 'snippet,contentDetails,statistics',
        'chart': 'mostPopular',
        'maxResults': '20',
        'regionCode': 'IN',
        'key': _apiKey,
        if (categoryId != null) 'videoCategoryId': categoryId,
        if (pageToken != null) 'pageToken': pageToken,
      };
      final uri =
          Uri.parse('$_baseUrl/videos').replace(queryParameters: params);
      final response = await _get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final videos = (data['items'] as List)
            .map((item) => _videoFromItem(item))
            .toList();
        return VideoPage(videos, data['nextPageToken']);
      }
    } catch (_) {}
    return VideoPage(Video.sampleVideos, null);
  }

  /// Search videos
  static Future<VideoPage> searchVideos(String query,
      {String? pageToken}) async {
    if (!_hasApiKey) {
      final vids = Video.sampleVideos
          .where((v) => v.title.toLowerCase().contains(query.toLowerCase()))
          .toList();
      return VideoPage(vids, null);
    }
    try {
      final params = {
        'part': 'snippet',
        'q': query,
        'type': 'video',
        'maxResults': '20',
        'key': _apiKey,
        if (pageToken != null) 'pageToken': pageToken,
      };
      final uri =
          Uri.parse('$_baseUrl/search').replace(queryParameters: params);
      final response = await _get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final videos = (data['items'] as List).map((item) {
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
        return VideoPage(videos, data['nextPageToken']);
      }
    } catch (_) {}
    return VideoPage([], null);
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
      final response = await _get(uri);
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

  /// Fetch public comments from the Data API. Posting requires OAuth.
  static Future<List<Map<String, String>>> fetchComments(String videoId) async {
    if (!_hasApiKey) return [];
    try {
      final uri =
          Uri.parse('$_baseUrl/commentThreads').replace(queryParameters: {
        'part': 'snippet,replies',
        'videoId': videoId,
        'maxResults': '50',
        'order': 'relevance',
        'textFormat': 'plainText',
        'key': _apiKey,
      });
      final response = await _get(uri);
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final result = <Map<String, String>>[];
      for (final item in (data['items'] as List? ?? const [])) {
        final snippet = item['snippet']['topLevelComment']['snippet'];
        result.add({
          'id': item['id']?.toString() ?? '',
          'user': snippet['authorDisplayName']?.toString() ?? 'YouTube user',
          'text': snippet['textDisplay']?.toString() ?? '',
          'time': _formatDate(snippet['publishedAt']?.toString()),
          'likes': snippet['likeCount']?.toString() ?? '0',
          'avatar': snippet['authorProfileImageUrl']?.toString() ?? '',
        });
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  static Future<String?> postComment(String videoId, String text) async {
    if (_accessToken == null || text.trim().isEmpty) return null;
    final uri = Uri.parse('$_baseUrl/commentThreads')
        .replace(queryParameters: {'part': 'snippet'});
    final response = await http.post(
      uri,
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode({
        'snippet': {
          'videoId': videoId,
          'topLevelComment': {
            'snippet': {'textOriginal': text.trim()}
          }
        }
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    return (jsonDecode(response.body)['id'] ?? '').toString();
  }

  static Future<String?> getVideoRating(String videoId) async {
    if (_accessToken == null) return null;
    final uri = Uri.parse('$_baseUrl/videos/getRating')
        .replace(queryParameters: {'id': videoId});
    final response = await _get(uri);
    if (response.statusCode != 200) return null;
    final items = jsonDecode(response.body)['items'] as List? ?? const [];
    return items.isEmpty ? 'none' : items.first['rating']?.toString();
  }

  static Future<bool> rateVideo(String videoId, String rating) async {
    if (_accessToken == null) return false;
    final uri = Uri.parse('$_baseUrl/videos/rate')
        .replace(queryParameters: {'id': videoId, 'rating': rating});
    final response = await http.post(uri, headers: _headers);
    return response.statusCode >= 200 && response.statusCode < 300;
  }

  static Future<ChannelPage> fetchMySubscriptions({String? pageToken}) async {
    if (_accessToken == null) return ChannelPage([], null);
    final uri = Uri.parse('$_baseUrl/subscriptions').replace(queryParameters: {
      'part': 'snippet,contentDetails',
      'mine': 'true',
      'maxResults': '50',
      if (pageToken != null) 'pageToken': pageToken,
    });
    final response = await _get(uri);
    if (response.statusCode != 200) return ChannelPage([], null);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final ids = (data['items'] as List? ?? const [])
        .map((item) => item['snippet']['resourceId']['channelId'].toString())
        .toList();
    final details = await fetchChannels(ids);
    return ChannelPage(details, data['nextPageToken']?.toString());
  }

  static Future<List<Map<String, dynamic>>> fetchChannels(
      List<String> ids) async {
    if (ids.isEmpty || (!_hasApiKey && _accessToken == null)) return [];
    final uri = Uri.parse('$_baseUrl/channels').replace(queryParameters: {
      'part': 'snippet,statistics,brandingSettings,contentDetails',
      'id': ids.join(','),
      if (_accessToken == null) 'key': _apiKey,
    });
    final response = await _get(uri);
    if (response.statusCode != 200) return [];
    return (jsonDecode(response.body)['items'] as List? ?? const [])
        .map<Map<String, dynamic>>(_channelFromItem)
        .toList();
  }

  static Future<Map<String, dynamic>?> fetchChannel(String channelId) async {
    final channels = await fetchChannels([channelId]);
    return channels.isEmpty ? null : channels.first;
  }

  static Future<VideoPage> fetchChannelVideos(String channelId,
      {String? pageToken}) async {
    if (!_hasApiKey && _accessToken == null) return VideoPage([], null);
    final searchUri = Uri.parse('$_baseUrl/search').replace(queryParameters: {
      'part': 'snippet',
      'channelId': channelId,
      'type': 'video',
      'order': 'date',
      'maxResults': '20',
      if (_accessToken == null) 'key': _apiKey,
      if (pageToken != null) 'pageToken': pageToken,
    });
    final searchResponse = await _get(searchUri);
    if (searchResponse.statusCode != 200) return VideoPage([], null);
    final data = jsonDecode(searchResponse.body) as Map<String, dynamic>;
    final ids = (data['items'] as List? ?? const [])
        .map((item) => item['id']['videoId'].toString())
        .join(',');
    if (ids.isEmpty) return VideoPage([], data['nextPageToken']?.toString());
    final videoUri = Uri.parse('$_baseUrl/videos').replace(queryParameters: {
      'part': 'snippet,contentDetails,statistics',
      'id': ids,
      if (_accessToken == null) 'key': _apiKey,
    });
    final videoResponse = await _get(videoUri);
    if (videoResponse.statusCode != 200) return VideoPage([], null);
    final videos =
        (jsonDecode(videoResponse.body)['items'] as List? ?? const [])
            .map<Video>((item) => _videoFromItem(item))
            .toList();
    return VideoPage(videos, data['nextPageToken']?.toString());
  }

  /// Fetch channel avatar (uses API or a fallback)
  static Future<String> getChannelAvatar(String channelId) async {
    if (!_hasApiKey)
      return 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=200';
    try {
      final uri = Uri.parse(
          '$_baseUrl/channels?part=snippet&id=$channelId&key=$_apiKey');
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['items'] != null && data['items'].isNotEmpty) {
          return data['items'][0]['snippet']['thumbnails']['default']['url'];
        }
      }
    } catch (_) {}
    return 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=200';
  }

  static Video _videoFromItem(Map item) {
    final snippet = item['snippet'];
    final stats = item['statistics'];
    final details = item['contentDetails'];
    final videoIdRaw = item['id'];
    final videoId =
        videoIdRaw is String ? videoIdRaw : videoIdRaw['videoId'] ?? videoIdRaw;

    final viewCountStr = stats?['viewCount'] ?? '0';
    final viewCount = int.tryParse(viewCountStr.toString()) ?? 0;

    final likeCountStr = stats?['likeCount'] ?? '0';
    final likeCount = int.tryParse(likeCountStr.toString()) ?? 0;

    return Video(
      id: videoId,
      title: snippet['title'] ?? '',
      thumbnailUrl: snippet['thumbnails']['high']['url'] ?? '',
      channelName: snippet['channelTitle'] ?? '',
      channelAvatarUrl:
          'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=200', // Update dynamically if needed
      views: _formatCount(viewCount),
      timestamp: _formatDate(snippet['publishedAt']),
      duration: _parseDuration(details?['duration'] ?? 'PT0S'),
      likes: _formatCount(likeCount),
      description: snippet['description'],
      videoUrl: 'https://www.youtube.com/watch?v=$videoId',
    );
  }

  static String _formatCount(int count) {
    if (count >= 1000000)
      return '${(count / 1000000).toStringAsFixed(1)}M views';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(0)}K views';
    return '$count views';
  }

  static Map<String, dynamic> _channelFromItem(dynamic raw) {
    final item = raw as Map<String, dynamic>;
    final snippet = item['snippet'] as Map? ?? const {};
    final statistics = item['statistics'] as Map? ?? const {};
    final branding = item['brandingSettings'] as Map? ?? const {};
    final image = snippet['thumbnails']?['high']?['url'] ??
        snippet['thumbnails']?['default']?['url'] ??
        '';
    return {
      'id': item['id']?.toString() ?? '',
      'name': snippet['title']?.toString() ?? 'YouTube channel',
      'avatar': image,
      'banner': branding['image']?['bannerExternalUrl']?.toString() ?? '',
      'subs': _formatSubscribers(statistics['subscriberCount']),
      'subscriberCount': statistics['subscriberCount']?.toString() ?? '0',
      'videoCount': statistics['videoCount']?.toString() ?? '0',
      'viewCount': statistics['viewCount']?.toString() ?? '0',
      'description': snippet['description']?.toString() ?? '',
      'isNew': false,
      'watchTime': '',
    };
  }

  static String _formatSubscribers(dynamic value) {
    final count = int.tryParse(value?.toString() ?? '') ?? 0;
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(0)}K';
    return count.toString();
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
    if (h > 0)
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
