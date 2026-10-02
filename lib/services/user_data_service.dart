import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/video.dart';

class UserDataService {
  static final List<Video> _likedVideos = [];
  static final List<Video> _watchHistory = [];
  static final List<Video> _yourVideos = [];
  static final List<VoidCallback> _listeners = [];
  static bool _isLoaded = false;

  static String _profileName = '';
  static String _profilePhotoUrl = '';

  static List<Video> get likedVideos => List.unmodifiable(_likedVideos);
  static List<Video> get watchHistory => List.unmodifiable(_watchHistory);
  static List<Video> get yourVideos => List.unmodifiable(_yourVideos);
  static String get profileName => _profileName;
  static String get profilePhotoUrl => _profilePhotoUrl;

  static void addListener(VoidCallback listener) => _listeners.add(listener);
  static void removeListener(VoidCallback listener) => _listeners.remove(listener);
  static void _notify() {
    for (final listener in _listeners) {
      listener();
    }
  }

  static Future<void> init() async {
    if (_isLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _profileName = prefs.getString('custom_profile_name') ?? '';
      _profilePhotoUrl = prefs.getString('custom_profile_photo') ?? '';

      final likedRaw = prefs.getString('user_liked_videos') ?? '[]';
      final likedList = jsonDecode(likedRaw) as List;
      _likedVideos.clear();
      _likedVideos.addAll(likedList.map((e) => Video.fromJson(e)));

      final historyRaw = prefs.getString('user_watch_history') ?? '[]';
      final historyList = jsonDecode(historyRaw) as List;
      _watchHistory.clear();
      _watchHistory.addAll(historyList.map((e) => Video.fromJson(e)));

      final yourRaw = prefs.getString('user_your_videos') ?? '[]';
      final yourList = jsonDecode(yourRaw) as List;
      _yourVideos.clear();
      _yourVideos.addAll(yourList.map((e) => Video.fromJson(e)));

      _isLoaded = true;
      _notify();
    } catch (e) {
      debugPrint('UserDataService init error: $e');
    }
  }

  static bool isLiked(String videoId) => _likedVideos.any((v) => v.id == videoId);

  static Future<bool> toggleLike(Video video) async {
    await init();
    final index = _likedVideos.indexWhere((v) => v.id == video.id);
    bool liked;
    if (index >= 0) {
      _likedVideos.removeAt(index);
      liked = false;
    } else {
      _likedVideos.insert(0, video);
      liked = true;
    }
    await _saveLikes();
    _notify();
    return liked;
  }

  static Future<void> unlikeMultiple(List<String> videoIds) async {
    await init();
    _likedVideos.removeWhere((v) => videoIds.contains(v.id));
    await _saveLikes();
    _notify();
  }

  static Future<void> addToHistory(Video video) async {
    await init();
    _watchHistory.removeWhere((v) => v.id == video.id);
    _watchHistory.insert(0, video);
    if (_watchHistory.length > 100) {
      _watchHistory.removeLast();
    }
    await _saveHistory();
    _notify();
  }

  static Future<void> clearHistory() async {
    await init();
    _watchHistory.clear();
    await _saveHistory();
    _notify();
  }

  static Future<void> updateProfile({String? name, String? photoUrl}) async {
    final prefs = await SharedPreferences.getInstance();
    if (name != null) {
      _profileName = name.trim();
      await prefs.setString('custom_profile_name', _profileName);
    }
    if (photoUrl != null) {
      _profilePhotoUrl = photoUrl.trim();
      await prefs.setString('custom_profile_photo', _profilePhotoUrl);
    }
    _notify();
  }

  static Future<void> addYourVideo(Video video) async {
    await init();
    _yourVideos.insert(0, video);
    await _saveYourVideos();
    _notify();
  }

  static Future<void> removeYourVideo(String videoId) async {
    await init();
    _yourVideos.removeWhere((v) => v.id == videoId);
    await _saveYourVideos();
    _notify();
  }

  static Future<void> _saveLikes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_likedVideos.map((v) => v.toJson()).toList());
    await prefs.setString('user_liked_videos', raw);
  }

  static Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_watchHistory.map((v) => v.toJson()).toList());
    await prefs.setString('user_watch_history', raw);
  }

  static Future<void> _saveYourVideos() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_yourVideos.map((v) => v.toJson()).toList());
    await prefs.setString('user_your_videos', raw);
  }
}
