import 'package:flutter/material.dart';

class Roles {
  static const patient = 'patient';
  static const provider = 'provider';
  static const receptionist = 'receptionist';
  static const admin = 'admin';

  /// List of all valid roles
  static const List<String> allRoles = [
    patient,
    provider,
    receptionist,
    admin,
  ];

  /// Check if a role is valid
  static bool isValidRole(String role) {
    return allRoles.contains(role);
  }
}

class RoleLabels {
  static String getDisplayLabel(String role) {
    switch (role) {
      case Roles.patient:
        return 'Patient';
      case Roles.provider:
        return 'Professional';
      case Roles.receptionist:
        return 'Receptionist';
      case Roles.admin:
        return 'Admin';
      default:
        return 'User';
    }
  }

  /// Get role description for role selection screen
  static String getDescription(String role) {
    switch (role) {
      case Roles.patient:
        return 'Access your mental health records, take assessments, and manage appointments';
      case Roles.provider:
        return 'Manage patient care, view assessments, and provide professional services';
      case Roles.receptionist:
        return 'Handle patient registration, schedule appointments, and manage front desk operations';
      case Roles.admin:
        return 'System administration, user management, and security oversight';
      default:
        return 'General user access';
    }
  }
}

class RoleUtils {
  static Color getRoleColor(String role) {
    switch (role) {
      case Roles.patient:
        return const Color(0xFF6BB7B7);
      case Roles.provider:
        return const Color(0xFF7D83FF);
      case Roles.receptionist:
        return const Color(0xFF9ED5C5);
      case Roles.admin:
        return const Color(0xFFB388EB);
      default:
        return const Color(0xFF6BB7B7);
    }
  }

  static IconData getRoleIcon(String role) {
    switch (role) {
      case Roles.patient:
        return Icons.self_improvement_outlined;
      case Roles.provider:
        return Icons.psychology_alt_outlined;
      case Roles.receptionist:
        return Icons.support_agent_outlined;
      case Roles.admin:
        return Icons.security_outlined;
      default:
        return Icons.person_outline;
    }
  }

  /// Get a lighter shade of the role color for backgrounds
  static Color getRoleColorLight(String role) {
    return getRoleColor(role).withOpacity(0.1);
  }

  /// Get a darker shade of the role color for text
  static Color getRoleColorDark(String role) {
    final color = getRoleColor(role);
    return Color.fromRGBO(
      (color.red * 0.8).round(),
      (color.green * 0.8).round(),
      (color.blue * 0.8).round(),
      1.0,
    );
  }
}

/// Navigation helper for role-based routing
class RoleNavigation {
  /// Get the default dashboard route for a role
  static String getDashboardRoute(String role) {
    switch (role) {
      case Roles.patient:
        return '/patient_dashboard';
      case Roles.provider:
        return '/doctor_dashboard';
      case Roles.admin:
        return '/admin_dashboard';
      case Roles.receptionist:
        return '/receptionist_dashboard';
      default:
        return '/login';
    }
  }

  /// Navigate to the appropriate dashboard based on role
  static void navigateToDashboard(BuildContext context, String role) {
    final route = getDashboardRoute(role);
    Navigator.of(context).pushReplacementNamed(route);
  }
}

/// Permissions system for role-based access control
class RolePermissions {
  // Define permission constants
  static const String viewOwnData = 'view_own_data';
  static const String viewPatientData = 'view_patient_data';
  static const String manageAppointments = 'manage_appointments';
  static const String manageUsers = 'manage_users';
  static const String systemAdmin = 'system_admin';
  static const String frontDesk = 'front_desk';

  /// Get permissions for a specific role
  static List<String> getPermissions(String role) {
    switch (role) {
      case Roles.patient:
        return [viewOwnData];
      case Roles.provider:
        return [viewPatientData, manageAppointments];
      case Roles.receptionist:
        return [frontDesk, manageAppointments];
      case Roles.admin:
        return [systemAdmin, manageUsers, viewPatientData, manageAppointments];
      default:
        return [];
    }
  }

  /// Check if a role has a specific permission
  static bool hasPermission(String role, String permission) {
    return getPermissions(role).contains(permission);
  }
}