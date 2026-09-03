import 'package:flutter/material.dart';
import '../models/video.dart';
import '../widgets/video_card.dart';
import '../widgets/capsule_modal.dart';
import '../services/youtube_service.dart';
import 'channel_profile_screen.dart';
import 'search_screen.dart';
import '../utils/page_transitions.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  final List<Map<String, dynamic>> _channels = [
    {'name': 'CodeMaster', 'avatar': 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=200', 'watchTime': '4h 32m', 'subs': '1.2M', 'isNew': true, 'banner': 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?q=80&w=1200&auto=format&fit=crop'},
    {'name': 'FlutterDevs', 'avatar': 'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?q=80&w=200', 'watchTime': '2h 15m', 'subs': '487K', 'isNew': false, 'banner': 'https://images.unsplash.com/photo-1555066931-4365d14bab8c?q=80&w=1200&auto=format&fit=crop'},
    {'name': 'Chillhop', 'avatar': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?q=80&w=200', 'watchTime': '8h 04m', 'subs': '3.2M', 'isNew': true, 'banner': 'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?q=80&w=1200&auto=format&fit=crop'},
    {'name': 'TechLog', 'avatar': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=200', 'watchTime': '1h 08m', 'subs': '210K', 'isNew': false, 'banner': 'https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?q=80&w=1200&auto=format&fit=crop'},
    {'name': 'DevLife', 'avatar': 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?q=80&w=200', 'watchTime': '55m', 'subs': '95K', 'isNew': false, 'banner': 'https://images.unsplash.com/photo-1614624532983-4ce03382d63d?q=80&w=1200&auto=format&fit=crop'},
  ];

  final Set<String> _unfollowed = {};

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _openChannel(Map<String, dynamic> ch) {
    // Open ChannelProfileScreen inside the app
    Navigator.push(
      context,
      FadeSlidePageRoute(page: ChannelProfileScreen(channel: ch)),
    );
  }

  void _showChannelOptions(Map<String, dynamic> ch) {
    final name = ch['name'] as String;
    showCapsuleModal(
      context: context,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(children: [
                CircleAvatar(radius: 20, backgroundImage: NetworkImage(ch['avatar'] as String)),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  Text('${ch['subs']} subscribers', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                ]),
              ]),
            ),
            const Divider(color: Color(0xFF272727), height: 1),
            CapsuleAction(icon: Icons.open_in_new, label: 'View Channel', onTap: () => _openChannel(ch)),
            CapsuleAction(
              icon: _unfollowed.contains(name) ? Icons.add : Icons.person_remove_outlined,
              label: _unfollowed.contains(name) ? 'Follow' : 'Unfollow',
              color: _unfollowed.contains(name) ? Colors.green : Colors.red,
              onTap: () {
                setState(() {
                  if (_unfollowed.contains(name)) _unfollowed.remove(name);
                  else _unfollowed.add(name);
                });
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(_unfollowed.contains(name) ? 'Unfollowed $name' : 'Following $name'),
                  backgroundColor: const Color(0xFF1A1A1A),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ));
              },
            ),
            CapsuleAction(icon: Icons.message_outlined, label: 'Message', onTap: () {}),
          ],
        ),
      ),
    );
  }

  void _shareVideo(Video video) {
    final shareUrl = YouTubeService.shareUrl(video.id);
    showCapsuleModal(
      context: context,
      child: ShareCapsule(shareUrl: shareUrl, title: video.title),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                floating: true,
                backgroundColor: const Color(0xFF0F0F0F),
                elevation: 0,
                title: const Text('Subscriptions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.search, color: Colors.white),
                    onPressed: () => Navigator.push(context, FadeSlidePageRoute(page: const SearchScreen())),
                  )
                ],
              ),

              // Channel avatars row
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 110,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _channels.length,
                    itemBuilder: (context, i) {
                      final ch = _channels[i];
                      final name = ch['name'] as String;
                      final isUnfollowed = _unfollowed.contains(name);
                      return GestureDetector(
                        onTap: () => _openChannel(ch),
                        onLongPress: () => _showChannelOptions(ch),
                        child: AnimatedOpacity(
                          opacity: isUnfollowed ? 0.4 : 1.0,
                          duration: const Duration(milliseconds: 300),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            child: Column(children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: ch['isNew'] == true ? Colors.red : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(2),
                                      child: CircleAvatar(radius: 28, backgroundImage: NetworkImage(ch['avatar'] as String)),
                                    ),
                                  ),
                                  Positioned(
                                    top: -6, right: -20,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      decoration: BoxDecoration(color: const Color(0xFF272727), borderRadius: BorderRadius.circular(6)),
                                      child: Text(ch['watchTime'] as String, style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(name, style: const TextStyle(color: Colors.white, fontSize: 11)),
                              Text(ch['subs'] as String, style: TextStyle(color: Colors.grey[500], fontSize: 10)),
                            ]),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              const SliverToBoxAdapter(child: Divider(color: Color(0xFF272727), height: 1)),

              SliverPadding(
                padding: const EdgeInsets.only(bottom: 110),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final video = Video.sampleVideos[index % Video.sampleVideos.length];
                      return VideoCard(
                        video: video,
                        animationIndex: index,
                        onShare: () => _shareVideo(video),
                      );
                    },
                    childCount: 8,
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
