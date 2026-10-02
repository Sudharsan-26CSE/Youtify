import 'dart:convert';
import 'video.dart';

class Album {
  final String id;
  final String userId;
  final String title;
  final String description;
  final String? coverUrl;
  final int gradientColorIndex;
  final DateTime createdAt;
  final List<Video> songs;

  Album({
    required this.id,
    required this.userId,
    required this.title,
    this.description = '',
    this.coverUrl,
    this.gradientColorIndex = 0,
    required this.createdAt,
    List<Video>? songs,
  }) : songs = songs ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'title': title,
        'description': description,
        'coverUrl': coverUrl,
        'gradientColorIndex': gradientColorIndex,
        'createdAt': createdAt.toIso8601String(),
        'songs': songs.map((s) => s.toJson()).toList(),
      };

  factory Album.fromJson(Map<String, dynamic> json) {
    var rawSongs = json['songs'];
    List<Video> parsedSongs = [];
    if (rawSongs is List) {
      for (final s in rawSongs) {
        try {
          if (s is Map<String, dynamic>) {
            parsedSongs.add(Video.fromJson(s));
          } else if (s is String) {
            parsedSongs.add(Video.fromJson(jsonDecode(s)));
          }
        } catch (_) {}
      }
    }

    return Album(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled Album',
      description: json['description'] as String? ?? '',
      coverUrl: json['coverUrl'] as String?,
      gradientColorIndex: json['gradientColorIndex'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      songs: parsedSongs,
    );
  }

  Album copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    String? coverUrl,
    int? gradientColorIndex,
    DateTime? createdAt,
    List<Video>? songs,
  }) {
    return Album(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      coverUrl: coverUrl ?? this.coverUrl,
      gradientColorIndex: gradientColorIndex ?? this.gradientColorIndex,
      createdAt: createdAt ?? this.createdAt,
      songs: songs ?? List<Video>.from(this.songs),
    );
  }
}
