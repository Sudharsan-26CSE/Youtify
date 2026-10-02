import 'package:flutter/material.dart';
import '../models/video.dart';
import '../screens/downloads_screen.dart';
import '../screens/channel_profile_screen.dart';
import '../services/youtube_service.dart';
import '../services/download_service.dart';
import '../utils/page_transitions.dart';
import '../main.dart';
import 'capsule_modal.dart';

class VideoCard extends StatefulWidget {
  final Video video;
  final int animationIndex;
  final VoidCallback? onShare;

  const VideoCard({
    super.key,
    required this.video,
    this.animationIndex = 0,
    this.onShare,
  });

  @override
  State<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<VideoCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _entryCtrl;
  late Animation<double> _entryFade;
  late Animation<Offset> _entrySlide;
  bool _isPressed = false;
  String _avatarUrl = '';

  @override
  void initState() {
    super.initState();
    _avatarUrl = widget.video.channelAvatarUrl;
    DownloadService.addListener(_onDownloadUpdated);

    if (widget.video.channelId != null && widget.video.channelId!.isNotEmpty) {
      YouTubeService.getChannelAvatar(widget.video.channelId!).then((url) {
        if (mounted && url.isNotEmpty && url != _avatarUrl) {
          setState(() => _avatarUrl = url);
        }
      });
    }

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entrySlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    // Staggered start based on index
    Future.delayed(Duration(milliseconds: widget.animationIndex * 80), () {
      if (mounted) _entryCtrl.forward();
    });
  }

