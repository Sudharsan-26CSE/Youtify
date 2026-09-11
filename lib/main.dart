import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/shorts_screen.dart';
import 'screens/subscriptions_screen.dart';
import 'screens/message_screen.dart';
import 'models/video.dart';
import 'screens/video_player_screen.dart';
import 'package:audio_session/audio_session.dart';
import 'package:video_player/video_player.dart';
import 'services/download_service.dart';

/// Global theme notifier — toggled from SettingsScreen
final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);

/// Global currently playing video notifier
final selectedVideo = ValueNotifier<Video?>(null);

final isPlayerExpanded = ValueNotifier<bool>(false);
final navigatorKey = GlobalKey<NavigatorState>();
final globalVideoController = ValueNotifier<VideoPlayerController?>(null);


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0F0F0F),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  
  // Configure AudioSession for background audio support
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());

  await DownloadService.init();
  runApp(const YoutifyApp());
}

class YoutifyApp extends StatelessWidget {
  const YoutifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Youtify',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          darkTheme: _buildDarkTheme(),
          theme: _buildLightTheme(),
          initialRoute: '/splash',
          routes: {
            '/splash': (context) => const SplashScreen(),
            '/login': (context) => const LoginScreen(),
            '/home': (context) => const MainNavigator(),
          },
        );
      },
    );
  }

  ThemeData _buildDarkTheme() => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
        primaryColor: Colors.red,
        fontFamily: 'Roboto',
        colorScheme: const ColorScheme.dark(
          primary: Colors.red,
          surface: Color(0xFF212121),
          background: Color(0xFF0F0F0F),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F0F0F),
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: MaterialStateProperty.resolveWith((states) =>
              states.contains(MaterialState.selected)
                  ? Colors.red
                  : Colors.grey),
          trackColor: MaterialStateProperty.resolveWith((states) =>
              states.contains(MaterialState.selected)
                  ? Colors.red.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.2)),
        ),
      );

  ThemeData _buildLightTheme() => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF9F9F9),
        primaryColor: Colors.red,
        fontFamily: 'Roboto',
        colorScheme: const ColorScheme.light(
          primary: Colors.red,
          surface: Color(0xFFFFFFFF),
          background: Color(0xFFF9F9F9),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFFFFF),
          elevation: 0,
          iconTheme: IconThemeData(color: Color(0xFF0F0F0F)),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: MaterialStateProperty.resolveWith((states) =>
              states.contains(MaterialState.selected)
                  ? Colors.red
                  : Colors.grey),
          trackColor: MaterialStateProperty.resolveWith((states) =>
              states.contains(MaterialState.selected)
                  ? Colors.red.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.2)),
        ),
      );
}

