import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  final String chatName;
  final String avatarUrl;

  const ChatScreen({super.key, required this.chatName, required this.avatarUrl});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _isTyping = false;

  final List<Map<String, dynamic>> _messages = [
    {'text': 'Hey! Just watched your latest video 🔥', 'isMe': false, 'time': '10:20 AM', 'read': true},
    {'text': 'Thanks! Glad you enjoyed it 😊', 'isMe': true, 'time': '10:22 AM', 'read': true},
    {'text': 'The Flutter animations part was insane!', 'isMe': false, 'time': '10:23 AM', 'read': true},
    {'text': 'Yeah I spent 3 days on those lol', 'isMe': true, 'time': '10:24 AM', 'read': true},
    {'text': 'Can you make a part 2? Please 🙏', 'isMe': false, 'time': '10:25 AM', 'read': true},
    {'text': 'Already planned! Coming next week', 'isMe': true, 'time': '10:26 AM', 'read': false},
  ];

  late List<AnimationController> _msgAnims;

  @override
  void initState() {
    super.initState();
    _msgAnims = List.generate(
      _messages.length,
      (i) => AnimationController(vsync: this, duration: const Duration(milliseconds: 350)),
    );
    // Stagger message entries
    for (int i = 0; i < _msgAnims.length; i++) {
      Future.delayed(Duration(milliseconds: i * 60), () {
        if (mounted) _msgAnims[i].forward();
      });
    }
  }

  @override
  void dispose() {
    for (final a in _msgAnims) {
      a.dispose();
    }
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    final newCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    setState(() {
      _messages.add({'text': text, 'isMe': true, 'time': _currentTime(), 'read': false});
      _msgAnims.add(newCtrl);
      _msgCtrl.clear();
      _isTyping = false;
    });

    newCtrl.forward();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    // Simulate reply after 1.5s
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      final replyCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
      setState(() {
        _messages.add({'text': 'Thanks for the message! 🙌', 'isMe': false, 'time': _currentTime(), 'read': true});
        _msgAnims.add(replyCtrl);
      });
      replyCtrl.forward();
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        }
      });
    });
  }

  String _currentTime() {
    final now = DateTime.now();
    final h = now.hour > 12 ? now.hour - 12 : now.hour == 0 ? 12 : now.hour;
    final m = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(radius: 18, backgroundImage: NetworkImage(widget.avatarUrl)),
                Positioned(right: 0, bottom: 0, child: Container(width: 10, height: 10, decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, border: Border.all(color: const Color(0xFF1A1A1A), width: 1.5)))),
              ],
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.chatName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                const Text('online', style: TextStyle(color: Colors.green, fontSize: 12)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.videocam_outlined, color: Colors.white), onPressed: () {}),
          IconButton(icon: const Icon(Icons.call_outlined, color: Colors.white), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert, color: Colors.white), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              itemCount: _messages.length,
              itemBuilder: (ctx, i) {
                final msg = _messages[i];
                final isMe = msg['isMe'] as bool;
                final anim = i < _msgAnims.length ? _msgAnims[i] : null;

                Widget bubble = _buildBubble(msg, isMe);

                if (anim != null) {
                  bubble = FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset(isMe ? 0.3 : -0.3, 0),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                      child: bubble,
                    ),
                  );
                }

                return bubble;
              },
            ),
          ),

          // Typing indicator / input
          Container(
            color: const Color(0xFF1A1A1A),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.grey),
                    onPressed: () {},
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF272727),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _msgCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        maxLines: null,
                        onChanged: (v) => setState(() => _isTyping = v.trim().isNotEmpty),
                        decoration: InputDecoration(
                          hintText: 'Message',
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                    child: _isTyping
                        ? GestureDetector(
                            key: const ValueKey('send'),
                            onTap: _sendMessage,
                            child: Container(
                              width: 44, height: 44,
                              decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                              child: const Icon(Icons.send, color: Colors.white, size: 20),
                            ),
                          )
                        : GestureDetector(
                            key: const ValueKey('mic'),
                            onTap: () {},
                            child: Container(
                              width: 44, height: 44,
                              decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                              child: const Icon(Icons.mic, color: Colors.white, size: 22),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(Map<String, dynamic> msg, bool isMe) {
    return Padding(
      padding: EdgeInsets.only(
        top: 4, bottom: 4,
        left: isMe ? 60 : 0,
        right: isMe ? 0 : 60,
      ),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(radius: 14, backgroundImage: NetworkImage(widget.avatarUrl)),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFF005C4B) : const Color(0xFF1F2C34),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(msg['text'] as String, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(msg['time'] as String, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          (msg['read'] as bool) ? Icons.done_all : Icons.done,
                          color: (msg['read'] as bool) ? Colors.blue[300] : Colors.white54,
                          size: 14,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
