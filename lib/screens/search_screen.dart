import 'package:flutter/material.dart';
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
  List<Video> _searchResults = [];
  bool _hasSearched = false;
  bool _isLoading = false;

  final List<String> _trendingSearches = [
    'Flutter 2026 Tutorial',
    'Lo-Fi Coding Beats',
    'Advanced State Management',
    'Building YouTube Clone',
    'Dart 3 Masterclass',
  ];

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
        _isLoading = false;
      });
      return;
    }
    setState(() {
      _hasSearched = true;
      _isLoading = true;
    });
    
    final results = await YouTubeService.searchVideos(query);
    
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    }
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
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        return VideoCard(video: _searchResults[index]);
                      },
                    )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
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
