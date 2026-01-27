import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'controllers/queueController.dart';
import 'views/authView.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => QueueController()),
      ],
      child: MaterialApp(
        title: 'Dr. Tudu Clinic',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          // Shift to a Dark, Glass-focused brightness
          brightness: Brightness.dark,

          // Using a deep slate for the primary scaffold to allow glass blurs to pop
          scaffoldBackgroundColor: const Color(0xFF0F172A),

          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6366F1), // Modern Indigo
            brightness: Brightness.dark,        // FIX: Explicitly match ThemeData brightness
            primary: const Color(0xFF6366F1),   // Vivid Indigo
            secondary: const Color(0xFFF43F5E), // Rose Accent for high energy
            surface: const Color(0xFF1E293B),   // Slate Surface
            onSurface: Colors.white,
          ),

          // Glassmorphic Card Style
          cardTheme: CardTheme(
            color: Colors.white.withOpacity(0.05),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32),
              side: BorderSide(color: Colors.white.withOpacity(0.1), width: 1.5),
            ),
          ),

          // High-End Input Design
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white.withOpacity(0.03),
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
            ),
          ),

          // Premium Button Styling
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              elevation: 8,
              shadowColor: const Color(0xFF6366F1).withOpacity(0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(vertical: 20),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),

          // Enhanced Typography
          textTheme: const TextTheme(
            displayLarge: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1),
            headlineMedium: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
            bodyLarge: TextStyle(color: Color(0xFFCBD5E1), fontSize: 16),
          ),
        ),
        home: const AuthView(),
      ),
    );
  }
}