import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/video.dart';

class ShortsScreen extends StatefulWidget {
  const ShortsScreen({super.key});

  @override
  State<ShortsScreen> createState() => _ShortsScreenState();
}

class _ShortsScreenState extends State<ShortsScreen> {
  final PageController _pageController = PageController();
  final List<Video> _shorts = Video.getShortsVideos();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: _shorts.length,
        onPageChanged: (i) => setState(() => _currentPage = i),
        itemBuilder: (context, index) {
          return _ShortPage(short: _shorts[index], isActive: index == _currentPage);
        },
      ),
    );
  }
}

class _ShortPage extends StatefulWidget {
  final Video short;
  final bool isActive;

  const _ShortPage({required this.short, required this.isActive});

  @override
  State<_ShortPage> createState() => _ShortPageState();
}

class _ShortPageState extends State<_ShortPage>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _vpCtrl;
  bool _isLiked = false;
  bool _isSaved = false;
  int _likeCount = 45200;
  late AnimationController _entryCtrl;
  late Animation<Offset> _rightPanelSlide;
  late Animation<Offset> _bottomPanelSlide;

  @override
  void initState() {
    super.initState();
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
      _vpCtrl?.pause();
      _entryCtrl.reset();
    }
  }

  Future<void> _startVideo() async {
    final url = widget.short.videoUrl ??
        'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4';
    _vpCtrl = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await _vpCtrl!.initialize();
      _vpCtrl!.setLooping(true);
      _vpCtrl!.play();
      _entryCtrl.forward();
      if (mounted) setState(() {});
    } catch (_) {
      _entryCtrl.forward();
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
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
    setState(() => _isSaved = !_isSaved);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isSaved ? 'Short saved! ✅' : 'Short removed from saved'),
        backgroundColor: const Color(0xFF1A1A1A),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _shareShort() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Share', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ShareOption(icon: Icons.link, label: 'Copy Link'),
                _ShareOption(icon: Icons.message, label: 'Message'),
                _ShareOption(icon: Icons.share, label: 'More'),
              ],
            ),
            const SizedBox(height: 16),
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
                    onPressed: () {},
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
                  onTap: () {},
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
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2))),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Comments', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                itemCount: 5,
                itemBuilder: (ctx, i) => ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(
                      'https://images.unsplash.com/photo-153571387500${i}d1d0cf377fde?q=80&w=100',
                    ),
                    onBackgroundImageError: (_, __) {},
                    backgroundColor: Colors.grey[800],
                    child: Text(String.fromCharCode(65 + i), style: const TextStyle(color: Colors.white)),
                  ),
                  title: Text('User $i', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text('Great short! 🔥 #${i + 1}', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                ),
              ),
            ),
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