  void _onDownloadUpdated() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    DownloadService.removeListener(_onDownloadUpdated);
    _entryCtrl.dispose();
    super.dispose();
  }

  void _openVideo() {
    selectedVideo.value = widget.video;
    isPlayerExpanded.value = true;
  }

  void _openChannelProfile() {
    Navigator.push(
      context,
      SlideRightPageRoute(
        page: ChannelProfileScreen(
          channel: {
            'id': widget.video.channelId ?? '',
            'name': widget.video.channelName,
            'avatar': _avatarUrl.isNotEmpty ? _avatarUrl : widget.video.channelAvatarUrl,
            'subs': '',
            'banner': '',
          },
        ),
      ),
    );
  }

  void _handleDownload() {
    if (DownloadService.isDownloading(widget.video.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Download already in progress...'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (DownloadService.isDownloaded(widget.video.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Saved in Youtify folder!'),
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.red,
            onPressed: () {
              Navigator.push(context, FadeSlidePageRoute(page: const DownloadsScreen()));
            },
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    DownloadService.startDownload(widget.video);
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading "${widget.video.title}" to Youtify folder...'),
        backgroundColor: const Color(0xFF212121),
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.red,
          onPressed: () {
            Navigator.push(context, FadeSlidePageRoute(page: const DownloadsScreen()));
          },
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildDownloadButton() {
    final isDownloading = DownloadService.isDownloading(widget.video.id);
    final isDownloaded = DownloadService.isDownloaded(widget.video.id);

    if (isDownloading) {
      return Container(
        width: 38,
        height: 38,
        padding: const EdgeInsets.all(9),
        child: const CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.red,
        ),
      );
    }

    return IconButton(
      icon: Icon(
        isDownloaded ? Icons.download_done_rounded : Icons.download_for_offline_outlined,
        color: isDownloaded ? Colors.red : Colors.grey[400],
        size: 22,
      ),
      tooltip: isDownloaded ? 'Downloaded to Youtify' : 'Download video',
      onPressed: _handleDownload,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F0F0F);
    final subtitleColor = isDark ? Colors.grey[400] : const Color(0xFF606060);
    final iconColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return FadeTransition(
      opacity: _entryFade,
      child: SlideTransition(
        position: _entrySlide,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) {
            setState(() => _isPressed = false);
            _openVideo();
          },
          onTapCancel: () => setState(() => _isPressed = false),
          onLongPress: () {
            _showPreviewSheet();
          },
          child: AnimatedScale(
            scale: _isPressed ? 0.97 : 1.0,
            duration: const Duration(milliseconds: 120),
            child: Column(
              children: [
                // Thumbnail — unique Hero tag using video id + widget key hashCode
                Hero(
                  tag: 'video_thumb_${widget.video.id}_${widget.key.hashCode}',
                  child: Stack(
                    children: [
                      Container(
                        height: 220,
                        width: double.infinity,
                        color: Colors.grey[900],
                        child: Image.network(
                          widget.video.thumbnailUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Center(
                            child: Icon(Icons.broken_image, color: Colors.grey[600], size: 50),
                          ),
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: Colors.grey[900],
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: Colors.red,
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      // Play overlay on press
                      if (_isPressed)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withOpacity(0.3),
                            child: const Center(
                              child: Icon(Icons.play_circle_fill, color: Colors.white, size: 56),
                            ),
                          ),
                        ),
                      // Duration badge
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: widget.video.isLive ? Colors.red : Colors.black.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            widget.video.duration,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      if (widget.video.isLive)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '● LIVE',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Details
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: _openChannelProfile,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey[800],
                          ),
                          child: ClipOval(
                            child: Image.network(
                              _avatarUrl.isNotEmpty ? _avatarUrl : widget.video.channelAvatarUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.person, color: Colors.white, size: 24),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.video.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: titleColor,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: _openChannelProfile,
                              child: Text(
                                '${widget.video.channelName} • ${widget.video.views} • ${widget.video.timestamp}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: subtitleColor, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildDownloadButton(),
                      IconButton(
                        icon: Icon(Icons.more_vert, color: iconColor, size: 20),
                        onPressed: () => _showOptionsSheet(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }


  void _showPreviewSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final txtColor = isDark ? Colors.white : Colors.black87;

    showModalBottomSheet(
      context: context,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    widget.video.thumbnailUrl,
                    width: 80,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Container(width: 80, height: 50, color: Colors.grey[900]),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.video.title,
                    maxLines: 2,
                    style: TextStyle(color: txtColor, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(Icons.play_circle_outline, color: txtColor),
            title: Text('Play video', style: TextStyle(color: txtColor)),
            onTap: () { Navigator.pop(ctx); _openVideo(); },
          ),
          ListTile(
            leading: Icon(Icons.watch_later_outlined, color: txtColor),
            title: Text('Save to Watch Later', style: TextStyle(color: txtColor)),
            onTap: () => Navigator.pop(ctx),
          ),
          ListTile(
            leading: Icon(Icons.download_outlined, color: txtColor),
            title: Text('Download', style: TextStyle(color: txtColor)),
            onTap: () {
              Navigator.pop(ctx);
              _handleDownload();
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showOptionsSheet() {
    showCapsuleModal(
      context: context,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(widget.video.thumbnailUrl, width: 60, height: 36, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(width: 60, height: 36, color: Colors.grey[900])),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(widget.video.title, maxLines: 2, style: const TextStyle(color: Colors.white, fontSize: 13))),
                ],
              ),
            ),
            const Divider(color: Color(0xFF272727), height: 1),
            CapsuleAction(icon: Icons.watch_later_outlined, label: 'Save to Watch Later', onTap: () {}),
            CapsuleAction(
              icon: Icons.download_outlined,
              label: 'Download',
              onTap: () {
                DownloadService.startDownload(widget.video);
                Navigator.push(context, FadeSlidePageRoute(page: const DownloadsScreen()));
              },
            ),
            CapsuleAction(
              icon: Icons.share_outlined,
              label: 'Share',
              onTap: () {
                if (widget.onShare != null) {
                  widget.onShare!();
                } else {
                  final url = YouTubeService.shareUrl(widget.video.id);
                  showCapsuleModal(context: context, child: ShareCapsule(shareUrl: url, title: widget.video.title));
                }
              },
            ),
            CapsuleAction(icon: Icons.not_interested, label: 'Not interested', onTap: () {}),
          ],
        ),
      ),
    );
  }
}
