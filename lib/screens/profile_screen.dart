import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/page_transitions.dart';
import '../widgets/capsule_modal.dart';
import 'settings_screen.dart';
import 'downloads_screen.dart';
import 'liked_videos_screen.dart';
import 'watch_history_screen.dart';
import 'playlists_screen.dart';
import 'your_videos_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  late AnimationController _fabCtrl;

  final _user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fabCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _fabCtrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _fabCtrl.dispose();
    super.dispose();
  }

  void _showEditProfile() {
    final nameCtrl = TextEditingController(text: _user?.displayName ?? '');
    final photoCtrl = TextEditingController(text: _user?.photoURL ?? '');
    showCapsuleModal(
      context: context,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(context).viewInsets.bottom + 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Edit Profile', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Display Name', style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1)),
            const SizedBox(height: 6),
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter your name...',
                hintStyle: TextStyle(color: Colors.grey[500]),
                filled: true,
                fillColor: Colors.white.withOpacity(0.07),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Photo URL', style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1)),
            const SizedBox(height: 6),
            TextField(
              controller: photoCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Paste photo URL...',
                hintStyle: TextStyle(color: Colors.grey[500]),
                filled: true,
                fillColor: Colors.white.withOpacity(0.07),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red)),
              ),
            ),
            const SizedBox(height: 8),
            Text('Email: ${_user?.email ?? 'N/A'}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  try {
                    if (nameCtrl.text.trim().isNotEmpty) {
                      await _user?.updateDisplayName(nameCtrl.text.trim());
                    }
                    if (photoCtrl.text.trim().isNotEmpty) {
                      await _user?.updatePhotoURL(photoCtrl.text.trim());
                    }
                    await _user?.reload();
                    if (mounted) {
                      Navigator.pop(context);
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Profile updated successfully! ✅'),
                          backgroundColor: const Color(0xFF1A1A1A),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to update: $e'),
                        backgroundColor: Colors.red[900],
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateOptions() {
    showCapsuleModal(
      context: context,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Create', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            CapsuleAction(icon: Icons.video_call_outlined, label: 'Upload Video', onTap: () {
              Navigator.push(context, FadeSlidePageRoute(page: const YourVideosScreen()));
            }),
            CapsuleAction(icon: Icons.live_tv_outlined, label: 'Go Live', color: Colors.red, onTap: () {}),
            CapsuleAction(icon: Icons.bolt_outlined, label: 'Create Short', onTap: () {}),
          ],
        ),
      ),
    );
  }

  void _confirmSignOut() {
    showCapsuleModal(
      context: context,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sign Out', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Are you sure you want to sign out?', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withOpacity(0.2)),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  void _showFeedback() {
    showCapsuleModal(
      context: context,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(context).viewInsets.bottom + 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Help & Feedback', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Tell us what you think...',
                hintStyle: TextStyle(color: Colors.grey[500]),
                filled: true,
                fillColor: Colors.white.withOpacity(0.07),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Feedback sent! Thank you ❤️'),
                      backgroundColor: const Color(0xFF1A1A1A),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                child: const Text('Send Feedback', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _user?.displayName ?? 'Sudharsan';
    final email = _user?.email ?? 'sudharsan@example.com';
    final photoUrl = _user?.photoURL;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      floatingActionButton: ScaleTransition(
        scale: CurvedAnimation(parent: _fabCtrl, curve: Curves.elasticOut),
        child: FloatingActionButton(
          onPressed: _showCreateOptions,
          backgroundColor: Colors.red,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      body: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: const Color(0xFF0F0F0F),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.white), onPressed: _showEditProfile),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Blurred gradient background
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF2A0A0A), Color(0xFF1A0505), Color(0xFF0F0F0F)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      // Blur overlay
                      BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                        child: Container(color: Colors.transparent),
                      ),
                      SafeArea(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 20),
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 44,
                                  backgroundColor: Colors.grey[800],
                                  backgroundImage: photoUrl != null
                                      ? NetworkImage(photoUrl)
                                      : const NetworkImage('https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=200&auto=format&fit=crop'),
                                ),
                                Positioned(
                                  right: 0, bottom: 0,
                                  child: Container(
                                    width: 28, height: 28,
                                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(displayName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                            Text('@${displayName.toLowerCase().replaceAll(' ', '_')}', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _StatChip(label: 'Subscribers', value: '1.2K'),
                                const SizedBox(width: 24),
                                _StatChip(label: 'Videos', value: '42'),
                                const SizedBox(width: 24),
                                _StatChip(label: 'Views', value: '89K'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionLabel('Account'),
                      _buildCard([
                        _MenuItem(icon: Icons.video_library_outlined, label: 'Your Videos', subtitle: '42 videos uploaded',
                            onTap: () => Navigator.push(context, FadeSlidePageRoute(page: const YourVideosScreen()))),
                        _MenuItem(icon: Icons.download_outlined, label: 'Downloads', subtitle: '25 videos saved offline',
                            onTap: () => Navigator.push(context, FadeSlidePageRoute(page: const DownloadsScreen()))),
                        _MenuItem(icon: Icons.thumb_up_outlined, label: 'Liked Videos', subtitle: 'Videos you\'ve liked',
                            onTap: () => Navigator.push(context, FadeSlidePageRoute(page: const LikedVideosScreen()))),
                      ]),

                      _SectionLabel('Activity'),
                      _buildCard([
                        _MenuItem(icon: Icons.history, label: 'Watch History', subtitle: 'View your watch history',
                            onTap: () => Navigator.push(context, FadeSlidePageRoute(page: const WatchHistoryScreen()))),
                        _MenuItem(icon: Icons.playlist_play, label: 'Playlists', subtitle: '8 playlists',
                            onTap: () => Navigator.push(context, FadeSlidePageRoute(page: const PlaylistsScreen()))),
                      ]),

                      _SectionLabel('Preferences'),
                      _buildCard([
                        _MenuItem(icon: Icons.settings_outlined, label: 'Settings', subtitle: 'App preferences',
                            onTap: () => Navigator.push(context, SlideRightPageRoute(page: const SettingsScreen()))),
                        _MenuItem(icon: Icons.help_outline, label: 'Help & Feedback', subtitle: 'Get support or share feedback',
                            onTap: _showFeedback),
                        _MenuItem(icon: Icons.info_outline, label: 'About Youtify', subtitle: 'Version 1.0.0', onTap: () {}),
                      ]),

                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _confirmSignOut,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            foregroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.logout),
                          label: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _SectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(label.toUpperCase(), style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
  );

  Widget _buildCard(List<_MenuItem> items) => Container(
    decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(14)),
    child: Column(
      children: items.asMap().entries.map((entry) {
        final i = entry.key;
        final item = entry.value;
        return Column(
          children: [
            ListTile(
              leading: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.07), borderRadius: BorderRadius.circular(10)),
                child: Icon(item.icon, color: Colors.white, size: 20),
              ),
              title: Text(item.label, style: const TextStyle(color: Colors.white, fontSize: 15)),
              subtitle: Text(item.subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: item.onTap,
            ),
            if (i < items.length - 1) const Divider(color: Color(0xFF272727), height: 1, indent: 16),
          ],
        );
      }).toList(),
    ),
  );
}

class _StatChip extends StatelessWidget {
  final String label, value;
  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
    Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
  ]);
}

class _MenuItem {
  final IconData icon;
  final String label, subtitle;
  final VoidCallback onTap;
  const _MenuItem({required this.icon, required this.label, required this.subtitle, required this.onTap});
}
