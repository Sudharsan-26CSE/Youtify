import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide Video;
import '../models/video.dart';
import '../services/youtube_service.dart';
import '../services/download_service.dart';
import '../services/user_data_service.dart';
import '../services/subscription_service.dart';
import '../widgets/video_card.dart';
import '../widgets/skeleton_loader.dart';
import 'downloads_screen.dart';
import 'channel_profile_screen.dart';
import '../main.dart';
import '../utils/page_transitions.dart';
import 'package:url_launcher/url_launcher.dart';

enum VideoPlayerPopup {
  description,
  comments,
  quality,
  settings,
  speed,
  share,
}

class VideoPlayerScreen extends StatefulWidget {
  final Video video;
  const VideoPlayerScreen({super.key, required this.video});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen>
    with TickerProviderStateMixin {
  VideoPlayerController? _videoPlayerController;
  final _yt = YouTubeService.yt;
  late Video _currentVideo;
  String? _channelSubs;
  bool _isLoadingDetails = true;
  VideoPlayerPopup? _activePopup;
  late AnimationController _popupCtrl;
  late Animation<double> _popupFadeAnim;
  late Animation<Offset> _popupSlideAnim;
  bool _isLiked = false;
  bool _isDisliked = false;
  bool _hasError = false;
  bool _isFullscreen = false;
  bool _isAudioOnly = false;
  double _playbackSpeed = 1.0;
  String _selectedQuality = 'Auto (1080p)';

  late AnimationController _likeAnim;
  late AnimationController _contentAnim;
  late Animation<double> _contentFade;
  late Animation<Offset> _contentSlide;

  final _commentController = TextEditingController();
  List<Map<String, String>> _comments = [];
  bool _isLoadingComments = true;

  List<Video> _relatedVideos = [];
  bool _isLoadingRelated = true;

  @override
  void initState() {
    super.initState();
    _currentVideo = widget.video;
    _isLiked = UserDataService.isLiked(widget.video.id);
    UserDataService.addToHistory(widget.video);

    _likeAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _contentAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
      ..forward();
    _contentFade = CurvedAnimation(parent: _contentAnim, curve: Curves.easeOut);
    _contentSlide =
        Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
            CurvedAnimation(parent: _contentAnim, curve: Curves.easeOutCubic));

    _popupCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _popupFadeAnim = CurvedAnimation(parent: _popupCtrl, curve: Curves.easeOut);
    _popupSlideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _popupCtrl, curve: Curves.easeOutCubic));

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    final resolvedId = widget.video.resolvedYoutubeId ?? widget.video.id;
    _initPlayer(resolvedId);
    _loadVideoDetails(resolvedId);
    _loadComments(resolvedId);
    _loadRating(resolvedId);
    _loadRelatedVideos();
  }

  @override
  void didUpdateWidget(VideoPlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.id != widget.video.id) {
      _currentVideo = widget.video;
      _isLiked = UserDataService.isLiked(widget.video.id);
      _isDisliked = false;
      final resolvedId = widget.video.resolvedYoutubeId ?? widget.video.id;
      _initPlayer(resolvedId);
      _loadVideoDetails(resolvedId);
      _loadComments(resolvedId);
      _loadRating(resolvedId);
      _loadRelatedVideos();
    }
  }

  Future<void> _loadVideoDetails(String id) async {
    try {
      final details = await YouTubeService.fetchVideoDetails(id);
      if (details != null && mounted) {
        setState(() {
          _currentVideo = details;
          _isLoadingDetails = false;
        });
      }
      final chId = details?.channelId ?? _currentVideo.channelId;
      if (chId != null && chId.isNotEmpty) {
        final chInfo = await YouTubeService.fetchChannelDetails(chId);
        if (chInfo != null && mounted) {
          setState(() {
            if (chInfo['avatar'] != null && chInfo['avatar']!.isNotEmpty) {
              _currentVideo = _currentVideo.copyWith(channelAvatarUrl: chInfo['avatar']!);
            }
            if (chInfo['subs'] != null && chInfo['subs']!.isNotEmpty) {
              _channelSubs = chInfo['subs'];
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading video details: $e');
    } finally {
      if (mounted) setState(() => _isLoadingDetails = false);
    }
  }

  void _openPopup(VideoPlayerPopup popup) {
    setState(() => _activePopup = popup);
    _popupCtrl.forward(from: 0);
  }

  void _closePopup() async {
    await _popupCtrl.reverse();
    if (mounted) setState(() => _activePopup = null);
  }

  void _showDescriptionSheet() => _openPopup(VideoPlayerPopup.description);
  void _showCommentsSheet() => _openPopup(VideoPlayerPopup.comments);
  void _showQualitySheet() => _openPopup(VideoPlayerPopup.quality);
  void _showSettingsSheet() => _openPopup(VideoPlayerPopup.settings);
  void _showSpeedSheet() => _openPopup(VideoPlayerPopup.speed);

  Future<void> _loadRelatedVideos() async {
    try {
      final page = await YouTubeService.searchVideos(widget.video.channelName);
      if (mounted) {
        setState(() {
          _relatedVideos = page.videos.where((v) => v.id != widget.video.id).toList();
          _isLoadingRelated = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingRelated = false);
    }
  }

  Future<void> _loadRating(String id) async {
    final rating = await YouTubeService.getVideoRating(id);
    if (!mounted || rating == null) return;
    setState(() {
      _isLiked = rating == 'like';
      _isDisliked = rating == 'dislike';
    });
  }

  Future<void> _rateVideo(String rating) async {
    final id = widget.video.resolvedYoutubeId ?? widget.video.id;
    if (!YouTubeService.isAccountConnected) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Connect your YouTube account to rate videos')));
      return;
    }
    final ok = await YouTubeService.rateVideo(id, rating);
    if (!mounted || !ok) return;
    setState(() {
      _isLiked = rating == 'like';
      _isDisliked = rating == 'dislike';
    });
  }

  Future<void> _submitComment(String text) async {
    final id = widget.video.resolvedYoutubeId ?? widget.video.id;
    if (!YouTubeService.isAccountConnected) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Connect your YouTube account to comment')));
      return;
    }
    final commentId = await YouTubeService.postComment(id, text);
    if (!mounted || commentId == null) return;
    _commentController.clear();
    final comments = await YouTubeService.fetchComments(id);
    if (mounted) setState(() => _comments = comments);
  }

  Future<void> _loadComments(String id) async {
    final comments = await YouTubeService.fetchComments(id);
    if (mounted) {
      setState(() {
        _comments = comments;
        _isLoadingComments = false;
      });
    }
  }

  void _initPlayer(String? videoId,
      {bool audioOnly = false, Duration? startAt}) async {
    if (videoId == null) {
      setState(() => _hasError = true);
      return;
    }
    setState(() => _hasError = false);

    try {
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);
      final streamInfo = audioOnly
          ? manifest.audioOnly.withHighestBitrate()
          : manifest.muxed.bestQuality;

      final oldController = _videoPlayerController;

      _videoPlayerController = VideoPlayerController.networkUrl(streamInfo.url);
      await _videoPlayerController!.initialize();

      if (startAt != null) {
        await _videoPlayerController!.seekTo(startAt);
      }
      _videoPlayerController!.play();

      // Expose to global PIP controls
      globalVideoController.value = _videoPlayerController;

      oldController?.dispose();

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error initializing player: $e');
      if (mounted) setState(() => _hasError = true);
    }
  }

  void _toggleAudioOnly(bool val) {
    setState(() => _isAudioOnly = val);
    final pos = _videoPlayerController?.value.position;
    final resolvedId = widget.video.resolvedYoutubeId ?? widget.video.id;
    _initPlayer(resolvedId, audioOnly: val, startAt: pos);
  }

  void _toggleFullscreen() {
    setState(() => _isFullscreen = !_isFullscreen);
    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _openInYouTube() async {
    final id = widget.video.resolvedYoutubeId ?? widget.video.id;
    final url = Uri.parse('https://www.youtube.com/watch?v=$id');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _closeVideo() {
    try {
      _videoPlayerController?.pause();
      globalVideoController.value?.pause();
    } catch (_) {}
    globalVideoController.value = null;
    isPlayerExpanded.value = false;
    selectedVideo.value = null;
  }

  @override
  void dispose() {
    try {
      _videoPlayerController?.pause();
      globalVideoController.value?.pause();
    } catch (_) {}
    globalVideoController.value = null;
    _videoPlayerController?.dispose();
    _likeAnim.dispose();
    _contentAnim.dispose();
    _popupCtrl.dispose();
    _commentController.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isFullscreen) return _buildFullscreen();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F0F0F) : Theme.of(context).scaffoldBackgroundColor;
    final dividerColor = isDark ? const Color(0xFF272727) : const Color(0xFFE0E0E0);

    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (_activePopup != null) return;
        if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
          _closeVideo();
        }
      },
      onHorizontalDragEnd: (details) {
        if (_activePopup != null) return;
        if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
          _closeVideo();
        }
      },
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _buildPlayerSection(),
                  Expanded(
                    child: FadeTransition(
                      opacity: _contentFade,
                      child: SlideTransition(
                        position: _contentSlide,
                        child: ListView(
                          padding: const EdgeInsets.only(bottom: 120),
                          children: [
                            _buildTitleActions(),
                            Divider(color: dividerColor, thickness: 1),
                            _buildChannelRow(),
                            _buildDescription(),
                            Divider(color: dividerColor, thickness: 1),
                            _buildCommentsCapsule(),
                            Divider(color: dividerColor, thickness: 1),
                            _buildRelatedVideos(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_activePopup != null)
                _buildInScreenPopupPanel(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Fullscreen mode ─────────────────────────────────────────────────────────
  Widget _buildFullscreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: _hasError ? _buildErrorWidget() : _buildYouTubePlayer(),
      ),
    );
  }

  // ─── Player section (normal mode) ───────────────────────────────────────────
  Widget _buildPlayerSection() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: _hasError ? _buildErrorWidget() : _buildYouTubePlayer(),
    );
  }

  Widget _buildYouTubePlayer() {
    if (_videoPlayerController == null ||
        !_videoPlayerController!.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
            child:
                CircularProgressIndicator(color: Colors.red, strokeWidth: 2)),
      );
    }
    return CustomVideoPlayer(
      controller: _videoPlayerController!,
      isFullscreen: _isFullscreen,
      onFullscreenToggle: _toggleFullscreen,
      onSettingsTap: _showSettingsSheet,
      onMinimize: _closeVideo,
      onClose: _closeVideo,
    );
  }

  // ─── Error widget (152-4 and other errors) ───────────────────────────────────
  Widget _buildErrorWidget() {
    return Container(
      color: const Color(0xFF0A0A0A),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: const Icon(Icons.play_circle_outline,
                color: Colors.red, size: 44),
          ),
          const SizedBox(height: 12),
          const Text('Playback Restricted',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
              'This video cannot be played in the app.\nTap below to watch on YouTube.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.grey[400], fontSize: 12, height: 1.5)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _openInYouTube,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.red.withOpacity(0.4), blurRadius: 12)
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow, color: Colors.white, size: 18),
                  SizedBox(width: 6),
                  Text('Watch on YouTube',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Title + action chips ────────────────────────────────────────────────────
  Widget _buildTitleActions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_currentVideo.title,
              style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.4)),
          const SizedBox(height: 6),
          Text('${_currentVideo.views} • ${_currentVideo.timestamp}',
              style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13)),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _ActionChip(
                  icon: _isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                  label: _currentVideo.likes ?? '0',
                  isActive: _isLiked,
                  onTap: () async {
                    UserDataService.toggleLike(_currentVideo);
                    setState(() {
                      _isLiked = UserDataService.isLiked(_currentVideo.id);
                      if (_isLiked) _isDisliked = false;
                    });
                    _likeAnim.forward(from: 0);
                    if (YouTubeService.isAccountConnected) {
                      await _rateVideo(_isLiked ? 'like' : 'none');
                    }
                  },
                  animController: _likeAnim,
                ),
                const SizedBox(width: 8),
                _ActionChip(
                  icon: _isDisliked
                      ? Icons.thumb_down
                      : Icons.thumb_down_outlined,
                  label: 'Dislike',
                  isActive: _isDisliked,
                  onTap: () async {
                    setState(() {
                      _isDisliked = !_isDisliked;
                      if (_isDisliked) {
                        if (_isLiked) UserDataService.toggleLike(_currentVideo);
                        _isLiked = false;
                      }
                    });
                    if (YouTubeService.isAccountConnected) {
                      await _rateVideo(_isDisliked ? 'dislike' : 'none');
                    }
                  },
                ),
                const SizedBox(width: 8),
                _ActionChip(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  onTap: () => _openPopup(VideoPlayerPopup.share),
                ),
                const SizedBox(width: 8),
                _ActionChip(
                  icon: Icons.download_outlined,
                  label: 'Download',
                  onTap: () {
                    DownloadService.startDownload(_currentVideo);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Downloading "${_currentVideo.title}" to Youtify storage...'),
                        behavior: SnackBarBehavior.floating,
                        action: SnackBarAction(
                          label: 'View',
                          onPressed: () => Navigator.push(
                            context,
                            FadeSlidePageRoute(page: const DownloadsScreen()),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                _ActionChip(
                    icon: Icons.hd_outlined,
                    label: 'Quality',
                    onTap: _showQualitySheet),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelRow() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSub = SubscriptionService.isSubscribed(_currentVideo.channelName);
    final hasRealAvatar = _currentVideo.channelAvatarUrl.isNotEmpty &&
        !_currentVideo.channelAvatarUrl.contains('ui-avatars.com');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                FadeSlidePageRoute(
                  page: ChannelProfileScreen(channel: {
                    'id': _currentVideo.channelId,
                    'name': _currentVideo.channelName,
                    'avatar': _currentVideo.channelAvatarUrl,
                    'subs': _channelSubs ?? '',
                  }),
                ),
              );
            },
            child: CircleAvatar(
              radius: 20,
              backgroundColor: isDark ? const Color(0xFF272727) : const Color(0xFFE0E0E0),
              backgroundImage: hasRealAvatar ? NetworkImage(_currentVideo.channelAvatarUrl) : null,
              child: !hasRealAvatar
                  ? Text(
                      _currentVideo.channelName.isNotEmpty
                          ? _currentVideo.channelName[0].toUpperCase()
                          : 'Y',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  FadeSlidePageRoute(
                    page: ChannelProfileScreen(channel: {
                      'id': _currentVideo.channelId,
                      'name': _currentVideo.channelName,
                      'avatar': _currentVideo.channelAvatarUrl,
                      'subs': _channelSubs ?? '',
                    }),
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_currentVideo.channelName,
                      style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize: 15)),
                  Text(
                    _channelSubs != null && _channelSubs!.isNotEmpty
                        ? '$_channelSubs subscribers'
                        : 'View channel',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: isSub
                ? OutlinedButton.icon(
                    key: const ValueKey('subbed'),
                    icon: const Icon(Icons.check, size: 14, color: Colors.grey),
                    label: const Text('Subscribed', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
                      backgroundColor: isDark ? const Color(0xFF272727) : const Color(0xFFE5E5E5),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: () async {
                      await SubscriptionService.toggleSubscribe(SubscribedChannel(
                        id: _currentVideo.channelId ?? '',
                        name: _currentVideo.channelName,
                        avatar: _currentVideo.channelAvatarUrl,
                        subs: _channelSubs ?? '',
                      ));
                      if (mounted) setState(() {});
                    },
                  )
                : ElevatedButton(
                    key: const ValueKey('notsubbed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: () async {
                      await SubscriptionService.toggleSubscribe(SubscribedChannel(
                        id: _currentVideo.channelId ?? '',
                        name: _currentVideo.channelName,
                        avatar: _currentVideo.channelAvatarUrl,
                        subs: _channelSubs ?? '',
                      ));
                      if (mounted) setState(() {});
                    },
                    child: const Text('Subscribe', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescription() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasDesc = _currentVideo.description != null && _currentVideo.description!.trim().isNotEmpty;
    final descText = hasDesc
        ? _currentVideo.description!
        : (_isLoadingDetails ? 'Loading description...' : 'No description provided.');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: GestureDetector(
        onTap: _showDescriptionSheet,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(_currentVideo.views,
                      style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  const SizedBox(width: 8),
                  Text(_currentVideo.timestamp,
                      style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  const Spacer(),
                  Text('more',
                      style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontWeight: FontWeight.w600,
                          fontSize: 12)),
                ],
              ),
              const SizedBox(height: 8),
              Text(descText,
                  style: TextStyle(
                      color: isDark ? Colors.grey[300] : Colors.grey[800], fontSize: 13, height: 1.5),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildStatColumn(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildCommentsCapsule() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final capsuleBg = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFEBEBEB);
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[700];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GestureDetector(
        onTap: _showCommentsSheet,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: capsuleBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Comments',
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_comments.length}',
                    style: TextStyle(color: textSecondary, fontSize: 13),
                  ),
                  const Spacer(),
                  Icon(Icons.unfold_more, size: 18, color: textSecondary),
                ],
              ),
              const SizedBox(height: 8),
              if (_isLoadingComments)
                const SizedBox(
                  height: 36,
                  child: Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
                    ),
                  ),
                )
              else if (_comments.isEmpty)
                Text(
                  'Add a comment...',
                  style: TextStyle(color: textSecondary, fontSize: 12),
                )
              else
                SizedBox(
                  height: 52,
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: _comments.length > 5 ? 5 : _comments.length,
                    itemBuilder: (ctx, i) {
                      final c = _comments[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 10,
                              backgroundImage: NetworkImage(c['avatar'] ?? ''),
                              backgroundColor: Colors.grey[800],
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                c['text'] ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: textPrimary, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildCommentTile(Map<String, String> c) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundImage: NetworkImage(c['avatar'] ?? ''),
            backgroundColor: Colors.grey[800],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(c['user'] ?? 'User',
                      style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Text(c['time'] ?? '',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ]),
                const SizedBox(height: 4),
                Text(c['text'] ?? '',
                    style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87, fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelatedVideos() {
    if (_isLoadingRelated) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Column(
          children: const [
            CompactVideoSkeleton(),
            CompactVideoSkeleton(),
          ],
        ),
      );
    }
    if (_relatedVideos.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Recommended Videos',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ..._relatedVideos.map((v) => VideoCard(
          video: v,
          animationIndex: 0,
          onShare: () => _openPopup(VideoPlayerPopup.share),
        )),
      ],
    );
  }

  Widget _buildInScreenPopupPanel() {
    if (_activePopup == null) return const SizedBox.shrink();

    String title;
    Widget content;

    switch (_activePopup!) {
      case VideoPlayerPopup.description:
        title = 'Description';
        content = _buildDescriptionPopupContent();
        break;
      case VideoPlayerPopup.comments:
        title = 'Comments (${_comments.length})';
        content = _buildCommentsPopupContent();
        break;
      case VideoPlayerPopup.quality:
        title = 'Video Quality';
        content = _buildQualityPopupContent();
        break;
      case VideoPlayerPopup.settings:
        title = 'Settings';
        content = _buildSettingsPopupContent();
        break;
      case VideoPlayerPopup.speed:
        title = 'Playback Speed';
        content = _buildSpeedPopupContent();
        break;
      case VideoPlayerPopup.share:
        title = 'Share';
        content = _buildSharePopupContent();
        break;
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = screenHeight * 0.70;

    return Positioned.fill(
      child: PopScope(
        canPop: false,
        onPopInvoked: (didPop) {
          if (!didPop) _closePopup();
        },
        child: Stack(
          children: [
            FadeTransition(
              opacity: _popupFadeAnim,
              child: GestureDetector(
                onTap: _closePopup,
                child: Container(
                  color: Colors.black.withOpacity(0.65),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SlideTransition(
                position: _popupSlideAnim,
                child: GestureDetector(
                  onVerticalDragEnd: (details) {
                    if (details.primaryVelocity != null && details.primaryVelocity! > 250) {
                      _closePopup();
                    }
                  },
                  child: Container(
                    height: maxHeight,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.7),
                          blurRadius: 24,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 10),
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey[600],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.white, size: 22),
                                onPressed: _closePopup,
                                splashRadius: 20,
                              ),
                            ],
                          ),
                        ),
                        const Divider(color: Color(0xFF2E2E2E), height: 1),
                        Expanded(child: content),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionPopupContent() {
    final hasDesc = _currentVideo.description != null && _currentVideo.description!.trim().isNotEmpty;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        Text(
          _currentVideo.title,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, height: 1.3),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF2E2E2E),
              backgroundImage: (_currentVideo.channelAvatarUrl.isNotEmpty && !_currentVideo.channelAvatarUrl.contains('ui-avatars.com'))
                  ? NetworkImage(_currentVideo.channelAvatarUrl)
                  : null,
              child: (_currentVideo.channelAvatarUrl.isEmpty || _currentVideo.channelAvatarUrl.contains('ui-avatars.com'))
                  ? Text(_currentVideo.channelName.isNotEmpty ? _currentVideo.channelName[0].toUpperCase() : 'Y',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_currentVideo.channelName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                  if (_channelSubs != null && _channelSubs!.isNotEmpty)
                    Text('$_channelSubs subscribers',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF282828),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatColumn(_currentVideo.likes ?? '0', 'Likes'),
              Container(width: 1, height: 28, color: Colors.white12),
              _buildStatColumn(_currentVideo.views, 'Views'),
              Container(width: 1, height: 28, color: Colors.white12),
              _buildStatColumn(_currentVideo.timestamp, 'Uploaded'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Description',
          style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        SelectableText(
          hasDesc ? _currentVideo.description! : (_isLoadingDetails ? 'Loading real description...' : 'No description provided.'),
          style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.6),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildCommentsPopupContent() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundImage: NetworkImage(UserDataService.profilePhotoUrl),
                backgroundColor: Colors.grey[800],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF282828),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TextField(
                    controller: _commentController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onSubmitted: (text) {
                      if (text.trim().isEmpty) return;
                      _submitComment(text.trim());
                    },
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: Colors.red, size: 20),
                onPressed: () {
                  if (_commentController.text.trim().isNotEmpty) {
                    _submitComment(_commentController.text.trim());
                  }
                },
              ),
            ],
          ),
        ),
        const Divider(color: Color(0xFF2E2E2E), height: 1),
        Expanded(
          child: _isLoadingComments
              ? const Center(child: CircularProgressIndicator(color: Colors.red, strokeWidth: 2))
              : _comments.isEmpty
                  ? Center(
                      child: Text('No comments yet. Be the first to comment!', style: TextStyle(color: Colors.grey[500])),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _comments.length,
                      itemBuilder: (ctx, i) => _buildCommentTile(_comments[i]),
                    ),
        ),
      ],
    );
  }

  Widget _buildQualityPopupContent() {
    final qualities = ['Auto (1080p)', '1080p', '720p', '480p', '360p', '240p'];
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final q in qualities)
          ListTile(
            title: Text(q, style: TextStyle(
              color: _selectedQuality == q ? Colors.red : Colors.white,
              fontWeight: _selectedQuality == q ? FontWeight.bold : FontWeight.normal,
            )),
            trailing: _selectedQuality == q
                ? const Icon(Icons.check, color: Colors.red, size: 20)
                : null,
            onTap: () {
              setState(() => _selectedQuality = q);
              _closePopup();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Quality set to $q'), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 1)),
              );
            },
          ),
      ],
    );
  }

  Widget _buildSpeedPopupContent() {
    final speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final speed in speeds)
          ListTile(
            title: Text(speed == 1.0 ? 'Normal' : '${speed}x', style: TextStyle(
              color: _playbackSpeed == speed ? Colors.red : Colors.white,
              fontWeight: _playbackSpeed == speed ? FontWeight.bold : FontWeight.normal,
            )),
            trailing: _playbackSpeed == speed
                ? const Icon(Icons.check, color: Colors.red, size: 20)
                : null,
            onTap: () {
              setState(() => _playbackSpeed = speed);
              _videoPlayerController?.setPlaybackSpeed(speed);
              _closePopup();
            },
          ),
      ],
    );
  }

  Widget _buildSettingsPopupContent() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        StatefulBuilder(builder: (context, setSheetState) {
          return SwitchListTile(
            title: const Text('Audio Only Stream', style: TextStyle(color: Colors.white, fontSize: 14)),
            secondary: const Icon(Icons.audiotrack, color: Colors.white),
            value: _isAudioOnly,
            activeColor: Colors.red,
            onChanged: (val) {
              setSheetState(() => _isAudioOnly = val);
              setState(() => _isAudioOnly = val);
              _toggleAudioOnly(val);
            },
          );
        }),
        _SettingsTile(
          icon: Icons.hd_outlined,
          title: 'Quality',
          subtitle: _selectedQuality,
          onTap: () => _openPopup(VideoPlayerPopup.quality),
        ),
        _SettingsTile(
          icon: Icons.speed,
          title: 'Playback speed',
          subtitle: _playbackSpeed == 1.0 ? 'Normal' : '${_playbackSpeed}x',
          onTap: () => _openPopup(VideoPlayerPopup.speed),
        ),
        const _SettingsTile(
          icon: Icons.closed_caption_outlined,
          title: 'Captions',
          subtitle: 'English',
        ),
        const _SettingsTile(
          icon: Icons.audiotrack_outlined,
          title: 'Audio track',
          subtitle: 'Original',
        ),
        const _SettingsTile(
          icon: Icons.lock_outline,
          title: 'Lock screen',
          subtitle: '',
        ),
      ],
    );
  }

  Widget _buildSharePopupContent() {
    final shareUrl = YouTubeService.shareUrl(_currentVideo.id);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    shareUrl,
                    style: TextStyle(color: Colors.blue[300], fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: shareUrl));
                    _closePopup();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Link copied! 🔗'),
                        backgroundColor: const Color(0xFF1A1A1A),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Copy', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _SharePopupBtn(
                icon: Icons.copy,
                label: 'Copy Link',
                onTap: () {
                  Clipboard.setData(ClipboardData(text: shareUrl));
                  _closePopup();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Link copied! 🔗'),
                      backgroundColor: const Color(0xFF1A1A1A),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                },
              ),
              _SharePopupBtn(
                icon: Icons.chat_bubble_outline,
                label: 'WhatsApp',
                onTap: () async {
                  _closePopup();
                  final uri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(shareUrl)}');
                  if (await canLaunchUrl(uri)) launchUrl(uri);
                },
              ),
              _SharePopupBtn(
                icon: Icons.send,
                label: 'Telegram',
                onTap: () async {
                  _closePopup();
                  final uri = Uri.parse('https://t.me/share/url?url=${Uri.encodeComponent(shareUrl)}');
                  if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
                },
              ),
              _SharePopupBtn(
                icon: Icons.more_horiz,
                label: 'More',
                onTap: () {
                  _closePopup();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _SettingsTile(
      {required this.icon, required this.title, required this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title,
          style: const TextStyle(color: Colors.white, fontSize: 14)),
      trailing: subtitle.isNotEmpty
          ? Text(subtitle,
              style: const TextStyle(color: Colors.grey, fontSize: 13))
          : null,
      onTap: onTap ?? () => Navigator.pop(context),
    );
  }
}

