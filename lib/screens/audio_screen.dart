import 'package:flutter/material.dart';
import '../models/album.dart';
import '../models/video.dart';
import '../services/album_service.dart';
import '../services/audio_player_service.dart';
import '../services/youtube_service.dart';
import '../widgets/skeleton_loader.dart';
import 'audio_player_screen.dart';

class AudioScreen extends StatefulWidget {
  const AudioScreen({super.key});

  @override
  State<AudioScreen> createState() => _AudioScreenState();
}

class _AudioScreenState extends State<AudioScreen> {
  final AudioPlayerService _player = AudioPlayerService.instance;
  final AlbumService _albumService = AlbumService.instance;

  final List<String> _languages = [
    'All',
    'English',
    'Hindi',
    'Tamil',
    'Telugu',
    'Punjabi',
    'Malayalam',
    'K-Pop',
    'Spanish',
    'Lo-Fi',
    'Pop',
    'Rock',
  ];

  String _selectedLanguage = 'All';

  List<Video> _trendingSongs = [];
  List<Video> _categorySongs = [];
  List<Video> _searchResults = [];

  bool _isLoadingTrending = true;
  bool _isLoadingCategory = true;
  bool _isSearching = false;
  bool _searchActive = false;

  final TextEditingController _searchController = TextEditingController();

  static const List<List<Color>> _albumGradients = [
    [Color(0xFFFF1A35), Color(0xFF7A0014)],
    [Color(0xFF8A2387), Color(0xFFE94057)],
    [Color(0xFF11998E), Color(0xFF38EF7D)],
    [Color(0xFF2193B0), Color(0xFF6DD5ED)],
    [Color(0xFFF12711), Color(0xFFF5AF19)],
    [Color(0xFF654EA3), Color(0xFFEAAFC8)],
  ];

