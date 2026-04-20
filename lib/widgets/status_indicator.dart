import 'package:flutter/material.dart';
import '../theme/style_constants.dart';

class StatusIndicator extends StatefulWidget {
  final String label;
  final String value;
  final bool active;

  const StatusIndicator({
    super.key,
    required this.label,
    required this.value,
    this.active = false,
  });

  @override
  State<StatusIndicator> createState() => _StatusIndicatorState();
}

class _StatusIndicatorState extends State<StatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 2.0, end: 8.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label.toUpperCase(),
          style: VelocityTextStyles.dimBody.copyWith(fontSize: 10, letterSpacing: 1.0),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) {
                return Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.active ? VelocityColors.primary : VelocityColors.textDim,
                    boxShadow: widget.active
                        ? [
                            BoxShadow(
                              color: VelocityColors.primary.withValues(alpha: 0.5),
                              blurRadius: _glowAnimation.value,
                              spreadRadius: _glowAnimation.value / 2,
                            )
                          ]
                        : null,
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            Text(
              widget.value.toUpperCase(),
              style: VelocityTextStyles.subHeading.copyWith(fontSize: 14),
            ),
          ],
        ),
      ],
    );
  }
}
