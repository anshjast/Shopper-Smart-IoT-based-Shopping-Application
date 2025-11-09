import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:firebase_core/firebase_core.dart'; // REQUIRED
import 'scanner.dart';
import 'welcome.dart';

// The global list of available cameras, populated before runApp()
late List<CameraDescription> cameras;

Future<void> main() async {
  // 1. Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // 2. CRITICAL FIX: Initialize Firebase Core first
  await Firebase.initializeApp();

  try {
    // 3. Initialize the global 'cameras' list AFTER Firebase is ready
    cameras = await availableCameras();
  } on CameraException catch (e) {
    print('Error: $e. Did you set up Android/iOS permissions?');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shopper',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: const WelcomeScreen(),
      routes: {
        // Routes are handled directly by push/pushReplacement
      },
    );
  }
}