import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/video.dart';
import '../widgets/video_card.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/capsule_modal.dart';
import '../utils/page_transitions.dart';
import 'video_player_screen.dart';
import '../services/youtube_service.dart';

/// Full in-app channel profile screen.
/// Displayed when user taps a subscribed channel.
class ChannelProfileScreen extends StatefulWidget {
  final Map<String, dynamic> channel;

  const ChannelProfileScreen({super.key, required this.channel});

  @override
  State<ChannelProfileScreen> createState() => _ChannelProfileScreenState();
}

class _ChannelProfileScreenState extends State<ChannelProfileScreen>
    with TickerProviderStateMixin {
  late AnimationController _entryCtrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  late TabController _tabCtrl;

  bool _isSubscribed = true;
  bool _isNotified = true;

  List<Video> _channelVideos = [];
  List<Video> get _channelShorts => Video.getShortsVideos();
  String? _nextPageToken;
  bool _isLoadingVideos = true;
  bool _isLoadingMore = false;
  final _videosController = ScrollController();

  Map<String, dynamic> _channelDetails = {};

  String get _name =>
      _channelDetails['name'] as String? ??
      widget.channel['name'] as String? ??
      'Channel';
  String get _avatar =>
      _channelDetails['avatar'] as String? ??
      widget.channel['avatar'] as String? ??
      'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=200';
  String get _subs =>
      _channelDetails['subs'] as String? ?? widget.channel['subs'] as String? ?? '';
  String get _watchTime =>
      _channelDetails['watchTime'] as String? ?? widget.channel['watchTime'] as String? ?? '';
  String get _banner =>
      _channelDetails['banner'] as String? ??
      widget.channel['banner'] as String? ??
      'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?q=80&w=1200&auto=format&fit=crop';
  String get _channelId => widget.channel['id'] as String? ?? '';
  String get _description =>
      _channelDetails['description'] as String? ?? widget.channel['description'] as String? ?? '';
  String get _videoCount =>
      _channelDetails['videoCount'] as String? ?? widget.channel['videoCount'] as String? ?? '';
  String get _viewCount =>
      _channelDetails['viewCount'] as String? ?? widget.channel['viewCount'] as String? ?? '';

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
    _fade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _tabCtrl = TabController(length: 3, vsync: this);
    _videosController.addListener(_onVideosScroll);
    _loadChannelDetails();
    _loadChannelVideos();
  }

  Future<void> _loadChannelDetails() async {
    if (_channelId.isNotEmpty) {
      final details = await YouTubeService.fetchChannel(_channelId);
      if (details != null && mounted) {
        setState(() {
          _channelDetails = details;
        });
      }
    }
  }


  void _onVideosScroll() {
    if (_videosController.position.pixels >=
        _videosController.position.maxScrollExtent - 200) {
      _loadMoreChannelVideos();
    }
  }

  Future<void> _loadChannelVideos() async {
    if (_channelId.isEmpty) {
      if (mounted)
        setState(() {
          _channelVideos = Video.sampleVideos;
          _isLoadingVideos = false;
        });
      return;
    }
    final page = await YouTubeService.fetchChannelVideos(_channelId);
    if (mounted)
      setState(() {
        _channelVideos = page.videos;
        _nextPageToken = page.nextPageToken;
        _isLoadingVideos = false;
      });
  }

  Future<void> _loadMoreChannelVideos() async {
    if (_isLoadingMore || _nextPageToken == null) return;
    setState(() => _isLoadingMore = true);
    final page = await YouTubeService.fetchChannelVideos(_channelId,
        pageToken: _nextPageToken);
    if (mounted)
      setState(() {
        _channelVideos.addAll(page.videos);
        _nextPageToken = page.nextPageToken;
        _isLoadingMore = false;
      });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _tabCtrl.dispose();
    _videosController.dispose();
    super.dispose();
  }

  void _showMoreOptions() {
    showCapsuleModal(
      context: context,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: NetworkImage(_avatar),
                  onBackgroundImageError: (e, s) => {},
                ),
                const SizedBox(width: 12),
                Text(_name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ]),
            ),
            const Divider(color: Color(0xFF272727), height: 1),
            CapsuleAction(
              icon: _isSubscribed
                  ? Icons.person_remove_outlined
                  : Icons.person_add_outlined,
              label: _isSubscribed ? 'Unsubscribe' : 'Subscribe',
              color: _isSubscribed ? Colors.red : Colors.green,
              onTap: () {
                setState(() => _isSubscribed = !_isSubscribed);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(_isSubscribed
                      ? 'Subscribed to $_name'
                      : 'Unsubscribed from $_name'),
                  backgroundColor: const Color(0xFF1A1A1A),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ));
              },
            ),
            CapsuleAction(
              icon: _isNotified
                  ? Icons.notifications_active
                  : Icons.notifications_none,
              label: _isNotified
                  ? 'Turn off notifications'
                  : 'Turn on notifications',
              onTap: () => setState(() => _isNotified = !_isNotified),
            ),
            CapsuleAction(
                icon: Icons.message_outlined, label: 'Message', onTap: () {}),
            CapsuleAction(
                icon: Icons.share_outlined,
                label: 'Share Channel',
                onTap: () {
                  showCapsuleModal(
                    context: context,
                    child: ShareCapsule(
                      shareUrl:
                          'https://youtube.com/@${_name.toLowerCase().replaceAll(' ', '_')}',
                      title: _name,
                    ),
                  );
                }),
            CapsuleAction(
                icon: Icons.flag_outlined,
                label: 'Report',
                color: Colors.orange,
                onTap: () {}),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: NestedScrollView(
            headerSliverBuilder: (ctx, inner) => [
              SliverAppBar(
                expandedHeight: 260,
                pinned: true,
                backgroundColor: const Color(0xFF0F0F0F),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onPressed: _showMoreOptions,
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: _buildHeader(),
                ),
                bottom: TabBar(
                  controller: _tabCtrl,
                  indicatorColor: Colors.red,
                  indicatorWeight: 2,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: const [
                    Tab(text: 'Videos'),
                    Tab(text: 'Shorts'),
                    Tab(text: 'About'),
                  ],
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildVideosTab(),
                _buildShortsTab(),
                _buildAboutTab(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Banner image
        Image.network(
          _banner,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2A0A0A), Color(0xFF1A0505)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        // Dark gradient overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        // Blur at bottom
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 80,
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.transparent),
            ),
          ),
        ),
        // Channel info
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Avatar
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 12)
                        ],
                      ),
                      child: ClipOval(
                        child: Container(
                          width: 72,
                          height: 72,
                          color: const Color(0xFF272727),
                          child: Image.network(
                            _avatar,
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xFFE50914),
                              alignment: Alignment.center,
                              child: Text(
                                _name.isNotEmpty ? _name[0].toUpperCase() : 'Y',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Name + stats
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(_name,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(width: 6),
                              const Icon(Icons.verified,
                                  color: Colors.blue, size: 16),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text('@${_name.toLowerCase().replaceAll(' ', '_')}',
                              style: TextStyle(
                                  color: Colors.grey[400], fontSize: 13)),
                          const SizedBox(height: 4),
                          Row(children: [
                            Text('$_subs subs',
                                style: TextStyle(
                                    color: Colors.grey[300], fontSize: 12)),
                            Text(' • ',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 12)),
                            Text('You watched $_watchTime',
                                style: TextStyle(
                                    color: Colors.grey[300], fontSize: 12)),
                          ]),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _isSubscribed = !_isSubscribed);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          height: 40,
                          decoration: BoxDecoration(
                            color: _isSubscribed
                                ? const Color(0xFF2A2A2A)
                                : Colors.red,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: _isSubscribed
                                    ? Colors.white.withOpacity(0.2)
                                    : Colors.transparent),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                    _isSubscribed
                                        ? Icons.notifications_active
                                        : Icons.subscriptions,
                                    color: Colors.white,
                                    size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  _isSubscribed ? 'Subscribed' : 'Subscribe',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _isNotified = !_isNotified),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _isNotified
                              ? Colors.red.withOpacity(0.15)
                              : const Color(0xFF2A2A2A),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _isNotified
                                ? Colors.red.withOpacity(0.5)
                                : Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: Icon(
                          _isNotified
                              ? Icons.notifications_active
                              : Icons.notifications_none,
                          color: _isNotified ? Colors.red : Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        showCapsuleModal(
                          context: context,
                          child: ShareCapsule(
                            shareUrl:
                                'https://youtube.com/@${_name.toLowerCase().replaceAll(' ', '_')}',
                            title: _name,
                          ),
                        );
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: const Icon(Icons.share_outlined,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVideosTab() {
    if (_isLoadingVideos) {
      return ListView.builder(
        itemCount: 4,
        padding: const EdgeInsets.only(top: 8, bottom: 120),
        itemBuilder: (_, __) => const CompactVideoSkeleton(),
      );
    }
    return ListView.builder(
      controller: _videosController,
      padding: const EdgeInsets.only(top: 8, bottom: 120),
      itemCount: _channelVideos.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i == _channelVideos.length) {
          return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: CompactVideoSkeleton());
        }
        final v = _channelVideos[i];
        return _ChannelVideoTile(
            video: v, channelName: _name, channelAvatar: _avatar);
      },
    );
  }

  Widget _buildShortsTab() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 0.56,
      ),
      itemCount: _channelShorts.length,
      itemBuilder: (ctx, i) {
        final v = _channelShorts[i];
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            FadeSlidePageRoute(page: _buildShortsViewer(i)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(v.thumbnailUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(color: Colors.grey[900])),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7)
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                const Positioned(
                    top: 6,
                    left: 6,
                    child: Icon(Icons.bolt, color: Colors.white, size: 14)),
                Positioned(
                  bottom: 6,
                  left: 4,
                  right: 4,
                  child: Text(v.title,
                      maxLines: 2,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500)),
                ),
                Positioned(
                  bottom: 36,
                  left: 4,
                  child: Text(v.views,
                      style: TextStyle(color: Colors.grey[300], fontSize: 9)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildShortsViewer(int startIndex) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
          child: Text('Shorts player',
              style: const TextStyle(color: Colors.white))),
    );
  }

  Widget _buildAboutTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _AboutSection(
          title: 'Description',
          content: _description.isEmpty
              ? 'No channel description available.'
              : _description,
        ),
        const SizedBox(height: 16),
        _AboutSection(
            title: 'Stats',
            content:
                '• $_subs subscribers\n• $_videoCount videos\n• $_viewCount total views'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Links',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
              const SizedBox(height: 12),
              _LinkItem(
                  icon: Icons.link,
                  label:
                      'youtube.com/@${_name.toLowerCase().replaceAll(' ', '_')}'),
              _LinkItem(
                  icon: Icons.camera_alt_outlined,
                  label:
                      'instagram.com/${_name.toLowerCase().replaceAll(' ', '')}'),
              _LinkItem(
                  icon: Icons.message_outlined,
                  label:
                      'twitter.com/${_name.toLowerCase().replaceAll(' ', '')}'),
            ],
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _ChannelVideoTile extends StatelessWidget {
  final Video video;
  final String channelName;
  final String channelAvatar;

  const _ChannelVideoTile(
      {required this.video,
      required this.channelName,
      required this.channelAvatar});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        FadeSlidePageRoute(page: VideoPlayerScreenWrapper(video: video)),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(12)),
              child: Stack(
                children: [
                  Image.network(video.thumbnailUrl,
                      width: 140,
                      height: 85,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                          width: 140, height: 85, color: Colors.grey[900])),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(3)),
                      child: Text(video.duration,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            height: 1.3)),
                    const SizedBox(height: 4),
                    Text('${video.views} • ${video.timestamp}',
                        style:
                            TextStyle(color: Colors.grey[500], fontSize: 11)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  final String title, content;
  const _AboutSection({required this.title, required this.content});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
            const SizedBox(height: 8),
            Text(content,
                style: TextStyle(
                    color: Colors.grey[300], fontSize: 13, height: 1.6)),
          ],
        ),
      );
}

class _LinkItem extends StatelessWidget {
  final IconData icon;
  final String label;
  const _LinkItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(icon, color: Colors.blue[300], size: 16),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: Colors.blue[300], fontSize: 13)),
        ]),
      );
}

// Wrapper to avoid direct reference issues in channel tile
class VideoPlayerScreenWrapper extends StatelessWidget {
  final Video video;
  const VideoPlayerScreenWrapper({super.key, required this.video});

  @override
  Widget build(BuildContext context) => VideoPlayerScreen(video: video);
}
