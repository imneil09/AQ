import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'controllers/queueController.dart';
import 'views/auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyAiNAGIFURSkqbSj8-K4AW9yT3PM2pwuCk",
        appId: "1:1074232279880:web:7e450c575004cb4934e97d",
        messagingSenderId: "1074232279880",
        projectId: "appqueue-fdef7",
        storageBucket: "appqueue-fdef7.firebasestorage.app",
        authDomain: "appqueue-fdef7.firebaseapp.com",
      ),
    );
  } else {
    await Firebase.initializeApp();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. REFACTOR: Removed unnecessary MultiProvider nesting
    return ChangeNotifierProvider(
      create: (_) => QueueController(),
      child: MaterialApp(
        title: 'Dr. Roy',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          // 2. REFACTOR: Removed redundant 'brightness: Brightness.dark' line
          // The colorScheme handles the brightness setting efficiently.
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(
              0xFF6366F1,
            ), // Hint: Use AppColors.primary if you added the file I suggested!
            brightness: Brightness.dark,
          ),
        ),
        home: const AuthView(),
      ),
    );
  }
}