class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _navAnim;

  final List<Widget> _screens = const [
    HomeScreen(),
    ShortsScreen(),
    SubscriptionsScreen(),
    MessageScreen(),
  ];

  OverlayEntry? _pipEntry;

  @override
  void initState() {
    super.initState();
    _navAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
        
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pipEntry == null) {
        _pipEntry = OverlayEntry(builder: (context) => const GlobalPlayerOverlay());
        navigatorKey.currentState?.overlay?.insert(_pipEntry!);
      }
    });
  }

  @override
  void dispose() {
    _navAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        // Prevent back button from closing app — only close from recent tasks
      },
      child: Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          // Floating Glass Capsule Bottom Nav
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(36),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                child: Container(
                  height: 68,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A).withOpacity(0.85),
                    borderRadius: BorderRadius.circular(36),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.1), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _NavItem(
                          icon: Icons.home_outlined,
                          activeIcon: Icons.home,
                          label: 'Home',
                          index: 0,
                          current: _currentIndex,
                          onTap: _onNavTap),
                      _NavItem(
                          icon: Icons.bolt_outlined,
                          activeIcon: Icons.bolt,
                          label: 'Shorts',
                          index: 1,
                          current: _currentIndex,
                          onTap: _onNavTap),
                      _NavItem(
                          icon: Icons.subscriptions_outlined,
                          activeIcon: Icons.subscriptions,
                          label: 'Sub',
                          index: 2,
                          current: _currentIndex,
                          onTap: _onNavTap),
                      _NavItem(
                          icon: Icons.message_outlined,
                          activeIcon: Icons.message,
                          label: 'Message',
                          index: 3,
                          current: _currentIndex,
                          onTap: _onNavTap),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }


  void _onNavTap(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
    _navAnim.forward(from: 0);
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int current;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = current == index;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding:
            EdgeInsets.symmetric(horizontal: isSelected ? 16 : 12, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected ? Colors.red.withOpacity(0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                isSelected ? activeIcon : icon,
                key: ValueKey(isSelected),
                color: isSelected ? Colors.redAccent : Colors.grey[400],
                size: 24,
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              child: isSelected
                  ? Row(
                      children: [
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class GlobalPlayerOverlay extends StatelessWidget {
  const GlobalPlayerOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Video?>(
            valueListenable: selectedVideo,
            builder: (context, video, _) {
              if (video == null) return const SizedBox.shrink();

              return ValueListenableBuilder<bool>(
                valueListenable: isPlayerExpanded,
                builder: (context, expanded, _) {
                  if (expanded) {
                    return Positioned.fill(
                      child: PopScope(
                        canPop: false,
                        onPopInvoked: (didPop) {
                          if (!didPop) isPlayerExpanded.value = false;
                        },
                        child: VideoPlayerScreen(video: video),
                      ),
                    );
                  } else {
                    return _PipWidget(video: video);
                  }
                },
              );
            },
          );
  }
}

class _PipWidget extends StatelessWidget {
  final Video video;
  const _PipWidget({required this.video});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 12,
      bottom: 100,
      child: GestureDetector(
        onTap: () => isPlayerExpanded.value = true,
        child: Dismissible(
          key: ValueKey(video.id),
          direction: DismissDirection.horizontal,
          onDismissed: (_) => selectedVideo.value = null,
          child: Material(
            elevation: 16,
            borderRadius: BorderRadius.circular(14),
            color: Colors.transparent,
            child: Container(
              width: 220,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 20, offset: const Offset(0, 6)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Thumbnail
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                        child: Image.network(
                          video.thumbnailUrl,
                          width: 220,
                          height: 124,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(width: 220, height: 124, color: Colors.grey[900]),
                        ),
                      ),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.25),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                          ),
                        ),
                      ),
                      // Close button
                      Positioned(
                        top: 6, right: 6,
                        child: GestureDetector(
                          onTap: () => selectedVideo.value = null,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                      // Expand icon
                      Positioned(
                        top: 6, left: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                          child: const Icon(Icons.fullscreen, color: Colors.white, size: 14),
                        ),
                      ),
                    ],
                  ),
                  // Controls row
                  ValueListenableBuilder<VideoPlayerController?>(
                    valueListenable: globalVideoController,
                    builder: (context, ctrl, _) {
                      final isPlaying = ctrl?.value.isPlaying ?? false;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _PipBtn(
                              icon: Icons.replay_10,
                              size: 20,
                              onTap: () {
                                final pos = ctrl?.value.position ?? Duration.zero;
                                ctrl?.seekTo(pos - const Duration(seconds: 10));
                              },
                            ),
                            _PipBtn(
                              icon: isPlaying ? Icons.pause : Icons.play_arrow,
                              size: 26,
                              onTap: () {
                                if (ctrl != null) {
                                  isPlaying ? ctrl.pause() : ctrl.play();
                                }
                              },
                            ),
                            _PipBtn(
                              icon: Icons.forward_10,
                              size: 20,
                              onTap: () {
                                final pos = ctrl?.value.position ?? Duration.zero;
                                ctrl?.seekTo(pos + const Duration(seconds: 10));
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  // Mini progress bar
                  ValueListenableBuilder<VideoPlayerController?>(
                    valueListenable: globalVideoController,
                    builder: (context, ctrl, _) {
                      if (ctrl == null || !ctrl.value.isInitialized) {
                        return const SizedBox.shrink();
                      }
                      final total = ctrl.value.duration.inMilliseconds;
                      final current = ctrl.value.position.inMilliseconds;
                      final progress = total > 0 ? current / total : 0.0;
                      return ClipRRect(
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey[800],
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
                          minHeight: 3,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PipBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;
  const _PipBtn({required this.icon, required this.size, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: size),
      ),
    );
  }
}
