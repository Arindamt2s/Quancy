import 'package:flutter/material.dart';

/// Colours of the Tobacco screens (same look as the Food inspection).
///
/// Path: lib/Inspections/Tobacco/View/widgets/TobaccoTheme.dart
class TbColors {
  TbColors._();

  // Lists (same as Mobile / Temp Food permit lists)
  static const primary = Color(0xFF1565C0);
  static const primaryLight = Color(0xFF1E88E5);
  static const background = Color(0xFFF5F7FA);
  static const textDark = Color(0xFF1A2B3C);
  static const textMuted = Color(0xFF6B7A90);
  static const border = Color(0xFFE3EAF3);

  // Inspection screens
  // Sampled from the Food inspection screen.
  static const page = Color(0xFFF4F6F9);
  static const brand = Color(0xFF1E53B4); // active tab, question headers
  static const brandSoft = Color(0xFFD7E6F9); // other tabs, chips
  static const brandText = Color(0xFF1E53B4);
  static const stepDone = Color(0xFF2375DD); // check circle on done tabs
  static const appBarStart = Color(0xFF2373DA);
  static const appBarEnd = Color(0xFF1F55B7);
  static const iconTile = Color(0xFFE6EEFB);
  static const fieldFill = Color(0xFFE9EDF3);
  static const fieldBorder = Color(0xFFD5DCE6);
  static const sectionBg = Color(0xFFF3F7FE);
  static const error = Color(0xFFD32F2F);
  static const subSection = Color(0xFFE3ECFB);

  // Answer chips
  static const yes = Color(0xFF16A34A);
  static const no = Color(0xFFD32F2F);
  static const na = Color(0xFF6B7280);

  // Kept for older widgets
  static const teal = brand;
  static const tealDone = brandSoft;
  static const stepIdle = brandSoft;
  static const panel = page;
  static const subSectionBlue = brand;
}
