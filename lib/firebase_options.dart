// File: lib/firebase_options.dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
              'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
              'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux; // <--- ✅ ADDED THIS LINE
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAiNAGIFURSkqbSj8-K4AW9yT3PM2pwuCk',
    appId: '1:1074232279880:web:7e450c575004cb4934e97d',
    messagingSenderId: '1074232279880',
    projectId: 'appqueue-fdef7',
    authDomain: 'appqueue-fdef7.firebaseapp.com',
    storageBucket: 'appqueue-fdef7.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDdITSbKDnxfLG-nxBqidsKqRQ7w9-jswI',
    appId: '1:1074232279880:android:a4bafadbf3da360134e97d',
    messagingSenderId: '1074232279880',
    projectId: 'appqueue-fdef7',
    storageBucket: 'appqueue-fdef7.firebasestorage.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAiNAGIFURSkqbSj8-K4AW9yT3PM2pwuCk',
    appId: '1:1074232279880:web:7e450c575004cb4934e97d',
    messagingSenderId: '1074232279880',
    projectId: 'appqueue-fdef7',
    authDomain: 'appqueue-fdef7.firebaseapp.com',
    storageBucket: 'appqueue-fdef7.firebasestorage.app',
  );

  // ✅ ADDED LINUX CONFIGURATION (Same as Windows/Web)
  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'AIzaSyAiNAGIFURSkqbSj8-K4AW9yT3PM2pwuCk',
    appId: '1:1074232279880:web:7e450c575004cb4934e97d',
    messagingSenderId: '1074232279880',
    projectId: 'appqueue-fdef7',
    authDomain: 'appqueue-fdef7.firebaseapp.com',
    storageBucket: 'appqueue-fdef7.firebasestorage.app',
  );
}