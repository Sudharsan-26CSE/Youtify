import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/album.dart';
import '../models/video.dart';
import '../services/album_service.dart';
import '../services/audio_player_service.dart';
import 'channel_profile_screen.dart';

class AudioPlayerScreen extends StatefulWidget {
  final Video initialSong;
  final List<Video>? playlist;

  const AudioPlayerScreen({
    super.key,
    required this.initialSong,
    this.playlist,
  });

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen>
    with SingleTickerProviderStateMixin {
  final AudioPlayerService _player = AudioPlayerService.instance;
  late AnimationController _heartAnimCtrl;
  bool _showLyricsSheet = false;
  bool _showQueueSheet = false;

  // Waveform bar heights pattern (simulating sound audio wave)
  static const List<double> _waveHeights = [
    0.3, 0.45, 0.25, 0.6, 0.8, 0.5, 0.95, 0.7, 0.4, 0.85,
    0.6, 0.35, 0.75, 1.0, 0.65, 0.4, 0.9, 0.55, 0.3, 0.7,
    0.85, 0.45, 0.6, 0.9, 0.75, 0.4, 0.65, 0.8, 0.5, 0.35,
    0.6, 0.75, 0.4, 0.85, 0.6, 0.45, 0.3
  ];

  @override
  void initState() {
    super.initState();
    _heartAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      lowerBound: 1.0,
      upperBound: 1.4,
    );

    // If initialSong is not already playing, start it
    if (_player.currentSong?.id != widget.initialSong.id) {
      _player.playSong(widget.initialSong, playlist: widget.playlist);
    }
  }

