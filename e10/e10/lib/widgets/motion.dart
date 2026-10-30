import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../school_store.dart';
import '../theme.dart';

/// Dashboard list children, animated. While the very first load is still
/// running (nothing saved on the device yet) it shows pulsing placeholder
/// cards instead of rows of zeros; once data is there each card fades and
/// rises in, one after another.
List<Widget> dashboardChildren(BuildContext context, List<Widget> children) {
  final store = SchoolScope.of(context);
  if (store.loading && store.tables.isEmpty) return const [DashboardSkeleton()];
  return [
    for (var i = 0; i < children.length; i++) FadeSlideIn(index: i, child: children[i]),
  ];
}

/// Fades and slides its child up into place once, when first shown.
/// [index] staggers siblings so a list builds up top to bottom.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  // The stagger delay is the start of the animation's own timeline (an
  // Interval), not a separate timer.
  static const _runMs = 420;
  late final int _delayMs = 45 * math.min(widget.index, 10);
  late final AnimationController _c = AnimationController(vsync: this, duration: Duration(milliseconds: _runMs + _delayMs))..forward();
  late final Animation<double> _t = CurvedAnimation(
    parent: _c,
    curve: Interval(_delayMs / (_runMs + _delayMs), 1, curve: Curves.easeOutCubic),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (context, child) => Opacity(
        opacity: _t.value,
        child: Transform.translate(offset: Offset(0, 16 * (1 - _t.value)), child: child),
      ),
      child: widget.child,
    );
  }
}

/// A grey block that gently pulses — stands in for content still loading.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({super.key, this.height = 16, this.width, this.radius = 12});

  final double height;
  final double? width;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = AppSurface.dark(context) ? Colors.white : AppColors.slate400;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          color: base.withValues(alpha: 0.10 + 0.10 * _c.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Placeholder layout for a dashboard's first load: a grid of stat tiles and
/// two larger cards.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading your school',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              SkeletonBox(height: 32, width: 70, radius: 20),
              SizedBox(width: 8),
              SkeletonBox(height: 32, width: 90, radius: 20),
              SizedBox(width: 8),
              SkeletonBox(height: 32, width: 90, radius: 20),
            ],
          ),
          const SizedBox(height: 14),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.14,
            children: [for (var i = 0; i < 6; i++) const SkeletonBox(height: double.infinity, radius: 16)],
          ),
          const SizedBox(height: 16),
          const SkeletonBox(height: 150, radius: 16),
          const SizedBox(height: 16),
          const SkeletonBox(height: 110, radius: 16),
        ],
      ),
    );
  }
}

/// A thin moving bar under a dashboard header while the app is refreshing
/// school data in the background; it disappears when the refresh finishes.
class SyncBar extends StatelessWidget {
  const SyncBar({super.key});

  @override
  Widget build(BuildContext context) {
    // Listens to the store itself: this is a const widget, so a rebuild of
    // the screen around it would otherwise skip it.
    final store = SchoolScope.read(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: store.loading
            ? LinearProgressIndicator(
                key: const ValueKey('sync'),
                minHeight: 2.5,
                color: AppSurface.brand(context),
                backgroundColor: AppSurface.brand(context).withValues(alpha: 0.15),
              )
            : const SizedBox(key: ValueKey('idle'), height: 2.5),
      ),
    );
  }
}

/// Shows [text], counting its number up from zero when it first appears or
/// changes ("1,234", "GHS 12.5K", "87%" keep their prefix, suffix and
/// formatting). Text without a number is shown as-is.
class CountUpText extends StatelessWidget {
  const CountUpText(this.text, {super.key, this.style, this.maxLines, this.overflow});

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  static final _number = RegExp(r'\d[\d,]*(\.\d+)?');

  @override
  Widget build(BuildContext context) {
    final match = _number.firstMatch(text);
    final target = match == null ? null : double.tryParse(match.group(0)!.replaceAll(',', ''));
    if (match == null || target == null) {
      return Text(text, style: style, maxLines: maxLines, overflow: overflow);
    }
    final decimals = match.group(1) == null ? 0 : match.group(1)!.length - 1;
    final commas = match.group(0)!.contains(',');
    String format(double v) {
      var s = v.toStringAsFixed(decimals);
      if (commas) {
        final parts = s.split('.');
        final whole = parts.first.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
        s = parts.length > 1 ? '$whole.${parts[1]}' : whole;
      }
      return text.replaceRange(match.start, match.end, s);
    }

    return TweenAnimationBuilder<double>(
      key: ValueKey(text),
      tween: Tween(begin: 0, end: target),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(format(v), style: style, maxLines: maxLines, overflow: overflow),
    );
  }
}

/// Shrinks its child slightly while pressed, for tappable cards.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child});

  final Widget child;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _down = true),
      onPointerUp: (_) => setState(() => _down = false),
      onPointerCancel: (_) => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.96 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
