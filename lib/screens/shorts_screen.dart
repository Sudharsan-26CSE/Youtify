import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide Video;
import '../models/video.dart';
import '../services/youtube_service.dart';
import '../services/user_data_service.dart';
import '../services/subscription_service.dart';
import '../widgets/capsule_modal.dart';
import '../widgets/skeleton_loader.dart';
import 'search_screen.dart';
import 'feedback_screen.dart';
import 'channel_profile_screen.dart';
import '../utils/page_transitions.dart';

/// Ultra-fast sliding-window preloading manager for YouTube Shorts
class _ShortsPreloadManager {
  static final _yt = YouTubeService.yt;
  static final Map<String, String> _streamCache = {};
  static final Map<String, Future<String?>> _inFlightStreamUrls = {};
  static final Map<String, VideoPlayerController> _controllerCache = {};
  static final Map<String, Future<void>> _inFlightControllers = {};

  /// Preload a sliding window of shorts around currentIndex
  static void preloadWindow(List<Video> shorts, int currentIndex) {
    if (shorts.isEmpty) return;

    // 1. Pre-resolve stream URLs ahead for upcoming 3 videos and previous 1
    final preloadStreamIndices = [
      currentIndex,
      currentIndex + 1,
      currentIndex + 2,
      currentIndex + 3,
      if (currentIndex > 0) currentIndex - 1,
    ];

    for (final idx in preloadStreamIndices) {
      if (idx >= 0 && idx < shorts.length) {
        getStreamUrl(shorts[idx]);
      }
    }

    // 2. Pre-warm / pre-initialize the next video's controller so it plays immediately on scroll
    if (currentIndex + 1 < shorts.length) {
      _prewarmController(shorts[currentIndex + 1]);
    }
    // Also prewarm previous video in case user swipes back
    if (currentIndex - 1 >= 0) {
      _prewarmController(shorts[currentIndex - 1]);
    }

    // 3. Keep memory clean: dispose controllers further than 1 step away
    final activeIds = <String>{};
    for (int offset = -1; offset <= 1; offset++) {
      final idx = currentIndex + offset;
      if (idx >= 0 && idx < shorts.length) {
        final id = shorts[idx].resolvedYoutubeId ?? shorts[idx].id;
        activeIds.add(id);
      }
    }

    final toRemove = _controllerCache.keys.where((k) => !activeIds.contains(k)).toList();
    for (final id in toRemove) {
      final ctrl = _controllerCache.remove(id);
      _inFlightControllers.remove(id);
      try {
        ctrl?.pause();
        ctrl?.dispose();
      } catch (_) {}
    }
  }

  /// Get stream URL (cached, in-flight, or fresh)
  static Future<String?> getStreamUrl(Video short, {String quality = 'Auto'}) async {
    final videoId = short.resolvedYoutubeId ?? short.id;

    if (_streamCache.containsKey(videoId)) {
      return _streamCache[videoId];
    }

    if (_inFlightStreamUrls.containsKey(videoId)) {
      return _inFlightStreamUrls[videoId];
    }

    final future = _fetchStreamUrl(short, quality);
    _inFlightStreamUrls[videoId] = future;

    try {
      final url = await future;
      if (url != null && url.isNotEmpty) {
        _streamCache[videoId] = url;
      }
      return url;
    } finally {
      _inFlightStreamUrls.remove(videoId);
    }
  }

  static Future<String?> _fetchStreamUrl(Video short, String quality) async {
    final videoId = short.resolvedYoutubeId ?? short.id;

    if (short.videoUrl != null && short.videoUrl!.endsWith('.mp4')) {
      return short.videoUrl;
    }

    try {
      final manifest = await _yt.videos.streamsClient
          .getManifest(videoId)
          .timeout(const Duration(seconds: 8));

      if (manifest.muxed.isNotEmpty) {
        if (quality == 'Auto' || quality == '720p') {
          // Look for 720p first, or fallback to highest muxed
          final muxed720 = manifest.muxed.where((s) => s.qualityLabel.contains('720')).toList();
          if (muxed720.isNotEmpty) {
            return muxed720.first.url.toString();
          }
          return manifest.muxed.withHighestBitrate().url.toString();
        } else {
          final matched = manifest.muxed.firstWhere(
            (s) => s.qualityLabel.contains(quality.replaceAll('p', '')),
            orElse: () => manifest.muxed.withHighestBitrate(),
          );
          return matched.url.toString();
        }
      } else if (manifest.videoOnly.isNotEmpty) {
        return manifest.videoOnly.withHighestBitrate().url.toString();
      }
    } catch (e) {
      debugPrint('Stream manifest fetch error for $videoId: $e');
    }

    return null;
  }

