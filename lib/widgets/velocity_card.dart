import 'package:flutter/material.dart';
import '../theme/style_constants.dart';

class VelocityCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final bool glow;
  final Color? borderColor;

  const VelocityCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.glow = false,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: VelocityColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor ?? VelocityColors.textDim.withValues(alpha: 0.1),
            width: 1,
          ),
          boxShadow: glow ? VelocityGlow.green(15) : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: padding ?? const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
