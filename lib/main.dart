import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // <-- ADDED THIS IMPORT

// Imports
import 'firebase_options.dart'; 
import 'controllers/queueController.dart';
import 'views/auth.dart';
import 'widgets/appColors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase using the generated options
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // <-- ADDED THIS BLOCK -->
  // Try to clear the offline cache on startup to prevent Windows crashes
  try {
    await FirebaseFirestore.instance.clearPersistence();
  } catch (e) {
    print('Could not clear Firestore cache: $e');
  }
  // <---------------------->

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => QueueController(),
      child: MaterialApp(
        title: 'Dr. Roy',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            brightness: Brightness.dark,
          ),
        ),
        home: const AuthView(),
      ),
    );
  }
}
