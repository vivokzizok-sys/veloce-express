import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService({
    FirebaseFirestore? firestore,
    FlutterLocalNotificationsPlugin? plugin,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationChannel(
    'veloce_express_alerts_v2',
    'Veloce Express',
    description: 'Trip, bid, and account notifications.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  final FirebaseFirestore _firestore;
  final FlutterLocalNotificationsPlugin _plugin;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _notificationsSub;
  bool _initializedSnapshot = false;
  int _notificationId = 1000;

  Future<void> initialize() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(initSettings);
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_channel);
    await android?.requestNotificationsPermission();
  }

  Future<void> show({
    required String title,
    required String body,
    String? payload,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        category: AndroidNotificationCategory.message,
        icon: '@mipmap/ic_launcher',
      ),
    );

    await _plugin.show(
      _notificationId++,
      title,
      body,
      details,
      payload: payload,
    );
  }

  Future<void> watchUserNotifications(String userId) async {
    await stopWatching();
    _initializedSnapshot = false;
    _notificationsSub = _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(25)
        .snapshots()
        .listen((snapshot) async {
      for (final change in snapshot.docChanges) {
        if (!_initializedSnapshot && change.doc.metadata.hasPendingWrites) {
          continue;
        }
        if (change.type != DocumentChangeType.added) continue;
        final data = change.doc.data();
        if (data == null) continue;
        if (data['read'] == true) continue;

        final title = data['title'] as String? ?? 'Veloce Express';
        final body = data['body'] as String? ?? '';
        await show(
          title: title,
          body: body,
          payload: data['orderId'] as String?,
        );

        await change.doc.reference.update({
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      _initializedSnapshot = true;
    }, onError: (Object error, StackTrace stackTrace) {
      debugPrint('Notification listener error: $error');
    });
  }

  Future<void> stopWatching() async {
    await _notificationsSub?.cancel();
    _notificationsSub = null;
    _initializedSnapshot = false;
  }

  Future<void> dispose() => stopWatching();
}
