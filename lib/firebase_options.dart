import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyARA1tjJ-HrHBpc_bXpRtnyFCSZ9wG70ok',
    appId: '1:499492677777:web:eb40b354dac388d437f730',
    messagingSenderId: '499492677777',
    projectId: 'dormease-app',
    authDomain: 'dormease-app.firebaseapp.com',
    storageBucket: 'dormease-app.firebasestorage.app',
    measurementId: 'G-SZXJE6LRVX',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBAJdx-EXhY3ajyvk_qWYII7e9ZKpUjJNY',
    appId: '1:499492677777:android:2ee2d96d1e1b398f37f730',
    messagingSenderId: '499492677777',
    projectId: 'dormease-app',
    storageBucket: 'dormease-app.firebasestorage.app',
  );
}
