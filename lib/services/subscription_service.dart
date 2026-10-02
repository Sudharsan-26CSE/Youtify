import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SubscribedChannel {
  final String id;
  final String name;
  final String avatar;
  final String subs;
  final String? banner;

  SubscribedChannel({
    required this.id,
    required this.name,
    required this.avatar,
    this.subs = '1M',
    this.banner,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatar': avatar,
        'subs': subs,
        'banner': banner,
      };

  factory SubscribedChannel.fromJson(Map<String, dynamic> json) =>
      SubscribedChannel(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        avatar: json['avatar'] ?? '',
        subs: json['subs'] ?? '1M',
        banner: json['banner'],
      );
}

class SubscriptionService {
  static final ValueNotifier<List<SubscribedChannel>> channelsNotifier =
      ValueNotifier<List<SubscribedChannel>>([]);

  static const String _key = 'user_subscriptions';

  static List<SubscribedChannel> get channels => channelsNotifier.value;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key);

    final localList = <SubscribedChannel>[];
    if (raw != null && raw.isNotEmpty) {
      for (final item in raw) {
        try {
          final data = jsonDecode(item);
          // Filter out legacy dummy entries
          final name = data['name']?.toString() ?? '';
          if (name != 'Google Developers' &&
              name != 'Flutter' &&
              name != 'Fireship') {
            localList.add(SubscribedChannel.fromJson(data));
          }
        } catch (_) {}
      }
    }
    channelsNotifier.value = localList;

    // Sync from Cloud Firestore if user is authenticated
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('subscriptions')
            .get();

        if (snapshot.docs.isNotEmpty) {
          final remoteList = snapshot.docs
              .map((doc) => SubscribedChannel.fromJson(doc.data()))
              .toList();

          // Merge without duplicates
          final merged = <String, SubscribedChannel>{};
          for (final c in localList) {
            merged[c.id.isNotEmpty ? c.id : c.name] = c;
          }
          for (final c in remoteList) {
            merged[c.id.isNotEmpty ? c.id : c.name] = c;
          }
          channelsNotifier.value = merged.values.toList();
          await _saveLocal();
        } else if (localList.isNotEmpty) {
          // Upload local subscriptions to user's database
          for (final c in localList) {
            final docId = c.id.isNotEmpty ? c.id : c.name.replaceAll(' ', '_');
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('subscriptions')
                .doc(docId)
                .set(c.toJson());
          }
        }
      } catch (e) {
        debugPrint('SubscriptionService firestore sync note: $e');
      }
    }
  }

  static bool isSubscribed(String nameOrId) {
    if (nameOrId.trim().isEmpty) return false;
    final query = nameOrId.trim().toLowerCase();
    return channelsNotifier.value.any(
      (c) =>
          (c.name.trim().toLowerCase() == query) ||
          (c.id.isNotEmpty && c.id.trim().toLowerCase() == query),
    );
  }

  static Future<bool> toggleSubscribe(SubscribedChannel channel) async {
    final exists = isSubscribed(channel.id) || isSubscribed(channel.name);
    final current = List<SubscribedChannel>.from(channelsNotifier.value);
    final user = FirebaseAuth.instance.currentUser;
    final docId = channel.id.isNotEmpty
        ? channel.id
        : channel.name.replaceAll(' ', '_');

    if (exists) {
      current.removeWhere((c) =>
          (c.name.trim().toLowerCase() == channel.name.trim().toLowerCase()) ||
          (c.id.isNotEmpty &&
              channel.id.isNotEmpty &&
              c.id.trim().toLowerCase() == channel.id.trim().toLowerCase()));
      channelsNotifier.value = current;
      await _saveLocal();

      // Delete from user database in Firestore
      if (user != null) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('subscriptions')
              .doc(docId)
              .delete();
        } catch (e) {
          debugPrint('SubscriptionService firestore delete note: $e');
        }
      }
      return false; // unsubscribed
    } else {
      current.insert(0, channel);
      channelsNotifier.value = current;
      await _saveLocal();

      // Save to user database in Firestore
      if (user != null) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('subscriptions')
              .doc(docId)
              .set(channel.toJson());
        } catch (e) {
          debugPrint('SubscriptionService firestore save note: $e');
        }
      }
      return true; // subscribed
    }
  }

  static Future<void> _saveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final list =
        channelsNotifier.value.map((c) => jsonEncode(c.toJson())).toList();
    await prefs.setStringList(_key, list);
  }
}
