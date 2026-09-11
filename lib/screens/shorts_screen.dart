import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide Video;
import '../models/video.dart';
import '../services/youtube_service.dart';
import '../widgets/capsule_modal.dart';
import 'search_screen.dart';
import 'feedback_screen.dart';
import '../utils/page_transitions.dart';

class ShortsScreen extends StatefulWidget {
  const ShortsScreen({super.key});

  @override
  State<ShortsScreen> createState() => _ShortsScreenState();
}

class _ShortsScreenState extends State<ShortsScreen> {
  final PageController _pageController = PageController();
  List<Video> _shorts = [];
  int _currentPage = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadShorts();
  }

  Future<void> _loadShorts() async {
    final shorts = await YouTubeService.fetchShorts();
    if (mounted) {
      setState(() {
        _shorts = shorts;
        _isLoading = false;
      });
    }
  }

  void _removeShort(int index) {
    setState(() {
      _shorts.removeAt(index);
      if (_currentPage >= _shorts.length && _shorts.isNotEmpty) {
        _currentPage = _shorts.length - 1;
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.red)),
      );
    }
    if (_shorts.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bolt, color: Colors.grey[600], size: 64),
              const SizedBox(height: 16),
              Text('No shorts available', style: TextStyle(color: Colors.grey[400], fontSize: 16)),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: _shorts.length,
        onPageChanged: (i) => setState(() => _currentPage = i),
        itemBuilder: (context, index) {
          return _ShortPage(
            short: _shorts[index],
            isActive: index == _currentPage,
            onNotInterested: () => _removeShort(index),
          );
        },
      ),
    );
  }
}

class _ShortPage extends StatefulWidget {
  final Video short;
  final bool isActive;
  final VoidCallback onNotInterested;

  const _ShortPage({required this.short, required this.isActive, required this.onNotInterested});

  @override
  State<_ShortPage> createState() => _ShortPageState();
}

