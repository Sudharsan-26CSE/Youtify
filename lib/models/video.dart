class Video {
  final String id;
  final String title;
  final String thumbnailUrl;
  final String channelName;
  final String channelAvatarUrl;
  final String views;
  final String timestamp;
  final String duration;
  final bool isLive;
  final String? videoUrl;
  final String? description;
  final String? likes;
  final String category;
  // YouTube video ID for in-app playback via youtube_player_iframe
  final String? youtubeVideoId;

  Video({
    required this.id,
    required this.title,
    required this.thumbnailUrl,
    required this.channelName,
    required this.channelAvatarUrl,
    required this.views,
    required this.timestamp,
    required this.duration,
    this.isLive = false,
    this.videoUrl,
    this.description,
    this.likes,
    this.category = 'All',
    this.youtubeVideoId,
  });

  /// Returns the YouTube video ID from either youtubeVideoId field or parsed from videoUrl
  String? get resolvedYoutubeId {
    if (youtubeVideoId != null && youtubeVideoId!.isNotEmpty) return youtubeVideoId;
    if (videoUrl == null) return null;
    final uri = Uri.tryParse(videoUrl!);
    if (uri == null) return null;
    // https://www.youtube.com/watch?v=ID
    if (uri.queryParameters.containsKey('v')) return uri.queryParameters['v'];
    // https://youtu.be/ID
    if (uri.host == 'youtu.be') return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    // https://youtube.com/shorts/ID
    if (uri.pathSegments.contains('shorts') && uri.pathSegments.length > 1) {
      return uri.pathSegments[uri.pathSegments.indexOf('shorts') + 1];
    }
    return null;
  }

  bool get isYouTubeVideo => resolvedYoutubeId != null;

  static List<Video> sampleVideos = [
    Video(
      id: 'l-POWT87vH8',
      title: 'Flutter in 100 Seconds',
      thumbnailUrl: 'https://img.youtube.com/vi/l-POWT87vH8/hqdefault.jpg',
      channelName: 'Fireship',
      channelAvatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=200&auto=format&fit=crop',
      views: '125K views',
      timestamp: '2 days ago',
      duration: '02:42',
      likes: '4.2K',
      category: 'Flutter',
      description: 'Flutter in 100 seconds. Learn the basics of Flutter and Dart.',
      youtubeVideoId: 'l-POWT87vH8',
    ),
    Video(
      id: 'lkF0GPEH2NU',
      title: 'SafeArea (Flutter Widget of the Week)',
      thumbnailUrl: 'https://img.youtube.com/vi/lkF0GPEH2NU/hqdefault.jpg',
      channelName: 'Flutter',
      channelAvatarUrl: 'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?q=80&w=200&auto=format&fit=crop',
      views: '48K views',
      timestamp: '1 week ago',
      duration: '01:15',
      likes: '1.8K',
      category: 'Flutter',
      description: 'SafeArea is a widget that inserts its child by sufficient padding to avoid intrusions by the operating system.',
      youtubeVideoId: 'lkF0GPEH2NU',
    ),
    Video(
      id: 'YE7VzlLtp-4',
      title: 'Big Buck Bunny 60fps 4K - Official Blender Foundation Short Film',
      thumbnailUrl: 'https://img.youtube.com/vi/YE7VzlLtp-4/hqdefault.jpg',
      channelName: 'Blender',
      channelAvatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?q=80&w=200&auto=format&fit=crop',
      views: '3.2M views',
      timestamp: '10 years ago',
      duration: '10:34',
      isLive: false,
      likes: '18K',
      category: 'Entertainment',
      description: 'Big Buck Bunny tells the story of a giant rabbit with a heart bigger than himself.',
      youtubeVideoId: 'YE7VzlLtp-4',
    ),
    Video(
      id: 'TLkA0RELQ1g',
      title: 'Elephants Dream - Open Source Short Film',
      thumbnailUrl: 'https://img.youtube.com/vi/TLkA0RELQ1g/hqdefault.jpg',
      channelName: 'Blender',
      channelAvatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=200&auto=format&fit=crop',
      views: '89K views',
      timestamp: '15 years ago',
      duration: '10:53',
      likes: '3.1K',
      category: 'Entertainment',
      description: 'Elephants Dream is the world’s first open movie, made entirely with open source graphics software.',
      youtubeVideoId: 'TLkA0RELQ1g',
    ),
    Video(
      id: 'eRsGyueVLvQ',
      title: 'Sintel - Third Open Movie by Blender Foundation',
      thumbnailUrl: 'https://img.youtube.com/vi/eRsGyueVLvQ/hqdefault.jpg',
      channelName: 'Blender',
      channelAvatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?q=80&w=200&auto=format&fit=crop',
      views: '412K views',
      timestamp: '12 years ago',
      duration: '14:48',
      likes: '12K',
      category: 'Entertainment',
      description: 'Sintel is an independently produced short film, initiated by the Blender Foundation.',
      youtubeVideoId: 'eRsGyueVLvQ',
    ),
    Video(
      id: 'p7KpmQ03v4c',
      title: 'Flutter in 2024: What\'s New?',
      thumbnailUrl: 'https://img.youtube.com/vi/p7KpmQ03v4c/hqdefault.jpg',
      channelName: 'Flutter',
      channelAvatarUrl: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?q=80&w=200&auto=format&fit=crop',
      views: '67K views',
      timestamp: '2 weeks ago',
      duration: '12:18',
      likes: '2.4K',
      category: 'Programming',
      description: 'Complete guide to the new Flutter features.',
      youtubeVideoId: 'p7KpmQ03v4c',
    ),
  ];

  static List<Video> getShortsVideos() => [
    Video(
      id: 'gDkbMyCTwLg',
      title: 'Flutter Shorts: The AnimatedContainer',
      thumbnailUrl: 'https://img.youtube.com/vi/gDkbMyCTwLg/hqdefault.jpg',
      channelName: 'CodeMaster',
      channelAvatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=200&auto=format&fit=crop',
      views: '2.1M views',
      timestamp: '3 days ago',
      duration: '0:45',
      likes: '45.2K',
      youtubeVideoId: 'gDkbMyCTwLg',
    ),
    Video(
      id: '15zG04yDq-k',
      title: 'Flutter Shorts: The Wrap Widget',
      thumbnailUrl: 'https://img.youtube.com/vi/15zG04yDq-k/hqdefault.jpg',
      channelName: 'FlutterDevs',
      channelAvatarUrl: 'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?q=80&w=200&auto=format&fit=crop',
      views: '980K views',
      timestamp: '1 week ago',
      duration: '0:58',
      likes: '128K',
      youtubeVideoId: '15zG04yDq-k',
    ),
    Video(
      id: 'EiEAxx5BGNM',
      title: 'Coding at 3AM hits different 🌙 #dev #coding #programmer',
      thumbnailUrl: 'https://img.youtube.com/vi/EiEAxx5BGNM/hqdefault.jpg',
      channelName: 'DevLife',
      channelAvatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=200&auto=format&fit=crop',
      views: '1.4M views',
      timestamp: '2 days ago',
      duration: '0:32',
      likes: '89K',
      youtubeVideoId: 'EiEAxx5BGNM',
    ),
  ];
}
