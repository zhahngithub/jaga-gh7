import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jaga/core/theme/app_colors.dart';
import 'package:jaga/core/theme/app_theme.dart';
import 'package:jaga/features/auth/presentation/screens/authentication_gate.dart';
import 'package:jaga/features/notifications/application/notification_routing_controller.dart';
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

class MainApp extends ConsumerStatefulWidget {
  const MainApp({super.key});

  @override
  ConsumerState<MainApp> createState() => _MainAppState();
}

class _MainAppState extends ConsumerState<MainApp> {
  @override
  void initState() {
    super.initState();
    unawaited(ref.read(notificationCoordinatorProvider.notifier).initialize());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      title: 'Jaga',
      home: const _LaunchTransition(child: AuthenticationGate()),
    );
  }
}

class _LaunchTransition extends StatefulWidget {
  const _LaunchTransition({required this.child});

  final Widget child;

  @override
  State<_LaunchTransition> createState() => _LaunchTransitionState();
}

class _LaunchTransitionState extends State<_LaunchTransition>
    with SingleTickerProviderStateMixin {
  static const _splashDuration = Duration(milliseconds: 1250);
  static const _fadeDuration = Duration(milliseconds: 450);

  late final AnimationController _logoController;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  Timer? _splashTimer;
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    final logoCurve = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOutCubic,
    );
    _logoOpacity = Tween<double>(begin: 0.35, end: 1).animate(logoCurve);
    _logoScale = Tween<double>(begin: 0.94, end: 1).animate(logoCurve);
    _logoController.forward();

    _splashTimer = Timer(_splashDuration, () {
      if (mounted) {
        setState(() => _showSplash = false);
      }
    });
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        IgnorePointer(
          ignoring: !_showSplash,
          child: AnimatedOpacity(
            opacity: _showSplash ? 1 : 0,
            duration: _fadeDuration,
            curve: Curves.easeInOutCubic,
            child: ColoredBox(
              color: AppColors.brandBlue,
              child: Center(
                child: FadeTransition(
                  opacity: _logoOpacity,
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: Image.asset(
                      'assets/branding/jaga.png',
                      width: 220,
                      height: 220,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