  @override
  void dispose() {
    _heartAnimCtrl.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  void _onShare(Video song) {
    final url = 'https://www.youtube.com/watch?v=${song.resolvedYoutubeId ?? song.id}';
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied song link: ${song.title} 🎵'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF22222E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Video?>(
      valueListenable: _player.currentSongNotifier,
      builder: (context, currentSong, _) {
        final song = currentSong ?? widget.initialSong;

        return Scaffold(
          backgroundColor: const Color(0xFF090A10),
          body: Stack(
            fit: StackFit.expand,
            children: [
              // Ambient blurred background from thumbnail
              Positioned.fill(
                child: Image.network(
                  song.thumbnailUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: const Color(0xFF0A0B12)),
                ),
              ),
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 60.0, sigmaY: 60.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF080910).withValues(alpha: 0.85),
                          const Color(0xFF07080F).withValues(alpha: 0.95),
                          const Color(0xFF05050A),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Subtle vertical scanlines/texture overlay
              Positioned.fill(
                child: CustomPaint(
                  painter: _ScanlinesPainter(),
                ),
              ),

              // Main content
              SafeArea(
                child: Column(
                  children: [
                    // Top Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildCircleBtn(
                            icon: Icons.arrow_back,
                            onTap: () => Navigator.of(context).pop(),
                          ),
                          const Text(
                            'NOW PLAYING',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2,
                            ),
                          ),
                          Row(
                            children: [
                              _buildCircleBtn(
                                icon: Icons.share_outlined,
                                onTap: () => _onShare(song),
                              ),
                              const SizedBox(width: 10),
                              _buildCircleBtn(
                                icon: Icons.more_vert,
                                onTap: () => _showMoreOptions(song),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const Spacer(flex: 1),

                    // Circular Centerpiece Artwork
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Glowing outer colored halo
                          Container(
                            width: 196,
                            height: 196,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF1A35).withValues(alpha: 0.35),
                                  blurRadius: 40,
                                  spreadRadius: 8,
                                ),
                                BoxShadow(
                                  color: const Color(0xFFB3001E).withValues(alpha: 0.25),
                                  blurRadius: 30,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          // Circle Artwork with Border
                          Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15),
                                width: 3,
                              ),
                            ),
                            child: ClipOval(
                              child: Image.network(
                                song.thumbnailUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey[900],
                                  child: const Icon(Icons.music_note, color: Colors.white54, size: 56),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Plays & Likes Counter
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.play_arrow_outlined, color: Colors.white60, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${song.views} Plays',
                          style: const TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 20),
                        const Icon(Icons.favorite_border, color: Colors.white60, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${song.likes ?? "32.1K"} Likes',
                          style: const TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Song Title & Artist
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          Text(
                            song.title,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            song.channelName,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Action Icons Row: Queue, Like, Artist, Add to playlist
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.queue_music, color: Colors.white70, size: 22),
                            tooltip: 'Queue',
                            onPressed: () => setState(() => _showQueueSheet = true),
                          ),
                          ValueListenableBuilder<Set<String>>(
                            valueListenable: _player.likedSongIdsNotifier,
                            builder: (context, likedIds, _) {
                              final isLiked = likedIds.contains(song.id);
                              return ScaleTransition(
                                scale: _heartAnimCtrl,
                                child: IconButton(
                                  icon: Icon(
                                    isLiked ? Icons.favorite : Icons.favorite_border,
                                    color: isLiked ? const Color(0xFFFF1A35) : Colors.white70,
                                    size: 24,
                                  ),
                                  tooltip: isLiked ? 'Liked' : 'Like',
                                  onPressed: () {
                                    _heartAnimCtrl.forward().then((_) => _heartAnimCtrl.reverse());
                                    _player.toggleLike(song);
                                  },
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.person_outline, color: Colors.white70, size: 22),
                            tooltip: 'Artist',
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ChannelProfileScreen(
                                    channel: {
                                      'name': song.channelName,
                                      'avatar': song.channelAvatarUrl,
                                      'id': song.channelId ?? '',
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.playlist_add, color: Colors.white70, size: 24),
                            tooltip: 'Add to Album',
                            onPressed: () => _showAddToAlbumDialog(song),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(flex: 1),

                    // Waveform Equalizer Visualizer & Scrubber
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: ValueListenableBuilder<Duration>(
                        valueListenable: _player.positionNotifier,
                        builder: (context, pos, _) {
                          return ValueListenableBuilder<Duration>(
                            valueListenable: _player.durationNotifier,
                            builder: (context, dur, _) {
                              final totalMs = dur.inMilliseconds > 0 ? dur.inMilliseconds : 1;
                              final currentMs = pos.inMilliseconds.clamp(0, totalMs);
                              final progress = (currentMs / totalMs).clamp(0.0, 1.0);

                              return Column(
                                children: [
                                  // Waveform bars with scrub gesture
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onHorizontalDragUpdate: (details) {
                                      final box = context.findRenderObject() as RenderBox?;
                                      if (box != null) {
                                        final localPos = details.localPosition.dx;
                                        final ratio = (localPos / box.size.width).clamp(0.0, 1.0);
                                        final targetMs = (ratio * totalMs).toInt();
                                        _player.seekTo(Duration(milliseconds: targetMs));
                                      }
                                    },
                                    onTapDown: (details) {
                                      final box = context.findRenderObject() as RenderBox?;
                                      if (box != null) {
                                        final localPos = details.localPosition.dx;
                                        final ratio = (localPos / box.size.width).clamp(0.0, 1.0);
                                        final targetMs = (ratio * totalMs).toInt();
                                        _player.seekTo(Duration(milliseconds: targetMs));
                                      }
                                    },
                                    child: SizedBox(
                                      height: 48,
                                      child: CustomPaint(
                                        size: const Size(double.infinity, 48),
                                        painter: _WaveformPainter(
                                          progress: progress,
                                          heights: _waveHeights,
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 6),

                                  // Timestamps
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _formatDuration(pos),
                                        style: const TextStyle(
                                          color: Colors.white60,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        _formatDuration(dur),
                                        style: const TextStyle(
                                          color: Colors.white60,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),

                    const Spacer(flex: 1),

                    // Playback Controls Row: Repeat, Prev, Big Gradient Play, Next, Shuffle
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Repeat
                          ValueListenableBuilder<bool>(
                            valueListenable: _player.isRepeatNotifier,
                            builder: (context, isRepeat, _) {
                              return IconButton(
                                icon: Icon(
                                  isRepeat ? Icons.repeat_one : Icons.repeat,
                                  color: isRepeat ? const Color(0xFFFF1A35) : Colors.white60,
                                  size: 22,
                                ),
                                onPressed: _player.toggleRepeat,
                              );
                            },
                          ),

                          // Previous
                          IconButton(
                            icon: const Icon(Icons.skip_previous, color: Colors.white, size: 30),
                            onPressed: _player.previous,
                          ),

                          // Big Vibrant Gradient Play/Pause
                          ValueListenableBuilder<bool>(
                            valueListenable: _player.isPlayingNotifier,
                            builder: (context, isPlaying, _) {
                              return ValueListenableBuilder<bool>(
                                valueListenable: _player.isBufferingNotifier,
                                builder: (context, isBuffering, _) {
                                  return GestureDetector(
                                    onTap: _player.togglePlayPause,
                                    child: Container(
                                      width: 66,
                                      height: 66,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Color(0xFFFF1A35),
                                            Color(0xFFC40028),
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFFF1A35).withValues(alpha: 0.45),
                                            blurRadius: 20,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: isBuffering
                                            ? const SizedBox(
                                                width: 26,
                                                height: 26,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2.5,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : Icon(
                                                isPlaying ? Icons.pause : Icons.play_arrow,
                                                color: Colors.white,
                                                size: 34,
                                              ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),

                          // Next
                          IconButton(
                            icon: const Icon(Icons.skip_next, color: Colors.white, size: 30),
                            onPressed: _player.next,
                          ),

                          // Shuffle
                          ValueListenableBuilder<bool>(
                            valueListenable: _player.isShuffleNotifier,
                            builder: (context, isShuffle, _) {
                              return IconButton(
                                icon: Icon(
                                  Icons.shuffle,
                                  color: isShuffle ? const Color(0xFFFF1A35) : Colors.white60,
                                  size: 22,
                                ),
                                onPressed: _player.toggleShuffle,
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const Spacer(flex: 1),

                    // Bottom Lyric Drawer Button
                    GestureDetector(
                      onTap: () => setState(() => _showLyricsSheet = true),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.keyboard_arrow_up, color: Colors.white60, size: 20),
                            Text(
                              'Lyric',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Queue Drawer
              if (_showQueueSheet) _buildQueueSheet(),

              // Lyrics Drawer
              if (_showLyricsSheet) _buildLyricsSheet(song),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCircleBtn({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  void _showMoreOptions(Video song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161822),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              // Background Play Switch
              ValueListenableBuilder<bool>(
                valueListenable: _player.isBackgroundPlayNotifier,
                builder: (context, isBgEnabled, _) {
                  return SwitchListTile(
                    secondary: const Icon(Icons.motion_photos_on_outlined, color: Color(0xFFFF1A35)),
                    title: const Text('Background Play', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Keep playing when screen is off or in background', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    value: isBgEnabled,
                    activeThumbColor: const Color(0xFFFF1A35),
                    onChanged: (val) {
                      _player.toggleBackgroundPlay(val);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(val
                              ? 'Background play enabled! Music plays when screen is off 🎧'
                              : 'Background play disabled.'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: const Color(0xFF1E202B),
                          duration: const Duration(seconds: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    },
                  );
                },
              ),
              const Divider(color: Colors.white12, height: 1),
              ListTile(
                leading: const Icon(Icons.playlist_add, color: Colors.white),
                title: const Text('Add to Album', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Save to your database albums', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAddToAlbumDialog(song);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share, color: Colors.white),
                title: const Text('Share Song Link', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _onShare(song);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person, color: Colors.white),
                title: const Text('View Channel / Artist', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChannelProfileScreen(
                        channel: {
                          'name': song.channelName,
                          'avatar': song.channelAvatarUrl,
                          'id': song.channelId ?? '',
                        },
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.close, color: Colors.grey),
                title: const Text('Close', style: TextStyle(color: Colors.grey)),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddToAlbumDialog(Video song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161822),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return ValueListenableBuilder<List<Album>>(
          valueListenable: AlbumService.instance.albumsNotifier,
          builder: (context, albums, _) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Save to Album', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  if (albums.isEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Icon(Icons.album_outlined, color: Colors.white24, size: 48),
                          const SizedBox(height: 12),
                          const Text('No albums created yet', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          const Text('Go to Audio screen to create your first album!', style: TextStyle(color: Colors.white38, fontSize: 12)),
                        ],
                      ),
                    ),
                  ] else ...[
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: albums.length,
                        itemBuilder: (context, idx) {
                          final album = albums[idx];
                          final isAlreadyIn = album.songs.any((s) => s.id == song.id);

                          return ListTile(
                            leading: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF1A35).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.album_rounded, color: Color(0xFFFF1A35), size: 24),
                            ),
                            title: Text(album.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            subtitle: Text('${album.songs.length} tracks', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            trailing: isAlreadyIn
                                ? const Icon(Icons.check_circle, color: Color(0xFFFF1A35))
                                : const Icon(Icons.add_circle_outline, color: Colors.white54),
                            onTap: () async {
                              if (isAlreadyIn) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Song already in "${album.title}"!'),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: const Color(0xFF1E202B),
                                  ),
                                );
                                return;
                              }
                              await AlbumService.instance.addSongToAlbum(album.id, song);
                              if (mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Added to "${album.title}"! 💿'),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: const Color(0xFF1E202B),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                );
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQueueSheet() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _showQueueSheet = false),
        child: Container(
          color: Colors.black.withValues(alpha: 0.6),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTap: () {},
              child: Container(
                height: MediaQuery.of(context).size.height * 0.65,
                decoration: const BoxDecoration(
                  color: Color(0xFF13141F),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Now Playing Queue', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white70),
                            onPressed: () => setState(() => _showQueueSheet = false),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white12, height: 1),
                    Expanded(
                      child: ValueListenableBuilder<List<Video>>(
                        valueListenable: _player.queueNotifier,
                        builder: (context, q, _) {
                          if (q.isEmpty) {
                            return const Center(child: Text('Queue is empty', style: TextStyle(color: Colors.white60)));
                          }
                          return ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: q.length,
                            itemBuilder: (ctx, i) {
                              final item = q[i];
                              final isCurrent = _player.currentSong?.id == item.id;
                              return ListTile(
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(item.thumbnailUrl, width: 44, height: 44, fit: BoxFit.cover),
                                ),
                                title: Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isCurrent ? const Color(0xFFFF1A35) : Colors.white,
                                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(item.channelName, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                trailing: isCurrent ? const Icon(Icons.graphic_eq, color: Color(0xFFFF1A35)) : null,
                                onTap: () {
                                  _player.playSong(item, playlist: q);
                                  setState(() => _showQueueSheet = false);
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLyricsSheet(Video song) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _showLyricsSheet = false),
        child: Container(
          color: Colors.black.withValues(alpha: 0.6),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTap: () {},
              child: Container(
                height: MediaQuery.of(context).size.height * 0.7,
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                decoration: const BoxDecoration(
                  color: Color(0xFF11121C),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Lyrics',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () =>
                              setState(() => _showLyricsSheet = false),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white12, height: 20),
                    Expanded(
                      child: ListView(
                        children: [
                          const SizedBox(height: 20),
                          _buildLyricLine("🎶 Music playing...", isActive: false),
                          const SizedBox(height: 16),
                          _buildLyricLine("Listen to the rhythm flow", isActive: false),
                          const SizedBox(height: 16),
                          _buildLyricLine(song.title, isActive: true),
                          const SizedBox(height: 16),
                          _buildLyricLine("By ${song.channelName}", isActive: false),
                          const SizedBox(height: 16),
                          _buildLyricLine("Feel the melody and sing along", isActive: false),
                          const SizedBox(height: 16),
                          _buildLyricLine("Enjoy uninterrupted high quality audio", isActive: false),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLyricLine(String text, {required bool isActive}) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: isActive ? const Color(0xFFFF1A35) : Colors.white.withValues(alpha: 0.45),
        fontSize: isActive ? 20 : 16,
        fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
        letterSpacing: 0.2,
      ),
    );
  }
}

// ─── Waveform Equalizer Painter ───────────────────────────────────────────────
class _WaveformPainter extends CustomPainter {
  final double progress;
  final List<double> heights;

  _WaveformPainter({required this.progress, required this.heights});

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = heights.length;
    final totalSpacing = size.width * 0.35;
    final totalBarWidth = size.width - totalSpacing;
    final barWidth = totalBarWidth / barCount;
    final spacing = totalSpacing / (barCount - 1);

    final activePaint = Paint()
      ..color = const Color(0xFFFF1A35)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.fill;

    final inactivePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.fill;

    final cursorPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (int i = 0; i < barCount; i++) {
      final x = i * (barWidth + spacing);
      final barRatio = (i / barCount);
      final isActive = barRatio <= progress;

      final normalizedH = heights[i];
      final barH = normalizedH * (size.height - 12);
      final top = (size.height - 12 - barH) / 2;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, top, barWidth, barH),
        const Radius.circular(3),
      );

      canvas.drawRRect(rect, isActive ? activePaint : inactivePaint);
    }

    // Draw little scrubber cursor triangle at current position
    final cursorX = (progress * size.width).clamp(4.0, size.width - 4.0);
    final path = Path()
      ..moveTo(cursorX - 5, size.height - 2)
      ..lineTo(cursorX + 5, size.height - 2)
      ..lineTo(cursorX, size.height - 8)
      ..close();
    canvas.drawPath(path, cursorPaint);
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// ─── Subtle vertical scanlines background painter ─────────────────────────────
class _ScanlinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.12)
      ..strokeWidth = 1.0;

    for (double x = 0; x < size.width; x += 4) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
