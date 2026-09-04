import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide Video;
import '../models/video.dart';
import '../widgets/capsule_modal.dart';
import '../services/youtube_service.dart';
import '../services/download_service.dart';
import 'downloads_screen.dart';
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
  ChewieController? _chewieController;
  final _yt = YoutubeExplode();
  bool _isLiked = false;
  bool _isDisliked = false;
  bool _isSubscribed = false;
  bool _hasError = false;
  bool _isFullscreen = false;
  bool _showControls = true;

  late AnimationController _likeAnim;
  late AnimationController _contentAnim;
  late Animation<double> _contentFade;
  late Animation<Offset> _contentSlide;
  late AnimationController _controlsAnim;

  final _commentController = TextEditingController();
  final List<Map<String, String>> _comments = [
    {'user': 'Aarav Kumar', 'text': 'This is absolutely amazing! 🔥', 'time': '2h', 'avatar': 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=100'},
    {'user': 'Priya Singh', 'text': 'Best tutorial I\'ve seen this year!', 'time': '5h', 'avatar': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?q=80&w=100'},
    {'user': 'Rohan Dev', 'text': 'Would love a part 2 🙏', 'time': '1d', 'avatar': 'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?q=80&w=100'},
  ];

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
    _likeAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _contentAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..forward();
    _contentFade = CurvedAnimation(parent: _contentAnim, curve: Curves.easeOut);
    _contentSlide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _contentAnim, curve: Curves.easeOutCubic));
    _controlsAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 250), value: 1.0);

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _initPlayer(widget.video.resolvedYoutubeId);
  }

  void _initPlayer(String? videoId) async {
    if (videoId == null) {
      setState(() => _hasError = true);
      return;
    }
    setState(() => _hasError = false);

    try {
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);
      final streamInfo = manifest.muxed.bestQuality;
      
      _videoPlayerController = VideoPlayerController.networkUrl(streamInfo.url);
      await _videoPlayerController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        showControls: true,
        allowFullScreen: false,
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.red,
          handleColor: Colors.red,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.white.withOpacity(0.5),
        ),
      );
      
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error initializing player: $e');
      if (mounted) setState(() => _hasError = true);
    }
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

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _controlsAnim.forward();
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _showControls) {
          _controlsAnim.reverse();
          setState(() => _showControls = false);
        }
      });
    } else {
      _controlsAnim.reverse();
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
    _chewieController?.dispose();
    _yt.close();
    _likeAnim.dispose();
    _contentAnim.dispose();
    _controlsAnim.dispose();
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
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            Center(
              child: _hasError ? _buildErrorWidget() : _buildYouTubePlayer(),
            ),
            // Controls overlay
            FadeTransition(
              opacity: _controlsAnim,
              child: Container(
                color: Colors.black.withOpacity(0.3),
                child: SafeArea(
                  child: Column(
                    children: [
                      // Top bar
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            _ControlBtn(
                              icon: Icons.close,
                              onTap: () {
                                _toggleFullscreen();
                              },
                            ),
                            const Spacer(),
                            _ControlBtn(icon: Icons.fullscreen_exit, onTap: _toggleFullscreen),
                          ],
                        ),
                      ),
                      const Spacer(),
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

  // ─── Player section (normal mode) ───────────────────────────────────────────
  Widget _buildPlayerSection() {
    return GestureDetector(
      onTap: _toggleControls,
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _hasError ? _buildErrorWidget() : _buildYouTubePlayer(),
          ),
          // Controls overlay
          Positioned.fill(
            child: FadeTransition(
              opacity: _controlsAnim,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  color: Colors.black.withOpacity(0.25),
                  child: Column(
                    children: [
                      // Top row: close + fullscreen
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Row(
                          children: [
                            _ControlBtn(
                              icon: Icons.arrow_back,
                              onTap: () => Navigator.pop(context),
                            ),
                            const Spacer(),
                            _ControlBtn(icon: Icons.open_in_new, onTap: _openInYouTube, tooltip: 'Watch on YouTube'),
                            const SizedBox(width: 4),
                            _ControlBtn(icon: Icons.fullscreen, onTap: _toggleFullscreen, tooltip: 'Fullscreen'),
                          ],
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYouTubePlayer() {
    if (_chewieController == null || _videoPlayerController == null || !_videoPlayerController!.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(child: CircularProgressIndicator(color: Colors.red, strokeWidth: 2)),
      );
    }
    return Chewie(controller: _chewieController!);
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
            child: const Icon(Icons.play_circle_outline, color: Colors.red, size: 44),
          ),
          const SizedBox(height: 12),
          const Text('Playback Restricted',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('This video cannot be played in the app.\nTap below to watch on YouTube.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 12, height: 1.5)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _openInYouTube,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.4), blurRadius: 12)],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow, color: Colors.white, size: 18),
                  SizedBox(width: 6),
                  Text('Watch on YouTube', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
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
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, height: 1.4)),
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
                  onTap: () {
                    setState(() { _isLiked = !_isLiked; if (_isLiked) _isDisliked = false; });
                    _likeAnim.forward(from: 0);
                  },
                  animController: _likeAnim,
                ),
                const SizedBox(width: 8),
                _ActionChip(
                  icon: _isDisliked ? Icons.thumb_down : Icons.thumb_down_outlined,
                  label: 'Dislike',
                  isActive: _isDisliked,
                  onTap: () => setState(() { _isDisliked = !_isDisliked; if (_isDisliked) _isLiked = false; }),
                ),
                const SizedBox(width: 8),
                _ActionChip(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  onTap: () => showCapsuleModal(context: context,
                      child: ShareCapsule(shareUrl: YouTubeService.shareUrl(widget.video.id), title: widget.video.title)),
                ),
                const SizedBox(width: 8),
                _ActionChip(
                  icon: Icons.download_outlined,
                  label: 'Download',
                  onTap: () {
                    DownloadService.startDownload(widget.video);
                    Navigator.push(context, FadeSlidePageRoute(page: const DownloadsScreen()));
                  },
                ),
                const SizedBox(width: 8),
                _ActionChip(icon: Icons.hd_outlined, label: 'Quality', onTap: _showQualitySheet),
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
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                Text('128K subscribers', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
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
                  fontWeight: FontWeight.bold, fontSize: 13,
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
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(widget.video.description!,
            style: TextStyle(color: Colors.grey[300], fontSize: 13, height: 1.5),
            maxLines: 3, overflow: TextOverflow.ellipsis),
      ),
    );
  }

  Widget _buildComments() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Comments (${_comments.length})',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 16),
          Row(
            children: [
              const CircleAvatar(radius: 16, backgroundColor: Colors.red, child: Icon(Icons.person, color: Colors.white, size: 16)),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _commentController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Add a comment...',
                    hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                    border: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF272727))),
                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.red)),
                    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF272727))),
                  ),
                  onSubmitted: (text) {
                    if (text.trim().isEmpty) return;
                    setState(() {
                      _comments.insert(0, {'user': 'You', 'text': text, 'time': 'Just now', 'avatar': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=100'});
                      _commentController.clear();
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
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
                  Text(c['user']!, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Text(c['time']!, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ]),
                const SizedBox(height: 4),
                Text(c['text']!, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
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
            const Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Align(alignment: Alignment.centerLeft,
                    child: Text('Video Quality', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)))),
            const Divider(color: Color(0xFF272727), height: 1),
            ...['Auto', '360p', '720p', '1080p'].map((q) => ListTile(
              title: Text(q, style: const TextStyle(color: Colors.white)),
              trailing: q == 'Auto' ? const Icon(Icons.check, color: Colors.red) : null,
              onTap: () => Navigator.pop(context),
            )),
            const SizedBox(height: 8),
          ],
        ),
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
          width: 36, height: 36,
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

  const _ActionChip({required this.icon, required this.label, this.isActive = false, required this.onTap, this.animController});

  @override
  Widget build(BuildContext context) {
    Widget iconWidget = Icon(icon, color: isActive ? Colors.red : Colors.white, size: 18);
    if (animController != null) {
      iconWidget = ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 1.4)
            .animate(CurvedAnimation(parent: animController!, curve: Curves.elasticOut)),
        child: iconWidget,
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.red.withOpacity(0.15) : const Color(0xFF272727),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? Colors.red.withOpacity(0.4) : Colors.transparent),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          iconWidget,
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: isActive ? Colors.red : Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}
