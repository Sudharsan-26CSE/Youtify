import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../main.dart';

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
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..forward();
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _loadPrefs();
    _loadVersion();
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
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text('Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: FadeTransition(
        opacity: _fade,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            _Header('Account'),
            _Card(children: [_ProfileTile()]),

            _Header('Playback'),
            _Card(children: [
              _Toggle(icon: Icons.play_circle_outline, label: 'Autoplay', subtitle: 'Automatically play next video',
                  value: _autoplay, onChanged: (v) { setState(() => _autoplay = v); _setPref('autoplay', v); }),
              _Toggle(icon: Icons.data_saver_off_outlined, label: 'Data Saver', subtitle: 'Reduce data usage',
                  value: _dataSaver, onChanged: (v) { setState(() => _dataSaver = v); _setPref('data_saver', v); }),
            ]),

            _Header('Privacy & History'),
            _Card(children: [
              _Toggle(
                icon: Icons.history, label: 'Watch History',
                subtitle: _historyEnabled ? 'History is being saved' : 'History is paused',
                value: _historyEnabled,
                onChanged: (v) {
                  setState(() => _historyEnabled = v);
                  _setPref('history_enabled', v);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(v ? 'Watch history resumed' : 'Watch history paused'),
                    backgroundColor: const Color(0xFF1A1A1A),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ));
                },
              ),
              _Toggle(icon: Icons.child_care_outlined, label: 'Restricted Mode', subtitle: 'Filter mature content',
                  value: _restrictedMode, onChanged: (v) { setState(() => _restrictedMode = v); _setPref('restricted_mode', v); }),
            ]),

            _Header('Notifications'),
            _Card(children: [
              _Toggle(icon: Icons.notifications_outlined, label: 'Push Notifications', subtitle: 'Get notified about new videos',
                  value: _notifications, onChanged: (v) { setState(() => _notifications = v); _setPref('notifications', v); }),
            ]),

            _Header('Appearance'),
            _Card(children: [
              _Toggle(
                icon: Icons.dark_mode_outlined, label: 'Dark Mode', subtitle: 'Switch between dark and light theme',
                value: _darkMode,
                onChanged: (v) {
                  setState(() => _darkMode = v);
                  _setPref('dark_mode', v);
                  // Immediately switch global theme
                  themeNotifier.value = v ? ThemeMode.dark : ThemeMode.light;
                },
              ),
            ]),

            _Header('About'),
            _Card(children: [
              ListTile(
                leading: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.07), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.info_outline, color: Colors.white, size: 18),
                ),
                title: const Text('Version', style: TextStyle(color: Colors.white, fontSize: 15)),
                subtitle: Text('Youtify $_version', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            ]),
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
    child: Text(label.toUpperCase(), style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
  );
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(14)),
    child: Column(children: children),
  );
}

class _Toggle extends StatelessWidget {
  final IconData icon;
  final String label, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _Toggle({required this.icon, required this.label, required this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.07), borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: Colors.white, size: 18),
    ),
    title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 15)),
    subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
    trailing: Transform.scale(
      scale: 0.9,
      child: Switch(value: value, onChanged: onChanged, activeColor: Colors.red, activeTrackColor: Colors.red.withOpacity(0.3), inactiveThumbColor: Colors.grey, inactiveTrackColor: Colors.grey.withOpacity(0.2)),
    ),
  );
}

class _ProfileTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return ListTile(
      leading: CircleAvatar(
        radius: 20,
        backgroundImage: user?.photoURL != null
            ? NetworkImage(user!.photoURL!)
            : const NetworkImage('https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=200&auto=format&fit=crop'),
      ),
      title: Text(user?.displayName ?? 'Sudharsan', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
      subtitle: Text(user?.email ?? 'sudharsan@example.com', style: const TextStyle(color: Colors.grey, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
    );
  }
}
