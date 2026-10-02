import 'package:flutter/material.dart';
import '../models/video.dart';
import '../services/user_data_service.dart';
import '../widgets/video_card.dart';
import '../main.dart';

class LikedVideosScreen extends StatefulWidget {
  const LikedVideosScreen({super.key});

  @override
  State<LikedVideosScreen> createState() => _LikedVideosScreenState();
}

class _LikedVideosScreenState extends State<LikedVideosScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  bool _isSelecting = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400))
      ..forward();
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    UserDataService.addListener(_onUserDataChanged);
  }

  @override
  void dispose() {
    UserDataService.removeListener(_onUserDataChanged);
    _ctrl.dispose();
    super.dispose();
  }

  void _onUserDataChanged() {
    if (mounted) setState(() {});
  }

  void _toggleSelection(String videoId) {
    setState(() {
      if (_selectedIds.contains(videoId)) {
        _selectedIds.remove(videoId);
        if (_selectedIds.isEmpty) {
          _isSelecting = false;
        }
      } else {
        _selectedIds.add(videoId);
      }
    });
  }

  void _cancelSelection() {
    setState(() {
      _selectedIds.clear();
      _isSelecting = false;
    });
  }

  Future<void> _unlikeSelected() async {
    final count = _selectedIds.length;
    final idsToRemove = _selectedIds.toList();
    await UserDataService.unlikeMultiple(idsToRemove);
    _cancelSelection();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unliked $count video${count > 1 ? 's' : ''}'),
          backgroundColor: const Color(0xFF1A1A1A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F0F0F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final likedVideos = UserDataService.likedVideos;

    return PopScope(
      canPop: !_isSelecting,
      onPopInvoked: (didPop) {
        if (!didPop && _isSelecting) {
          _cancelSelection();
        }
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          elevation: 0,
          leading: _isSelecting
              ? IconButton(
                  icon: Icon(Icons.close, color: textColor),
                  onPressed: _cancelSelection,
                  tooltip: 'Cancel',
                )
              : IconButton(
                  icon: Icon(Icons.arrow_back, color: textColor),
                  onPressed: () => Navigator.pop(context),
                ),
          title: Text(
            _isSelecting
                ? '${_selectedIds.length} selected'
                : 'Liked Videos',
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          ),
          actions: [
            if (_isSelecting)
              TextButton.icon(
                onPressed: _selectedIds.isEmpty ? null : _unlikeSelected,
                icon: const Icon(Icons.thumb_down_outlined, color: Colors.redAccent, size: 18),
                label: const Text(
                  'Unlike',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              )
            else if (likedVideos.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Text(
                    '${likedVideos.length} videos',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                ),
              ),
          ],
        ),
        body: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: likedVideos.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.thumb_up_outlined,
                            size: 72, color: Colors.grey[600]),
                        const SizedBox(height: 16),
                        Text(
                          'No liked videos yet',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Videos you like will appear here',
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 120),
                    itemCount: likedVideos.length,
                    itemBuilder: (context, i) {
                      final video = likedVideos[i];
                      final isSelected = _selectedIds.contains(video.id);

                      return GestureDetector(
                        onLongPress: () {
                          if (!_isSelecting) {
                            setState(() {
                              _isSelecting = true;
                              _selectedIds.add(video.id);
                            });
                          }
                        },
                        onTap: () {
                          if (_isSelecting) {
                            _toggleSelection(video.id);
                          } else {
                            selectedVideo.value = video;
                            isPlayerExpanded.value = true;
                          }
                        },
                        child: Stack(
                          children: [
                            VideoCard(
                              video: video,
                              animationIndex: i > 8 ? 0 : i,
                            ),
                            if (_isSelecting)
                              Positioned.fill(
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  color: isSelected
                                      ? Colors.red.withValues(alpha: 0.2)
                                      : Colors.transparent,
                                  child: Align(
                                    alignment: Alignment.topRight,
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Colors.red
                                              : Colors.black.withValues(alpha: 0.6),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                        ),
                                        child: isSelected
                                            ? const Icon(
                                                Icons.check,
                                                color: Colors.white,
                                                size: 16,
                                              )
                                            : null,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}
