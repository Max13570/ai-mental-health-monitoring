import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // For debugPrint

/// Enum for different appointment priorities.
enum Priority {
  low,
  normal,
  high,
  urgent,
}

/// Enum for different types of appointments.
enum AppointmentType {
  consultation,
  followUp,
  checkup,
  emergency,
  vaccination,
}

/// Enum for appointment status.
enum AppointmentStatus {
  pending,
  accepted,
  rejected,
  completed,
  cancelled,
}

/// A model class to represent an an appointment request.
class AppointmentRequest {
  final String id;
  final String patientName;
  final String phoneNumber;
  final String email;
  final DateTime requestedDateTime;
  final String reasonForVisit;
  final AppointmentType appointmentType;
  final Priority priority;
  final DateTime submittedAt; // Timestamp when the request was submitted
  final String notes;
  AppointmentStatus status; // Status can be changed (e.g., by receptionist)
  final String? userId; // ID of the user who booked the appointment
  final String? selectedDoctor; // The doctor selected by the patient
  final String? selectedTime; // The time string selected by the patient (e.g., "10:00 AM")

  AppointmentRequest({
    required this.id,
    required this.patientName,
    required this.phoneNumber,
    required this.email,
    required this.requestedDateTime,
    required this.reasonForVisit,
    required this.appointmentType,
    this.priority = Priority.normal,
    required this.submittedAt,
    this.notes = '',
    this.status = AppointmentStatus.pending,
    this.userId,
    this.selectedDoctor,
    this.selectedTime,
  });

  /// Converts this AppointmentRequest object into a Map for Firestore.
  Map<String, dynamic> toMap() {
    return {
      'patientName': patientName,
      'phoneNumber': phoneNumber,
      'email': email,
      'requestedDateTime': Timestamp.fromDate(requestedDateTime),
      'reasonForVisit': reasonForVisit,
      'appointmentType': appointmentType.name, // Store enum as string
      'priority': priority.name, // Store enum as string
      'submittedAt': Timestamp.fromDate(submittedAt),
      'notes': notes,
      'status': status.name, // Store enum as string
      'userId': userId,
      'selectedDoctor': selectedDoctor,
      'selectedTime': selectedTime,
    };
  }

  /// Factory constructor to create an AppointmentRequest from a Firestore document snapshot.
  factory AppointmentRequest.fromMap(String id, Map<String, dynamic> data) {
    // Helper function to safely parse enum strings
    T _parseEnum<T>(String? value, List<T> values, T defaultValue) {
      if (value == null) return defaultValue;
      try {
        return values.firstWhere(
              (e) => e.toString().split('.').last.toLowerCase() == value.toLowerCase(),
          orElse: () => defaultValue,
        );
      } catch (e) {
        debugPrint('Error parsing enum value "$value": $e');
        return defaultValue;
      }
    }

    // Helper function to safely get DateTime from Firestore Timestamp or other types
    DateTime _getSafeDateTime(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          debugPrint('Error parsing date string: $value - $e');
        }
      }
      return DateTime.now(); // Fallback to current time if parsing fails
    }

    return AppointmentRequest(
      id: id,
      patientName: data['patientName'] ?? 'Unknown Patient',
      phoneNumber: data['phoneNumber'] ?? 'N/A',
      email: data['email'] ?? 'N/A',
      requestedDateTime: _getSafeDateTime(data['requestedDateTime']),
      reasonForVisit: data['reasonForVisit'] ?? 'No reason provided',
      appointmentType: _parseEnum(
        data['appointmentType'],
        AppointmentType.values,
        AppointmentType.consultation,
      ),
      priority: _parseEnum(
        data['priority'],
        Priority.values,
        Priority.normal,
      ),
      submittedAt: _getSafeDateTime(data['submittedAt']),
      notes: data['notes'] ?? '',
      status: _parseEnum(
        data['status'],
        AppointmentStatus.values,
        AppointmentStatus.pending,
      ),
      userId: data['userId'],
      selectedDoctor: data['selectedDoctor'],
      selectedTime: data['selectedTime'],
    );
  }

  /// Getter to format the time since the appointment was submitted.
  String get timeAgo {
    final difference = DateTime.now().difference(submittedAt);
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }
}
