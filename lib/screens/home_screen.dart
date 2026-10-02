import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/video.dart';
import '../widgets/video_card.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/capsule_modal.dart';
import 'search_screen.dart';
import 'profile_screen.dart';
import '../utils/page_transitions.dart';
import '../widgets/donate_bottom_sheet.dart';
import '../services/youtube_service.dart';
import '../services/user_data_service.dart';
import '../services/subscription_service.dart';
import 'feedback_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _selectedCategoryIndex = 0;
  List<String> _categories = [
    'All',
    'Gaming',
    'Flutter',
    'Music',
    'Podcasts',
    'Live',
    'Programming',
    'Tech',
  ];

  late AnimationController _appBarCtrl;
  late Animation<double> _appBarFade;
  late Animation<Offset> _appBarSlide;

  List<Map<String, dynamic>> _notifications = [];

  List<Video> _videos = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _nextPageToken;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _appBarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _appBarFade = CurvedAnimation(parent: _appBarCtrl, curve: Curves.easeOut);
    _appBarSlide = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _appBarCtrl, curve: Curves.easeOutCubic));

    _scrollController.addListener(_onScroll);
    _initNotifications();
    _loadCategories();

    UserDataService.addListener(_onUserDataChanged);
  }

  void _onUserDataChanged() {
    if (mounted) setState(() {});
  }

  void _initNotifications() {
    _notifications = [
      {
        'id': '1',
        'icon': Icons.subscriptions,
        'title': 'New video from subscribed channels',
        'time': 'Just now',
        'color': Colors.red,
        'read': false
      },
      {
        'id': '2',
        'icon': Icons.thumb_up,
        'title': 'Your liked video list updated',
        'time': '12m ago',
        'color': Colors.blue,
        'read': false
      },
      {
        'id': '3',
        'icon': Icons.download_done,
        'title': 'Offline downloads ready for viewing',
        'time': '1h ago',
        'color': Colors.green,
        'read': false
      },
      {
        'id': '4',
        'icon': Icons.star,
        'title': 'Welcome to Youtify! Enjoy ad-free streaming',
        'time': '1d ago',
        'color': Colors.amber,
        'read': true
      },
    ];
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500) {
      _loadMoreVideos();
    }
  }

  Future<void> _loadVideos() async {
    setState(() {
      _isLoading = true;
      _nextPageToken = null;
    });

    try {
      VideoPage page;
      if (_selectedCategoryIndex == 0 && _categories[0] == 'All') {
        page = await YouTubeService.fetchPopularVideos();
      } else {
        page = await YouTubeService.searchVideos(
            _categories[_selectedCategoryIndex]);
      }

      if (mounted) {
        setState(() {
          _videos = page.videos.isNotEmpty ? page.videos : Video.sampleVideos;
          _nextPageToken = page.nextPageToken;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _videos = Video.sampleVideos;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreVideos() async {
    if (_isLoadingMore || _nextPageToken == null || _isLoading) return;

    setState(() => _isLoadingMore = true);
    try {
      VideoPage page;
      if (_selectedCategoryIndex == 0 && _categories[0] == 'All') {
        page =
            await YouTubeService.fetchPopularVideos(pageToken: _nextPageToken);
      } else {
        page = await YouTubeService.searchVideos(
            _categories[_selectedCategoryIndex],
            pageToken: _nextPageToken);
      }

      if (mounted) {
        setState(() {
          final existingIds = _videos.map((v) => v.id).toSet();
          final newVideos =
              page.videos.where((v) => !existingIds.contains(v.id)).toList();
          _videos.addAll(newVideos);
          _nextPageToken = page.nextPageToken;
          _isLoadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('home_categories');
    if (saved != null && saved.isNotEmpty) {
      setState(() => _categories = saved);
    }
    final lastSearch = prefs.getString('last_search');
    if (lastSearch != null && lastSearch.isNotEmpty) {
      if (!_categories.contains(lastSearch)) {
        setState(() => _categories.insert(1, lastSearch));
      }
    }
    _loadVideos();
  }

  Future<void> _saveCategories() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('home_categories', _categories);
  }

  @override
  void dispose() {
    UserDataService.removeListener(_onUserDataChanged);
    _appBarCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showNotifications() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Notifications',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, __, child) {
        return FadeTransition(
          opacity: anim,
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 80, right: 12, left: 36),
              child: Material(
                color: Colors.transparent,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: dialogBg.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.1),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          )
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Notifications',
                                  style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Row(
                                  children: [
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          for (var n in _notifications) {
                                            n['read'] = true;
                                          }
                                        });
                                        Navigator.pop(ctx);
                                      },
                                      child: const Text('Mark read',
                                          style: TextStyle(
                                              color: Colors.redAccent,
                                              fontSize: 12)),
                                    ),
                                    GestureDetector(
                                      onTap: () => Navigator.pop(ctx),
                                      child: Icon(Icons.close,
                                          color: Colors.grey[500], size: 20),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Divider(
                            height: 1,
                            color: isDark
                                ? const Color(0xFF272727)
                                : Colors.black.withValues(alpha: 0.08),
                          ),
                          ..._notifications.map((n) => _NotifTile(
                                icon: n['icon'] as IconData,
                                title: n['title'] as String,
                                time: n['time'] as String,
                                color: n['color'] as Color,
                                textColor: textColor,
                                isDark: isDark,
                                onTap: () => Navigator.pop(ctx),
                              )),
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

  void _showEditCategories() {
    showCapsuleModal(
      context: context,
      child: StatefulBuilder(
        builder: (ctx, setInner) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Edit Categories',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      _saveCategories();
                      Navigator.pop(ctx);
                    },
                    child: const Text('Done',
                        style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('Tap category to filter. Tap × to remove.',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.asMap().entries.map((entry) {
                  final i = entry.key;
                  final cat = entry.value;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: Colors.red.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(cat,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13)),
                        if (i > 0) ...[
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              setInner(() => _categories.removeAt(i));
                              setState(() {});
                            },
                            child: Icon(Icons.close,
                                size: 14, color: Colors.grey[400]),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFF272727)),
              const SizedBox(height: 8),
              const Text('Add Category',
                  style: TextStyle(
                      color: Colors.grey, fontSize: 12, letterSpacing: 1)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  'News',
                  'Sports',
                  'Comedy',
                  'Education',
                  'Food',
                  'Travel'
                ]
                    .where((c) => !_categories.contains(c))
                    .map((c) => GestureDetector(
                          onTap: () {
                            setInner(() => _categories.add(c));
                            setState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add,
                                    size: 14, color: Colors.grey[400]),
                                const SizedBox(width: 4),
                                Text(c,
                                    style: TextStyle(
                                        color: Colors.grey[300], fontSize: 13)),
                              ],
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F0F0F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    final user = FirebaseAuth.instance.currentUser;
    final photoUrl = UserDataService.profilePhotoUrl.isNotEmpty
        ? UserDataService.profilePhotoUrl
        : (user?.photoURL ??
            'https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=200&auto=format&fit=crop');

    return Scaffold(
      backgroundColor: bgColor,
      body: RefreshIndicator(
        onRefresh: _loadVideos,
        color: Colors.red,
        backgroundColor: isDark ? const Color(0xFF212121) : Colors.white,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // AppBar
            SliverAppBar(
              floating: true,
              snap: true,
              backgroundColor: bgColor,
              elevation: 0,
              title: SlideTransition(
                position: _appBarSlide,
                child: FadeTransition(
                  opacity: _appBarFade,
                  child: GestureDetector(
                    onTap: () => showDonateSheet(context),
                    child: Row(
                      children: [
                        Hero(
                          tag: 'youtify_logo',
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              'assets/images/app_icon.png',
                              width: 28,
                              height: 28,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Youtify',
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                // Feedback star
                FadeTransition(
                  opacity: _appBarFade,
                  child: IconButton(
                    icon: const Icon(Icons.star_outline_rounded,
                        color: Colors.amber, size: 24),
                    onPressed: () => Navigator.push(
                        context, FadeSlidePageRoute(page: const FeedbackScreen())),
                  ),
                ),
                // Notification bell with badge
                FadeTransition(
                  opacity: _appBarFade,
                  child: IconButton(
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(Icons.notifications_outlined,
                            color: textColor, size: 24),
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                    onPressed: _showNotifications,
                  ),
                ),
                // Search
                FadeTransition(
                  opacity: _appBarFade,
                  child: IconButton(
                    icon: Icon(Icons.search, color: textColor, size: 22),
                    onPressed: () {
                      Navigator.push(context,
                          FadeSlidePageRoute(page: const SearchScreen()));
                    },
                  ),
                ),
                // Profile Avatar from UserDataService
                FadeTransition(
                  opacity: _appBarFade,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(context,
                          SlideRightPageRoute(page: const ProfileScreen()));
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: ClipOval(
                        child: Container(
                          width: 32,
                          height: 32,
                          color: Colors.grey[700],
                          child: Image.network(
                            photoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.person,
                                    color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Category chips
            SliverToBoxAdapter(
              child: SizedBox(
                height: 52,
                child: Row(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        itemCount: _categories.length,
                        itemBuilder: (context, index) {
                          final isSelected = _selectedCategoryIndex == index;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () {
                                if (_selectedCategoryIndex != index) {
                                  setState(
                                      () => _selectedCategoryIndex = index);
                                  _loadVideos();
                                }
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOutCubic,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? (isDark ? Colors.white : Colors.black87)
                                      : (isDark
                                          ? const Color(0xFF272727)
                                          : const Color(0xFFEFEFEF)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _categories[index],
                                  style: TextStyle(
                                    color: isSelected
                                        ? (isDark
                                            ? Colors.black
                                            : Colors.white)
                                        : (isDark
                                            ? Colors.white
                                            : Colors.black87),
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Edit categories
                    GestureDetector(
                      onTap: _showEditCategories,
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF272727)
                              : const Color(0xFFEFEFEF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.15)
                                : Colors.black.withValues(alpha: 0.1),
                            width: 1,
                          ),
                        ),
                        child: Icon(Icons.tune, color: textColor, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Video List
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 110),
              sliver: _isLoading
                  ? SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => const VideoCardSkeleton(),
                        childCount: 4,
                      ),
                    )
                  : _videos.isEmpty
                      ? SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(60),
                            child: Column(
                              children: [
                                Icon(Icons.video_library_outlined,
                                    color: Colors.grey[600], size: 64),
                                const SizedBox(height: 16),
                                Text(
                                  'No videos found',
                                  style: TextStyle(
                                      color: Colors.grey[500], fontSize: 15),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              return VideoCard(
                                video: _videos[index],
                                animationIndex: index > 8 ? 0 : index,
                              );
                            },
                            childCount: _videos.length,
                          ),
                        ),
            ),
            if (_isLoadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 120),
                  child: CompactVideoSkeleton(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String time;
  final Color color;
  final Color textColor;
  final bool isDark;
  final VoidCallback onTap;

  const _NotifTile({
    required this.icon,
    required this.title,
    required this.time,
    required this.color,
    required this.textColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(time,
                      style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
