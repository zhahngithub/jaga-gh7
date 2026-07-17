import 'package:flutter/material.dart';
import 'package:jaga/core/theme/app_colors.dart';

class AuthPageScaffold extends StatelessWidget {
  const AuthPageScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
    this.leading,
    this.trailing,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF6FF),
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned(
              top: -90,
              right: -70,
              child: _GlowCircle(size: 230, color: Color(0x330087FF)),
            ),
            const Positioned(
              top: 170,
              left: -75,
              child: _GlowCircle(size: 150, color: Color(0x1F0087FF)),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          ?leading,
                          if (leading != null) const SizedBox(width: 8),
                          const _JagaBrand(),
                          const Spacer(),
                          ?trailing,
                        ],
                      ),
                      const SizedBox(height: 36),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(color: AppColors.textDark),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 26),
                      Material(
                        color: Colors.white,
                        elevation: 0,
                        borderRadius: BorderRadius.circular(28),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: const Color(0xFFD8ECFA)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x12004788),
                                blurRadius: 30,
                                offset: Offset(0, 14),
                              ),
                            ],
                          ),
                          child: child,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthBackButton extends StatelessWidget {
  const AuthBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: 'Kembali',
      onPressed: () => Navigator.of(context).pop(),
      icon: const Icon(Icons.arrow_back_rounded),
    );
  }
}

class _JagaBrand extends StatelessWidget {
  const _JagaBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'JAGA',
          style: TextStyle(
            color: AppColors.textDark,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.2,
          ),
        ),
      ],
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
