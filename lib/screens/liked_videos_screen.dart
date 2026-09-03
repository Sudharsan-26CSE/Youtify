import 'package:flutter/material.dart';
import '../models/video.dart';
import '../widgets/video_card.dart';

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

  // Simulated liked videos
  final List<Video> _likedVideos = Video.sampleVideos.take(3).toList();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
      ..forward();
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
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
        title: const Text('Liked Videos',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort, color: Colors.grey),
            onPressed: () {},
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: _likedVideos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.thumb_up_outlined,
                          size: 72, color: Colors.grey[700]),
                      const SizedBox(height: 16),
                      Text('No liked videos yet',
                          style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 18,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text('Videos you like will appear here',
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 13)),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.thumb_up,
                              color: Colors.red, size: 18),
                          const SizedBox(width: 8),
                          Text('${_likedVideos.length} videos',
                              style: TextStyle(
                                  color: Colors.grey[400], fontSize: 13)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 120),
                        itemCount: _likedVideos.length,
                        itemBuilder: (context, i) => VideoCard(
                          video: _likedVideos[i],
                          animationIndex: i,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
