import 'package:flutter/material.dart';
import '../theme/style_constants.dart';

class VelocityButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool primary;
  final bool busy;

  const VelocityButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.primary = true,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: ElevatedButton(
        onPressed: busy ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: primary ? VelocityColors.textBody : VelocityColors.surfaceLight,
          foregroundColor: primary ? VelocityColors.black : VelocityColors.textBody,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
            side: !primary
                ? BorderSide(color: VelocityColors.textDim.withOpacity(0.3))
                : BorderSide.none,
          ),
          elevation: 0,
        ),
        child: busy
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(VelocityColors.black),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label.toUpperCase(),
                    style: VelocityTextStyles.subHeading.copyWith(
                      color: primary ? VelocityColors.black : VelocityColors.textBody,
                      fontSize: 14,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
