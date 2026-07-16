import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'features/map/presentation/screens/main_safety_map_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final firebaseApp = await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  debugPrint('Firebase berhasil diinisialisasi');
  debugPrint('Project ID: ${firebaseApp.options.projectId}');
  debugPrint('Firebase App ID: ${firebaseApp.options.appId}');
  
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Jaga',
      home: MainSafetyMapScreen(),
    );
  }
}