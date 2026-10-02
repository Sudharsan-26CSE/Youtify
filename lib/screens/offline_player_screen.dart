import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../services/download_service.dart';

class OfflinePlayerScreen extends StatefulWidget {
  final DownloadItem item;

  const OfflinePlayerScreen({super.key, required this.item});

  @override
  State<OfflinePlayerScreen> createState() => _OfflinePlayerScreenState();
}

class _OfflinePlayerScreenState extends State<OfflinePlayerScreen> {
  VideoPlayerController? _controller;
  bool _isPlaying = false;
  bool _showControls = true;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final path = widget.item.savePath;
    if (path == null) {
      setState(() => _isError = true);
      return;
    }
    final file = File(path);
    if (!file.existsSync()) {
      setState(() => _isError = true);
      return;
    }

    final controller = VideoPlayerController.file(file);
    _controller = controller;

    try {
      await controller.initialize();
      controller.addListener(() {
        if (!mounted) return;
        setState(() {
          _position = controller.value.position;
          _duration = controller.value.duration;
          _isPlaying = controller.value.isPlaying;
        });
      });
      await controller.play();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Offline player error: $e");
      if (mounted) setState(() => _isError = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F0F0F) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF2F2F2);
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Video Area
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    color: Colors.black,
                    child: _isError
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.error_outline,
                                    color: Colors.red, size: 40),
                                SizedBox(height: 8),
                                Text('Unable to play offline file',
                                    style: TextStyle(color: Colors.white70)),
                              ],
                            ),
                          )
                        : _controller != null &&
                                _controller!.value.isInitialized
                            ? GestureDetector(
                                onTap: () => setState(
                                    () => _showControls = !_showControls),
                                child: VideoPlayer(_controller!),
                              )
                            : const Center(
                                child: CircularProgressIndicator(
                                    color: Colors.red),
                              ),
                  ),
                ),
                // Top control bar
                Positioned(
                  top: 8,
                  left: 8,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                // Center play/pause overlay
                if (_showControls &&
                    _controller != null &&
                    _controller!.value.isInitialized)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black38,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            iconSize: 36,
                            icon: const Icon(Icons.replay_10,
                                color: Colors.white),
                            onPressed: () {
                              final newPos =
                                  _position - const Duration(seconds: 10);
                              _controller?.seekTo(newPos > Duration.zero
                                  ? newPos
                                  : Duration.zero);
                            },
                          ),
                          const SizedBox(width: 20),
                          IconButton(
                            iconSize: 56,
                            icon: Icon(
                                _isPlaying
                                    ? Icons.pause_circle
                                    : Icons.play_circle,
                                color: Colors.white),
                            onPressed: () {
                              if (_isPlaying) {
                                _controller?.pause();
                              } else {
                                _controller?.play();
                              }
                            },
                          ),
                          const SizedBox(width: 20),
                          IconButton(
                            iconSize: 36,
                            icon: const Icon(Icons.forward_10,
                                color: Colors.white),
                            onPressed: () {
                              final newPos =
                                  _position + const Duration(seconds: 10);
                              _controller?.seekTo(
                                  newPos < _duration ? newPos : _duration);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                // Bottom timeline bar
                if (_controller != null && _controller!.value.isInitialized)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 6),
                        activeTrackColor: Colors.red,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: Colors.red,
                      ),
                      child: Slider(
                        value: _position.inMilliseconds
                            .toDouble()
                            .clamp(0.0, _duration.inMilliseconds.toDouble()),
                        min: 0.0,
                        max: _duration.inMilliseconds.toDouble() > 0
                            ? _duration.inMilliseconds.toDouble()
                            : 1.0,
                        onChanged: (val) {
                          _controller
                              ?.seekTo(Duration(milliseconds: val.toInt()));
                        },
                      ),
                    ),
                  ),
              ],
            ),
            // Video Information & File Path
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                        style: TextStyle(
                            color: textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border:
                              Border.all(color: Colors.green.withOpacity(0.4)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.offline_pin,
                                color: Colors.green, size: 14),
                            SizedBox(width: 4),
                            Text('Offline Mode',
                                style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.item.video.title,
                    style: TextStyle(
                        color: textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.item.video.channelName,
                    style: TextStyle(color: textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  // File Location Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isDark ? Colors.white12 : Colors.black12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.folder_open,
                                    color: Colors.amber, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'File Location',
                                  style: TextStyle(
                                      color: textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 18),
                              tooltip: 'Copy file path',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(
                                    text: widget.item.savePath ?? ''));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'File location copied to clipboard!'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SelectableText(
                          widget.item.savePath ?? 'Path unavailable',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Text(
                              'File Size: ${widget.item.formattedTotalSize}',
                              style: TextStyle(
                                  fontSize: 12, color: textSecondary),
                            ),
                          ],
                        ),
                      ],
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
}
