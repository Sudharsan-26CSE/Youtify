import 'dart:convert';
import 'dart:math';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt_exp;
import '../models/video.dart';

class AudioPlayerService {
  static final AudioPlayerService instance = AudioPlayerService._internal();
  AudioPlayerService._internal() {
    _initStorage();
  }

  static final yt_exp.YoutubeExplode _yt = yt_exp.YoutubeExplode();

  VideoPlayerController? _controller;
  VideoPlayerController? get controller => _controller;

  // Notifiers
  final ValueNotifier<Video?> currentSongNotifier = ValueNotifier<Video?>(null);
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isBufferingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<Duration> positionNotifier = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<Duration> durationNotifier = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<List<Video>> queueNotifier = ValueNotifier<List<Video>>([]);
  final ValueNotifier<int> currentIndexNotifier = ValueNotifier<int>(-1);
  final ValueNotifier<bool> isShuffleNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isRepeatNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<Set<String>> likedSongIdsNotifier = ValueNotifier<Set<String>>({});
  final ValueNotifier<List<Video>> recentSongsNotifier = ValueNotifier<List<Video>>([]);
  final ValueNotifier<bool> isBackgroundPlayNotifier = ValueNotifier<bool>(true);

  Video? get currentSong => currentSongNotifier.value;
  bool get isPlaying => isPlayingNotifier.value;
  List<Video> get queue => queueNotifier.value;
  bool get isBackgroundPlayEnabled => isBackgroundPlayNotifier.value;

  static const String _kRecentKey = 'youtify_recent_audio_songs';
  static const String _kLikedKey = 'youtify_liked_audio_songs';
  static const String _kBackgroundPlayKey = 'youtify_background_play_enabled';

  Future<void> _initStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Load background play setting
      isBackgroundPlayNotifier.value = prefs.getBool(_kBackgroundPlayKey) ?? true;
      if (isBackgroundPlayNotifier.value) {
        _enableAudioSession();
      }

      // Load recent songs
      final rawRecent = prefs.getStringList(_kRecentKey) ?? [];
      final loadedRecent = <Video>[];
      for (final item in rawRecent) {
        try {
          loadedRecent.add(Video.fromJson(jsonDecode(item)));
        } catch (_) {}
      }
      recentSongsNotifier.value = loadedRecent;

