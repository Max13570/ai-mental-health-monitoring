export 'welcome_screen.dart';
export 'role_constants.dart';
export 'signup_screen.dart';
export 'login_screen.dart';
export 'role_selection_screen.dart';

// Dashboards by role
export 'patient/patient_dashboard_screen.dart';
export 'Doctor/doctor_dashboard_screen.dart';
export 'Doctor/doctor_appointments_screen.dart';
export 'Admin/admin_dashboard_screen.dart';
export 'Receptionist/receptionist_dashboard_screen.dart';

// Assessment and Report Screens
export 'patient/assessment_screen.dart';

import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF667eea);
  static const Color secondary = Color(0xFF764ba2);
  static const Color accent = Color(0xFF8B5CF6);
  static const Color teal = Color(0xFF06b6d4);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 0.4, 0.8, 1.0],
    colors: [primary, secondary, accent, teal],
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Colors.white, Color(0xFFF8F9FA)],
  );
}

class AppTextStyles {
  static const TextStyle heading = TextStyle(
    fontSize: 42,
    fontWeight: FontWeight.w800,
    color: Colors.white,
    letterSpacing: -0.5,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
  );

  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );
}

class AppAnimations {
  static const Duration fast = Duration(milliseconds: 300);
  static const Duration medium = Duration(milliseconds: 600);
  static const Duration slow = Duration(milliseconds: 1200);

  static const Curve bouncy = Curves.elasticOut;
  static const Curve smooth = Curves.easeInOut;
  static const Curve slideUp = Curves.easeOutCubic;
}

class AppShadows {
  static List<BoxShadow> get card => [
    BoxShadow(
      color: Colors.black.withOpacity(0.1),
      blurRadius: 20,
      offset: const Offset(0, 10),
    ),
  ];

  static List<BoxShadow> get glow => [
    BoxShadow(
      color: Colors.white.withOpacity(0.2),
      blurRadius: 40,
      spreadRadius: 5,
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.1),
      blurRadius: 20,
      offset: const Offset(0, 10),
    ),
  ];

  static List<Shadow> get text => [
    Shadow(
      color: Colors.black.withOpacity(0.2),
      offset: const Offset(0, 2),
      blurRadius: 4,
    ),
  ];
}

class AppUtils {
  static bool get isTablet {
    return false;
  }

  static double getResponsiveFontSize(BuildContext context, double baseFontSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 600) {
      return baseFontSize * 1.2;
    }
    return baseFontSize;
  }

  static EdgeInsets getResponsivePadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 600) {
      return const EdgeInsets.symmetric(horizontal: 64.0, vertical: 40.0);
    }
    return const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40.0);
  }
}