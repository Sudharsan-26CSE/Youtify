import 'package:flutter/material.dart';
import '../models/video.dart';
import '../services/user_data_service.dart';
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

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
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

  void _showUploadDialog() {
    final titleCtrl = TextEditingController();
    final urlCtrl = TextEditingController(
        text: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ');
    final thumbCtrl = TextEditingController(
        text: 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?q=80&w=600');

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final dialogBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black87;

        return AlertDialog(
          backgroundColor: dialogBg,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Upload Video',
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: 'Video Title',
                    labelStyle: TextStyle(color: Colors.grey[500]),
                    hintText: 'e.g. My Flutter App Showcase',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: thumbCtrl,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: 'Thumbnail Image URL',
                    labelStyle: TextStyle(color: Colors.grey[500]),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: urlCtrl,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: 'Video URL',
                    labelStyle: TextStyle(color: Colors.grey[500]),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleCtrl.text.trim().isEmpty
                    ? 'My New Creation'
                    : titleCtrl.text.trim();
                final newVideo = Video(
                  id: 'user_${DateTime.now().millisecondsSinceEpoch}',
                  title: title,
                  channelName: UserDataService.profileName.isNotEmpty
                      ? UserDataService.profileName
                      : 'You',
                  thumbnailUrl: thumbCtrl.text.trim(),
                  channelAvatarUrl: UserDataService.profilePhotoUrl.isNotEmpty
                      ? UserDataService.profilePhotoUrl
                      : 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=200',
                  views: '1 view',
                  timestamp: 'Just now',
                  duration: '3:45',
                  videoUrl: urlCtrl.text.trim(),
                );

                await UserDataService.addYourVideo(newVideo);
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Video uploaded successfully! 🚀'),
                      backgroundColor: const Color(0xFF1A1A1A),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Upload'),
            ),
          ],
        );
      },
    );
  }

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
              child: Text(
                'Create',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            CapsuleAction(
              icon: Icons.video_call_outlined,
              label: 'Upload Video',
              onTap: () {
                Navigator.pop(context);
                _showUploadDialog();
              },
            ),
            CapsuleAction(
              icon: Icons.live_tv_outlined,
              label: 'Go Live',
              color: Colors.red,
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Live streaming feature is ready'),
                    backgroundColor: const Color(0xFF1A1A1A),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                );
              },
            ),
            CapsuleAction(
              icon: Icons.bolt_outlined,
              label: 'Create Short',
              onTap: () {
                Navigator.pop(context);
                _showUploadDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F0F0F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final yourVideos = UserDataService.yourVideos;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Your Videos',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (yourVideos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${yourVideos.length} videos',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 500),
        curve: Curves.elasticOut,
        builder: (ctx, val, child) =>
            Transform.scale(scale: val, child: child),
        child: FloatingActionButton.extended(
          onPressed: _showAddOptions,
          backgroundColor: Colors.red,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            'Create',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: yourVideos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.video_library_outlined,
                          size: 72, color: Colors.grey[600]),
                      const SizedBox(height: 16),
                      Text(
                        'No videos yet',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap Create (+) to upload your first video',
                        style: TextStyle(
                            color: Colors.grey[500], fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _showUploadDialog,
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: const Text('Upload Video'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 120),
                  itemCount: yourVideos.length,
                  itemBuilder: (ctx, i) {
                    final v = yourVideos[i];
                    return Dismissible(
                      key: Key(v.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.redAccent,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) {
                        UserDataService.removeYourVideo(v.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Video removed'),
                            backgroundColor: const Color(0xFF1A1A1A),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      },
                      child: VideoCard(video: v, animationIndex: i > 6 ? 0 : i),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
