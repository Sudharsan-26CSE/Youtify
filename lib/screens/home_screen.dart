import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/video.dart';
import '../widgets/video_card.dart';
import '../widgets/capsule_modal.dart';
import 'search_screen.dart';
import 'profile_screen.dart';
import '../utils/page_transitions.dart';
import '../widgets/donate_bottom_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _selectedCategoryIndex = 0;
  List<String> _categories = [
    'All', 'Gaming', 'Flutter', 'Music', 'Podcasts',
    'Live', 'Programming', 'Tech',
  ];

  late AnimationController _appBarCtrl;
  late Animation<double> _appBarFade;
  late Animation<Offset> _appBarSlide;

  // Mock recent notifications
  final List<Map<String, dynamic>> _notifications = [
    {'icon': Icons.subscriptions, 'title': 'CodeMaster uploaded a new video', 'time': '2m ago', 'color': Colors.red},
    {'icon': Icons.live_tv, 'title': 'FlutterDevs is live now!', 'time': '15m ago', 'color': Colors.red},
    {'icon': Icons.thumb_up, 'title': 'Your video got 100 likes', 'time': '1h ago', 'color': Colors.blue},
    {'icon': Icons.comment, 'title': 'Someone replied to your comment', 'time': '3h ago', 'color': Colors.green},
    {'icon': Icons.person_add, 'title': 'TechGuru subscribed to you', 'time': '1d ago', 'color': Colors.purple},
  ];

  List<Video> get _filteredVideos {
    if (_selectedCategoryIndex == 0) return Video.sampleVideos;
    final cat = _categories[_selectedCategoryIndex];
    return Video.sampleVideos.where((v) => v.category == cat).toList();
  }

  @override
  void initState() {
    super.initState();
    _appBarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _appBarFade = CurvedAnimation(parent: _appBarCtrl, curve: Curves.easeOut);
    _appBarSlide = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _appBarCtrl, curve: Curves.easeOutCubic));
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('home_categories');
    if (saved != null && saved.isNotEmpty) {
      setState(() => _categories = saved);
    }
  }

  Future<void> _saveCategories() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('home_categories', _categories);
  }

  @override
  void dispose() {
    _appBarCtrl.dispose();
    super.dispose();
  }

  void _showNotifications() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Notifications',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, __, child) {
        return FadeTransition(
          opacity: anim,
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 80, right: 12, left: 40),
              child: Material(
                color: Colors.transparent,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A).withOpacity(0.95),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.1), width: 1),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.4),
                              blurRadius: 24,
                              offset: const Offset(0, 8))
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Notifications',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                                GestureDetector(
                                  onTap: () => Navigator.pop(ctx),
                                  child: Icon(Icons.close,
                                      color: Colors.grey[500], size: 20),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: Color(0xFF272727)),
                          ..._notifications.map((n) => _NotifTile(
                                icon: n['icon'] as IconData,
                                title: n['title'] as String,
                                time: n['time'] as String,
                                color: n['color'] as Color,
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
                  const Text('Edit Categories',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
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
              Text('Long-press to reorder. Tap × to remove.',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.asMap().entries.map((entry) {
                  final i = entry.key;
                  final cat = entry.value;
                  return GestureDetector(
                    onLongPress: () {/* reorder handled by user drag */},
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: Colors.red.withOpacity(0.4)),
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
                children: ['News', 'Sports', 'Comedy', 'Education', 'Food', 'Travel']
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
                              color: Colors.white.withOpacity(0.07),
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
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // AppBar with entry animation
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: const Color(0xFF0F0F0F),
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
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.4),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.play_arrow,
                              color: Colors.white, size: 20),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Youtify',
                        style: TextStyle(
                          color: Colors.white,
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
              // Notification bell
              FadeTransition(
                opacity: _appBarFade,
                child: IconButton(
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.notifications_outlined,
                          color: Colors.white, size: 24),
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              color: Colors.red, shape: BoxShape.circle),
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
                  icon: const Icon(Icons.search, color: Colors.white, size: 22),
                  onPressed: () {
                    Navigator.push(
                        context, FadeSlidePageRoute(page: const SearchScreen()));
                  },
                ),
              ),
              // Avatar
              FadeTransition(
                opacity: _appBarFade,
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                        context,
                        SlideRightPageRoute(page: const ProfileScreen()));
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: ClipOval(
                      child: Container(
                        width: 30,
                        height: 30,
                        color: Colors.grey[700],
                        child: Image.network(
                          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=200&auto=format&fit=crop',
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

          // Category chips with edit on long-press
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
                            onTap: () => setState(
                                () => _selectedCategoryIndex = index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF272727),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _categories[index],
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.black
                                      : Colors.white,
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
                  // Edit categories button
                  GestureDetector(
                    onTap: _showEditCategories,
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF272727),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.15), width: 1),
                      ),
                      child: const Icon(Icons.tune,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Video list with staggered entry animations
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 110),
            sliver: _filteredVideos.isEmpty
                ? SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(60),
                      child: Column(
                        children: [
                          Icon(Icons.video_library_outlined,
                              color: Colors.grey[600], size: 64),
                          const SizedBox(height: 16),
                          Text(
                            'No videos in this category',
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
                        final video = _filteredVideos[
                            index % _filteredVideos.length];
                        return VideoCard(
                          video: video,
                          animationIndex: index,
                        );
                      },
                      childCount: _filteredVideos.isEmpty
                          ? 0
                          : 10,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String time;
  final Color color;
  final VoidCallback onTap;

  const _NotifTile({
    required this.icon,
    required this.title,
    required this.time,
    required this.color,
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
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13, height: 1.3)),
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