class _ShortPageState extends State<_ShortPage>
  with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  VideoPlayerController? _vpCtrl;
  bool _isLiked = false;
  bool _isSaved = false;
  bool _showPlaybackIcon = false;
  Timer? _playbackIconTimer;
  int _loadRequest = 0;
  int _likeCount = 45200;
  late AnimationController _entryCtrl;
  late Animation<Offset> _rightPanelSlide;
  late Animation<Offset> _bottomPanelSlide;

  final _yt = YouTubeService.yt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _rightPanelSlide = Tween<Offset>(
      begin: const Offset(1.0, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    _bottomPanelSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    if (widget.isActive) _startVideo();
  }

  @override
  void didUpdateWidget(_ShortPage old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) {
      _startVideo();
    } else if (!widget.isActive && old.isActive) {
      _stopVideo();
      _entryCtrl.reset();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopVideo();
    }
  }

  void _stopVideo() {
    _loadRequest++;
    final controller = _vpCtrl;
    _vpCtrl = null;
    controller?.pause();
    controller?.dispose();
    if (mounted) setState(() {});
  }

  Future<void> _startVideo() async {
    final request = ++_loadRequest;
    String url = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4';
    
    try {
      final videoId = widget.short.resolvedYoutubeId ?? widget.short.id;
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);
      
      if (manifest.muxed.isNotEmpty) {
        final streamInfo = manifest.muxed.withHighestBitrate();
        url = streamInfo.url.toString();
      } else {
        debugPrint('No muxed streams found for Short $videoId');
      }
    } catch (e) {
      debugPrint('Error fetching stream for Short: $e');
    }

    if (!mounted || !widget.isActive || request != _loadRequest) return;
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _vpCtrl = controller;
    try {
      await controller.initialize();
      if (!mounted || !widget.isActive || request != _loadRequest) {
        await controller.dispose();
        if (identical(_vpCtrl, controller)) _vpCtrl = null;
        return;
      }
      controller.setLooping(true);
      controller.play();
      _entryCtrl.forward();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error initializing VideoPlayer: $e');
      _entryCtrl.forward();
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _playbackIconTimer?.cancel();
    _loadRequest++;
    _vpCtrl?.pause();
    _vpCtrl?.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  void _toggleLike() {
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });
  }

  void _toggleSave() {
    _showSaveOptions();
  }

  void _togglePlayback() {
    final controller = _vpCtrl;
    if (controller == null || !controller.value.isInitialized) return;

    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
    _playbackIconTimer?.cancel();
    setState(() => _showPlaybackIcon = true);
    _playbackIconTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showPlaybackIcon = false);
    });
  }

  void _showSaveOptions() {
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
                child: Text('Save to...', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            const Divider(color: Color(0xFF272727), height: 1),
            CapsuleAction(
              icon: Icons.add,
              label: 'Create New Save List',
              onTap: () => _showCreateListDialog(),
            ),
            CapsuleAction(
              icon: Icons.watch_later_outlined,
              label: 'Watch Later',
              onTap: () {
                setState(() => _isSaved = true);
                _showSaveSnackbar('Saved to Watch Later');
              },
            ),
            CapsuleAction(
              icon: Icons.favorite_border,
              label: 'Favorites',
              onTap: () {
                setState(() => _isSaved = true);
                _showSaveSnackbar('Saved to Favorites');
              },
            ),
            CapsuleAction(
              icon: Icons.playlist_play,
              label: 'My Playlist',
              onTap: () {
                setState(() => _isSaved = true);
                _showSaveSnackbar('Saved to My Playlist');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateListDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('New Save List', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'List name...',
            hintStyle: TextStyle(color: Colors.grey[500]),
            filled: true,
            fillColor: Colors.white.withOpacity(0.07),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              Navigator.pop(ctx);
              if (controller.text.isNotEmpty) {
                setState(() => _isSaved = true);
                _showSaveSnackbar('Saved to "${controller.text}"');
              }
            },
            child: const Text('Create & Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSaveSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$msg ✅'),
        backgroundColor: const Color(0xFF1A1A1A),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _shareShort() {
    final url = YouTubeService.shareUrl(widget.short.id, isShort: true);
    showCapsuleModal(
      context: context,
      child: ShareCapsule(shareUrl: url, title: widget.short.title),
    );
  }

  void _showMoreOptions() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'More',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, __, child) {
        return FadeTransition(
          opacity: anim,
          child: Align(
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Material(
                color: Colors.transparent,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A).withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('More Options', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                          const Divider(color: Color(0xFF272727), height: 1),
                          _GlassyTile(icon: Icons.description_outlined, label: 'Description', onTap: () {
                            Navigator.pop(ctx);
                            _showShortDescription();
                          }),
                          _GlassyTile(icon: Icons.visibility_off_outlined, label: 'Clear Screen', onTap: () => Navigator.pop(ctx)),
                          _GlassyTile(icon: Icons.closed_caption_outlined, label: 'Captions', onTap: () => Navigator.pop(ctx)),
                          _GlassyTile(icon: Icons.hd_outlined, label: 'Quality', onTap: () => Navigator.pop(ctx)),
                          _GlassyTile(icon: Icons.not_interested, label: 'Not Interested', color: Colors.orange, onTap: () {
                            Navigator.pop(ctx);
                            widget.onNotInterested();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Sorry for the inconvenience. This short has been removed.'),
                                backgroundColor: const Color(0xFF1A1A1A),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                          }),
                          _GlassyTile(icon: Icons.feedback_outlined, label: 'Feedback', onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(context, FadeSlidePageRoute(page: const FeedbackScreen()));
                          }),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showShortDescription() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.8,
        minChildSize: 0.3,
        expand: false,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2))),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Description', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const Divider(color: Color(0xFF272727), height: 1),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(16),
                children: [
                  Text(widget.short.title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(widget.short.views, style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                      const SizedBox(width: 12),
                      Text(widget.short.timestamp, style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.short.description ?? 'No description available for this short.',
                    style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Video or fallback
        if (_vpCtrl != null && _vpCtrl!.value.isInitialized)
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _vpCtrl!.value.size.width,
              height: _vpCtrl!.value.size.height,
              child: VideoPlayer(_vpCtrl!),
            ),
          )
        else
          Image.network(
            widget.short.thumbnailUrl,
            fit: BoxFit.cover,
            errorBuilder: (c, e, s) => Container(color: Colors.grey[900]),
          ),

        // Gradient overlays
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withOpacity(0.5),
                Colors.transparent,
                Colors.black.withOpacity(0.85),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),

        // Tap the video to pause or resume playback.
        if (_vpCtrl != null && _vpCtrl!.value.isInitialized)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _togglePlayback,
              child: Center(
                child: ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: _vpCtrl!,
                  builder: (context, value, child) => AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: AnimatedOpacity(
                      opacity: _showPlaybackIcon ? 1 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Container(
                        key: ValueKey(value.isPlaying),
                        padding: const EdgeInsets.all(14),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          value.isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 42,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

        // Top bar
        Positioned(
          top: 44,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Shorts',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.search, color: Colors.white, size: 26),
                    onPressed: () => Navigator.push(context, FadeSlidePageRoute(page: const SearchScreen())),
                  ),
                  IconButton(
                    icon: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 26),
                    onPressed: () {},
                  ),
                ],
              ),
            ],
          ),
        ),

        // Right action panel
        Positioned(
          right: 12,
          bottom: 110,
          child: SlideTransition(
            position: _rightPanelSlide,
            child: Column(
              children: [
                _buildActionButton(
                  icon: _isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                  label: _formatCount(_likeCount),
                  color: _isLiked ? Colors.red : Colors.white,
                  onTap: _toggleLike,
                ),
                const SizedBox(height: 20),
                _buildActionButton(
                  icon: Icons.thumb_down_outlined,
                  label: 'Dislike',
                  onTap: () {},
                ),
                const SizedBox(height: 20),
                _buildActionButton(
                  icon: Icons.comment_outlined,
                  label: '1.2K',
                  onTap: () => _showComments(),
                ),
                const SizedBox(height: 20),
                _buildActionButton(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  onTap: _shareShort,
                ),
                const SizedBox(height: 20),
                _buildActionButton(
                  icon: _isSaved ? Icons.bookmark : Icons.bookmark_outline,
                  label: 'Save',
                  color: _isSaved ? Colors.yellow : Colors.white,
                  onTap: _toggleSave,
                ),
                const SizedBox(height: 20),
                _buildActionButton(
                  icon: Icons.more_vert,
                  label: 'More',
                  onTap: _showMoreOptions,
                ),
              ],
            ),
          ),
        ),

        // Bottom info
        Positioned(
          left: 16,
          bottom: 110,
          right: 80,
          child: SlideTransition(
            position: _bottomPanelSlide,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundImage: NetworkImage(widget.short.channelAvatarUrl),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      widget.short.channelName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white70),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Follow', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.short.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.music_note, color: Colors.white70, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Original Audio — ${widget.short.channelName}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Progress indicator
        if (_vpCtrl != null && _vpCtrl!.value.isInitialized)
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: VideoProgressIndicator(
              _vpCtrl!,
              allowScrubbing: true,
              colors: VideoProgressColors(
                playedColor: Colors.red,
                bufferedColor: Colors.white30,
                backgroundColor: Colors.white10,
              ),
              padding: EdgeInsets.zero,
            ),
          ),
      ],
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    Color color = Colors.white,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedScale(
            scale: 1.0,
            duration: const Duration(milliseconds: 200),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  void _showComments() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _RealCommentsSheet(videoId: widget.short.resolvedYoutubeId ?? widget.short.id),
    );
  }
}

