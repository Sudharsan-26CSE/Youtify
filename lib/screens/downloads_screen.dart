import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/download_service.dart';
import '../services/youtube_service.dart';
import '../widgets/capsule_modal.dart';
import 'offline_player_screen.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _entryCtrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  final Set<String> _selectedIds = {};
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    DownloadService.addListener(_onUpdate);
  }

  void _onUpdate() {
    if (mounted) {
      setState(() {
        _selectedIds.removeWhere(
            (id) => !DownloadService.downloads.any((d) => d.video.id == id));
      });
    }
  }

  void _toggleSelection(String id) {
    setState(() {
      if (!_selectedIds.add(id)) _selectedIds.remove(id);
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            title: const Text('Delete downloads?',
                style: TextStyle(color: Colors.white)),
            content: Text(
                'This will permanently remove the selected local files.',
                style: TextStyle(color: Colors.grey[400])),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    for (final id in _selectedIds.toList()) {
      await DownloadService.removeDownload(id);
    }
    if (mounted) setState(() => _selectedIds.clear());
  }

  void _shareSelected() {
    if (_selectedIds.length != 1) return;
    final item = DownloadService.downloads
        .firstWhere((download) => download.video.id == _selectedIds.first);
    showCapsuleModal(
      context: context,
      child: ShareCapsule(
        shareUrl: YouTubeService.shareUrl(item.video.id),
        title: item.video.title,
      ),
    );
  }

  @override
  void dispose() {
    DownloadService.removeListener(_onUpdate);
    _entryCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F0F0F) : Theme.of(context).scaffoldBackgroundColor;
    final allDownloads = DownloadService.downloads;
    final downloads = _searchQuery.trim().isEmpty
        ? allDownloads
        : allDownloads.where((d) {
            final query = _searchQuery.toLowerCase();
            return d.video.title.toLowerCase().contains(query) ||
                d.video.channelName.toLowerCase().contains(query);
          }).toList();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Downloads',
            style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold)),
        actions: [
          if (downloads.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.grey),
              onPressed: () async {
                setState(() => _selectedIds
                  ..clear()
                  ..addAll(downloads.map((d) => d.video.id)));
                await _deleteSelected();
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: allDownloads.isEmpty
                  ? _buildEmpty()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Search bar
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFEDEDED),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextField(
                              controller: _searchCtrl,
                              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
                              onChanged: (val) => setState(() => _searchQuery = val),
                              decoration: InputDecoration(
                                hintText: 'Search downloaded videos...',
                                hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
                                prefixIcon: Icon(Icons.search, color: Colors.grey[500], size: 20),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () {
                                          _searchCtrl.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Downloaded Videos (${downloads.length})',
                                  style: TextStyle(
                                      color: isDark ? Colors.white : Colors.black87,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              if (allDownloads.isNotEmpty)
                                Text(
                                  'Tap to play offline',
                                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: downloads.isEmpty
                              ? Center(
                                  child: Text('No videos match "$_searchQuery"',
                                      style: TextStyle(color: Colors.grey[500])),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.only(bottom: 120),
                                  itemCount: downloads.length,
                                  itemBuilder: (context, i) {
                                    final item = downloads[i];
                                    return _DownloadTile(
                                      item: item,
                                      animIndex: i,
                                      selected: _selectedIds.contains(item.video.id),
                                      onLongPress: () => _toggleSelection(item.video.id),
                                      onTap: () {
                                        if (_selectedIds.isNotEmpty) {
                                          _toggleSelection(item.video.id);
                                        } else if (item.isComplete) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => OfflinePlayerScreen(item: item),
                                            ),
                                          );
                                        }
                                      },
                                      onDelete: () => _deleteSelected(),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
            ),
          ),
          AnimatedSlide(
            offset: _selectedIds.isEmpty ? const Offset(0, 1.2) : Offset.zero,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF292929),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.red.withOpacity(0.35)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Clear selection',
                        onPressed: () => setState(() => _selectedIds.clear()),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                      Expanded(
                        child: Text('${_selectedIds.length} selected',
                            style: const TextStyle(color: Colors.white)),
                      ),
                      IconButton(
                        tooltip: 'Share',
                        onPressed: _selectedIds.length == 1 ? _shareSelected : null,
                        icon: const Icon(Icons.share_outlined),
                        color: Colors.white,
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        onPressed: _deleteSelected,
                        icon: const Icon(Icons.delete_outline),
                        color: Colors.redAccent,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.download_outlined, size: 72, color: Colors.grey[700]),
          const SizedBox(height: 16),
          Text('No downloads yet',
              style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Tap the download icon on any video\nto save it offline',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        ],
      ),
    );
  }
}

class _DownloadTile extends StatefulWidget {
  final DownloadItem item;
  final int animIndex;
  final bool selected;
  final VoidCallback onLongPress;
  final VoidCallback? onTap;
  final VoidCallback onDelete;

  const _DownloadTile(
      {required this.item,
      required this.animIndex,
      required this.selected,
      required this.onLongPress,
      required this.onTap,
      required this.onDelete});

  @override
  State<_DownloadTile> createState() => _DownloadTileState();
}

class _DownloadTileState extends State<_DownloadTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slide = Tween<Offset>(begin: const Offset(0.3, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    Future.delayed(Duration(milliseconds: widget.animIndex * 60), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Dismissible(
          key: Key(item.video.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: Colors.red.withOpacity(0.2),
            child: const Icon(Icons.delete_outline, color: Colors.red, size: 28),
          ),
          onDismissed: (_) => widget.onDelete(),
          child: GestureDetector(
            onLongPress: widget.onLongPress,
            onTap: widget.onTap,
            child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1A1A1A)
                  : const Color(0xFFF2F2F2),
              borderRadius: BorderRadius.circular(14),
              border: widget.selected
                  ? Border.all(color: Colors.redAccent, width: 2)
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          item.video.thumbnailUrl,
                          width: 90,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Container(width: 90, height: 56, color: Colors.grey[900]),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.video.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.white
                                      : Colors.black87,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 4),
                            Text(item.video.channelName,
                                style: TextStyle(
                                    color: Colors.grey[500], fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (!item.isComplete) ...[
                    // Dino game loading animation
                    SizedBox(
                      height: 40,
                      child: _DinoLoadingAnimation(progress: item.progress),
                    ),
                    const SizedBox(height: 8),
                    // Stats row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${item.formattedReceivedSize} / ${item.formattedTotalSize}',
                          style: TextStyle(color: Colors.grey[400], fontSize: 11),
                        ),
                        Text(
                          '${(item.progress * 100).toInt()}%',
                          style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.speed, color: Colors.grey[500], size: 14),
                            const SizedBox(width: 4),
                            Text(item.formattedSpeed, style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                          ],
                        ),
                        if (item.availableStorageMB > 0)
                          Row(
                            children: [
                              Icon(Icons.storage, color: Colors.grey[500], size: 14),
                              const SizedBox(width: 4),
                              Text('${item.availableStorageMB} MB free', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                            ],
                          ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle,
                                color: Colors.green, size: 14),
                            const SizedBox(width: 4),
                            Text('Downloaded • ${item.formattedTotalSize}',
                                style: TextStyle(
                                    color: Colors.grey[500], fontSize: 11)),
                          ],
                        ),
                        Row(
                          children: const [
                            Icon(Icons.play_circle_fill, color: Colors.red, size: 18),
                            SizedBox(width: 4),
                            Text('Play', style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // File path container
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF252525)
                            : const Color(0xFFE5E5E5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.folder_open, size: 14, color: Colors.amber),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item.savePath ?? 'Path unavailable',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white70
                                    : Colors.black87,
                                fontSize: 10,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: item.savePath ?? ''));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('File location copied!'),
                                  duration: Duration(seconds: 1),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            child: const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(Icons.copy, size: 12, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dino jump loading animation — a simple T-Rex running across the screen
class _DinoLoadingAnimation extends StatefulWidget {
  final double progress;
  const _DinoLoadingAnimation({required this.progress});

  @override
  State<_DinoLoadingAnimation> createState() => _DinoLoadingAnimationState();
}

class _DinoLoadingAnimationState extends State<_DinoLoadingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _runCtrl;

  @override
  void initState() {
    super.initState();
    _runCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat();
  }

  @override
  void dispose() {
    _runCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _runCtrl,
      builder: (context, _) {
        return CustomPaint(
          size: const Size(double.infinity, 40),
          painter: _DinoPainter(
            progress: widget.progress,
            runPhase: _runCtrl.value,
          ),
        );
      },
    );
  }
}

class _DinoPainter extends CustomPainter {
  final double progress;
  final double runPhase;
  _DinoPainter({required this.progress, required this.runPhase});

  @override
  void paint(Canvas canvas, Size size) {
    final groundY = size.height - 4;
    final groundPaint = Paint()
      ..color = Colors.grey[700]!
      ..strokeWidth = 1;

    // Ground line
    canvas.drawLine(Offset(0, groundY), Offset(size.width, groundY), groundPaint);

    // Progress bar (ground fill)
    final progressPaint = Paint()
      ..color = Colors.red.withOpacity(0.3)
      ..strokeWidth = 3;
    canvas.drawLine(Offset(0, groundY + 2), Offset(size.width * progress, groundY + 2), progressPaint);

    // Dino position based on progress
    final dinoX = size.width * progress;
    final jumpHeight = sin(runPhase * pi * 2) * 12;
    final dinoY = groundY - 16 - (jumpHeight > 0 ? jumpHeight : 0);

    // Draw dino body (simple T-Rex shape)
    final dinoPaint = Paint()..color = Colors.white;
    
    // Body
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(dinoX - 6, dinoY - 8, 12, 14), const Radius.circular(2)),
      dinoPaint,
    );
    // Head
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(dinoX - 2, dinoY - 14, 10, 8), const Radius.circular(2)),
      dinoPaint,
    );
    // Eye
    canvas.drawCircle(Offset(dinoX + 4, dinoY - 11), 1.5, Paint()..color = Colors.black);
    
    // Legs (alternate based on run phase)
    final legPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    
    if (runPhase < 0.5) {
      // Left leg forward
      canvas.drawLine(Offset(dinoX - 3, dinoY + 6), Offset(dinoX - 5, groundY), legPaint);
      canvas.drawLine(Offset(dinoX + 3, dinoY + 6), Offset(dinoX + 1, groundY), legPaint);
    } else {
      // Right leg forward
      canvas.drawLine(Offset(dinoX - 3, dinoY + 6), Offset(dinoX - 1, groundY), legPaint);
      canvas.drawLine(Offset(dinoX + 3, dinoY + 6), Offset(dinoX + 5, groundY), legPaint);
    }

    // Tail
    canvas.drawLine(
      Offset(dinoX - 6, dinoY - 2),
      Offset(dinoX - 14, dinoY - 6 + sin(runPhase * pi * 4) * 2),
      legPaint,
    );

    // Cacti (static obstacles)
    final cactusPaint = Paint()..color = Colors.green[700]!;
    for (int i = 1; i <= 4; i++) {
      final cx = size.width * (i / 5);
      if ((cx - dinoX).abs() > 20) { // Don't draw cactus on top of dino
        // Trunk
        canvas.drawRect(Rect.fromLTWH(cx - 1.5, groundY - 12, 3, 12), cactusPaint);
        // Arms
        canvas.drawRect(Rect.fromLTWH(cx - 5, groundY - 10, 4, 2), cactusPaint);
        canvas.drawRect(Rect.fromLTWH(cx + 1.5, groundY - 8, 4, 2), cactusPaint);
        canvas.drawRect(Rect.fromLTWH(cx - 5, groundY - 12, 2, 4), cactusPaint);
        canvas.drawRect(Rect.fromLTWH(cx + 3.5, groundY - 10, 2, 4), cactusPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DinoPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.runPhase != runPhase;
}
