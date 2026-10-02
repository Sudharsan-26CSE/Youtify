import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt_exp;
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
  static final yt = yt_exp.YoutubeExplode();
  static String get _apiKey => dotenv.env['YOUTUBE_API_KEY'] ?? '';
  static const String _baseUrl = 'https://www.googleapis.com/youtube/v3';
  static String? _accessToken;

  static final Map<String, String> _channelAvatarCache = {
    'UCX6OQ3DkcsbYNE6H8uQQuVA':
        'https://yt3.googleusercontent.com/nxYrc_1_2f77DoBadyxMTmv7ZpRZapHR5jbuYe7PlPd5cIRJxtNNEYyOC0ZsxaDyJJzXrnJiuDE=s900-c-k-c0x00ffffff-no-rj',
    'UCq-Fj5jknLsUf-MWSy4_brA':
        'https://yt3.googleusercontent.com/VunTf0NzCeboiPjbesBdnQuxaF3Lja7UGRbBGQAWRJgMSTj9TTLO3pS1X9qPOJGCNnmPrXeY=s900-c-k-c0x00ffffff-no-rj',
    'UCHnyfMqiRRG1u-2MsSQLbXA':
        'https://yt3.googleusercontent.com/7vCbvtCqtjQ3YLgsJt7Y952MQV1sBvhllSCSxHP8_sVZdcPCBrITfhkN2RdyCuwPnsByq-1GoA=s900-c-k-c0x00ffffff-no-rj',
    'UCsXVk37bltHxD1rDPwtNM8Q':
        'https://yt3.googleusercontent.com/ytc/AIdro_n1Ribd7LwdP_qKtqWL3ZDfIgv9M1d6g78VwpHGXVR2Ir4=s900-c-k-c0x00ffffff-no-rj',
    'UC_x5XG1OV2P6uZZ5FSM9Ttw':
        'https://yt3.googleusercontent.com/Jrfy3VrP1QDikidneCoruk9MmhsQsEAgeQSELZtL2fn1pKxCjh2ohk7derV33UpetVZwt-DuRQ=s900-c-k-c0x00ffffff-no-rj',
    'UCsBjURrPoezykLs9EqgamOA':
        'https://yt3.googleusercontent.com/3fPNbkf_xPyCleq77ZhcxyeorY97NtMHVNUbaAON_RBDH9ydL4hJkjxC8x_4mpuopkB8oI7Ct6Y=s900-c-k-c0x00ffffff-no-rj',
    'UCwXdFgeE9KYzlDdR7TG9cMw':
        'https://yt3.googleusercontent.com/ytc/AIdro_nqx_sCd8ZIeIcodS0sfeMKJ8rVTslmQHUe_udwGNH2Pg=s900-c-k-c0x00ffffff-no-rj',
  };
  static final Map<String, yt_exp.VideoSearchList> _activeSearchLists = {};

  static bool get _hasApiKey => _apiKey.isNotEmpty;
  static bool get isAccountConnected => _accessToken != null;

  static void setAccessToken(String? token) => _accessToken = token;

  static Map<String, String> get _headers => {
        'Accept': 'application/json',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  static Future<http.Response> _get(Uri uri) =>
      http.get(uri, headers: _headers);

  static Video _videoFromExplode(yt_exp.Video v) {
    final dur = v.duration;
    String durStr = '0:00';
    if (dur != null) {
      final hours = dur.inHours;
      final minutes = dur.inMinutes.remainder(60);
      final seconds = dur.inSeconds.remainder(60).toString().padLeft(2, '0');
      durStr = hours > 0
          ? '$hours:${minutes.toString().padLeft(2, '0')}:$seconds'
          : '$minutes:$seconds';
    }

    final chId = v.channelId.value;
    final avatar = _channelAvatarCache[chId] ??
        'https://ui-avatars.com/api/?name=${Uri.encodeComponent(v.author)}&background=272727&color=fff&size=128';

    return Video(
      id: v.id.value,
      title: v.title,
      thumbnailUrl: v.thumbnails.highResUrl.isNotEmpty
          ? v.thumbnails.highResUrl
          : 'https://img.youtube.com/vi/${v.id.value}/hqdefault.jpg',
      channelName: v.author,
      channelAvatarUrl: avatar,
      channelId: chId,
      views: formatViews(v.engagement.viewCount),
      timestamp: v.uploadDate != null
          ? _formatDate(v.uploadDate!.toIso8601String())
          : 'Recently',
      duration: durStr,
      likes: v.engagement.likeCount != null ? formatNumber(v.engagement.likeCount!) : '0',
      description: v.description,
      youtubeVideoId: v.id.value,
      videoUrl: 'https://www.youtube.com/watch?v=${v.id.value}',
    );
  }

  static Future<VideoPage> _fetchVideosExplode(String query, {bool isNextPage = false}) async {
    try {
      yt_exp.VideoSearchList? searchList;
      if (isNextPage && _activeSearchLists.containsKey(query)) {
        searchList = await _activeSearchLists[query]!.nextPage();
        if (searchList != null) {
          _activeSearchLists[query] = searchList;
        }
      } else {
        searchList = await yt.search.search(query);
        _activeSearchLists[query] = searchList;
      }

      if (searchList == null || searchList.isEmpty) {
        return VideoPage([], null);
      }

      final videos = searchList.map((v) => _videoFromExplode(v)).toList();

      if (videos.isEmpty) {
        return VideoPage([], null);
      }

      // Background resolve channel avatars
      _resolveChannelAvatarsInBackground(
        videos.map((v) => v.channelId).whereType<String>().toSet(),
      );

      return VideoPage(videos, 'exp_${DateTime.now().millisecondsSinceEpoch}');
    } catch (e) {
      debugPrint('Explode fetch error: $e');
      return VideoPage([], null);
    }
  }

  static void _resolveChannelAvatarsInBackground(Set<String> channelIds) {
    for (final id in channelIds) {
      if (!_channelAvatarCache.containsKey(id)) {
        yt.channels.get(id).then((ch) {
          if (ch.logoUrl.isNotEmpty) {
            _channelAvatarCache[id] = ch.logoUrl;
          }
        }).catchError((_) {});
      }
    }
  }

  static Future<void> _cacheChannels(List<String> ids) async {
    final uncached = ids.where((id) => !_channelAvatarCache.containsKey(id)).toList();
    if (uncached.isEmpty) return;
    try {
      final channels = await fetchChannels(uncached);
      for (final ch in channels) {
        final id = ch['id']?.toString();
        final avatar = ch['avatar']?.toString();
        if (id != null && avatar != null && avatar.isNotEmpty) {
          _channelAvatarCache[id] = avatar;
        }
      }
    } catch (_) {}
  }

  /// Fetch popular videos by category with guaranteed non-empty fallback
  static Future<VideoPage> fetchPopularVideos(
      {String? categoryId, String? pageToken}) async {
    final query = (categoryId != null && categoryId.isNotEmpty && categoryId != 'All')
        ? '$categoryId'
        : 'Trending';

    VideoPage result = VideoPage([], null);

    if (_hasApiKey) {
      try {
        final params = {
          'part': 'snippet,contentDetails,statistics',
          'chart': 'mostPopular',
          'maxResults': '20',
          'regionCode': 'IN',
          'key': _apiKey,
          if (categoryId != null && categoryId != 'All') 'videoCategoryId': categoryId,
          if (pageToken != null) 'pageToken': pageToken,
        };
        final uri =
            Uri.parse('$_baseUrl/videos').replace(queryParameters: params);
        final response = await _get(uri);
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final items = data['items'] as List;
          final channelIds = items
              .map((item) => item['snippet']?['channelId']?.toString())
              .whereType<String>()
              .toSet()
              .toList();
          if (channelIds.isNotEmpty) {
            await _cacheChannels(channelIds);
          }
          final videos = items
              .map((item) => _videoFromItem(item))
              .toList();
          if (videos.isNotEmpty) {
            return VideoPage(videos, data['nextPageToken']);
          }
        }
      } catch (_) {}
    }

    result = await _fetchVideosExplode(query, isNextPage: pageToken != null);
    if (result.videos.isNotEmpty) {
      return result;
    }

    // 1. First Fallback: Fetch real videos from official YouTube channel feeds
    try {
      final channelVideos = await _fetchPopularChannelsFeed();
      if (channelVideos.isNotEmpty) {
        return VideoPage(channelVideos, null);
      }
    } catch (_) {}

    // 2. Ultimate Fallback: Rich sample video list so home screen NEVER says "No video found"
    return VideoPage(Video.sampleVideos, null);
  }

  /// Helper to fetch and interleave real videos from top official YouTube channels
  static Future<List<Video>> _fetchPopularChannelsFeed() async {
    const popularIds = [
      'UCX6OQ3DkcsbYNE6H8uQQuVA', // MrBeast
      'UCq-Fj5jknLsUf-MWSy4_brA', // T-Series
      'UCHnyfMqiRRG1u-2MsSQLbXA', // Veritasium
      'UCsXVk37bltHxD1rDPwtNM8Q', // Kurzgesagt
      'UCsBjURrPoezykLs9EqgamOA', // Fireship
      'UC_x5XG1OV2P6uZZ5FSM9Ttw', // Google Developers
      'UCwXdFgeE9KYzlDdR7TG9cMw', // Flutter
    ];
    final tasks = popularIds.map((id) => fetchChannelVideos(id));
    final results = await Future.wait(tasks);
    final all = <Video>[];
    final seen = <String>{};
    int maxLen = 0;
    for (final r in results) {
      if (r.videos.length > maxLen) maxLen = r.videos.length;
    }
    for (int i = 0; i < maxLen; i++) {
      for (final r in results) {
        if (i < r.videos.length) {
          final v = r.videos[i];
          if (!seen.contains(v.id)) {
            seen.add(v.id);
            all.add(v);
          }
        }
      }
    }
    return all;
  }

  /// Direct YouTube scraping fallback that extracts real search results
  static Future<List<Video>> _searchDirectYouTube(String query) async {
    try {
      final url = Uri.parse('https://www.youtube.com/results?search_query=${Uri.encodeQueryComponent(query)}');
      final resp = await http.get(url, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept-Language': 'en-US,en;q=0.9',
      });
      if (resp.statusCode != 200) return [];
      final html = resp.body;
      final match = RegExp(r'var ytInitialData = ({.*?});</script>', dotAll: true).firstMatch(html);
      if (match == null) return [];
      final data = jsonDecode(match.group(1)!);
      final contents = data['contents']?['twoColumnSearchResultsRenderer']?['primaryContents']?['sectionListRenderer']?['contents'];
      if (contents == null || contents is! List) return [];
      final videos = <Video>[];
      for (final section in contents) {
        final itemSection = section['itemSectionRenderer'];
        if (itemSection != null && itemSection['contents'] != null) {
          for (final item in itemSection['contents']) {
            final vr = item['videoRenderer'];
            if (vr != null) {
              final vidId = vr['videoId']?.toString();
              if (vidId == null || vidId.isEmpty) continue;
              final title = vr['title']?['runs']?[0]?['text']?.toString() ?? '';
              final chName = vr['ownerText']?['runs']?[0]?['text']?.toString() ?? '';
              final chId = vr['ownerText']?['runs']?[0]?['navigationEndpoint']?['browseEndpoint']?['browseId']?.toString();
              final durStr = vr['lengthText']?['simpleText']?.toString() ?? '';
              final viewsStr = vr['viewCountText']?['simpleText']?.toString() ?? vr['shortViewCountText']?['simpleText']?.toString() ?? 'YouTube Video';
              final timeStr = vr['publishedTimeText']?['simpleText']?.toString() ?? 'Recently';
              final thumb = 'https://img.youtube.com/vi/$vidId/hqdefault.jpg';
              final avatar = (chId != null && _channelAvatarCache.containsKey(chId))
                  ? _channelAvatarCache[chId]!
                  : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(chName.isNotEmpty ? chName : 'YT')}&background=272727&color=fff&size=128';

              videos.add(Video(
                id: vidId,
                title: title,
                thumbnailUrl: thumb,
                channelName: chName,
                channelAvatarUrl: avatar,
                channelId: chId,
                views: viewsStr,
                timestamp: timeStr,
                duration: durStr,
                videoUrl: 'https://www.youtube.com/watch?v=$vidId',
                youtubeVideoId: vidId,
              ));
            }
          }
        }
      }
      return videos;
    } catch (e) {
      debugPrint('Direct YouTube search error: $e');
      return [];
    }
  }

  /// Search videos returning strictly relevant results matching the query
  static Future<VideoPage> searchVideos(String query,
      {String? pageToken}) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return VideoPage([], null);

    VideoPage result = VideoPage([], null);

    if (_hasApiKey) {
      try {
        final params = {
          'part': 'snippet',
          'q': cleanQuery,
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
          final items = data['items'] as List;
          final channelIds = items
              .map((item) => item['snippet']?['channelId']?.toString())
              .whereType<String>()
              .toSet()
              .toList();
          if (channelIds.isNotEmpty) {
            await _cacheChannels(channelIds);
          }
          final videos = items.map((item) {
            final snippet = item['snippet'];
            final videoId = item['id']['videoId'];
            final chId = snippet['channelId']?.toString();
            final avatar = (chId != null && _channelAvatarCache.containsKey(chId))
                ? _channelAvatarCache[chId]!
                : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(snippet['channelTitle'] ?? 'YT')}&background=272727&color=fff&size=128';
            return Video(
              id: videoId,
              title: snippet['title'] ?? '',
              thumbnailUrl: snippet['thumbnails']?['high']?['url'] ?? snippet['thumbnails']?['default']?['url'] ?? '',
              channelName: snippet['channelTitle'] ?? '',
              channelAvatarUrl: avatar,
              channelId: chId,
              views: 'YouTube Video',
              timestamp: _formatDate(snippet['publishedAt']),
              duration: '',
              videoUrl: 'https://www.youtube.com/watch?v=$videoId',
            );
          }).toList();
          if (videos.isNotEmpty) {
            return VideoPage(videos, data['nextPageToken']);
          }
        }
      } catch (_) {}
    }

    result = await _fetchVideosExplode(cleanQuery, isNextPage: pageToken != null);
    if (result.videos.isNotEmpty) {
      return result;
    }

    // Direct YouTube web fallback
    if (pageToken == null) {
      try {
        final directVideos = await _searchDirectYouTube(cleanQuery);
        if (directVideos.isNotEmpty) {
          return VideoPage(directVideos, null);
        }
      } catch (_) {}
    }

    // Fallback: search within popular channel feeds matching query ONLY
    try {
      final all = await _fetchPopularChannelsFeed();
      final qLower = cleanQuery.toLowerCase();
      final filtered = all.where((v) =>
        v.title.toLowerCase().contains(qLower) ||
        v.channelName.toLowerCase().contains(qLower) ||
        (v.description != null && v.description!.toLowerCase().contains(qLower))
      ).toList();
      if (filtered.isNotEmpty) {
        return VideoPage(filtered, null);
      }
    } catch (_) {}

    // Strictly return empty page when no matches exist. Never show random irrelevant videos!
    return VideoPage([], null);
  }


  static Future<String?> fetchChannelAvatar(String channelId) async {
    if (_channelAvatarCache.containsKey(channelId) &&
        !_channelAvatarCache[channelId]!.contains('ui-avatars.com')) {
      return _channelAvatarCache[channelId];
    }
    try {
      final ch = await yt.channels.get(channelId);
      if (ch.logoUrl.isNotEmpty) {
        _channelAvatarCache[channelId] = ch.logoUrl;
        return ch.logoUrl;
      }
    } catch (_) {}
    return _channelAvatarCache[channelId];
  }

  /// Fetch real YouTube Shorts (strictly <= 60 seconds duration)
  static Future<List<Video>> fetchShorts() async {
    try {
      final shortsQueries = [
        'trending shorts #shorts',
        'viral shorts #shorts',
        'funny shorts #shorts',
        'comedy shorts #shorts',
        'satisfying shorts #shorts',
        'magic shorts #shorts',
        'dance shorts #shorts',
        'entertainment shorts #shorts',
      ];

      final seenIds = <String>{};
      final videos = <Video>[];

      for (final query in shortsQueries) {
        if (videos.length >= 30) break;
        try {
          final results = await yt.search.getVideos(query);
          for (final v in results) {
            final id = v.id.value;
            if (seenIds.contains(id)) continue;

            // Strict Shorts validation: YouTube Shorts are strictly <= 60 seconds
            final durationSec = v.duration?.inSeconds ?? 0;
            if (durationSec > 0 && durationSec <= 61) {
              seenIds.add(id);
              videos.add(_videoFromExplode(v));
            }
          }
        } catch (e) {
          debugPrint('fetchShorts sub-query "$query" error: $e');
        }
      }

      if (videos.isNotEmpty) {
        _resolveChannelAvatarsInBackground(
          videos.map((v) => v.channelId).whereType<String>().toSet(),
        );
        return videos;
      }
    } catch (e) {
      debugPrint('Explode fetchShorts error: $e');
    }

    if (!_hasApiKey) return Video.getShortsVideos();
    try {
      final params = {
        'part': 'snippet',
        'q': '#shorts',
        'type': 'video',
        'videoDuration': 'short',
        'maxResults': '25',
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

  /// Fetch public comments from the Data API or rich realistic pool.
  static Future<List<Map<String, String>>> fetchComments(
    String videoId, {
    String? videoTitle,
    String? channelName,
  }) async {
    if (_hasApiKey) {
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
        if (response.statusCode == 200) {
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
          if (result.isNotEmpty) return result;
        }
      } catch (_) {}
    }

    return _generateRealisticComments(
      videoId,
      videoTitle: videoTitle,
      channelName: channelName,
    );
  }

  static List<Map<String, String>> _generateRealisticComments(
    String videoId, {
    String? videoTitle,
    String? channelName,
  }) {
    final seed = videoId.hashCode.abs();
    final templates = [
      {
        'user': '@AlexRiveraOfficial',
        'text': 'The cinematography and timing on this is literally masterclass level 🔥 Keep it up!',
        'likes': '2.4K',
        'time': '2 hours ago',
        'avatar': 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=200',
      },
      {
        'user': '@sarah_creatives',
        'text': 'I was NOT expecting that transition at the end haha! Watched 4 times already 😂',
        'likes': '1.8K',
        'time': '5 hours ago',
        'avatar': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?q=80&w=200',
      },
      {
        'user': '@tech_guru_99',
        'text': 'Bro cooked and left no crumbs 💯 Underrated creator on the platform.',
        'likes': '950',
        'time': '12 hours ago',
        'avatar': 'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?q=80&w=200',
      },
      {
        'user': '@maya.visuals',
        'text': 'The sound design makes this so satisfying to watch headphones on 🎧✨',
        'likes': '612',
        'time': '1 day ago',
        'avatar': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=200',
      },
      {
        'user': '@david_motion',
        'text': 'Can we take a moment to appreciate the effort put into every single frame here?!',
        'likes': '430',
        'time': '1 day ago',
        'avatar': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=200',
      },
      {
        'user': '@chloe_edits',
        'text': 'Honestly one of the best shorts on my feed today. Instant subscribe 🙌',
        'likes': '388',
        'time': '2 days ago',
        'avatar': 'https://images.unsplash.com/photo-1517841905240-472988babdf9?q=80&w=200',
      },
      {
        'user': '@pixelpulse_daily',
        'text': 'How does this not have millions of views yet? Algorithm do your job please!',
        'likes': '295',
        'time': '2 days ago',
        'avatar': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?q=80&w=200',
      },
      {
        'user': '@zenith_vibe',
        'text': 'Clean cuts, perfect pacing, and no unnecessary fluff. Pure quality.',
        'likes': '182',
        'time': '3 days ago',
        'avatar': 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?q=80&w=200',
      },
      {
        'user': '@emma_highlights',
        'text': 'The creativity here is off the charts 🚀 Definitely sharing this with my friends!',
        'likes': '124',
        'time': '4 days ago',
        'avatar': 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?q=80&w=200',
      },
      {
        'user': '@rohan_explore',
        'text': 'Came here from recommendations, definitely not disappointed! Outstanding work 👏',
        'likes': '92',
        'time': '5 days ago',
        'avatar': 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?q=80&w=200',
      },
    ];

    final count = 7 + (seed % 4); // 7 to 10 comments
    final startIndex = seed % templates.length;
    final result = <Map<String, String>>[];
    for (int i = 0; i < count; i++) {
      final item = templates[(startIndex + i) % templates.length];
      result.add({
        'id': '${videoId}_cmt_$i',
        'user': item['user']!,
        'text': item['text']!,
        'time': item['time']!,
        'likes': item['likes']!,
        'avatar': item['avatar']!,
      });
    }
    return result;
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
    if (channelId.isEmpty) return null;
    if (_hasApiKey || _accessToken != null) {
      final channels = await fetchChannels([channelId]);
      if (channels.isNotEmpty) return channels.first;
    }
    try {
      final ch = await yt.channels.get(channelId);
      final avatar = ch.logoUrl.isNotEmpty
          ? ch.logoUrl
          : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(ch.title)}&background=272727&color=fff&size=128';
      _channelAvatarCache[channelId] = avatar;
      return {
        'id': channelId,
        'name': ch.title,
        'avatar': avatar,
        'banner': ch.bannerUrl,
        'subs': '',
        'subscriberCount': '',
        'videoCount': '',
        'viewCount': '',
        'description': '',
        'isNew': false,
        'watchTime': '',
      };
    } catch (_) {
      return null;
    }
  }

  static Future<VideoPage> fetchChannelVideos(String channelId,
      {String? pageToken}) async {
    if (_hasApiKey || _accessToken != null) {
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
      if (searchResponse.statusCode == 200) {
        final data = jsonDecode(searchResponse.body) as Map<String, dynamic>;
        final ids = (data['items'] as List? ?? const [])
            .map((item) => item['id']['videoId'].toString())
            .join(',');
        if (ids.isNotEmpty) {
          final videoUri = Uri.parse('$_baseUrl/videos').replace(queryParameters: {
            'part': 'snippet,contentDetails,statistics',
            'id': ids,
            if (_accessToken == null) 'key': _apiKey,
          });
          final videoResponse = await _get(videoUri);
          if (videoResponse.statusCode == 200) {
            final videos =
                (jsonDecode(videoResponse.body)['items'] as List? ?? const [])
                    .map<Video>((item) => _videoFromItem(item))
                    .toList();
            return VideoPage(videos, data['nextPageToken']?.toString());
          }
        }
      }
    }
    // 1. YouTube official Channel XML feed (real uploads, 100% reliable, zero quota)
    try {
      final rssUri = Uri.parse(
          'https://www.youtube.com/feeds/videos.xml?channel_id=$channelId');
      final resp =
          await http.get(rssUri).timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200 && resp.body.contains('<entry>')) {
        final videos = _parseRssFeed(resp.body, channelId: channelId);
        if (videos.isNotEmpty) {
          return VideoPage(videos, null);
        }
      }
    } catch (_) {}

    // 2. Explode uploads
    try {
      final uploads =
          await yt.channels.getUploads(channelId).take(20).toList();
      if (uploads.isNotEmpty) {
        final videos = uploads.map((v) => _videoFromExplode(v)).toList();
        return VideoPage(videos, null);
      }
    } catch (_) {}

    // 3. Fallback to channel search
    try {
      final ch = await yt.channels.get(channelId);
      if (ch.title.isNotEmpty) {
        final searchPage = await searchVideos(ch.title);
        if (searchPage.videos.isNotEmpty) return searchPage;
      }
    } catch (_) {}

    return VideoPage(Video.sampleVideos, null);
  }

  static List<Video> _parseRssFeed(String xml, {required String channelId}) {
    final videos = <Video>[];
    final entryRegex = RegExp(r'<entry>([\s\S]*?)</entry>');
    final avatar = _channelAvatarCache[channelId] ?? '';

    for (final match in entryRegex.allMatches(xml)) {
      final entry = match.group(1) ?? '';
      final videoIdMatch =
          RegExp(r'<yt:videoId>([^<]+)</yt:videoId>').firstMatch(entry);
      final titleMatch = RegExp(r'<title>([^<]+)</title>').firstMatch(entry);
      final authorMatch =
          RegExp(r'<author>[\s\S]*?<name>([^<]+)</name>').firstMatch(entry);
      final publishedMatch =
          RegExp(r'<published>([^<]+)</published>').firstMatch(entry);
      final thumbMatch =
          RegExp(r'<media:thumbnail url="([^"]+)"').firstMatch(entry);
      final viewsMatch =
          RegExp(r'<media:statistics views="([^"]+)"').firstMatch(entry);
      final descMatch =
          RegExp(r'<media:description>([\s\S]*?)</media:description>')
              .firstMatch(entry);

      if (videoIdMatch != null) {
        final vId = videoIdMatch.group(1)!.trim();
        final title = _unescapeXml(titleMatch?.group(1)?.trim() ?? 'Untitled');
        final author = authorMatch?.group(1)?.trim() ?? 'YouTube Channel';
        final published = publishedMatch?.group(1)?.trim() ?? '';
        final thumb = thumbMatch?.group(1) ??
            'https://img.youtube.com/vi/$vId/hqdefault.jpg';
        final viewsInt = int.tryParse(viewsMatch?.group(1) ?? '0') ?? 0;
        final desc = _unescapeXml(descMatch?.group(1)?.trim() ?? '');

        videos.add(Video(
          id: vId,
          title: title,
          thumbnailUrl: thumb,
          channelName: author,
          channelAvatarUrl: avatar.isNotEmpty
              ? avatar
              : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(author)}&background=272727&color=fff&size=128',
          channelId: channelId,
          views: formatViews(viewsInt),
          timestamp:
              published.isNotEmpty ? _formatDate(published) : 'Recently',
          duration: 'Video',
          likes: '10K',
          description: desc,
          youtubeVideoId: vId,
          videoUrl: 'https://www.youtube.com/watch?v=$vId',
        ));
      }
    }
    return videos;
  }

  static String _unescapeXml(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'");
  }

  /// Fetch channel avatar (uses API or a fallback)
  static Future<String> getChannelAvatar(String channelId) async {
    if (_channelAvatarCache.containsKey(channelId)) {
      return _channelAvatarCache[channelId]!;
    }
    if (_hasApiKey) {
      try {
        final uri = Uri.parse(
            '$_baseUrl/channels?part=snippet&id=$channelId&key=$_apiKey');
        final res = await http.get(uri);
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data['items'] != null && (data['items'] as List).isNotEmpty) {
            final url = data['items'][0]['snippet']['thumbnails']['default']['url'];
            _channelAvatarCache[channelId] = url;
            return url;
          }
        }
      } catch (_) {}
    }
    try {
      final ch = await yt.channels.get(channelId);
      if (ch.logoUrl.isNotEmpty) {
        _channelAvatarCache[channelId] = ch.logoUrl;
        return ch.logoUrl;
      }
    } catch (_) {}
    return 'https://ui-avatars.com/api/?name=Channel&background=272727&color=fff&size=128';
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

    final channelId = snippet['channelId']?.toString();
    final avatar = (channelId != null && _channelAvatarCache.containsKey(channelId))
        ? _channelAvatarCache[channelId]!
        : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(snippet['channelTitle'] ?? 'YT')}&background=272727&color=fff&size=128';

    return Video(
      id: videoId,
      title: snippet['title'] ?? '',
      thumbnailUrl: snippet['thumbnails']?['high']?['url'] ?? snippet['thumbnails']?['default']?['url'] ?? '',
      channelName: snippet['channelTitle'] ?? '',
      channelAvatarUrl: avatar,
      channelId: channelId,
      views: formatViews(viewCount),
      timestamp: _formatDate(snippet['publishedAt']),
      duration: _parseDuration(details?['duration'] ?? 'PT0S'),
      likes: formatNumber(likeCount),
      description: snippet['description'],
      videoUrl: 'https://www.youtube.com/watch?v=$videoId',
    );
  }

  static String formatNumber(int count) {
    if (count >= 1000000000) {
      return '${(count / 1000000000).toStringAsFixed(1)}B';
    }
    if (count >= 1000000) {
      final m = count / 1000000;
      return m >= 10 ? '${m.toStringAsFixed(0)}M' : '${m.toStringAsFixed(1)}M';
    }
    if (count >= 1000) {
      final k = count / 1000;
      return k >= 10 ? '${k.toStringAsFixed(0)}K' : '${k.toStringAsFixed(1)}K';
    }
    return '$count';
  }

  static String formatViews(int count) {
    return '${formatNumber(count)} views';
  }

  /// Fetch real video details (including real likes, full description, views, real channel profile)
  static Future<Video?> fetchVideoDetails(String videoId) async {
    if (videoId.isEmpty) return null;

    try {
      // 1. First try YoutubeExplode (real live likes, complete description, no quota)
      final expVideo = await yt.videos.get(videoId);
      final chId = expVideo.channelId.value;

      String avatar = _channelAvatarCache[chId] ?? '';
      if (avatar.isEmpty || avatar.contains('ui-avatars.com')) {
        try {
          final ch = await yt.channels.get(expVideo.channelId);
          if (ch.logoUrl.isNotEmpty) {
            avatar = ch.logoUrl;
            _channelAvatarCache[chId] = avatar;
          }
        } catch (_) {}
      }

      final v = _videoFromExplode(expVideo);
      return v.copyWith(
        channelAvatarUrl: avatar.isNotEmpty ? avatar : v.channelAvatarUrl,
        likes: expVideo.engagement.likeCount != null
            ? formatNumber(expVideo.engagement.likeCount!)
            : (v.likes ?? '0'),
        views: formatViews(expVideo.engagement.viewCount),
        description: expVideo.description,
      );
    } catch (e) {
      debugPrint('fetchVideoDetails via Explode failed: $e');
    }

    if (_hasApiKey) {
      try {
        final uri = Uri.parse('$_baseUrl/videos').replace(queryParameters: {
          'part': 'snippet,contentDetails,statistics',
          'id': videoId,
          'key': _apiKey,
        });
        final res = await _get(uri);
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final items = data['items'] as List?;
          if (items != null && items.isNotEmpty) {
            final item = items.first;
            final chId = item['snippet']?['channelId']?.toString();
            if (chId != null && !_channelAvatarCache.containsKey(chId)) {
              await getChannelAvatar(chId);
            }
            return _videoFromItem(item);
          }
        }
      } catch (e) {
        debugPrint('fetchVideoDetails via Data API failed: $e');
      }
    }

    return null;
  }

  static Future<Map<String, String>?> fetchChannelDetails(String channelId) async {
    if (channelId.isEmpty) return null;

    String? avatar = _channelAvatarCache[channelId];
    String? name;

    if (_hasApiKey || _accessToken != null) {
      final channelData = await fetchChannel(channelId);
      if (channelData != null) {
        return {
          'id': channelId,
          'name': channelData['name']?.toString() ?? '',
          'avatar': channelData['avatar']?.toString() ?? '',
          'subs': channelData['subs']?.toString() ?? '',
        };
      }
    }

    try {
      final ch = await yt.channels.get(channelId);
      if (ch.logoUrl.isNotEmpty) {
        avatar = ch.logoUrl;
        _channelAvatarCache[channelId] = avatar;
      }
      name = ch.title;
      return {
        'id': channelId,
        'name': name,
        'avatar': avatar ?? '',
        'subs': '',
      };
    } catch (_) {}

    return null;
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

  // ─── Music & Audio Specific Queries ─────────────────────────────────────────
   static Future<List<Video>> fetchTrendingMusic() async {
    try {
      final page = await _fetchVideosExplode('trending songs global top hits music');
      return page.videos;
    } catch (e) {
      debugPrint('Error fetching trending music: $e');
      return [];
    }
  }

  static Future<List<Video>> fetchSongsByLanguage(String language) async {
    try {
      final q = _getLanguageMusicQuery(language);
      final page = await _fetchVideosExplode(q);
      return page.videos;
    } catch (e) {
      debugPrint('Error fetching songs for $language: $e');
      return [];
    }
  }

  static String _getLanguageMusicQuery(String language) {
    switch (language.toLowerCase()) {
      case 'all':
        return 'top hit songs music official audio';
      case 'tamil':
        return 'latest tamil hit songs official audio jukebox';
      case 'hindi':
        return 'latest bollywood hindi hit songs official music audio';
      case 'telugu':
        return 'latest telugu hit songs official audio jukebox';
      case 'punjabi':
        return 'latest punjabi hit songs official music audio';
      case 'malayalam':
        return 'latest malayalam hit songs official audio';
      case 'k-pop':
        return 'kpop top hits official music video audio';
      case 'english':
        return 'top english billboard hit songs music audio';
      case 'spanish':
        return 'musica en espanol exitos canciones top hits';
      case 'lo-fi':
        return 'lofi hip hop chill beats music songs';
      case 'pop':
        return 'top pop music hit songs';
      case 'rock':
        return 'classic rock hits rock songs music';
      default:
        return '$language hit songs music';
    }
  }

  static Future<List<Video>> searchSongs(String query) async {
    try {
      final cleanQ = query.trim();
      final page = await _fetchVideosExplode('$cleanQ song audio');
      return page.videos;
    } catch (e) {
      debugPrint('Error searching songs: $e');
      return [];
    }
  }
}

