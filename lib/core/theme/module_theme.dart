import 'package:flutter/material.dart';

enum ModuleType {
  social,
  shopping,
  aiAssistant,
  profile,
  weather,
  utilities,
  browser,
  calendar,
  tasks,
  notes,
  news,
  maps,
}

class ModulePalette {
  final Color primary;
  final Color secondary;
  final Color background;
  final Color surface;
  final Color accent;

  const ModulePalette({
    required this.primary,
    required this.secondary,
    required this.background,
    required this.surface,
    required this.accent,
  });

  List<Color> get gradient => [primary, secondary];

  static ModulePalette forModule(ModuleType module) {
    switch (module) {
      case ModuleType.social:
        return const ModulePalette(
          primary: Color(0xFF7C3AED),
          secondary: Color(0xFFA78BFA),
          background: Color(0xFFF5F0FF),
          surface: Color(0xFFFFFFFF),
          accent: Color(0xFFE9D5FF),
        );

      case ModuleType.shopping:
        return const ModulePalette(
          primary: Color(0xFFF28C28),
          secondary: Color(0xFFFFF1DC),
          background: Color(0xFFFFF8ED),
          surface: Color(0xFFFFFFFF),
          accent: Color(0xFFFFE0B2),
        );

      case ModuleType.aiAssistant:
        return const ModulePalette(
          primary: Color(0xFF2563EB),
          secondary: Color(0xFF06B6D4),
          background: Color(0xFFEFF8FF),
          surface: Color(0xFFFFFFFF),
          accent: Color(0xFFCFFAFE),
        );

      case ModuleType.calendar:
        return const ModulePalette(
          primary: Color(0xFF0F9D8A),
          secondary: Color(0xFF22C55E),
          background: Color(0xFFECFDF5),
          surface: Color(0xFFFFFFFF),
          accent: Color(0xFFCCFBF1),
        );

      case ModuleType.tasks:
        return const ModulePalette(
          primary: Color(0xFFF97316),
          secondary: Color(0xFFF59E0B),
          background: Color(0xFFFFF7ED),
          surface: Color(0xFFFFFFFF),
          accent: Color(0xFFFDE68A),
        );

      case ModuleType.notes:
        return const ModulePalette(
          primary: Color(0xFFEAB308),
          secondary: Color(0xFFFFF7CC),
          background: Color(0xFFFFFCED),
          surface: Color(0xFFFFFFFF),
          accent: Color(0xFFFEF3C7),
        );

      case ModuleType.news:
        return const ModulePalette(
          primary: Color(0xFFDC2626),
          secondary: Color(0xFFFFFFFF),
          background: Color(0xFFFFF5F5),
          surface: Color(0xFFFFFFFF),
          accent: Color(0xFFFEE2E2),
        );

      case ModuleType.maps:
        return const ModulePalette(
          primary: Color(0xFF16A34A),
          secondary: Color(0xFF2563EB),
          background: Color(0xFFEFF6FF),
          surface: Color(0xFFFFFFFF),
          accent: Color(0xFFDCFCE7),
        );

      case ModuleType.weather:
        return const ModulePalette(
          primary: Color(0xFF38BDF8),
          secondary: Color(0xFF0284C7),
          background: Color(0xFFF0F9FF),
          surface: Color(0xFFFFFFFF),
          accent: Color(0xFFBAE6FD),
        );

      case ModuleType.profile:
        return const ModulePalette(
          primary: Color(0xFF64748B),
          secondary: Color(0xFF94A3B8),
          background: Color(0xFFF1F5F9),
          surface: Color(0xFFFFFFFF),
          accent: Color(0xFFE2E8F0),
        );

      case ModuleType.utilities:
        return const ModulePalette(
          primary: Color(0xFF6366F1),
          secondary: Color(0xFF818CF8),
          background: Color(0xFFEEF2FF),
          surface: Color(0xFFFFFFFF),
          accent: Color(0xFFE0E7FF),
        );

      case ModuleType.browser:
        return const ModulePalette(
          primary: Color(0xFF0D9488),
          secondary: Color(0xFF2DD4BF),
          background: Color(0xFFF0FDFA),
          surface: Color(0xFFFFFFFF),
          accent: Color(0xFFCCFBF1),
        );
    }
  }
}
