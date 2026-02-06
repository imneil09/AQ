import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'controllers/queueController.dart';
import 'views/authView.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // FIREBASE CONFIGURATION (WEB, WINDOWS, LINUX)
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

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => QueueController())],
      child: MaterialApp(
        title: 'Universal Clinic',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6366F1),
            brightness: Brightness.dark,
          ),
        ),
        home: const AuthView(),
      ),
    );
  }
}