  /// Pre-warms the VideoPlayerController (initializes it in paused state)
  static Future<void> _prewarmController(Video short) async {
    final videoId = short.resolvedYoutubeId ?? short.id;

    if (_controllerCache.containsKey(videoId) || _inFlightControllers.containsKey(videoId)) {
      return;
    }

    final streamUrl = await getStreamUrl(short);
    if (streamUrl == null || streamUrl.isEmpty) return;

    if (_controllerCache.containsKey(videoId)) return;

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(streamUrl),
    );

    final completer = Completer<void>();
    _inFlightControllers[videoId] = completer.future;

    try {
      await controller.initialize();
      await controller.setLooping(true);
      _controllerCache[videoId] = controller;
      if (!completer.isCompleted) completer.complete();
    } catch (e) {
      debugPrint('Pre-warm initialize error for $videoId: $e');
      try {
        await controller.dispose();
      } catch (_) {}
      _controllerCache.remove(videoId);
      if (!completer.isCompleted) completer.complete();
    } finally {
      _inFlightControllers.remove(videoId);
    }
  }

  /// Retrieve existing pre-warmed controller synchronously if ready
  static VideoPlayerController? getReadyController(String videoId) {
    final ctrl = _controllerCache[videoId];
    if (ctrl != null && ctrl.value.isInitialized) {
      return ctrl;
    }
    return null;
  }

  /// Get or initialize controller for playback
  static Future<VideoPlayerController?> getControllerForPlayback(
    Video short, {
    String quality = 'Auto',
  }) async {
    final videoId = short.resolvedYoutubeId ?? short.id;

    // 1. Ready in cache?
    final ready = getReadyController(videoId);
    if (ready != null) return ready;

    // 2. Initializing in progress?
    if (_inFlightControllers.containsKey(videoId)) {
      try {
        await _inFlightControllers[videoId];
        final readyAfterWait = getReadyController(videoId);
        if (readyAfterWait != null) return readyAfterWait;
      } catch (_) {}
    }

    // 3. Create fresh controller
    final streamUrl = await getStreamUrl(short, quality: quality);
    if (streamUrl == null || streamUrl.isEmpty) return null;

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(streamUrl),
    );

    try {
      await controller.initialize();
      await controller.setLooping(true);
      _controllerCache[videoId] = controller;
      return controller;
    } catch (e) {
      debugPrint('Failed to initialize $videoId: $e');
      try {
        await controller.dispose();
      } catch (_) {}

      // If initial stream failed, try alternative muxed streams for the same YouTube short
      try {
        final manifest = await _yt.videos.streamsClient
            .getManifest(videoId)
            .timeout(const Duration(seconds: 5));
        if (manifest.muxed.isNotEmpty) {
          for (final s in manifest.muxed) {
            final altUrl = s.url.toString();
            if (altUrl == streamUrl) continue;
            final altCtrl = VideoPlayerController.networkUrl(Uri.parse(altUrl));
            try {
              await altCtrl.initialize();
              await altCtrl.setLooping(true);
              _controllerCache[videoId] = altCtrl;
              return altCtrl;
            } catch (_) {
              try {
                await altCtrl.dispose();
              } catch (_) {}
            }
          }
        }
      } catch (_) {}

      return null;
    }
  }

  static void invalidateVideo(String videoId) {
    _streamCache.remove(videoId);
    final ctrl = _controllerCache.remove(videoId);
    ctrl?.dispose();
  }

  /// Release all cached controllers when user leaves shorts screen
  static void disposeAll() {
    for (final ctrl in _controllerCache.values) {
      try {
        ctrl.pause();
        ctrl.dispose();
      } catch (_) {}
    }
    _controllerCache.clear();
    _inFlightControllers.clear();
  }

  /// Pause all active controllers (e.g. when user switches tab)
  static void pauseAll() {
    for (final ctrl in _controllerCache.values) {
      try {
        ctrl.pause();
      } catch (_) {}
    }
  }
}

