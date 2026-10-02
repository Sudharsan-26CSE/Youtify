import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/page_transitions.dart';
import '../widgets/capsule_modal.dart';
import '../services/user_data_service.dart';
import '../services/download_service.dart';
import '../services/auth_service.dart';
import 'settings_screen.dart';
import 'downloads_screen.dart';
import 'liked_videos_screen.dart';
import 'watch_history_screen.dart';
import 'playlists_screen.dart';
import 'your_videos_screen.dart';

void showEditProfileDialog(BuildContext context) {
  final user = FirebaseAuth.instance.currentUser;
  final currentName = UserDataService.profileName.isNotEmpty
      ? UserDataService.profileName
      : (user?.displayName ?? 'Sudharsan');
  final currentPhoto = UserDataService.profilePhotoUrl.isNotEmpty
      ? UserDataService.profilePhotoUrl
      : (user?.photoURL ??
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=200&auto=format&fit=crop');

  final nameCtrl = TextEditingController(text: currentName);
  final photoCtrl = TextEditingController(text: currentPhoto);

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      final dialogBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
      final textColor = isDark ? Colors.white : Colors.black87;
      final inputBg = isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.05);

      return Center(
        child: SingleChildScrollView(
          child: Dialog(
            backgroundColor: dialogBg,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Edit Profile',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.grey[500]),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Display Name',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textColor, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Enter your name...',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      filled: true,
                      fillColor: inputBg,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Photo URL',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: photoCtrl,
                          style: TextStyle(color: textColor, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Paste photo URL...',
                            hintStyle: TextStyle(color: Colors.grey[500]),
                            filled: true,
                            fillColor: inputBg,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.red),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: inputBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.copy, size: 20),
                          color: Colors.redAccent,
                          tooltip: 'Copy Photo URL',
                          onPressed: () {
                            Clipboard.setData(
                                ClipboardData(text: photoCtrl.text.trim()));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    const Text('Photo link copied to clipboard! 📋'),
                                backgroundColor: const Color(0xFF1A1A1A),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Email: ${user?.email ?? 'sudharsan@example.com'}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final newName = nameCtrl.text.trim();
                        final newPhoto = photoCtrl.text.trim();

                        await UserDataService.updateProfile(
                          name: newName.isNotEmpty ? newName : null,
                          photoUrl: newPhoto.isNotEmpty ? newPhoto : null,
                        );

                        try {
                          if (newName.isNotEmpty) {
                            await user?.updateDisplayName(newName);
                          }
                          if (newPhoto.isNotEmpty) {
                            await user?.updatePhotoURL(newPhoto);
                          }
                          await user?.reload();
                        } catch (_) {}

                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Profile saved successfully! ✅'),
                            backgroundColor: const Color(0xFF1A1A1A),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Save Changes',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

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

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
      ..forward();
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fabCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _fabCtrl.forward();
    });

    UserDataService.addListener(_onUserDataChanged);
    DownloadService.addListener(_onUserDataChanged);
  }

  @override
  void dispose() {
    UserDataService.removeListener(_onUserDataChanged);
    DownloadService.removeListener(_onUserDataChanged);
    _ctrl.dispose();
    _fabCtrl.dispose();
    super.dispose();
  }

  void _onUserDataChanged() {
    if (mounted) setState(() {});
  }

  void _showAvatarPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final sheetBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black87;

        return Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Change Profile Photo',
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt, color: Colors.red),
                ),
                title: Text(
                  'Take Selfie (Camera)',
                  style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Capture a new photo from your camera',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  // Use dynamic modern selfie portrait
                  final selfieUrl =
                      'https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=400&auto=format&fit=crop';
                  await UserDataService.updateProfile(photoUrl: selfieUrl);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Selfie captured and updated! 📸'),
                      backgroundColor: const Color(0xFF1A1A1A),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                },
              ),
              const Divider(height: 16),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library, color: Colors.blue),
                ),
                title: Text(
                  'Choose from Gallery',
                  style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Pick from your photos or avatars',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showGalleryPresets();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showGalleryPresets() {
    final presets = [
      'https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=400',
      'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=400',
      'https://images.unsplash.com/photo-1494790108377-be9c29b29330?q=80&w=400',
      'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?q=80&w=400',
      'https://images.unsplash.com/photo-1517841905240-472988babdf9?q=80&w=400',
      'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?q=80&w=400',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final sheetBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black87;

        return Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Avatar from Gallery',
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: presets.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, idx) {
                    final url = presets[idx];
                    return GestureDetector(
                      onTap: () async {
                        Navigator.pop(ctx);
                        await UserDataService.updateProfile(photoUrl: url);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Avatar changed from gallery! ✨'),
                            backgroundColor: const Color(0xFF1A1A1A),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      },
                      child: CircleAvatar(
                        radius: 38,
                        backgroundImage: NetworkImage(url),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
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
                child: Text(
                  'Create',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            CapsuleAction(
              icon: Icons.video_call_outlined,
              label: 'Upload Video',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    FadeSlidePageRoute(page: const YourVideosScreen()));
              },
            ),
            CapsuleAction(
              icon: Icons.live_tv_outlined,
              label: 'Go Live',
              color: Colors.red,
              onTap: () => Navigator.pop(context),
            ),
            CapsuleAction(
              icon: Icons.bolt_outlined,
              label: 'Create Short',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    FadeSlidePageRoute(page: const YourVideosScreen()));
              },
            ),
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
            const Text(
              'Sign Out',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Are you sure you want to sign out?',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await AuthService.signOut();
                      if (context.mounted) {
                        Navigator.of(context)
                            .pushNamedAndRemoveUntil('/login', (_) => false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Sign Out',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
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
    final cardBg = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);
    final textColor = isDark ? Colors.white : Colors.black87;

    final displayName = UserDataService.profileName.isNotEmpty
        ? UserDataService.profileName
        : (_user?.displayName?.isNotEmpty == true
            ? _user!.displayName!
            : (_user?.email?.split('@').first ?? 'User'));
    final photoUrl = UserDataService.profilePhotoUrl.isNotEmpty
        ? UserDataService.profilePhotoUrl
        : (_user?.photoURL ??
            'https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=200&auto=format&fit=crop');

    final yourVideosCount = UserDataService.yourVideos.length;
    final downloadsCount = DownloadService.items.length;
    final likedCount = UserDataService.likedVideos.length;
    final historyCount = UserDataService.watchHistory.length;

    return Scaffold(
      backgroundColor: bgColor,
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
                backgroundColor: isDark ? const Color(0xFF0F0F0F) : Colors.white,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back, color: textColor),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    icon: Icon(Icons.edit_outlined, color: textColor),
                    tooltip: 'Edit Profile',
                    onPressed: () => showEditProfileDialog(context),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? [
                                    const Color(0xFF2A0A0A),
                                    const Color(0xFF1A0505),
                                    const Color(0xFF0F0F0F)
                                  ]
                                : [
                                    Colors.red.shade100,
                                    Colors.red.shade50,
                                    Colors.white
                                  ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
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
                                  backgroundImage: NetworkImage(photoUrl),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: GestureDetector(
                                    onTap: _showAvatarPicker,
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isDark
                                              ? const Color(0xFF0F0F0F)
                                              : Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                      child: const Icon(Icons.camera_alt,
                                          color: Colors.white, size: 16),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              displayName,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '@${displayName.toLowerCase().replaceAll(' ', '_')}',
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _StatChip(
                                    label: 'Subscribers',
                                    value: '1.2K',
                                    textColor: textColor),
                                const SizedBox(width: 24),
                                _StatChip(
                                    label: 'Videos',
                                    value: '$yourVideosCount',
                                    textColor: textColor),
                                const SizedBox(width: 24),
                                _StatChip(
                                    label: 'Views',
                                    value: '89K',
                                    textColor: textColor),
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
                      _buildCard(cardBg, textColor, isDark, [
                        _MenuItem(
                          icon: Icons.video_library_outlined,
                          label: 'Your Videos',
                          subtitle: yourVideosCount == 0
                              ? 'No videos uploaded yet'
                              : '$yourVideosCount video${yourVideosCount > 1 ? 's' : ''} uploaded',
                          onTap: () => Navigator.push(
                              context,
                              FadeSlidePageRoute(
                                  page: const YourVideosScreen())),
                        ),
                        _MenuItem(
                          icon: Icons.download_outlined,
                          label: 'Downloads',
                          subtitle: downloadsCount == 0
                              ? 'No downloads'
                              : '$downloadsCount video${downloadsCount > 1 ? 's' : ''} saved offline',
                          onTap: () => Navigator.push(
                              context,
                              FadeSlidePageRoute(
                                  page: const DownloadsScreen())),
                        ),
                        _MenuItem(
                          icon: Icons.thumb_up_outlined,
                          label: 'Liked Videos',
                          subtitle: likedCount == 0
                              ? 'No liked videos'
                              : '$likedCount video${likedCount > 1 ? 's' : ''} liked',
                          onTap: () => Navigator.push(
                              context,
                              FadeSlidePageRoute(
                                  page: const LikedVideosScreen())),
                        ),
                      ]),
                      _SectionLabel('Activity'),
                      _buildCard(cardBg, textColor, isDark, [
                        _MenuItem(
                          icon: Icons.history,
                          label: 'Watch History',
                          subtitle: historyCount == 0
                              ? 'No watch history'
                              : '$historyCount video${historyCount > 1 ? 's' : ''} watched',
                          onTap: () => Navigator.push(
                              context,
                              FadeSlidePageRoute(
                                  page: const WatchHistoryScreen())),
                        ),
                        _MenuItem(
                          icon: Icons.playlist_play,
                          label: 'Playlists',
                          subtitle: '6 playlists',
                          onTap: () => Navigator.push(
                              context,
                              FadeSlidePageRoute(
                                  page: const PlaylistsScreen())),
                        ),
                      ]),
                      _SectionLabel('Preferences'),
                      _buildCard(cardBg, textColor, isDark, [
                        _MenuItem(
                          icon: Icons.settings_outlined,
                          label: 'Settings',
                          subtitle: 'App preferences & appearance',
                          onTap: () => Navigator.push(context,
                              SlideRightPageRoute(page: const SettingsScreen())),
                        ),
                        _MenuItem(
                          icon: Icons.info_outline,
                          label: 'About Youtify',
                          subtitle: 'Version 1.0.0',
                          onTap: () {},
                        ),
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
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.logout),
                          label: const Text('Sign Out',
                              style: TextStyle(fontWeight: FontWeight.bold)),
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
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      );

  Widget _buildCard(Color cardBg, Color textColor, bool isDark,
          List<_MenuItem> items) =>
      Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: items.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            return Column(
              children: [
                ListTile(
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.07)
                          : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(item.icon,
                        color: isDark ? Colors.white : Colors.black87, size: 20),
                  ),
                  title: Text(item.label,
                      style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w500)),
                  subtitle: Text(item.subtitle,
                      style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: item.onTap,
                ),
                if (i < items.length - 1)
                  Divider(
                    color: isDark
                        ? const Color(0xFF272727)
                        : Colors.black.withValues(alpha: 0.06),
                    height: 1,
                    indent: 16,
                  ),
              ],
            );
          }).toList(),
        ),
      );
}

class _StatChip extends StatelessWidget {
  final String label, value;
  final Color textColor;
  const _StatChip(
      {required this.label, required this.value, required this.textColor});

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value,
            style: TextStyle(
                color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
      ]);
}

class _MenuItem {
  final IconData icon;
  final String label, subtitle;
  final VoidCallback onTap;
  const _MenuItem(
      {required this.icon,
      required this.label,
      required this.subtitle,
      required this.onTap});
}
