import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

class NotificationService {
  NotificationService({
    FirebaseFirestore? firestore,
    FlutterLocalNotificationsPlugin? plugin,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _defaultChannel = AndroidNotificationChannel(
    'veloce_express_alerts_system_v1',
    'Nawdli express alerts',
    description: 'General Nawdli express notifications.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  final FirebaseFirestore _firestore;
  final FlutterLocalNotificationsPlugin _plugin;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _notificationsSub;
  StreamSubscription<RemoteMessage>? _fcmForegroundSub;
  StreamSubscription<RemoteMessage>? _fcmOpenedSub;
  StreamSubscription<String>? _tokenRefreshSub;
  bool _initializedSnapshot = false;
  int _notificationId = 1000;

  Future<void> initialize({
    void Function(String? payload)? onTap,
  }) async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        onTap?.call(response.payload);
      },
    );
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_defaultChannel);
    await android?.requestNotificationsPermission();
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    _fcmForegroundSub = FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      final title =
          notification?.title ?? message.data['title'] ?? 'Nawdli express';
      final body = notification?.body ?? message.data['body'] ?? '';
      show(
        title: title,
        body: body,
        type: message.data['type'] as String?,
        payload: message.data['orderId'] as String?,
      );
    });
    _fcmOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      onTap?.call(message.data['orderId'] as String?);
    });
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      onTap?.call(initialMessage.data['orderId'] as String?);
    }
  }

  Future<void> show({
    required String title,
    required String body,
    String? type,
    String? payload,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _defaultChannel.id,
        _defaultChannel.name,
        channelDescription: _defaultChannel.description,
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
    await registerFcmToken(userId);
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

        final title = data['title'] as String? ?? 'Nawdli express';
        final body = data['body'] as String? ?? '';
        await show(
          title: title,
          body: body,
          type: data['type'] as String?,
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

  Future<void> registerFcmToken(String userId) async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await _firestore.collection('users').doc(userId).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen(
      (newToken) {
        _firestore.collection('users').doc(userId).update({
          'fcmTokens': FieldValue.arrayUnion([newToken]),
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      },
      onError: (Object error) {
        debugPrint('FCM token refresh error: $error');
      },
    );
  }

  Future<void> stopWatching() async {
    await _notificationsSub?.cancel();
    await _tokenRefreshSub?.cancel();
    _notificationsSub = null;
    _tokenRefreshSub = null;
    _initializedSnapshot = false;
  }

  Future<void> dispose() async {
    await _fcmForegroundSub?.cancel();
    await _fcmOpenedSub?.cancel();
    await stopWatching();
  }
}
