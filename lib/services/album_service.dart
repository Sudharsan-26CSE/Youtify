import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/album.dart';
import '../models/video.dart';

class AlbumService {
  static final AlbumService instance = AlbumService._internal();
  AlbumService._internal();

  final ValueNotifier<List<Album>> albumsNotifier = ValueNotifier<List<Album>>([]);
  bool _isInitialized = false;

  String get _currentUserId {
    return FirebaseAuth.instance.currentUser?.uid ?? 'guest_user';
  }

  String get _storageKey => 'user_albums_$_currentUserId';

  Future<void> init() async {
    if (_isInitialized) return;
    await reload();
    _isInitialized = true;

    // Listen to auth changes so when a user logs in, their database albums load automatically
    FirebaseAuth.instance.authStateChanges().listen((user) {
      reload();
    });
  }

  Future<void> reload() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_storageKey) ?? [];
      final localAlbums = <Album>[];
      for (final raw in rawList) {
        try {
          localAlbums.add(Album.fromJson(jsonDecode(raw) as Map<String, dynamic>));
        } catch (e) {
          debugPrint('Error parsing cached album: $e');
        }
      }
      albumsNotifier.value = localAlbums;

      // Sync with Cloud Firestore if authenticated
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          final snapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('albums')
              .get();

          if (snapshot.docs.isNotEmpty) {
            final remoteAlbums = snapshot.docs.map((doc) {
              final data = doc.data();
              return Album.fromJson(data);
            }).toList();

            // Merge local and remote
            final map = <String, Album>{};
            for (final a in localAlbums) {
              map[a.id] = a;
            }
            for (final a in remoteAlbums) {
              map[a.id] = a;
            }
            albumsNotifier.value = map.values.toList();
            await _saveLocal();
          } else if (localAlbums.isNotEmpty) {
            // Push existing local albums to Firestore
            for (final a in localAlbums) {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('albums')
                  .doc(a.id)
                  .set(a.toJson());
            }
          }
        } catch (e) {
          debugPrint('AlbumService firestore sync note: $e');
        }
      }
    } catch (e) {
      debugPrint('AlbumService reload error: $e');
    }
  }

  Future<void> _saveLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = albumsNotifier.value.map((a) => jsonEncode(a.toJson())).toList();
      await prefs.setStringList(_storageKey, list);
    } catch (e) {
      debugPrint('Error saving local albums: $e');
    }
  }

  Future<Album> createAlbum(
    String title, {
    String description = '',
    int gradientColorIndex = 0,
    List<Video>? initialSongs,
  }) async {
    final newAlbum = Album(
      id: 'album_${DateTime.now().millisecondsSinceEpoch}',
      userId: _currentUserId,
      title: title.trim().isEmpty ? 'My Album' : title.trim(),
      description: description.trim(),
      gradientColorIndex: gradientColorIndex,
      createdAt: DateTime.now(),
      songs: initialSongs ?? [],
    );

    final updated = List<Album>.from(albumsNotifier.value)..insert(0, newAlbum);
    albumsNotifier.value = updated;
    await _saveLocal();

    // Store in Cloud Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('albums')
            .doc(newAlbum.id)
            .set(newAlbum.toJson());
      } catch (e) {
        debugPrint('Firestore createAlbum error: $e');
      }
    }

    return newAlbum;
  }

  Future<void> addSongToAlbum(String albumId, Video song) async {
    final list = List<Album>.from(albumsNotifier.value);
    final idx = list.indexWhere((a) => a.id == albumId);
    if (idx < 0) return;

    final target = list[idx];
    if (target.songs.any((s) => s.id == song.id)) {
      return; // Already in album
    }

    final updatedSongs = List<Video>.from(target.songs)..add(song);
    final updatedAlbum = target.copyWith(
      songs: updatedSongs,
      coverUrl: target.coverUrl ?? song.thumbnailUrl,
    );
    list[idx] = updatedAlbum;
    albumsNotifier.value = list;
    await _saveLocal();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('albums')
            .doc(albumId)
            .set(updatedAlbum.toJson());
      } catch (e) {
        debugPrint('Firestore addSongToAlbum error: $e');
      }
    }
  }

  Future<void> removeSongFromAlbum(String albumId, String songId) async {
    final list = List<Album>.from(albumsNotifier.value);
    final idx = list.indexWhere((a) => a.id == albumId);
    if (idx < 0) return;

    final target = list[idx];
    final updatedSongs = List<Video>.from(target.songs)..removeWhere((s) => s.id == songId);
    final updatedAlbum = target.copyWith(
      songs: updatedSongs,
      coverUrl: updatedSongs.isNotEmpty ? updatedSongs.first.thumbnailUrl : null,
    );
    list[idx] = updatedAlbum;
    albumsNotifier.value = list;
    await _saveLocal();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('albums')
            .doc(albumId)
            .set(updatedAlbum.toJson());
      } catch (e) {
        debugPrint('Firestore removeSongFromAlbum error: $e');
      }
    }
  }

  Future<void> deleteAlbum(String albumId) async {
    final list = List<Album>.from(albumsNotifier.value)..removeWhere((a) => a.id == albumId);
    albumsNotifier.value = list;
    await _saveLocal();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('albums')
            .doc(albumId)
            .delete();
      } catch (e) {
        debugPrint('Firestore deleteAlbum error: $e');
      }
    }
  }

  bool isSongInAlbum(String albumId, String songId) {
    final album = albumsNotifier.value.firstWhere(
      (a) => a.id == albumId,
      orElse: () => Album(id: '', userId: '', title: '', createdAt: DateTime.now()),
    );
    return album.songs.any((s) => s.id == songId);
  }
}
