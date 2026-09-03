import 'package:flutter/material.dart';

class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  final List<Map<String, dynamic>> _playlists = [
    {'title': 'Flutter Tutorials', 'count': 12, 'thumb': 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?q=80&w=400'},
    {'title': 'Lo-Fi Music', 'count': 8, 'thumb': 'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?q=80&w=400'},
    {'title': 'Gaming Highlights', 'count': 5, 'thumb': 'https://images.unsplash.com/photo-1542751371-adc38448a05e?q=80&w=400'},
    {'title': 'Tech Reviews', 'count': 20, 'thumb': 'https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?q=80&w=400'},
    {'title': 'Watch Later', 'count': 3, 'thumb': 'https://images.unsplash.com/photo-1555066931-4365d14bab8c?q=80&w=400'},
    {'title': 'Favourites', 'count': 16, 'thumb': 'https://images.unsplash.com/photo-1614624532983-4ce03382d63d?q=80&w=400'},
  ];

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text('Playlists', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.add, color: Colors.white), onPressed: () {}),
        ],
      ),
      body: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: _playlists.length,
            itemBuilder: (ctx, i) {
              final pl = _playlists[i];
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 300 + i * 60),
                curve: Curves.easeOutCubic,
                builder: (ctx, val, child) => Opacity(opacity: val, child: Transform.translate(offset: Offset(0, 20 * (1 - val)), child: child)),
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(14)),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(pl['thumb'] as String, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(color: Colors.grey[900])),
                              Container(color: Colors.black.withOpacity(0.3)),
                              Center(child: Icon(Icons.playlist_play, color: Colors.white.withOpacity(0.8), size: 40)),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(pl['title'] as String, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Text('${pl['count']} videos', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
