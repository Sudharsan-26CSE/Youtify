import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide Video;
import '../models/video.dart';
import '../widgets/capsule_modal.dart';
import '../services/youtube_service.dart';
import '../services/download_service.dart';
import 'downloads_screen.dart';
import '../main.dart';
import '../utils/page_transitions.dart';
import 'package:url_launcher/url_launcher.dart';

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
  bool _isLiked = false;
  bool _isDisliked = false;
  bool _isSubscribed = false;
  bool _hasError = false;
  bool _isFullscreen = false;
  bool _isAudioOnly = false;
  // Removed _showControls and _controlsAnim as they are moved to CustomVideoPlayer

  late AnimationController _likeAnim;
  late AnimationController _contentAnim;
  late Animation<double> _contentFade;
  late Animation<Offset> _contentSlide;
  late AnimationController _controlsAnim;

  final _commentController = TextEditingController();
  List<Map<String, String>> _comments = [];
  bool _isLoadingComments = true;

  // Fallback video IDs that allow embedding
  static const _fallbackIds = [
    'M7lc1UVf-VE', // YouTube official test video
    'YE7VzlLtp-4', // Big Buck Bunny on YouTube
    'aqz-KE-bpKQ', // Relaxing music - embedding allowed
  ];
  int _fallbackIndex = 0;

  @override
  void initState() {
    super.initState();
    _likeAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _contentAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
      ..forward();
    _contentFade = CurvedAnimation(parent: _contentAnim, curve: Curves.easeOut);
    _contentSlide =
        Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
            CurvedAnimation(parent: _contentAnim, curve: Curves.easeOutCubic));

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    final resolvedId = widget.video.resolvedYoutubeId ?? widget.video.id;
    _initPlayer(resolvedId);
    _loadComments(resolvedId);
    _loadRating(resolvedId);
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

  void _onPlayerError() {
    if (mounted) setState(() => _hasError = true);
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

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _likeAnim.dispose();
    _contentAnim.dispose();
    _commentController.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isFullscreen) return _buildFullscreen();
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: Column(
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
                      const Divider(color: Color(0xFF272727), thickness: 1),
                      _buildChannelRow(),
                      if (widget.video.description != null) _buildDescription(),
                      const Divider(color: Color(0xFF272727), thickness: 1),
                      _buildComments(),
                    ],
                  ),
                ),
              ),
            ),
          ],
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
      onMinimize: () => isPlayerExpanded.value = false,
      onClose: () => selectedVideo.value = null,
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.video.title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.4)),
          const SizedBox(height: 6),
          Text('${widget.video.views} • ${widget.video.timestamp}',
              style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _ActionChip(
                  icon: _isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                  label: widget.video.likes ?? '0',
                  isActive: _isLiked,
                  onTap: () async {
                    if (!YouTubeService.isAccountConnected) {
                      await _rateVideo('like');
                      return;
                    }
                    setState(() {
                      _isLiked = !_isLiked;
                      if (_isLiked) _isDisliked = false;
                    });
                    _likeAnim.forward(from: 0);
                    await _rateVideo(_isLiked ? 'like' : 'none');
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
                    if (!YouTubeService.isAccountConnected) {
                      await _rateVideo('dislike');
                      return;
                    }
                    setState(() {
                      _isDisliked = !_isDisliked;
                      if (_isDisliked) _isLiked = false;
                    });
                    await _rateVideo(_isDisliked ? 'dislike' : 'none');
                  },
                ),
                const SizedBox(width: 8),
                _ActionChip(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  onTap: () => showCapsuleModal(
                      context: context,
                      child: ShareCapsule(
                          shareUrl: YouTubeService.shareUrl(widget.video.id),
                          title: widget.video.title)),
                ),
                const SizedBox(width: 8),
                _ActionChip(
                  icon: Icons.download_outlined,
                  label: 'Download',
                  onTap: () {
                    DownloadService.startDownload(widget.video);
                    Navigator.push(context,
                        FadeSlidePageRoute(page: const DownloadsScreen()));
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: NetworkImage(widget.video.channelAvatarUrl),
            onBackgroundImageError: (e, s) => {},
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.video.channelName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
                Text('Live YouTube channel data',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _isSubscribed = !_isSubscribed),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _isSubscribed ? const Color(0xFF272727) : Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _isSubscribed ? 'Subscribed ✓' : 'Subscribe',
                style: TextStyle(
                  color: _isSubscribed ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescription() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: GestureDetector(
        onTap: _showDescriptionSheet,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(widget.video.views,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  const SizedBox(width: 8),
                  Text(widget.video.timestamp,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ],
              ),
              const SizedBox(height: 8),
              Text(widget.video.description ?? 'No description provided.',
                  style: TextStyle(
                      color: Colors.grey[300], fontSize: 13, height: 1.5),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }

  void _showDescriptionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
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
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Description',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                ),
                const Divider(color: Color(0xFF272727), height: 1),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatColumn(widget.video.likes ?? '0', 'Likes'),
                          _buildStatColumn(widget.video.views, 'Views'),
                          _buildStatColumn(widget.video.timestamp, 'Date'),
                          _buildStatColumn(widget.video.duration, 'Duration'),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        widget.video.description ?? 'No description provided.',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
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

  Widget _buildComments() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Comments (${_comments.length})',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
          const SizedBox(height: 16),
          Row(
            children: [
              const CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.red,
                  child: Icon(Icons.person, color: Colors.white, size: 16)),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _commentController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Add a comment...',
                    hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                    border: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF272727))),
                    focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.red)),
                    enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF272727))),
                  ),
                  onSubmitted: (text) {
                    if (text.trim().isEmpty) return;
                    _submitComment(text.trim());
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_isLoadingComments)
            const Center(child: CircularProgressIndicator(color: Colors.red))
          else if (_comments.isEmpty)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text("No comments available",
                        style: TextStyle(color: Colors.grey))))
          else
            ..._comments.map((c) => _buildCommentTile(c)),
        ],
      ),
    );
  }

  Widget _buildCommentTile(Map<String, String> c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 16, backgroundImage: NetworkImage(c['avatar']!)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(c['user']!,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Text(c['time']!,
                      style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ]),
                const SizedBox(height: 4),
                Text(c['text']!,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSettingsSheet() {
    showCapsuleModal(
      context: context,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Settings',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)))),
            const Divider(color: Color(0xFF272727), height: 1),
            StatefulBuilder(builder: (context, setSheetState) {
              return SwitchListTile(
                title: const Text('Audio Only Stream',
                    style: TextStyle(color: Colors.white, fontSize: 14)),
                secondary: const Icon(Icons.audiotrack, color: Colors.white),
                value: _isAudioOnly,
                activeColor: Colors.red,
                onChanged: (val) {
                  setSheetState(() => _isAudioOnly = val);
                  _toggleAudioOnly(val);
                },
              );
            }),
            _SettingsTile(
                icon: Icons.hd_outlined,
                title: 'Quality',
                subtitle: 'Auto (1080p)'),
            _SettingsTile(
                icon: Icons.speed, title: 'Playback speed', subtitle: 'Normal'),
            _SettingsTile(
                icon: Icons.closed_caption_outlined,
                title: 'Captions',
                subtitle: 'English'),
            _SettingsTile(
                icon: Icons.audiotrack_outlined,
                title: 'Audio track',
                subtitle: 'Original'),
            _SettingsTile(
                icon: Icons.lock_outline, title: 'Lock screen', subtitle: ''),
            _SettingsTile(
                icon: Icons.settings_outlined,
                title: 'More',
                subtitle: 'Advanced settings'),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showQualitySheet() {
    showCapsuleModal(
      context: context,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Video Quality',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)))),
            const Divider(color: Color(0xFF272727), height: 1),
            ...['Auto', '360p', '720p', '1080p'].map((q) => ListTile(
                  title: Text(q, style: const TextStyle(color: Colors.white)),
                  trailing: q == 'Auto'
                      ? const Icon(Icons.check, color: Colors.red)
                      : null,
                  onTap: () => Navigator.pop(context),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SettingsTile(
      {required this.icon, required this.title, required this.subtitle});

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
      onTap: () => Navigator.pop(context),
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
                                icon: Icons.keyboard_arrow_down,
                                onTap: widget.onMinimize,
                                tooltip: 'Minimize'),
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
                                child: Icon(
                                  value.isPlaying
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                  color: Colors.white,
                                  size: 48,
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
