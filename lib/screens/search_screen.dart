import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/video.dart';
import '../widgets/video_card.dart';
import '../services/youtube_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Video> _searchResults = [];
  bool _hasSearched = false;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _nextPageToken;

  List<String> _recentSearches = [];

  final List<String> _trendingSearches = [
    'Flutter 2026 Tutorial',
    'Lo-Fi Coding Beats',
    'Advanced State Management',
    'Building YouTube Clone',
    'Dart 3 Masterclass',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadSearchHistory();
  }

  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('recent_searches') ?? [];
    setState(() => _recentSearches = saved);
  }

  Future<void> _saveSearchHistory(String query) async {
    if (query.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    _recentSearches.remove(query);
    _recentSearches.insert(0, query);
    if (_recentSearches.length > 15) _recentSearches = _recentSearches.sublist(0, 15);
    await prefs.setStringList('recent_searches', _recentSearches);
    await prefs.setString('last_search', query);
  }

  Future<void> _removeRecentSearch(String query) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _recentSearches.remove(query));
    await prefs.setStringList('recent_searches', _recentSearches);
  }

  Future<void> _clearAllRecent() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _recentSearches.clear());
    await prefs.setStringList('recent_searches', []);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _nextPageToken == null || _isLoading) return;
    setState(() => _isLoadingMore = true);

    final page = await YouTubeService.searchVideos(_searchController.text, pageToken: _nextPageToken);
    
    if (mounted) {
      setState(() {
        _searchResults.addAll(page.videos);
        _nextPageToken = page.nextPageToken;
        _isLoadingMore = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
        _isLoading = false;
        _nextPageToken = null;
      });
      return;
    }
    
    await _saveSearchHistory(query);

    setState(() {
      _hasSearched = true;
      _isLoading = true;
      _nextPageToken = null;
    });
    
    final page = await YouTubeService.searchVideos(query);
    
    if (mounted) {
      setState(() {
        _searchResults = page.videos;
        _nextPageToken = page.nextPageToken;
        _isLoading = false;
      });
    }
  }

  void _showVideoOptions(Video video) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Options',
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
                        color: const Color(0xFF1A1A1A).withOpacity(0.88),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 24, offset: const Offset(0, 8)),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Video info header
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(video.thumbnailUrl, width: 60, height: 40, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(width: 60, height: 40, color: Colors.grey[800]),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(color: Color(0xFF272727), height: 1),
                          _GlassyOption(icon: Icons.play_circle_outline, label: 'Play Now', onTap: () => Navigator.pop(ctx)),
                          _GlassyOption(icon: Icons.playlist_add, label: 'Add to Playlist', onTap: () => Navigator.pop(ctx)),
                          _GlassyOption(icon: Icons.download_outlined, label: 'Download', onTap: () => Navigator.pop(ctx)),
                          _GlassyOption(icon: Icons.share_outlined, label: 'Share', onTap: () => Navigator.pop(ctx)),
                          _GlassyOption(icon: Icons.not_interested, label: 'Not Interested', color: Colors.orange, onTap: () => Navigator.pop(ctx)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search Youtify...',
            hintStyle: TextStyle(color: Colors.grey[500]),
            border: InputBorder.none,
          ),
          onSubmitted: _performSearch,
          onChanged: _performSearch,
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.white),
              onPressed: () {
                _searchController.clear();
                _performSearch('');
              },
            ),
        ],
      ),
      body: _hasSearched
          ? _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.red))
              : _searchResults.isEmpty
                  ? Center(
                      child: Text(
                        'No results found for "${_searchController.text}"',
                        style: TextStyle(color: Colors.grey[400], fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: _searchResults.length + (_isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _searchResults.length) {
                          return const Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Center(child: CircularProgressIndicator(color: Colors.red)),
                          );
                        }
                        return GestureDetector(
                          onLongPress: () => _showVideoOptions(_searchResults[index]),
                          child: VideoCard(video: _searchResults[index]),
                        );
                      },
                    )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Recent Searches
                if (_recentSearches.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Searches',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      GestureDetector(
                        onTap: _clearAllRecent,
                        child: Text('Clear All', style: TextStyle(color: Colors.red[300], fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._recentSearches.map((term) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history, color: Colors.grey),
                    title: Text(term, style: const TextStyle(color: Colors.white)),
                    trailing: IconButton(
                      icon: Icon(Icons.close, color: Colors.grey[600], size: 18),
                      onPressed: () => _removeRecentSearch(term),
                    ),
                    onTap: () {
                      _searchController.text = term;
                      _performSearch(term);
                    },
                  )),
                  const Divider(color: Color(0xFF272727), height: 24),
                ],

                // Trending
                const Text(
                  'Trending Searches',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ..._trendingSearches.map((term) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.trending_up, color: Colors.grey),
                      title: Text(term, style: const TextStyle(color: Colors.white)),
                      onTap: () {
                        _searchController.text = term;
                        _performSearch(term);
                      },
                    )),
              ],
            ),
    );
  }
}

class _GlassyOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _GlassyOption({required this.icon, required this.label, this.color = Colors.white, required this.onTap});

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
