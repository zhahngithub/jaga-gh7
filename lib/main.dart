import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jaga/core/theme/app_theme.dart';
import 'package:jaga/features/auth/presentation/screens/authentication_gate.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final firebaseApp = await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  debugPrint('Firebase berhasil diinisialisasi');
  debugPrint('Project ID: ${firebaseApp.options.projectId}');
  debugPrint('Firebase App ID: ${firebaseApp.options.appId}');

  // runApp(const MainApp());
  runApp(
    const ProviderScope(child: MainApp()),
  ); // pake provider riverpod buat state management
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      title: 'Jaga',
      home: const AuthenticationGate(),
    );
  }
}
