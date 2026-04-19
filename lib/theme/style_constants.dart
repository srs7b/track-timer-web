import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class VelocityColors {
  static const Color black = Color(0xFF000000);
  static const Color surface = Color(0xFF0A0A0A);
  static const Color surfaceLight = Color(0xFF121212);
  static const Color primary = Color(0xFF00FF88); // Emerald Green
  static const Color secondary = Color(0xFF00D1FF); // Electric Blue
  static const Color accent = Color(0xFFBB86FC); // Purple (Coaching)
  static const Color textBody = Color(0xFFFFFFFF);
  static const Color textDim = Color(0xFF888888);
  
  static const Gradient coachingGradient = LinearGradient(
    colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class VelocityTextStyles {
  static TextStyle get heading => GoogleFonts.inter(
        color: VelocityColors.textBody,
        fontSize: 24,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
      );

  static TextStyle get subHeading => GoogleFonts.inter(
        color: VelocityColors.textBody,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get technical => GoogleFonts.spaceMono(
        color: VelocityColors.primary,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      );

  static TextStyle get terminal => GoogleFonts.spaceMono(
        color: VelocityColors.primary,
        fontSize: 12,
      );

  static TextStyle get body => GoogleFonts.inter(
        color: VelocityColors.textBody,
        fontSize: 14,
      );

  static TextStyle get dimBody => GoogleFonts.inter(
        color: VelocityColors.textDim,
        fontSize: 12,
      );
}

class VelocityGlow {
  static List<BoxShadow> green(double radius) => [
        BoxShadow(
          color: VelocityColors.primary.withOpacity(0.3),
          blurRadius: radius,
          spreadRadius: 2,
        ),
      ];

  static List<BoxShadow> purple(double radius) => [
        BoxShadow(
          color: VelocityColors.accent.withOpacity(0.3),
          blurRadius: radius,
          spreadRadius: 2,
        ),
      ];
}