      // Load liked songs
      final rawLiked = prefs.getStringList(_kLikedKey) ?? [];
      likedSongIdsNotifier.value = rawLiked.toSet();
    } catch (e) {
      debugPrint('Error loading audio storage: $e');
    }
  }

  Future<void> _saveRecent(Video song) async {
    try {
      final current = List<Video>.from(recentSongsNotifier.value);
      current.removeWhere((v) => v.id == song.id);
      current.insert(0, song);
      if (current.length > 30) current.removeLast();
      recentSongsNotifier.value = current;

      final prefs = await SharedPreferences.getInstance();
      final encoded = current.map((v) => jsonEncode(v.toJson())).toList();
      await prefs.setStringList(_kRecentKey, encoded);
    } catch (e) {
      debugPrint('Error saving recent song: $e');
    }
  }

  Future<void> toggleLike(Video song) async {
    final current = Set<String>.from(likedSongIdsNotifier.value);
    if (current.contains(song.id)) {
      current.remove(song.id);
    } else {
      current.add(song.id);
    }
    likedSongIdsNotifier.value = current;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kLikedKey, current.toList());
    } catch (e) {
      debugPrint('Error saving liked songs: $e');
    }
  }

  bool isLiked(String songId) => likedSongIdsNotifier.value.contains(songId);

  Future<void> playSong(Video song, {List<Video>? playlist}) async {
    if (playlist != null && playlist.isNotEmpty) {
      queueNotifier.value = List<Video>.from(playlist);
      final idx = queueNotifier.value.indexWhere((v) => v.id == song.id);
      currentIndexNotifier.value = idx >= 0 ? idx : 0;
    } else {
      if (!queueNotifier.value.any((v) => v.id == song.id)) {
        final q = List<Video>.from(queueNotifier.value)..add(song);
        queueNotifier.value = q;
        currentIndexNotifier.value = q.length - 1;
      } else {
        currentIndexNotifier.value = queueNotifier.value.indexWhere((v) => v.id == song.id);
      }
    }

    currentSongNotifier.value = song;
    isBufferingNotifier.value = true;
    _saveRecent(song);

    // Stop and dispose previous controller
    final oldController = _controller;
    _controller = null;
    if (oldController != null) {
      try {
        await oldController.pause();
        await oldController.dispose();
      } catch (_) {}
    }

    try {
      final targetId = song.resolvedYoutubeId ?? song.id;
      final manifest = await _yt.videos.streamsClient.getManifest(targetId);

      // Collect candidate stream URLs.
      // YouTube CDN returns HTTP 200 reliably for muxed streams,
      // whereas pure audioOnly streams often return 403 Forbidden on mobile ExoPlayer.
      final candidateUris = <Uri>[];
      if (manifest.muxed.isNotEmpty) {
        candidateUris.add(manifest.muxed.withHighestBitrate().url);
        for (final m in manifest.muxed) {
          if (!candidateUris.contains(m.url)) candidateUris.add(m.url);
        }
      }
      if (manifest.audioOnly.isNotEmpty) {
        candidateUris.add(manifest.audioOnly.withHighestBitrate().url);
        for (final a in manifest.audioOnly) {
          if (!candidateUris.contains(a.url)) candidateUris.add(a.url);
        }
      }

      if (isBackgroundPlayNotifier.value) {
        await _enableAudioSession();
      }

      VideoPlayerController? workingController;
      for (final uri in candidateUris) {
        try {
          final ctrl = VideoPlayerController.networkUrl(
            uri,
            videoPlayerOptions: VideoPlayerOptions(
              mixWithOthers: isBackgroundPlayNotifier.value,
            ),
          );
          await ctrl.initialize();
          workingController = ctrl;
          break;
        } catch (err) {
          debugPrint('Stream candidate failed ($uri): $err');
        }
      }

      if (workingController == null) {
        throw Exception('Could not initialize any playable audio stream for $targetId');
      }

      _controller = workingController;
      durationNotifier.value = workingController.value.duration;
      positionNotifier.value = Duration.zero;

      workingController.addListener(_onControllerUpdate);
      await workingController.play();

      isPlayingNotifier.value = true;
      isBufferingNotifier.value = false;
    } catch (e) {
      debugPrint('Audio playback error: $e');
      isBufferingNotifier.value = false;
      isPlayingNotifier.value = false;
    }
  }

  void _onControllerUpdate() {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;

    final val = ctrl.value;
    isPlayingNotifier.value = val.isPlaying;
    isBufferingNotifier.value = val.isBuffering;
    positionNotifier.value = val.position;
    durationNotifier.value = val.duration;

    // Track completion
    if (val.position >= val.duration && val.duration > Duration.zero) {
      if (isRepeatNotifier.value) {
        seekTo(Duration.zero);
        ctrl.play();
      } else {
        next();
      }
    }
  }

  Future<void> togglePlayPause() async {
    final ctrl = _controller;
    if (ctrl == null) {
      if (currentSongNotifier.value != null) {
        await playSong(currentSongNotifier.value!);
      }
      return;
    }

    if (ctrl.value.isPlaying) {
      await ctrl.pause();
      isPlayingNotifier.value = false;
    } else {
      await ctrl.play();
      isPlayingNotifier.value = true;
    }
  }

  Future<void> seekTo(Duration position) async {
    final ctrl = _controller;
    if (ctrl != null && ctrl.value.isInitialized) {
      await ctrl.seekTo(position);
      positionNotifier.value = position;
    }
  }

  void next() {
    final q = queueNotifier.value;
    if (q.isEmpty) return;

    if (isShuffleNotifier.value && q.length > 1) {
      final rand = Random().nextInt(q.length);
      final nextIdx = rand == currentIndexNotifier.value ? (rand + 1) % q.length : rand;
      currentIndexNotifier.value = nextIdx;
      playSong(q[nextIdx]);
      return;
    }

    final nextIdx = (currentIndexNotifier.value + 1) % q.length;
    currentIndexNotifier.value = nextIdx;
    playSong(q[nextIdx]);
  }

  void previous() {
    final q = queueNotifier.value;
    if (q.isEmpty) return;

    if (positionNotifier.value.inSeconds > 3) {
      seekTo(Duration.zero);
      return;
    }

    final prevIdx = (currentIndexNotifier.value - 1 + q.length) % q.length;
    currentIndexNotifier.value = prevIdx;
    playSong(q[prevIdx]);
  }

  void toggleShuffle() {
    isShuffleNotifier.value = !isShuffleNotifier.value;
  }

  void toggleRepeat() {
    isRepeatNotifier.value = !isRepeatNotifier.value;
  }

  Future<void> stop() async {
    final ctrl = _controller;
    _controller = null;
    if (ctrl != null) {
      await ctrl.pause();
      await ctrl.dispose();
    }
    isPlayingNotifier.value = false;
    positionNotifier.value = Duration.zero;
  }

  Future<void> _enableAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      await session.setActive(true);
    } catch (e) {
      debugPrint('AudioSession error: $e');
    }
  }

  Future<void> toggleBackgroundPlay(bool enabled) async {
    isBackgroundPlayNotifier.value = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kBackgroundPlayKey, enabled);
      if (enabled) {
        await _enableAudioSession();
      }
    } catch (e) {
      debugPrint('Error toggling background play: $e');
    }
  }
}
