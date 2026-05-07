import 'package:cloud_functions/cloud_functions.dart';

class PushNotificationSender {
  const PushNotificationSender._();

  static Future<void> send({
    required String toUserId,
    required String title,
    required String body,
    String? orderId,
    String? type,
  }) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'sendNotification',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 12)),
    );
    await callable.call<Map<String, dynamic>>({
      'toUserId': toUserId,
      'title': title,
      'body': body,
      if (orderId != null) 'orderId': orderId,
      if (type != null) 'type': type,
    });
  }
}
