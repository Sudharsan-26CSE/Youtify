import 'package:flutter/material.dart';
import '../models/video.dart';
import '../widgets/video_card.dart';
import '../widgets/capsule_modal.dart';

class YourVideosScreen extends StatefulWidget {
  const YourVideosScreen({super.key});

  @override
  State<YourVideosScreen> createState() => _YourVideosScreenState();
}

class _YourVideosScreenState extends State<YourVideosScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  bool _showUploadFAB = false;

  final List<Video> _yourVideos = Video.sampleVideos.take(2).toList();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..forward();
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _showAddOptions() {
    showCapsuleModal(
      context: context,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Create', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            CapsuleAction(icon: Icons.video_call_outlined, label: 'Upload Video', onTap: () {}),
            CapsuleAction(icon: Icons.live_tv_outlined, label: 'Go Live', color: Colors.red, onTap: () {}),
            CapsuleAction(icon: Icons.bolt_outlined, label: 'Create Short', onTap: () {}),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text('Your Videos', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 500),
        curve: Curves.elasticOut,
        builder: (ctx, val, child) => Transform.scale(scale: val, child: child),
        child: FloatingActionButton.extended(
          onPressed: _showAddOptions,
          backgroundColor: Colors.red,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Create', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
      body: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: _yourVideos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.video_library_outlined, size: 72, color: Colors.grey[700]),
                      const SizedBox(height: 16),
                      Text('No videos yet', style: TextStyle(color: Colors.grey[500], fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text('Tap + to upload your first video', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 120),
                  itemCount: _yourVideos.length,
                  itemBuilder: (ctx, i) => VideoCard(video: _yourVideos[i], animationIndex: i),
                ),
        ),
      ),
    );
  }
}
