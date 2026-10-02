import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../main.dart';
import '../services/user_data_service.dart';
import 'profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;

  bool _historyEnabled = true;
  bool _autoplay = true;
  bool _notifications = true;
  bool _dataSaver = false;
  bool _darkMode = true;
  bool _restrictedMode = false;
  String _version = '1.0.0';

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400))
      ..forward();
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _loadPrefs();
    _loadVersion();
    UserDataService.addListener(_onUserDataChanged);
  }

  void _onUserDataChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _historyEnabled = prefs.getBool('history_enabled') ?? true;
      _autoplay = prefs.getBool('autoplay') ?? true;
      _notifications = prefs.getBool('notifications') ?? true;
      _dataSaver = prefs.getBool('data_saver') ?? false;
      _darkMode = prefs.getBool('dark_mode') ?? true;
      _restrictedMode = prefs.getBool('restricted_mode') ?? false;
    });
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      setState(() => _version = '${info.version}+${info.buildNumber}');
    } catch (_) {
      setState(() => _version = '1.0.0');
    }
  }

  Future<void> _setPref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  void dispose() {
    UserDataService.removeListener(_onUserDataChanged);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F0F0F) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);
    final textColor = isDark ? Colors.white : Colors.black87;

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
          'Settings',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
      ),
      body: FadeTransition(
        opacity: _fade,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 60),
          children: [
            _Header('Account'),
            _Card(
              cardBg: cardBg,
              children: [
                _ProfileTile(
                  textColor: textColor,
                  isDark: isDark,
                  onTap: () => showEditProfileDialog(context),
                )
              ],
            ),

            _Header('Appearance'),
            _Card(
              cardBg: cardBg,
              children: [
                _Toggle(
                  icon: _darkMode
                      ? Icons.dark_mode_outlined
                      : Icons.light_mode_outlined,
                  label: _darkMode ? 'Dark Mode' : 'Bright Mode',
                  subtitle: _darkMode
                      ? 'Dark theme is active across all screens'
                      : 'Bright theme is active across all screens',
                  value: _darkMode,
                  textColor: textColor,
                  isDark: isDark,
                  onChanged: (v) {
                    setState(() => _darkMode = v);
                    _setPref('dark_mode', v);
                    // Immediately toggle global theme mode
                    themeNotifier.value =
                        v ? ThemeMode.dark : ThemeMode.light;
                  },
                ),
              ],
            ),

            _Header('Playback'),
            _Card(
              cardBg: cardBg,
              children: [
                _Toggle(
                  icon: Icons.play_circle_outline,
                  label: 'Autoplay',
                  subtitle: 'Automatically play next video',
                  value: _autoplay,
                  textColor: textColor,
                  isDark: isDark,
                  onChanged: (v) {
                    setState(() => _autoplay = v);
                    _setPref('autoplay', v);
                  },
                ),
                _Toggle(
                  icon: Icons.data_saver_off_outlined,
                  label: 'Data Saver',
                  subtitle: 'Reduce data usage and video quality',
                  value: _dataSaver,
                  textColor: textColor,
                  isDark: isDark,
                  onChanged: (v) {
                    setState(() => _dataSaver = v);
                    _setPref('data_saver', v);
                  },
                ),
              ],
            ),

            _Header('Privacy & History'),
            _Card(
              cardBg: cardBg,
              children: [
                _Toggle(
                  icon: Icons.history,
                  label: 'Watch History',
                  subtitle: _historyEnabled
                      ? 'History is being saved'
                      : 'History is paused',
                  value: _historyEnabled,
                  textColor: textColor,
                  isDark: isDark,
                  onChanged: (v) {
                    setState(() => _historyEnabled = v);
                    _setPref('history_enabled', v);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(v
                            ? 'Watch history resumed'
                            : 'Watch history paused'),
                        backgroundColor: const Color(0xFF1A1A1A),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  },
                ),
                _Toggle(
                  icon: Icons.child_care_outlined,
                  label: 'Restricted Mode',
                  subtitle: 'Filter mature content',
                  value: _restrictedMode,
                  textColor: textColor,
                  isDark: isDark,
                  onChanged: (v) {
                    setState(() => _restrictedMode = v);
                    _setPref('restricted_mode', v);
                  },
                ),
              ],
            ),

            _Header('Notifications'),
            _Card(
              cardBg: cardBg,
              children: [
                _Toggle(
                  icon: Icons.notifications_outlined,
                  label: 'Push Notifications',
                  subtitle: 'Get notified about new videos & subscriptions',
                  value: _notifications,
                  textColor: textColor,
                  isDark: isDark,
                  onChanged: (v) {
                    setState(() => _notifications = v);
                    _setPref('notifications', v);
                  },
                ),
              ],
            ),

            _Header('About'),
            _Card(
              cardBg: cardBg,
              children: [
                ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.07)
                          : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.info_outline,
                        color: isDark ? Colors.white : Colors.black87,
                        size: 18),
                  ),
                  title: Text('Version',
                      style: TextStyle(color: textColor, fontSize: 15)),
                  subtitle: Text('Youtify $_version',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String label;
  const _Header(this.label);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 16, top: 24, bottom: 8),
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
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  final Color cardBg;
  const _Card({required this.children, required this.cardBg});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(children: children),
      );
}

class _Toggle extends StatelessWidget {
  final IconData icon;
  final String label, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color textColor;
  final bool isDark;

  const _Toggle({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.textColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon,
              color: isDark ? Colors.white : Colors.black87, size: 18),
        ),
        title: Text(label,
            style: TextStyle(
                color: textColor, fontSize: 15, fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle,
            style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        trailing: Transform.scale(
          scale: 0.9,
          child: Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.red,
            activeTrackColor: Colors.red.withValues(alpha: 0.3),
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Colors.grey.withValues(alpha: 0.2),
          ),
        ),
      );
}

class _ProfileTile extends StatelessWidget {
  final Color textColor;
  final bool isDark;
  final VoidCallback onTap;

  const _ProfileTile({
    required this.textColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = UserDataService.profileName.isNotEmpty
        ? UserDataService.profileName
        : (user?.displayName?.isNotEmpty == true
            ? user!.displayName!
            : (user?.email?.split('@').first ?? 'User'));
    final email = user?.email ?? 'Not signed in';
    final photoUrl = UserDataService.profilePhotoUrl.isNotEmpty
        ? UserDataService.profilePhotoUrl
        : (user?.photoURL ??
            'https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=200&auto=format&fit=crop');

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: Colors.grey[800],
        backgroundImage: NetworkImage(photoUrl),
      ),
      title: Text(
        displayName,
        style: TextStyle(
            color: textColor, fontSize: 15, fontWeight: FontWeight.w600),
      ),
      subtitle: Text('Tap to edit profile • $email',
          style: TextStyle(color: Colors.grey[500], fontSize: 12)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('Edit',
            style: TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold)),
      ),
    );
  }
}
