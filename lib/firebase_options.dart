import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('Unsupported platform');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAwERYtQ-v6BXCMBW8cQkwztrQMs7l8F3w',
    appId: '1:626658041304:android:42b97d7efaef9b3f30a6ad',
    messagingSenderId: '626658041304',
    projectId: 'tokencare-13eab',
    databaseURL:
        'https://tokencare-13eab-default-rtdb.asia-southeast1.firebasedatabase.app/',
    storageBucket: 'tokencare-13eab.firebasestorage.app',
  );
}