class _SharePopupBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SharePopupBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ─── Control button overlay ───────────────────────────────────────────────────
class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  const _ControlBtn({required this.icon, required this.onTap, this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

// ─── Action chip ──────────────────────────────────────────────────────────────
class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final AnimationController? animController;

  const _ActionChip(
      {required this.icon,
      required this.label,
      this.isActive = false,
      required this.onTap,
      this.animController});

  @override
  Widget build(BuildContext context) {
    Widget iconWidget =
        Icon(icon, color: isActive ? Colors.red : Colors.white, size: 18);
    if (animController != null) {
      iconWidget = ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 1.4).animate(
            CurvedAnimation(parent: animController!, curve: Curves.elasticOut)),
        child: iconWidget,
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color:
              isActive ? Colors.red.withOpacity(0.15) : const Color(0xFF272727),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color:
                  isActive ? Colors.red.withOpacity(0.4) : Colors.transparent),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          iconWidget,
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: isActive ? Colors.red : Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}

class CustomVideoPlayer extends StatefulWidget {
  final VideoPlayerController controller;
  final VoidCallback onFullscreenToggle;
  final bool isFullscreen;
  final VoidCallback onSettingsTap;
  final VoidCallback onMinimize;
  final VoidCallback onClose;

  const CustomVideoPlayer({
    super.key,
    required this.controller,
    required this.onFullscreenToggle,
    required this.isFullscreen,
    required this.onSettingsTap,
    required this.onMinimize,
    required this.onClose,
  });

  @override
  State<CustomVideoPlayer> createState() => _CustomVideoPlayerState();
}

class _CustomVideoPlayerState extends State<CustomVideoPlayer>
    with SingleTickerProviderStateMixin {
  bool _showControls = true;
  late AnimationController _controlsAnim;

  @override
  void initState() {
    super.initState();
    _controlsAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250), value: 1.0);
    _startHideTimer();
  }

  void _startHideTimer() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _showControls && widget.controller.value.isPlaying) {
        _controlsAnim.reverse();
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _controlsAnim.forward();
      _startHideTimer();
    } else {
      _controlsAnim.reverse();
    }
  }

  void _seekRelative(Duration duration) {
    final current = widget.controller.value.position;
    widget.controller.seekTo(current + duration);
    _startHideTimer();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleControls,
      child: Stack(
        fit: StackFit.expand,
        children: [
          VideoPlayer(widget.controller),

          // Double Tap zones
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onDoubleTap: () {
                    _seekRelative(const Duration(seconds: -10));
                  },
                  child: Container(color: Colors.transparent),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onDoubleTap: () {
                    _seekRelative(const Duration(seconds: 10));
                  },
                  child: Container(color: Colors.transparent),
                ),
              ),
            ],
          ),

          // Controls Overlay
          FadeTransition(
            opacity: _controlsAnim,
            child: IgnorePointer(
              ignoring: !_showControls,
              child: Container(
                color: Colors.black.withOpacity(0.4),
                child: Column(
                  children: [
                    // Top bar
                    if (!widget.isFullscreen)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        child: Row(
                          children: [
                            _ControlBtn(
                                icon: Icons.arrow_back,
                                onTap: widget.onClose,
                                tooltip: 'Close video'),
                            const SizedBox(width: 4),
                            _ControlBtn(
                                icon: Icons.keyboard_arrow_down,
                                onTap: widget.onClose,
                                tooltip: 'Close video'),
                            const Spacer(),
                            _ControlBtn(
                                icon: Icons.fullscreen,
                                onTap: widget.onFullscreenToggle,
                                tooltip: 'Fullscreen'),
                            const SizedBox(width: 4),
                            _ControlBtn(
                                icon: Icons.settings,
                                onTap: widget.onSettingsTap,
                                tooltip: 'Settings'),
                            const SizedBox(width: 4),
                            _ControlBtn(
                                icon: Icons.close,
                                onTap: widget.onClose,
                                tooltip: 'Close'),
                          ],
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            _ControlBtn(
                                icon: Icons.close,
                                onTap: widget.onFullscreenToggle),
                            const Spacer(),
                            _ControlBtn(
                                icon: Icons.fullscreen_exit,
                                onTap: widget.onFullscreenToggle),
                          ],
                        ),
                      ),

                    const Spacer(),

                    // Center play/pause
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.replay_10,
                              color: Colors.white, size: 36),
                          onPressed: () =>
                              _seekRelative(const Duration(seconds: -10)),
                        ),
                        const SizedBox(width: 24),
                        ValueListenableBuilder(
                          valueListenable: widget.controller,
                          builder: (context, VideoPlayerValue value, child) {
                            return GestureDetector(
                              onTap: () {
                                value.isPlaying
                                    ? widget.controller.pause()
                                    : widget.controller.play();
                                _startHideTimer();
                              },
                              child: Container(
                                decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black54),
                                padding: const EdgeInsets.all(12),
                                child: value.isPlaying
                                    ? const Icon(
                                        Icons.pause,
                                        color: Colors.white,
                                        size: 48,
                                      )
                                    : ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.asset(
                                          'assets/images/app_icon.png',
                                          width: 48,
                                          height: 48,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 24),
                        IconButton(
                          icon: const Icon(Icons.forward_10,
                              color: Colors.white, size: 36),
                          onPressed: () =>
                              _seekRelative(const Duration(seconds: 10)),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Bottom Timeline
                    ValueListenableBuilder(
                      valueListenable: widget.controller,
                      builder: (context, VideoPlayerValue value, child) {
                        final position = value.position;
                        final duration = value.duration;
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Row(
                            children: [
                              Text(_formatDuration(position),
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12)),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 2,
                                    thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 6),
                                    overlayShape: const RoundSliderOverlayShape(
                                        overlayRadius: 12),
                                    activeTrackColor: Colors.red,
                                    inactiveTrackColor: Colors.white30,
                                    thumbColor: Colors.red,
                                  ),
                                  child: Slider(
                                    value: position.inMilliseconds
                                        .toDouble()
                                        .clamp(0,
                                            duration.inMilliseconds.toDouble()),
                                    min: 0,
                                    max: duration.inMilliseconds.toDouble() > 0
                                        ? duration.inMilliseconds.toDouble()
                                        : 1,
                                    onChanged: (val) {
                                      widget.controller.seekTo(
                                          Duration(milliseconds: val.toInt()));
                                    },
                                  ),
                                ),
                              ),
                              Text(_formatDuration(duration),
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12)),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    if (d.inHours > 0) return "${d.inHours}:$twoDigitMinutes:$twoDigitSeconds";
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}