  @override
  void initState() {
    super.initState();
    _albumService.init();
    _loadTrending();
    _loadCategorySongs(_selectedLanguage);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTrending() async {
    setState(() => _isLoadingTrending = true);
    final songs = await YouTubeService.fetchTrendingMusic();
    if (mounted) {
      setState(() {
        _trendingSongs = songs;
        _isLoadingTrending = false;
      });
    }
  }

  Future<void> _loadCategorySongs(String language) async {
    setState(() => _isLoadingCategory = true);
    final songs = await YouTubeService.fetchSongsByLanguage(language);
    if (mounted) {
      setState(() {
        _categorySongs = songs;
        _isLoadingCategory = false;
      });
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    final results = await YouTubeService.searchSongs(query.trim());
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  void _openPlayer(Video song, List<Video> playlist) {
    _player.playSong(song, playlist: playlist);
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, anim, secondaryAnim) => AudioPlayerScreen(
          initialSong: song,
          playlist: playlist,
        ),
        transitionsBuilder: (context, anim, secondaryAnim, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .chain(CurveTween(curve: Curves.easeOutCubic))
                .animate(anim),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0C0D14) : const Color(0xFFF7F8FA);
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // App Bar / Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFF1A35),
                                    Color(0xFFC40028),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF1A35)
                                        .withValues(alpha: 0.4),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.music_note,
                                  color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Music',
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                Text(
                                  'Youtify Audio Experience',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.black54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            // Create Album (+) Button
                            IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF1A35)
                                      .withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFFF1A35)
                                        .withValues(alpha: 0.4),
                                    width: 1.2,
                                  ),
                                ),
                                child: const Icon(Icons.add,
                                    color: Color(0xFFFF1A35), size: 18),
                              ),
                              tooltip: 'Create Album',
                              onPressed: _showCreateAlbumDialog,
                            ),
                            // Search Icon Button
                            IconButton(
                              icon: Icon(
                                _searchActive ? Icons.close : Icons.search,
                                color: textColor,
                                size: 26,
                              ),
                              onPressed: () {
                                setState(() {
                                  _searchActive = !_searchActive;
                                  if (!_searchActive) {
                                    _searchController.clear();
                                    _searchResults = [];
                                  }
                                });
                              },
                            ),
                          ],
                        ),

                        // Expandable Search Bar
                        if (_searchActive) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E202C)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? Colors.white12 : Colors.black12,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.search,
                                    color: Color(0xFFFF1A35), size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    autofocus: true,
                                    style: TextStyle(
                                        color: textColor, fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText:
                                          'Search songs, artists, or audio...',
                                      hintStyle: TextStyle(
                                        color: isDark
                                            ? Colors.white38
                                            : Colors.black38,
                                        fontSize: 14,
                                      ),
                                      border: InputBorder.none,
                                    ),
                                    onSubmitted: _performSearch,
                                  ),
                                ),
                                if (_searchController.text.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.black54,
                                    onPressed: () {
                                      _searchController.clear();
                                      _performSearch('');
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Search Results View if Searching
                if (_searchActive &&
                    (_isSearching ||
                        _searchResults.isNotEmpty ||
                        _searchController.text.isNotEmpty)) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'Search Results',
                        style: TextStyle(
                            color: textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  if (_isSearching)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFFFF1A35))),
                      ),
                    )
                  else if (_searchResults.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: Text(
                            'No songs found for "${_searchController.text}"',
                            style: TextStyle(
                                color:
                                    isDark ? Colors.white54 : Colors.black54),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final song = _searchResults[index];
                          return _buildSongListTile(
                              song, _searchResults, isDark, textColor);
                        },
                        childCount: _searchResults.length,
                      ),
                    ),
                ] else ...[
                  // ── Categories & Languages Filter Chips (At Top for Instant Access) ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      child: SizedBox(
                        height: 44,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _languages.length,
                          itemBuilder: (context, index) {
                            final lang = _languages[index];
                            final isSelected = _selectedLanguage == lang;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(lang),
                                selected: isSelected,
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark
                                          ? Colors.white70
                                          : Colors.black87),
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  fontSize: 13,
                                ),
                                selectedColor: const Color(0xFFFF1A35),
                                backgroundColor: isDark
                                    ? const Color(0xFF1E202C)
                                    : Colors.black.withValues(alpha: 0.06),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                                side: BorderSide.none,
                                onSelected: (selected) {
                                  final newLang = selected ? lang : 'All';
                                  if (_selectedLanguage != newLang) {
                                    setState(() => _selectedLanguage = newLang);
                                    _loadCategorySongs(newLang);
                                  }
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  // ── WHEN A SPECIFIC LANGUAGE IS CHOSEN (NOT 'All'): SHOW THAT LANGUAGE MUSIC LIST ONLY! ──
                  if (_selectedLanguage != 'All') ...[
                    // Language Header Card with Play All
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isDark
                                  ? [
                                      const Color(0xFFFF1A35).withValues(alpha: 0.25),
                                      const Color(0xFF161822),
                                    ]
                                  : [
                                      const Color(0xFFFF1A35).withValues(alpha: 0.12),
                                      Colors.white,
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFFF1A35).withValues(alpha: 0.3),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFFF1A35), Color(0xFFC40028)],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFF1A35).withValues(alpha: 0.4),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.music_note_rounded,
                                    color: Colors.white, size: 28),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$_selectedLanguage Music',
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _isLoadingCategory
                                          ? 'Fetching $_selectedLanguage tracks...'
                                          : '${_categorySongs.length} songs available',
                                      style: TextStyle(
                                        color: isDark ? Colors.white54 : Colors.black54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!_isLoadingCategory && _categorySongs.isNotEmpty)
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF1A35),
                                    foregroundColor: Colors.white,
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20)),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 8),
                                  ),
                                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                                  label: const Text('Play All',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold, fontSize: 13)),
                                  onPressed: () =>
                                      _openPlayer(_categorySongs.first, _categorySongs),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Language songs list only
                    if (_isLoadingCategory)
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => const CompactVideoSkeleton(),
                          childCount: 4,
                        ),
                      )
                    else if (_categorySongs.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Center(
                            child: Text(
                              'No songs found for $_selectedLanguage',
                              style: TextStyle(
                                  color: isDark ? Colors.white54 : Colors.black54),
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final song = _categorySongs[index];
                              return _buildSongListTile(
                                  song, _categorySongs, isDark, textColor);
                            },
                            childCount: _categorySongs.length,
                          ),
                        ),
                      ),
                  ] else ...[
                    // ── WHEN "All" IS SELECTED: SHOW COMPLETE OVERVIEW ──

                    // Section 1: Trending Hits
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Row(
                          children: [
                            const Text('🔥', style: TextStyle(fontSize: 18)),
                            const SizedBox(width: 8),
                            Text(
                              'Trending Hits',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 200,
                        child: _isLoadingTrending
                            ? const Center(
                                child: CircularProgressIndicator(
                                    color: Color(0xFFFF1A35), strokeWidth: 2))
                            : ListView.builder(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                itemCount: _trendingSongs.length,
                                itemBuilder: (context, index) {
                                  final song = _trendingSongs[index];
                                  return _buildTrendingCard(
                                      song, _trendingSongs, isDark, textColor);
                                },
                              ),
                      ),
                    ),

                    // Section 2: Recently Played
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                        child: Row(
                          children: [
                            const Icon(Icons.history,
                                color: Color(0xFFFF1A35), size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Recently Played',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: ValueListenableBuilder<List<Video>>(
                        valueListenable: _player.recentSongsNotifier,
                        builder: (context, recentSongs, _) {
                          if (recentSongs.isEmpty) {
                            return _buildEmptyRecentCard(isDark);
                          }
                          return SizedBox(
                            height: 175,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              itemCount: recentSongs.length,
                              itemBuilder: (context, index) {
                                final song = recentSongs[index];
                                return _buildRecentCard(
                                    song, recentSongs, isDark, textColor);
                              },
                            ),
                          );
                        },
                      ),
                    ),

                    // Section 2.5: Your Albums
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                        child: Row(
                          children: [
                            const Icon(Icons.album_rounded,
                                color: Color(0xFFFF1A35), size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Your Albums',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: _showCreateAlbumDialog,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF1A35)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.add,
                                        color: Color(0xFFFF1A35), size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      'New',
                                      style: TextStyle(
                                        color: Color(0xFFFF1A35),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: ValueListenableBuilder<List<Album>>(
                        valueListenable: _albumService.albumsNotifier,
                        builder: (context, albums, _) {
                          if (albums.isEmpty) {
                            return _buildEmptyAlbumsCard(isDark);
                          }
                          return SizedBox(
                            height: 195,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              itemCount: albums.length,
                              itemBuilder: (context, index) {
                                final album = albums[index];
                                return _buildAlbumCard(
                                    album, isDark, textColor);
                              },
                            ),
                          );
                        },
                      ),
                    ),

                    // Section 3: Recommended Hits
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                        child: Row(
                          children: [
                            const Icon(Icons.recommend_rounded,
                                color: Color(0xFFFF1A35), size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Recommended Hits',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_isLoadingCategory)
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => const CompactVideoSkeleton(),
                          childCount: 4,
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final song = _categorySongs[index];
                              return _buildSongListTile(
                                  song, _categorySongs, isDark, textColor);
                            },
                            childCount: _categorySongs.length,
                          ),
                        ),
                      ),
                  ],
                ],
              ],
            ),
          ),

          // Floating Spotify-style Mini Player Bar (above bottom capsule nav bar)
          Positioned(
            left: 16,
            right: 16,
            bottom: 96,
            child: _buildFloatingMiniPlayer(isDark),
          ),
        ],
      ),
    );
  }

  // ── Trending Card ──────────────────────────────────────────────────────────
  Widget _buildTrendingCard(
      Video song, List<Video> playlist, bool isDark, Color textColor) {
    return GestureDetector(
      onTap: () => _openPlayer(song, playlist),
      child: Container(
        width: 140,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161822) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Image.network(
                    song.thumbnailUrl,
                    width: 140,
                    height: 115,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        width: 140, height: 115, color: Colors.grey[900]),
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF1A35),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF1A35).withValues(alpha: 0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.play_arrow,
                        color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    song.channelName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black54,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Recently Played Card ───────────────────────────────────────────────────
  Widget _buildRecentCard(
      Video song, List<Video> playlist, bool isDark, Color textColor) {
    return GestureDetector(
      onTap: () => _openPlayer(song, playlist),
      child: Container(
        width: 120,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161822) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              child: Image.network(
                song.thumbnailUrl,
                width: 120,
                height: 95,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(width: 120, height: 95, color: Colors.grey[900]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: textColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.channelName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black54,
                        fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Clean Spotify Empty State Card ─────────────────────────────────────────
  Widget _buildEmptyRecentCard(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151722) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFF1A35).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.music_note,
                color: Color(0xFFFF1A35), size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No recently played tracks',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Explore trending songs or select a language to start listening!',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty Albums Card ──────────────────────────────────────────────────────
  Widget _buildEmptyAlbumsCard(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151722) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFF1A35).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.album_outlined,
                color: Color(0xFFFF1A35), size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No albums yet',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Create personal albums to collect your favorite music tracks!',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black54,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _showCreateAlbumDialog,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF1A35), Color(0xFFC40028)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFFFF1A35).withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Create Album',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Album Card ─────────────────────────────────────────────────────────────
  Widget _buildAlbumCard(Album album, bool isDark, Color textColor) {
    final gradientColors =
        _albumGradients[album.gradientColorIndex % _albumGradients.length];

    return GestureDetector(
      onTap: () => _openAlbumDetails(album),
      child: Container(
        width: 135,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161822) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Art with Gradient & Vinyl Icon
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Container(
                    width: 135,
                    height: 110,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: gradientColors,
                      ),
                    ),
                    child: album.coverUrl != null && album.coverUrl!.isNotEmpty
                        ? Image.network(
                            album.coverUrl!,
                            width: 135,
                            height: 110,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.album,
                                  color: Colors.white60, size: 48),
                            ),
                          )
                        : const Center(
                            child: Icon(Icons.album_rounded,
                                color: Colors.white70, size: 48),
                          ),
                  ),
                ),
                // Song count pill badge
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${album.songs.length} tracks',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                // Play button if album has tracks
                if (album.songs.isNotEmpty)
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: GestureDetector(
                      onTap: () => _openPlayer(album.songs.first, album.songs),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF1A35),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF1A35)
                                  .withValues(alpha: 0.5),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.play_arrow,
                            color: Colors.white, size: 16),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    album.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    album.description.isNotEmpty
                        ? album.description
                        : '${album.songs.length} songs',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black54,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Create Album Dialog ────────────────────────────────────────────────────
  void _showCreateAlbumDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    int selectedGrad = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161824) : Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFFF1A35).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.album_rounded,
                            color: Color(0xFFFF1A35), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Create New Album',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleCtrl,
                    autofocus: true,
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Album Title',
                      labelStyle: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black54),
                      hintText: 'e.g. Chill Vibes, Morning Hits...',
                      hintStyle: TextStyle(
                          color: isDark ? Colors.white30 : Colors.black38),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF1E2030)
                          : Colors.grey.withValues(alpha: 0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Description (Optional)',
                      labelStyle: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black54),
                      hintText: 'Add an optional description',
                      hintStyle: TextStyle(
                          color: isDark ? Colors.white30 : Colors.black38),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF1E2030)
                          : Colors.grey.withValues(alpha: 0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Cover Theme',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _albumGradients.length,
                      itemBuilder: (ctx, i) {
                        final isSel = selectedGrad == i;
                        return GestureDetector(
                          onTap: () => setModalState(() => selectedGrad = i),
                          child: Container(
                            width: 40,
                            height: 40,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: _albumGradients[i],
                              ),
                              border: isSel
                                  ? Border.all(color: Colors.white, width: 3)
                                  : null,
                              boxShadow: isSel
                                  ? [
                                      BoxShadow(
                                        color:
                                            Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 6,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: isSel
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 20)
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF1A35),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () async {
                            final name = titleCtrl.text.trim();
                            if (name.isEmpty) return;
                            Navigator.of(ctx).pop();
                            await _albumService.createAlbum(
                              name,
                              description: descCtrl.text.trim(),
                              gradientColorIndex: selectedGrad,
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Album "$name" created! 💿'),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: const Color(0xFF1E202C),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                ),
                              );
                            }
                          },
                          child: const Text(
                            'Create Album',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Open Album Details Sheet ───────────────────────────────────────────────
  void _openAlbumDetails(Album initialAlbum) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return ValueListenableBuilder<List<Album>>(
          valueListenable: _albumService.albumsNotifier,
          builder: (context, allAlbums, _) {
            final album = allAlbums.firstWhere(
              (a) => a.id == initialAlbum.id,
              orElse: () => initialAlbum,
            );
            final gradientColors = _albumGradients[
                album.gradientColorIndex % _albumGradients.length];

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF141522) : Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Album Header Banner
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: gradientColors),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: gradientColors.first
                                    .withValues(alpha: 0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: album.coverUrl != null &&
                                  album.coverUrl!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.network(
                                    album.coverUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                        Icons.album,
                                        color: Colors.white,
                                        size: 36),
                                  ),
                                )
                              : const Icon(Icons.album_rounded,
                                  color: Colors.white, size: 36),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                album.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white
                                      : Colors.black87,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${album.songs.length} tracks • ${album.description.isNotEmpty ? album.description : "Personal Album"}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Delete album button
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.redAccent, size: 22),
                          tooltip: 'Delete Album',
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (dCtx) => AlertDialog(
                                backgroundColor: isDark
                                    ? const Color(0xFF1E202E)
                                    : Colors.white,
                                title: const Text('Delete Album?'),
                                content: Text(
                                    'Are you sure you want to delete "${album.title}"?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(dCtx),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(dCtx);
                                      Navigator.pop(ctx);
                                      _albumService.deleteAlbum(album.id);
                                    },
                                    child: const Text('Delete',
                                        style:
                                            TextStyle(color: Colors.redAccent)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Play All Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow, color: Colors.white),
                        label: Text(
                          album.songs.isEmpty
                              ? 'No Tracks Yet'
                              : 'Play All (${album.songs.length})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF1A35),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: album.songs.isEmpty
                            ? null
                            : () {
                                Navigator.pop(ctx);
                                _openPlayer(album.songs.first, album.songs);
                              },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white12, height: 1),
                  // Song list
                  Expanded(
                    child: album.songs.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.queue_music,
                                      color: isDark
                                          ? Colors.white24
                                          : Colors.black26,
                                      size: 48),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No songs in this album yet',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black87,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Tap the 3 dots on any song while playing to add it to this album!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white38
                                          : Colors.black38,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            itemCount: album.songs.length,
                            itemBuilder: (context, idx) {
                              final song = album.songs[idx];
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    song.thumbnailUrl,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                        width: 48,
                                        height: 48,
                                        color: Colors.grey[900]),
                                  ),
                                ),
                                title: Text(
                                  song.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                subtitle: Text(
                                  '${song.channelName} • ${song.duration}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.black54,
                                    fontSize: 11,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.remove_circle_outline,
                                      color: Colors.white38, size: 20),
                                  onPressed: () {
                                    _albumService.removeSongFromAlbum(
                                        album.id, song.id);
                                  },
                                ),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _openPlayer(song, album.songs);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Song Tile in Category / Search List ─────────────────────────────────────
  Widget _buildSongListTile(
      Video song, List<Video> playlist, bool isDark, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => _openPlayer(song, playlist),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141520) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  song.thumbnailUrl,
                  width: 54,
                  height: 54,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(width: 54, height: 54, color: Colors.grey[900]),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${song.channelName} • ${song.duration}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF1A35).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow,
                    color: Color(0xFFFF1A35), size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Floating Mini Audio Player ─────────────────────────────────────────────
  Widget _buildFloatingMiniPlayer(bool isDark) {
    return ValueListenableBuilder<Video?>(
      valueListenable: _player.currentSongNotifier,
      builder: (context, currentSong, _) {
        if (currentSong == null) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () => _openPlayer(currentSong, _player.queue),
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E202E).withValues(alpha: 0.95)
                  : Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black12,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          currentSong.thumbnailUrl,
                          width: 42,
                          height: 42,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                              width: 42, height: 42, color: Colors.grey[900]),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentSong.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              currentSong.channelName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDark ? Colors.white54 : Colors.black54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ValueListenableBuilder<bool>(
                        valueListenable: _player.isPlayingNotifier,
                        builder: (context, isPlaying, _) {
                          return IconButton(
                            icon: Icon(
                              isPlaying ? Icons.pause : Icons.play_arrow,
                              color: const Color(0xFFFF1A35),
                              size: 26,
                            ),
                            onPressed: _player.togglePlayPause,
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.skip_next,
                          color: isDark ? Colors.white70 : Colors.black54,
                          size: 24,
                        ),
                        onPressed: _player.next,
                      ),
                    ],
                  ),
                ),

                // Tiny bottom progress indicator
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 0,
                  child: ValueListenableBuilder<Duration>(
                    valueListenable: _player.positionNotifier,
                    builder: (context, pos, _) {
                      return ValueListenableBuilder<Duration>(
                        valueListenable: _player.durationNotifier,
                        builder: (context, dur, _) {
                          final total =
                              dur.inMilliseconds > 0 ? dur.inMilliseconds : 1;
                          final progress =
                              (pos.inMilliseconds / total).clamp(0.0, 1.0);
                          return ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(16)),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.transparent,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFFFF1A35)),
                              minHeight: 2.5,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
