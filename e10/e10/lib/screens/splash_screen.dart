import 'dart:async';

import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/common.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _dots;
  late final AnimationController _entrance;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _textFade;
  Timer? _autoContinue;

  @override
  void initState() {
    super.initState();
    _dots = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    // A one-shot "arrival" animation for the logo/title block — the logo
    // scales in with a slight overshoot while the title/tagline rise and
    // fade in just after it, instead of the whole block simply appearing.
    // Continue on its own (to the landing page, or a restored dashboard):
    // the pulsing dots read as a loading indicator, and Play review flagged
    // the app as never finishing loading when it sat here waiting for a tap.
    _autoContinue = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) widget.onDone();
    });

    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _logoScale = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOutBack),
    );
    _logoFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
    );
    _textFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.35, 0.85, curve: Curves.easeOut),
    );
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(parent: _entrance, curve: const Interval(0.35, 0.85, curve: Curves.easeOutCubic)),
    );
  }

  @override
  void dispose() {
    _autoContinue?.cancel();
    _dots.dispose();
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppGradients.chrome),
      child: SafeArea(
        // Scrolls (and shrinks the logo) when the screen is short, e.g. a
        // phone turned sideways; otherwise the Spacers centre it as before.
        child: LayoutBuilder(
          builder: (context, box) {
            final short = box.maxHeight < 560;
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: IntrinsicHeight(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 448),
                      child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
                children: [
                  const Spacer(),
                  ScaleTransition(
                    scale: _logoScale,
                    child: FadeTransition(
                      opacity: _logoFade,
                      child: AppLogo(size: short ? 84 : 140),
                    ),
                  ),
                  SizedBox(height: short ? 12 : 22),
                  SlideTransition(
                    position: _textSlide,
                    child: FadeTransition(
                      opacity: _textFade,
                      child: RichText(
                        text: TextSpan(
                          style: AppText.display(
                            size: 36,
                            weight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                          children: [
                            const TextSpan(text: 'e'),
                            TextSpan(
                              text: '10',
                              style: AppText.display(
                                size: 36,
                                weight: FontWeight.w600,
                                color: AppColors.honey,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  FadeTransition(
                    opacity: _textFade,
                    child: Text(
                      'SCHOOL SYSTEMS',
                      style: AppText.body(
                        size: 13,
                        weight: FontWeight.w700,
                        color: AppColors.honeyLight.withValues(alpha: 0.85),
                        letterSpacing: 2.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FadeTransition(
                    opacity: _textFade,
                    child: Text(
                      'Making Access to Schools Swift and Secure',
                      textAlign: TextAlign.center,
                      style: AppText.body(
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  SizedBox(height: short ? 16 : 36),
                  AnimatedBuilder(
                    animation: _dots,
                    builder: (context, _) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (i) {
                          final active = i == 0;
                          final t = ((_dots.value + i * 0.2) % 1);
                          final pulse = 0.35 + 0.65 * (1 - (t - 0.5).abs() * 2).clamp(0, 1);
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: active
                                  ? AppColors.honey.withValues(alpha: pulse.toDouble())
                                  : Colors.white.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                          );
                        }),
                      );
                    },
                  ),
                  const Spacer(),
                  Text(
                    'Powered by BeeSoft Hive © 2026',
                    style: AppText.body(
                      size: 12,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  SizedBox(height: short ? 12 : 24),
                ],
              ),
            ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
