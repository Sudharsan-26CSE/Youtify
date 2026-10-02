import 'dart:async';
import 'package:flutter/material.dart';
import '../models/video.dart';
import '../widgets/video_card.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/capsule_modal.dart';
import '../services/youtube_service.dart';
import '../services/auth_service.dart';
import '../services/subscription_service.dart';
import 'channel_profile_screen.dart';
import 'search_screen.dart';
import '../utils/page_transitions.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  static final List<Map<String, dynamic>> _defaultYouTubeChannels = [
    {
      'id': 'UCX6OQ3DkcsbYNE6H8uQQuVA',
      'name': 'MrBeast',
      'avatar':
          'https://yt3.googleusercontent.com/nxYrc_1_2f77DoBadyxMTmv7ZpRZapHR5jbuYe7PlPd5cIRJxtNNEYyOC0ZsxaDyJJzXrnJiuDE=s900-c-k-c0x00ffffff-no-rj',
      'subs': '318M',
      'watchTime': 'New',
      'isNew': true,
    },
    {
      'id': 'UCq-Fj5jknLsUf-MWSy4_brA',
      'name': 'T-Series',
      'avatar':
          'https://yt3.googleusercontent.com/VunTf0NzCeboiPjbesBdnQuxaF3Lja7UGRbBGQAWRJgMSTj9TTLO3pS1X9qPOJGCNnmPrXeY=s900-c-k-c0x00ffffff-no-rj',
      'subs': '270M',
      'watchTime': '2h ago',
      'isNew': true,
    },
    {
      'id': 'UCHnyfMqiRRG1u-2MsSQLbXA',
      'name': 'Veritasium',
      'avatar':
          'https://yt3.googleusercontent.com/7vCbvtCqtjQ3YLgsJt7Y952MQV1sBvhllSCSxHP8_sVZdcPCBrITfhkN2RdyCuwPnsByq-1GoA=s900-c-k-c0x00ffffff-no-rj',
      'subs': '16M',
      'watchTime': '1d ago',
      'isNew': false,
    },
    {
      'id': 'UCsXVk37bltHxD1rDPwtNM8Q',
      'name': 'Kurzgesagt',
      'avatar':
          'https://yt3.googleusercontent.com/ytc/AIdro_n1Ribd7LwdP_qKtqWL3ZDfIgv9M1d6g78VwpHGXVR2Ir4=s900-c-k-c0x00ffffff-no-rj',
      'subs': '22M',
      'watchTime': '3h ago',
      'isNew': true,
    },
    {
      'id': 'UC_x5XG1OV2P6uZZ5FSM9Ttw',
      'name': 'Google Developers',
      'avatar':
          'https://yt3.googleusercontent.com/Jrfy3VrP1QDikidneCoruk9MmhsQsEAgeQSELZtL2fn1pKxCjh2ohk7derV33UpetVZwt-DuRQ=s900-c-k-c0x00ffffff-no-rj',
      'subs': '2.3M',
      'watchTime': '5h ago',
      'isNew': false,
    },
    {
      'id': 'UCsBjURrPoezykLs9EqgamOA',
      'name': 'Fireship',
      'avatar':
          'https://yt3.googleusercontent.com/3fPNbkf_xPyCleq77ZhcxyeorY97NtMHVNUbaAON_RBDH9ydL4hJkjxC8x_4mpuopkB8oI7Ct6Y=s900-c-k-c0x00ffffff-no-rj',
      'subs': '3.2M',
      'watchTime': 'Just now',
      'isNew': true,
    },
    {
      'id': 'UCwXdFgeE9KYzlDdR7TG9cMw',
      'name': 'Flutter',
      'avatar':
          'https://yt3.googleusercontent.com/ytc/AIdro_nqx_sCd8ZIeIcodS0sfeMKJ8rVTslmQHUe_udwGNH2Pg=s900-c-k-c0x00ffffff-no-rj',
      'subs': '650K',
      'watchTime': '4h ago',
      'isNew': false,
    },
  ];

  List<Map<String, dynamic>> get _channels {
    final list = <Map<String, dynamic>>[];
    if (SubscriptionService.channels.isNotEmpty) {
      list.addAll(SubscriptionService.channels.map((c) => {
            'id': c.id,
            'name': c.name,
            'avatar': c.avatar,
            'subs': c.subs.isNotEmpty ? c.subs : 'Subscribed',
            'watchTime': 'Subscribed',
            'isNew': true,
          }));
    }
    final existingIds = list.map((c) => c['id']).toSet();
    final existingNames = list.map((c) => c['name']).toSet();
    for (final def in _defaultYouTubeChannels) {
      if (!existingIds.contains(def['id']) &&
          !existingNames.contains(def['name'])) {
        list.add(def);
      }
    }
    return list;
  }

  bool _isConnecting = false;
  Timer? _channelRefreshTimer;

  final Set<String> _unfollowed = {};
  String? _selectedChannelName;

  List<Video> _videos = [];
  bool _isLoading = true;
  String? _nextPageToken;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _scrollController.addListener(_onScroll);
    SubscriptionService.channelsNotifier.addListener(_onSubscriptionsUpdated);
    _loadVideos();
  }

  void _onSubscriptionsUpdated() {
    if (mounted) setState(() {});
  }

  Future<void> _filterByChannel(Map<String, dynamic> ch) async {
    final name = ch['name'] as String;
    final id = ch['id'] as String? ?? '';

    if (_selectedChannelName == name) {
      setState(() {
        _selectedChannelName = null;
        _isLoading = true;
      });
      await _loadVideos();
      return;
    }

    setState(() {
      _selectedChannelName = name;
      _isLoading = true;
    });

    try {
      VideoPage page = VideoPage([], null);
      if (id.isNotEmpty && id.startsWith('UC')) {
        page = await YouTubeService.fetchChannelVideos(id);
      }
      if (page.videos.isEmpty) {
        page = await YouTubeService.searchVideos(name);
      }

      if (mounted) {
        setState(() {
          _videos = page.videos;
          _isLoading = false;
          _nextPageToken = page.nextPageToken;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _connectYouTube() async {
    setState(() => _isConnecting = true);
    final connected = await AuthService.connectYouTube();
    if (mounted) {
      setState(() => _isConnecting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(connected
            ? 'YouTube account connected'
            : 'YouTube account connection was cancelled'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreVideos();
    }
  }

  Future<void> _loadVideos() async {
    setState(() => _isLoading = true);
    try {
      final channels = _channels;
      final allVideos = <Video>[];

      final fetchTasks = channels.take(10).map((ch) async {
        final id = ch['id'] as String? ?? '';
        final name = ch['name'] as String;
        try {
          if (id.isNotEmpty && id.startsWith('UC')) {
            final page = await YouTubeService.fetchChannelVideos(id);
            if (page.videos.isNotEmpty) return page.videos;
          }
          final page = await YouTubeService.searchVideos(name);
          return page.videos;
        } catch (_) {
          return <Video>[];
        }
      });

      final results = await Future.wait(fetchTasks);
      final seenIds = <String>{};

      int maxLen = 0;
      for (final r in results) {
        if (r.length > maxLen) maxLen = r.length;
      }
      for (int i = 0; i < maxLen; i++) {
        for (final list in results) {
          if (i < list.length) {
            final v = list[i];
            if (!seenIds.contains(v.id)) {
              seenIds.add(v.id);
              allVideos.add(v);
            }
          }
        }
      }

      if (allVideos.isEmpty) {
        final pop = await YouTubeService.fetchPopularVideos();
        allVideos.addAll(pop.videos);
      }

      if (mounted) {
        setState(() {
          _videos = allVideos;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMoreVideos() async {
    if (_isLoading) return;
    if (_selectedChannelName != null) {
      final ch = _channels.firstWhere(
        (c) => c['name'] == _selectedChannelName,
        orElse: () => <String, dynamic>{},
      );
      final id = ch['id'] as String? ?? '';
      if (_nextPageToken != null) {
        final page = await YouTubeService.fetchChannelVideos(id, pageToken: _nextPageToken);
        if (mounted && page.videos.isNotEmpty) {
          setState(() {
            _videos.addAll(page.videos);
            _nextPageToken = page.nextPageToken;
          });
        }
      }
    } else {
      if (_nextPageToken != null) {
        final page = await YouTubeService.fetchPopularVideos(pageToken: _nextPageToken);
        if (mounted) {
          setState(() {
            _videos.addAll(page.videos);
            _nextPageToken = page.nextPageToken;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    SubscriptionService.channelsNotifier.removeListener(_onSubscriptionsUpdated);
    _ctrl.dispose();
    _scrollController.dispose();
    _channelRefreshTimer?.cancel();
    super.dispose();
  }

  void _openChannel(Map<String, dynamic> ch) {
    Navigator.push(
      context,
      FadeSlidePageRoute(page: ChannelProfileScreen(channel: ch)),
    );
  }

  Widget _buildChannelAvatar(String url, String name, {double radius = 28}) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'Y';
    return ClipOval(
      child: Container(
        width: radius * 2,
        height: radius * 2,
        color: const Color(0xFF272727),
        child: url.isNotEmpty
            ? Image.network(
                url,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: const Color(0xFFE50914),
                    alignment: Alignment.center,
                    child: Text(
                      initial,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: radius * 0.8,
                      ),
                    ),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: const Color(0xFF272727),
                    child: Center(
                      child: SizedBox(
                        width: radius * 0.7,
                        height: radius * 0.7,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                        ),
                      ),
                    ),
                  );
                },
              )
            : Container(
                color: const Color(0xFFE50914),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: radius * 0.8,
                  ),
                ),
              ),
      ),
    );
  }

  void _showChannelOptions(Map<String, dynamic> ch) {
    final name = ch['name'] as String;
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
                _buildChannelAvatar(ch['avatar'] as String? ?? '', name, radius: 20),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                  Text('${ch['subs']} subscribers',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                ]),
              ]),
            ),
            const Divider(color: Color(0xFF272727), height: 1),
            CapsuleAction(
                icon: Icons.open_in_new,
                label: 'View Channel',
                onTap: () => _openChannel(ch)),
            CapsuleAction(
              icon: _unfollowed.contains(name)
                  ? Icons.add
                  : Icons.person_remove_outlined,
              label: _unfollowed.contains(name) ? 'Follow' : 'Unfollow',
              color: _unfollowed.contains(name) ? Colors.green : Colors.red,
              onTap: () {
                setState(() {
                  if (_unfollowed.contains(name))
                    _unfollowed.remove(name);
                  else
                    _unfollowed.add(name);
                });
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(_unfollowed.contains(name)
                      ? 'Unfollowed $name'
                      : 'Following $name'),
                  backgroundColor: const Color(0xFF1A1A1A),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ));
              },
            ),
            CapsuleAction(
                icon: Icons.message_outlined, label: 'Message', onTap: () {}),
          ],
        ),
      ),
    );
  }

  void _shareVideo(Video video) {
    final shareUrl = YouTubeService.shareUrl(video.id);
    showCapsuleModal(
      context: context,
      child: ShareCapsule(shareUrl: shareUrl, title: video.title),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F0F0F) : Theme.of(context).scaffoldBackgroundColor;
    final txtColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bg,
      body: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                floating: true,
                backgroundColor: bg,
                elevation: 0,
                title: Text('Subscriptions',
                    style: TextStyle(
                        color: txtColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 20)),
                actions: [
                  IconButton(
                    tooltip: 'Connect YouTube account',
                    icon: _isConnecting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.red))
                        : Icon(
                            YouTubeService.isAccountConnected
                                ? Icons.cloud_done
                                : Icons.cloud_off,
                            color: txtColor),
                    onPressed: _isConnecting ? null : _connectYouTube,
                  ),
                  IconButton(
                    icon: Icon(Icons.search, color: txtColor),
                    onPressed: () => Navigator.push(context,
                        FadeSlidePageRoute(page: const SearchScreen())),
                  )
                ],
              ),

              // Channel avatars horizontal scroll
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 110,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _channels.length,
                    itemBuilder: (context, i) {
                      final ch = _channels[i];
                      final name = ch['name'] as String;
                      final isUnfollowed = _unfollowed.contains(name);
                      final isSelected = _selectedChannelName == name;

                      return GestureDetector(
                        onTap: () => _filterByChannel(ch),
                        onLongPress: () => _showChannelOptions(ch),
                        child: AnimatedOpacity(
                          opacity: isUnfollowed ? 0.4 : 1.0,
                          duration: const Duration(milliseconds: 300),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            child: Column(children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.red
                                            : Colors.transparent,
                                        width: isSelected ? 3 : 2,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(2),
                                      child: _buildChannelAvatar(
                                        ch['avatar'] as String? ?? '',
                                        name,
                                        radius: 28,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: -6,
                                    right: -20,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 2),
                                      decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF272727) : const Color(0xFFE0E0E0),
                                          borderRadius:
                                              BorderRadius.circular(6)),
                                      child: Text(ch['watchTime'] as String,
                                          style: TextStyle(
                                              color: isDark ? Colors.white70 : Colors.black87,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(name,
                                  style: TextStyle(
                                      color: isSelected ? Colors.red : txtColor,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 11)),
                              Text(ch['subs'] as String,
                                  style: TextStyle(
                                      color: Colors.grey[500], fontSize: 10)),
                            ]),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Filter banner if channel is selected
              if (_selectedChannelName != null)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.filter_list, color: Colors.red, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Videos by $_selectedChannelName',
                              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedChannelName = null;
                              _isLoading = true;
                            });
                            _loadVideos();
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.close, color: Colors.red, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 4)),
              SliverToBoxAdapter(
                  child: Divider(color: isDark ? const Color(0xFF272727) : const Color(0xFFE0E0E0), height: 1)),

              if (_isLoading)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => const VideoCardSkeleton(),
                    childCount: 4,
                  ),
                )
              else if (_videos.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Text('No videos found', style: TextStyle(color: Colors.grey[500])),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 110),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final video = _videos[index];
                        return VideoCard(
                          video: video,
                          animationIndex: index > 10 ? 0 : index,
                          onShare: () => _shareVideo(video),
                        );
                      },
                      childCount: _videos.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
