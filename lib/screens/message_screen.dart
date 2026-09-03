import 'package:flutter/material.dart';
import 'chat_screen.dart';
import '../utils/page_transitions.dart';

class MessageScreen extends StatefulWidget {
  const MessageScreen({super.key});

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final _searchCtrl = TextEditingController();
  bool _showSearch = false;

  final List<Map<String, dynamic>> _chats = [
    {
      'name': 'CodeMaster',
      'avatar': 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=200&auto=format&fit=crop',
      'lastMsg': 'Check out my latest Flutter tutorial! 🚀',
      'time': '2:34 PM',
      'unread': 3,
      'isOnline': true,
      'pinned': true,
    },
    {
      'name': 'FlutterDevs',
      'avatar': 'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?q=80&w=200&auto=format&fit=crop',
      'lastMsg': 'Awesome tips! Loved the video 🔥',
      'time': '11:20 AM',
      'unread': 0,
      'isOnline': true,
      'pinned': false,
    },
    {
      'name': 'Chillhop Music',
      'avatar': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?q=80&w=200&auto=format&fit=crop',
      'lastMsg': 'New lo-fi playlist is live 🎧',
      'time': 'Yesterday',
      'unread': 1,
      'isOnline': false,
      'pinned': false,
    },
    {
      'name': 'TechLog',
      'avatar': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=200&auto=format&fit=crop',
      'lastMsg': 'Thanks for the review! 🙏',
      'time': 'Mon',
      'unread': 0,
      'isOnline': false,
      'pinned': false,
    },
    {
      'name': 'DevLife',
      'avatar': 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?q=80&w=200&auto=format&fit=crop',
      'lastMsg': 'Coding at 3 AM hits different 🌙',
      'time': 'Sun',
      'unread': 0,
      'isOnline': false,
      'pinned': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
        title: _showSearch
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search messages...',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  border: InputBorder.none,
                ),
              )
            : const Text('Messages', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search, color: Colors.white),
            onPressed: () => setState(() {
              _showSearch = !_showSearch;
              if (!_showSearch) _searchCtrl.clear();
            }),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Online stories row
          SizedBox(
            height: 88,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _chats.length,
              itemBuilder: (ctx, i) {
                final chat = _chats[i];
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundImage: NetworkImage(chat['avatar'] as String),
                          ),
                          if (chat['isOnline'] == true)
                            Positioned(
                              right: 1, bottom: 1,
                              child: Container(
                                width: 12, height: 12,
                                decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, border: Border.all(color: const Color(0xFF0F0F0F), width: 2)),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (chat['name'] as String).split(' ').first,
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const Divider(color: Color(0xFF272727), height: 1),

          // Chat list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 110),
              itemCount: _chats.length,
              itemBuilder: (ctx, i) {
                final chat = _chats[i];
                final unread = chat['unread'] as int;
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 250 + i * 60),
                  curve: Curves.easeOut,
                  builder: (ctx, val, child) => Opacity(
                    opacity: val,
                    child: Transform.translate(offset: Offset(30 * (1 - val), 0), child: child),
                  ),
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      SlideRightPageRoute(page: ChatScreen(chatName: chat['name'] as String, avatarUrl: chat['avatar'] as String)),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(radius: 26, backgroundImage: NetworkImage(chat['avatar'] as String)),
                              if (chat['isOnline'] == true)
                                Positioned(right: 1, bottom: 1, child: Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, border: Border.all(color: const Color(0xFF0F0F0F), width: 2)))),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (chat['pinned'] == true) ...[
                                      const Icon(Icons.push_pin, color: Colors.grey, size: 12),
                                      const SizedBox(width: 4),
                                    ],
                                    Text(
                                      chat['name'] as String,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: unread > 0 ? FontWeight.bold : FontWeight.w500,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  chat['lastMsg'] as String,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: unread > 0 ? Colors.white70 : Colors.grey[500],
                                    fontSize: 13,
                                    fontWeight: unread > 0 ? FontWeight.w500 : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                chat['time'] as String,
                                style: TextStyle(
                                  color: unread > 0 ? Colors.green : Colors.grey[500],
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (unread > 0)
                                Container(
                                  width: 20, height: 20,
                                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                                  child: Center(
                                    child: Text(unread.toString(), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                )
                              else
                                const Icon(Icons.done_all, color: Colors.grey, size: 16),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        onPressed: () {},
        child: const Icon(Icons.message_outlined, color: Colors.white),
      ),
    );
  }
}
