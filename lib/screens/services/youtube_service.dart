import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../models/video.dart';

class YouTubeService {
  final String? apiKey;

  YouTubeService({this.apiKey});

  Future<List<Video>> fetchTrendingVideos() async {
    if (apiKey == null || apiKey!.isEmpty) {
      // Fallback to sample videos if API key is not configured
      return Video.sampleVideos;
    }

    try {
      final url = Uri.parse(
        'https://www.googleapis.com/youtube/v3/videos?part=snippet,statistics,contentDetails&chart=mostPopular&maxResults=10&key=$apiKey',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List items = data['items'] ?? [];
        return items.map((item) {
          final snippet = item['snippet'] ?? {};
          final statistics = item['statistics'] ?? {};
          final contentDetails = item['contentDetails'] ?? {};
          return Video(
            id: item['id'] ?? '',
            title: snippet['title'] ?? '',
            thumbnailUrl: snippet['thumbnails']?['high']?['url'] ?? '',
            channelName: snippet['channelTitle'] ?? '',
            channelAvatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=200&auto=format&fit=crop',
            views: '${statistics['viewCount'] ?? '0'} views',
            timestamp: snippet['publishedAt'] ?? '',
            duration: contentDetails['duration'] ?? '',
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('YouTube API Error: $e');
    }
    return Video.sampleVideos;
  }
}
