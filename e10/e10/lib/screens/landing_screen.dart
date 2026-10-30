import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';

/// The signed-out welcome page, built like the sign-in screen: a blue hero
/// on top and a white sheet below with what e10 does and "Get started".
/// Fully loaded content (no spinner), so it never reads as an app stuck
/// loading.
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key, required this.onGetStarted, this.onRegisterSchool});

  final VoidCallback onGetStarted;
  final VoidCallback? onRegisterSchool;

  static const _features = [
    (Icons.family_restroom_rounded, 'For parents', 'Fees, feeding, reports and daily updates.'),
    (Icons.school_rounded, 'For teachers', 'Attendance, homework, marks and news.'),
    (Icons.point_of_sale_rounded, 'For the school office', 'Fees and feeding, with a receipt every time.'),
  ];

  static const _highlights = ['Fees & feeding', 'Attendance', 'Report cards'];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppGradients.chrome),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: LayoutBuilder(
            builder: (context, box) {
              // Below this height the hero tightens up so "Get started" stays on
              // screen without scrolling.
              final short = box.maxHeight < 780;
              return CustomScrollView(
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Column(
                      children: [
                        SafeArea(bottom: false, child: _hero(short)),
                        Expanded(child: _sheet(context, short, bottom)),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _hero(bool short) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, short ? 6 : 20, 24, short ? 14 : 26),
      child: Column(
        children: [
          FadeSlideIn(index: 0, child: AppLogo(size: short ? 72 : 96)),
          SizedBox(height: short ? 8 : 16),
          FadeSlideIn(
            index: 1,
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: AppText.display(size: short ? 24 : 30, weight: FontWeight.w800, color: Colors.white, letterSpacing: -0.4),
                children: [
                  const TextSpan(text: 'Welcome to e'),
                  TextSpan(text: '10', style: TextStyle(color: AppColors.honeyLight)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          FadeSlideIn(
            index: 2,
            child: Text(
              'Making Access to Schools Swift and Secure',
              textAlign: TextAlign.center,
              style: AppText.body(size: 13.5, color: Colors.white.withValues(alpha: 0.75)),
            ),
          ),
          if (!short) const SizedBox(height: 16),
          if (!short)
            FadeSlideIn(
              index: 3,
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final h in _highlights)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.honeyLight),
                          const SizedBox(width: 6),
                          Text(h, style: AppText.body(size: 12, weight: FontWeight.w600, color: Colors.white)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _sheet(BuildContext context, bool short, double bottom) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppSurface.card(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
        boxShadow: [BoxShadow(color: AppColors.honey.withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, -8))],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(22, 12, 22, 14 + bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppSurface.line(context), borderRadius: BorderRadius.circular(99)),
              ),
            ),
            SizedBox(height: short ? 10 : 20),
            Text(
              'EVERYTHING YOUR SCHOOL NEEDS',
              style: AppText.body(size: 11, weight: FontWeight.w800, color: AppColors.blue, letterSpacing: 0.9),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < _features.length; i++)
              FadeSlideIn(index: 4 + i, child: _FeatureRow(feature: _features[i], last: i == _features.length - 1, compact: short)),
            SizedBox(height: short ? 8 : 24),
            const Spacer(),
            FadeSlideIn(
              index: 8,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onGetStarted,
                  borderRadius: BorderRadius.circular(16),
                  child: Ink(
                    height: short ? 52 : 56,
                    decoration: BoxDecoration(
                      gradient: AppGradients.header,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: AppColors.blue.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Get started', style: AppType.button.copyWith(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                        const SizedBox(width: 10),
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                          child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (onRegisterSchool != null)
              TextButton(
                onPressed: onRegisterSchool,
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: 'New school? ', style: AppText.body(size: 13, color: AppSurface.muted(context))),
                    TextSpan(text: 'Register here', style: AppText.body(size: 13, weight: FontWeight.w700, color: AppColors.blue)),
                  ]),
                ),
              ),
            if (!short)
              Text(
                'Powered by BeeSoft Hive © 2026',
                textAlign: TextAlign.center,
                style: AppText.body(size: 11.5, color: AppSurface.muted(context).withValues(alpha: 0.8)),
              ),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.feature, required this.last, this.compact = false});

  final (IconData, String, String) feature;
  final bool last;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (icon, title, text) = feature;
    return Container(
      padding: EdgeInsets.symmetric(vertical: compact ? 7 : 10),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: AppSurface.line(context))),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: AppColors.blue, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.body(size: 14.5, weight: FontWeight.w700, color: AppSurface.ink(context))),
                const SizedBox(height: 2),
                Text(text, style: AppText.body(size: 12.5, color: AppSurface.muted(context))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
