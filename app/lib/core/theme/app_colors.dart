// lib/core/theme/app_colors.dart
// Marrty IFR31 — Color System
// Dev: rahulpr2000 | RAHUL PR | Marrty LLC

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Brand ───────────────────────────────────────────
  static const primary      = Color(0xFF4CAF50); // Light Green
  static const primaryDark  = Color(0xFF66BB6A); // Dark mode primary
  static const primaryDeep  = Color(0xFF2E7D32); // Deep green accent
  static const onPrimary    = Color(0xFFFFFFFF);
  static const onPrimaryDark = Color(0xFF121212);

  // ── Backgrounds ─────────────────────────────────────
  static const bgLight      = Color(0xFFFFFFFF);
  static const bgDark       = Color(0xFF0F0F0F);
  static const surfaceLight = Color(0xFFF5F7FA);
  static const surfaceDark  = Color(0xFF1A1A1A);
  static const surfaceVarLight = Color(0xFFE8F5E9); // Pale green
  static const surfaceVarDark  = Color(0xFF1B3A1D); // Dark green

  // ── Text ────────────────────────────────────────────
  static const textLight    = Color(0xFF1A1A2E);
  static const textDark     = Color(0xFFFAFAFA);
  static const textSecLight = Color(0xFF6B7280);
  static const textSecDark  = Color(0xFF9CA3AF);

  // ── Cards ───────────────────────────────────────────
  static const cardLight    = Color(0xFFFFFFFF);
  static const cardDark     = Color(0xFF1E1E1E);
  static const borderDark   = Color(0xFF2D2D2D);

  // ── Status ──────────────────────────────────────────
  static const success  = Color(0xFF2E7D32);
  static const warning  = Color(0xFFF59E0B);
  static const error    = Color(0xFFEF4444);
  static const info     = Color(0xFF3B82F6);

  // ── Attendance badges ───────────────────────────────
  static const present = Color(0xFF4CAF50);
  static const late    = Color(0xFFF59E0B);
  static const absent  = Color(0xFFEF4444);
  static const manual  = Color(0xFF3B82F6);

  // ── Streak / Emoji ──────────────────────────────────
  static const streak  = Color(0xFFFF6D00); // fire orange
  static const calm    = Color(0xFF0EA5E9); // blue
  static const sad     = Color(0xFFEAB308); // amber

  // ── Dividers ────────────────────────────────────────
  static const dividerLight = Color(0xFFE5E7EB);
  static const dividerDark  = Color(0xFF2D2D2D);

  // ── AppBar ──────────────────────────────────────────
  static const appBarLight = Color(0xFFFFFFFF);
  static const appBarDark  = Color(0xFF1A1A1A);
}