class ShortsScreen extends StatefulWidget {
  final bool isTabActive;
  const ShortsScreen({super.key, this.isTabActive = true});

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

  @override
  void didUpdateWidget(ShortsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isTabActive && oldWidget.isTabActive) {
      _ShortsPreloadManager.pauseAll();
    }
  }

  Future<void> _loadShorts() async {
    final shorts = await YouTubeService.fetchShorts();
    if (mounted) {
      setState(() {
        _shorts = shorts;
        _isLoading = false;
      });
      if (widget.isTabActive) {
        _ShortsPreloadManager.preloadWindow(_shorts, 0);
      }
    }
  }

  void _removeShort(int index) {
    setState(() {
      _shorts.removeAt(index);
      if (_currentPage >= _shorts.length && _shorts.isNotEmpty) {
        _currentPage = _shorts.length - 1;
      }
    });
    _ShortsPreloadManager.preloadWindow(_shorts, _currentPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _ShortsPreloadManager.disposeAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: ShortsSkeleton(),
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
        onPageChanged: (i) {
          setState(() => _currentPage = i);
          _ShortsPreloadManager.preloadWindow(_shorts, i);
        },
        itemBuilder: (context, index) {
          return _ShortPage(
            short: _shorts[index],
            isActive: (index == _currentPage) && widget.isTabActive,
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
  bool _isLoadingVideo = true;
  bool _hasVideoError = false;
  late int _likeCount;
  int _commentCount = 1200;
  String? _channelAvatar;
  String _channelSubs = '1.2M';

  late AnimationController _entryCtrl;
  late Animation<Offset> _rightPanelSlide;
  late Animation<Offset> _bottomPanelSlide;

  String _selectedQuality = 'Auto';

  static int _parseLikes(String? likesStr, String videoId) {
    if (likesStr != null && likesStr.isNotEmpty && likesStr != '0') {
      final clean = likesStr.replaceAll(',', '').trim().toUpperCase();
      if (clean.endsWith('M')) {
        final val = double.tryParse(clean.replaceAll('M', '')) ?? 1.0;
        return (val * 1000000).toInt();
      } else if (clean.endsWith('K')) {
        final val = double.tryParse(clean.replaceAll('K', '')) ?? 1.0;
        return (val * 1000).toInt();
      } else {
        final val = int.tryParse(clean);
        if (val != null && val > 0) return val;
      }
    }
    final seed = videoId.hashCode.abs();
    return 14000 + (seed % 175000);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isLiked = UserDataService.isLiked(widget.short.id);
    _likeCount = _parseLikes(widget.short.likes, widget.short.id);
    _commentCount = (widget.short.id.hashCode.abs() % 3800) + 180;
    _channelAvatar = widget.short.channelAvatarUrl;
    
    // Load channel details asynchronously without competing with initial video start
    Future.microtask(_loadChannelDetails);

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

  void _loadChannelDetails() async {
    final chId = widget.short.channelId;
    if (chId != null && chId.isNotEmpty) {
      final avatar = await YouTubeService.fetchChannelAvatar(chId);
      if (mounted && avatar != null && avatar.isNotEmpty) {
        setState(() => _channelAvatar = avatar);
      }
      final ch = await YouTubeService.fetchChannel(chId);
      if (mounted && ch != null) {
        setState(() {
          if (ch['avatar'] != null && (ch['avatar'] as String).isNotEmpty) {
            _channelAvatar = ch['avatar'];
          }
          if (ch['subs'] != null && (ch['subs'] as String).isNotEmpty) {
            _channelSubs = ch['subs'];
          }
        });
      }
    }
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
    _vpCtrl?.pause();
    _vpCtrl = null;
    if (mounted) setState(() {});
  }

  Future<void> _startVideo() async {
    final request = ++_loadRequest;
    final videoId = widget.short.resolvedYoutubeId ?? widget.short.id;

    // Fast path: controller is already pre-warmed & initialized in background!
    final readyCtrl = _ShortsPreloadManager.getReadyController(videoId);
    if (readyCtrl != null) {
      _vpCtrl = readyCtrl;
      await readyCtrl.play();
      _entryCtrl.forward();
      if (mounted) {
        setState(() {
          _isLoadingVideo = false;
          _hasVideoError = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingVideo = true;
        _hasVideoError = false;
      });
    }

    final controller = await _ShortsPreloadManager.getControllerForPlayback(
      widget.short,
      quality: _selectedQuality,
    );

    if (!mounted || !widget.isActive || request != _loadRequest) return;

    if (controller != null && controller.value.isInitialized) {
      _vpCtrl = controller;
      await controller.play();
      _entryCtrl.forward();
      if (mounted) {
        setState(() {
          _isLoadingVideo = false;
          _hasVideoError = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoadingVideo = false;
          _hasVideoError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _playbackIconTimer?.cancel();
    _loadRequest++;
    _vpCtrl?.pause();
    _vpCtrl = null;
    _entryCtrl.dispose();
    super.dispose();
  }

  void _toggleLike() {
    UserDataService.toggleLike(widget.short);
    setState(() {
      _isLiked = UserDataService.isLiked(widget.short.id);
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
            fillColor: Colors.white.withValues(alpha: 0.07),
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
      barrierColor: Colors.black.withValues(alpha: 0.5),
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
                        color: const Color(0xFF1A1A1A).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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
                          _GlassyTile(
                            icon: Icons.hd_outlined,
                            label: 'Quality ($_selectedQuality)',
                            onTap: () {
                              Navigator.pop(ctx);
                              _showQualitySheet();
                            },
                          ),
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

  void _showQualitySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Quality', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            for (final q in ['Auto', '1080p', '720p', '480p', '360p'])
              ListTile(
                title: Text(q, style: TextStyle(color: _selectedQuality == q ? Colors.red : Colors.white)),
                trailing: _selectedQuality == q ? const Icon(Icons.check, color: Colors.red) : null,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _selectedQuality = q);
                  final videoId = widget.short.resolvedYoutubeId ?? widget.short.id;
                  _ShortsPreloadManager.invalidateVideo(videoId);
                  _startVideo();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Quality set to $q'),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
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

        // Centered loading indicator
        if (_isLoadingVideo)
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const CircularProgressIndicator(
                color: Colors.red,
                strokeWidth: 3,
              ),
            ),
          ),

        // Retry button if error
        if (_hasVideoError && !_isLoadingVideo)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.replay_rounded,
                      color: Colors.white, size: 48),
                  onPressed: _startVideo,
                ),
                const SizedBox(height: 8),
                const Text('Tap to retry',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),

        // Gradient overlays
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withValues(alpha: 0.5),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.85),
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
                  label: _formatCount(_commentCount),
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
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          FadeSlidePageRoute(
                            page: ChannelProfileScreen(channel: {
                              'id': widget.short.channelId ?? widget.short.id,
                              'name': widget.short.channelName,
                              'avatar': _channelAvatar ?? widget.short.channelAvatarUrl,
                              'subs': _channelSubs,
                            }),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.grey[800],
                            backgroundImage: (_channelAvatar != null && _channelAvatar!.isNotEmpty)
                                ? NetworkImage(_channelAvatar!)
                                : null,
                            child: (_channelAvatar == null || _channelAvatar!.isEmpty)
                                ? const Icon(Icons.person, color: Colors.white, size: 20)
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            widget.short.channelName,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: SubscriptionService.isSubscribed(widget.short.channelName)
                          ? OutlinedButton.icon(
                              key: const ValueKey('subscribed'),
                              icon: const Icon(Icons.check, size: 14, color: Colors.white70),
                              label: const Text('Subscribed', style: TextStyle(fontSize: 12, color: Colors.white70)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white38),
                                backgroundColor: Colors.white12,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () async {
                                await SubscriptionService.toggleSubscribe(SubscribedChannel(
                                  id: widget.short.channelId ?? widget.short.channelName,
                                  name: widget.short.channelName,
                                  avatar: _channelAvatar ?? widget.short.channelAvatarUrl,
                                  subs: _channelSubs,
                                ));
                                if (mounted) setState(() {});
                              },
                            )
                          : ElevatedButton(
                              key: const ValueKey('subscribe'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () async {
                                await SubscriptionService.toggleSubscribe(SubscribedChannel(
                                  id: widget.short.channelId ?? widget.short.channelName,
                                  name: widget.short.channelName,
                                  avatar: _channelAvatar ?? widget.short.channelAvatarUrl,
                                  subs: _channelSubs,
                                ));
                                if (mounted) setState(() {});
                              },
                              child: const Text('Subscribe', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
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
      builder: (ctx) => _RealCommentsSheet(
        videoId: widget.short.resolvedYoutubeId ?? widget.short.id,
        videoTitle: widget.short.title,
        channelName: widget.short.channelName,
        onCommentAdded: (count) {
          if (mounted) setState(() => _commentCount = count);
        },
      ),
    );
  }
}

// Real comments sheet that fetches from YouTube or realistic community pool
class _RealCommentsSheet extends StatefulWidget {
  final String videoId;
  final String? videoTitle;
  final String? channelName;
  final ValueChanged<int>? onCommentAdded;

  const _RealCommentsSheet({
    required this.videoId,
    this.videoTitle,
    this.channelName,
    this.onCommentAdded,
  });

  @override
  State<_RealCommentsSheet> createState() => _RealCommentsSheetState();
}

class _RealCommentsSheetState extends State<_RealCommentsSheet> {
  List<Map<String, String>> _comments = [];
  bool _isLoading = true;
  final TextEditingController _commentCtrl = TextEditingController();
  final Set<String> _likedComments = {};

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    final comments = await YouTubeService.fetchComments(
      widget.videoId,
      videoTitle: widget.videoTitle,
      channelName: widget.channelName,
    );
    if (mounted) {
      setState(() {
        _comments = List.from(comments);
        _isLoading = false;
      });
    }
  }

  void _submitComment() {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;

    final newComment = {
      'id': 'my_${DateTime.now().millisecondsSinceEpoch}',
      'user': '@you',
      'text': text,
      'time': 'Just now',
      'likes': '0',
      'avatar': 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=200',
    };

    setState(() {
      _comments.insert(0, newComment);
      _commentCtrl.clear();
    });

    widget.onCommentAdded?.call(_comments.length);
    FocusScope.of(context).unfocus();
  }

  void _toggleCommentLike(String id) {
    setState(() {
      if (_likedComments.contains(id)) {
        _likedComments.remove(id);
      } else {
        _likedComments.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Text(
                    'Comments (${_comments.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF272727), height: 1),
            if (_isLoading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: Colors.red),
                ),
              )
            else if (_comments.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    'No comments yet. Be the first to comment!',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _comments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    final c = _comments[i];
                    final isLiked = _likedComments.contains(c['id']);
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.grey[800],
                          backgroundImage: (c['avatar'] != null && c['avatar']!.isNotEmpty)
                              ? NetworkImage(c['avatar']!)
                              : null,
                          child: (c['avatar'] == null || c['avatar']!.isEmpty)
                              ? Text(
                                  c['user']?.substring(0, 1).toUpperCase() ?? 'U',
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    c['user'] ?? '',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    c['time'] ?? '',
                                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                c['text'] ?? '',
                                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.35),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => _toggleCommentLike(c['id'] ?? '$i'),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                                          color: isLiked ? Colors.red : Colors.grey[400],
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          c['likes'] ?? '0',
                                          style: TextStyle(
                                            color: isLiked ? Colors.red : Colors.grey[400],
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Icon(Icons.thumb_down_outlined, color: Colors.grey[500], size: 14),
                                  const SizedBox(width: 16),
                                  Text('Reply', style: TextStyle(color: Colors.grey[400], fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            const Divider(color: Color(0xFF272727), height: 1),
            // Bottom comment input bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFF1F1F1F),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 16,
                    backgroundImage: NetworkImage(
                      'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=200',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _commentCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.08),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _submitComment(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.red, size: 22),
                    onPressed: _submitComment,
                  ),
                ],
              ),
            ),
          ],
        ),
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