// Real comments sheet that fetches from YouTube
class _RealCommentsSheet extends StatefulWidget {
  final String videoId;
  const _RealCommentsSheet({required this.videoId});

  @override
  State<_RealCommentsSheet> createState() => _RealCommentsSheetState();
}

class _RealCommentsSheetState extends State<_RealCommentsSheet> {
  List<Map<String, String>> _comments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    final comments = await YouTubeService.fetchComments(widget.videoId);
    if (mounted) {
      setState(() {
        _comments = comments;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Comments (${_comments.length})', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: Colors.red)))
          else if (_comments.isEmpty)
            Expanded(child: Center(child: Text('No comments available', style: TextStyle(color: Colors.grey[400]))))
          else
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                itemCount: _comments.length,
                itemBuilder: (ctx, i) {
                  final c = _comments[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: NetworkImage(c['avatar'] ?? ''),
                      backgroundColor: Colors.grey[800],
                    ),
                    title: Text(c['user'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text(c['text'] ?? '', style: TextStyle(color: Colors.grey[400], fontSize: 13), maxLines: 3, overflow: TextOverflow.ellipsis),
                    trailing: Text(c['time'] ?? '', style: TextStyle(color: Colors.grey[600], fontSize: 10)),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _GlassyTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _GlassyTile({required this.icon, required this.label, this.color = Colors.white, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 16),
            Text(label, style: TextStyle(color: color, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _ShareOption extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ShareOption({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}
