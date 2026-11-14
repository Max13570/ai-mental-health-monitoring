import 'package:cloud_firestore/cloud_firestore.dart';

class Appointment {
  final String id;
  final String therapistName;
  final String therapistId;
  final DateTime dateTime;
  final String status;
  final String? notes;
  final String? patientName;
  final String? reason;
  final String? appointmentType;
  final String? priority;
  final DateTime? submittedAt;

  Appointment({
    required this.id,
    required this.therapistName,
    required this.therapistId,
    required this.dateTime,
    this.status = 'Booked',
    this.notes,
    this.patientName,
    this.reason,
    this.appointmentType,
    this.priority,
    this.submittedAt,
  });

  factory Appointment.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Appointment(
      id: doc.id,
      therapistName: data['therapistName'] ??
          data['selectedDoctor'] ??
          'Unknown Therapist',
      therapistId: data['therapistId'] ?? '',
      dateTime: _parseDateTime(data['dateTime'] ?? data['requestedDateTime']),
      status: data['status'] ?? 'Booked',
      notes: data['notes'],
      patientName: data['patientName'],
      reason: data['reason'] ?? data['reasonForVisit'],
      appointmentType: data['appointmentType'],
      priority: data['priority'],
      submittedAt: data['submittedAt']?.toDate(),
    );
  }

  static DateTime _parseDateTime(dynamic timestamp) {
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is DateTime) return timestamp;
    return DateTime.now(); // Fallback
  }

  Map<String, dynamic> toMap() {
    return {
      'therapistName': therapistName,
      'therapistId': therapistId,
      'dateTime': dateTime,
      'status': status,
      if (notes != null) 'notes': notes,
      if (patientName != null) 'patientName': patientName,
      if (reason != null) 'reason': reason,
      if (appointmentType != null) 'appointmentType': appointmentType,
      if (priority != null) 'priority': priority,
      if (submittedAt != null) 'submittedAt': submittedAt,
    };
  }

  Appointment copyWith({
    String? id,
    String? therapistName,
    String? therapistId,
    DateTime? dateTime,
    String? status,
    String? notes,
    String? patientName,
    String? reason,
    String? appointmentType,
    String? priority,
    DateTime? submittedAt,
  }) {
    return Appointment(
      id: id ?? this.id,
      therapistName: therapistName ?? this.therapistName,
      therapistId: therapistId ?? this.therapistId,
      dateTime: dateTime ?? this.dateTime,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      patientName: patientName ?? this.patientName,
      reason: reason ?? this.reason,
      appointmentType: appointmentType ?? this.appointmentType,
      priority: priority ?? this.priority,
      submittedAt: submittedAt ?? this.submittedAt,
    );
  }

  @override
  String toString() {
    return 'Appointment(id: $id, therapistName: $therapistName, dateTime: $dateTime, status: $status)';
  }
}