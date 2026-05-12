import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Nawdli express is configured for Android only.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
            'Nawdli express is configured for Android only.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAvxTNotYH6Eibgj7bQgVF6kQCccjOUpHc',
    appId: '1:391374475758:android:de697a7b790fe1f7c0feff',
    messagingSenderId: '391374475758',
    projectId: 'veloce-express',
    databaseURL:
        'https://veloce-express-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'veloce-express.firebasestorage.app',
  );
}
