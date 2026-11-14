import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum Priority { low, normal, high, urgent }
enum AppointmentType { consultation, followUp, checkup, emergency, vaccination }
enum AppointmentStatus { pending, accepted, rejected, completed, cancelled }

class AppointmentRequest {
  final String id;
  final String patientName;
  final String phoneNumber;
  final String email;
  final DateTime requestedDateTime;
  final String reasonForVisit;
  final AppointmentType appointmentType;
  final Priority priority;
  final DateTime submittedAt;
  final String notes;
  AppointmentStatus status;
  final String? userId;
  String? rejectionReason;
  final String? selectedDoctor;

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
    this.rejectionReason,
    this.selectedDoctor,
  });

  factory AppointmentRequest.fromMap(String id, Map<String, dynamic> data) {
    return AppointmentRequest(
      id: id,
      patientName: data['patientName'] ?? 'Unknown Patient',
      phoneNumber: data['phoneNumber'] ?? 'N/A',
      email: data['email'] ?? 'N/A',
      requestedDateTime: (data['requestedDateTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reasonForVisit: data['reasonForVisit'] ?? 'No reason provided',
      appointmentType: _parseAppointmentType(data['appointmentType']),
      priority: _parsePriority(data['priority']),
      submittedAt: (data['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notes: data['notes'] ?? '',
      status: _parseStatus(data['status']),
      userId: data['userId'],
      rejectionReason: data['rejectionReason'],
      selectedDoctor: data['selectedDoctor'],
    );
  }

  static AppointmentType _parseAppointmentType(String? type) {
    switch (type?.toLowerCase()) {
      case 'followup':
        return AppointmentType.followUp;
      case 'checkup':
        return AppointmentType.checkup;
      case 'emergency':
        return AppointmentType.emergency;
      case 'vaccination':
        return AppointmentType.vaccination;
      default:
        return AppointmentType.consultation;
    }
  }

  static Priority _parsePriority(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'high':
        return Priority.high;
      case 'urgent':
        return Priority.urgent;
      case 'low':
        return Priority.low;
      default:
        return Priority.normal;
    }
  }

  static AppointmentStatus _parseStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'accepted':
        return AppointmentStatus.accepted;
      case 'rejected':
        return AppointmentStatus.rejected;
      case 'completed':
        return AppointmentStatus.completed;
      case 'cancelled':
        return AppointmentStatus.cancelled;
      default:
        return AppointmentStatus.pending;
    }
  }

  String get timeAgo {
    final difference = DateTime.now().difference(submittedAt);
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    }
    return 'Just now';
  }
}

class AcceptAppointmentsScreen extends StatefulWidget {
  const AcceptAppointmentsScreen({super.key});

  @override
  State<AcceptAppointmentsScreen> createState() => _AcceptAppointmentsScreenState();
}

class _AcceptAppointmentsScreenState extends State<AcceptAppointmentsScreen> {
  static const Color medicalBlue = Color(0xFF1E3A8A);
  static const Color medicalTeal = Color(0xFF0F766E);
  static const Color medicalGreen = Color(0xFF047857);
  static const Color lightMedicalBlue = Color(0xFF3B82F6);
  static const Color medicalGray = Color(0xFF64748B);
  static const Color lightGray = Color(0xFFF8FAFC);
  static const Color successGreen = Color(0xFF10B981);
  static const Color warningOrange = Color(0xFFF59E0B);
  static const Color errorRed = Color(0xFFEF4444);

  static const double _padding = 16.0;
  static const double _cardElevation = 4.0;
  static const double _cardRadius = 12.0;
  static const double _spacing = 16.0;

  final List<AppointmentRequest> _appointments = [];
  List<AppointmentRequest> _filteredAppointments = [];
  AppointmentStatus _filterStatus = AppointmentStatus.pending;
  Priority? _filterPriority;
  AppointmentType? _filterType;
  bool _isLoading = true;
  String _searchQuery = '';
  String? _errorMessage;
  StreamSubscription? _appointmentsSubscription;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkAuthenticationAndLoad();
  }

  @override
  void dispose() {
    _appointmentsSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthenticationAndLoad() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _errorMessage = 'Please log in to view appointments.';
        _isLoading = false;
      });
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final role = userDoc.data()?['role'] as String?;
      if (!userDoc.exists || !['receptionist', 'admin'].contains(role)) {
        setState(() {
          _errorMessage = 'You do not have permission to view appointments.';
          _isLoading = false;
        });
        return;
      }
      _loadAppointments();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error verifying user role: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAppointments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        _appointmentsSubscription?.cancel();
        _appointmentsSubscription = FirebaseFirestore.instance
            .collection('all_appointment_requests')
            .orderBy('submittedAt', descending: true)
            .snapshots()
            .listen(
              (snapshot) {
            if (!mounted) return;

            setState(() {
              _appointments.clear();
              _appointments.addAll(
                snapshot.docs.map((doc) {
                  final data = doc.data();
                  final timestamp = data['requestedDateTime'] as Timestamp?;
                  if (timestamp == null) {
                    print('Warning: Missing requestedDateTime for doc ${doc.id}');
                    return AppointmentRequest.fromMap(doc.id, {
                      ...data,
                      'requestedDateTime': Timestamp.fromDate(DateTime.now()),
                    });
                  }
                  return AppointmentRequest.fromMap(doc.id, data);
                }).where((appt) => appt.requestedDateTime != null).toList(),
              );
              _filterAppointments();
              _isLoading = false;
            });
          },
          onError: (e, stackTrace) {
            if (mounted) {
              setState(() {
                _errorMessage = 'Failed to load appointments: $e';
                _isLoading = false;
              });
              print('Error: $e\nStack trace: $stackTrace');
            }
          },
          onDone: () {
            if (mounted) setState(() => _isLoading = false);
          },
        );
        break;
      } catch (e) {
        retryCount++;
        if (retryCount == maxRetries) {
          if (mounted) {
            setState(() {
              _errorMessage = 'Failed to connect after $maxRetries attempts: $e';
              _isLoading = false;
            });
          }
        }
        await Future.delayed(Duration(seconds: retryCount * 2));
      }
    }
  }

  void _filterAppointments() {
    setState(() {
      _filteredAppointments = _appointments.where((appt) {
        final matchesStatus = appt.status == _filterStatus;
        final matchesPriority = _filterPriority == null || appt.priority == _filterPriority;
        final matchesType = _filterType == null || appt.appointmentType == _filterType;
        final matchesSearch = _searchQuery.isEmpty ||
            appt.patientName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            appt.reasonForVisit.toLowerCase().contains(_searchQuery.toLowerCase());
        return matchesStatus && matchesPriority && matchesType && matchesSearch;
      }).toList();
    });
  }

  Future<void> _acceptAppointment(AppointmentRequest appointment) async {
    try {
      await FirebaseFirestore.instance
          .collection('all_appointment_requests')
          .doc(appointment.id)
          .update({'status': 'accepted'});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Appointment accepted'),
          backgroundColor: successGreen,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to accept: $e'),
          backgroundColor: errorRed,
        ),
      );
    }
  }

  Future<void> _rejectAppointment(AppointmentRequest appointment) async {
    final TextEditingController _reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Appointment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Reason for rejection:'),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(hintText: 'Enter reason'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (_reasonController.text.isNotEmpty) {
                try {
                  await FirebaseFirestore.instance
                      .collection('all_appointment_requests')
                      .doc(appointment.id)
                      .update({
                    'status': 'rejected',
                    'rejectionReason': _reasonController.text,
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Appointment rejected'),
                      backgroundColor: errorRed,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to reject: $e'),
                      backgroundColor: errorRed,
                    ),
                  );
                }
              }
              Navigator.pop(context);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(Priority priority) {
    switch (priority) {
      case Priority.urgent:
        return errorRed;
      case Priority.high:
        return warningOrange;
      case Priority.low:
        return medicalGray;
      default:
        return lightMedicalBlue;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: medicalGray.withOpacity(0.1),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(
              Icons.event_note_rounded,
              size: 48,
              color: medicalGray,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No appointments found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: medicalBlue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters or check data',
            style: TextStyle(
              fontSize: 14,
              color: medicalGray,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard(AppointmentRequest appointment) {
    final isToday = appointment.requestedDateTime.day == DateTime.now().day &&
        appointment.requestedDateTime.month == DateTime.now().month &&
        appointment.requestedDateTime.year == DateTime.now().year;

    return Container(
      margin: const EdgeInsets.only(bottom: _spacing),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(_padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isToday ? medicalTeal : lightMedicalBlue,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('MMM d, EEEE').format(appointment.requestedDateTime),
                        style: TextStyle(
                          fontSize: 12,
                          color: medicalGray,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        appointment.patientName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: medicalBlue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        appointment.selectedDoctor ?? 'No doctor assigned',
                        style: TextStyle(
                          fontSize: 13,
                          color: medicalGray,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      DateFormat('hh:mm a').format(appointment.requestedDateTime),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: medicalBlue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getPriorityColor(appointment.priority).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        appointment.priority.toString().split('.').last.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _getPriorityColor(appointment.priority),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              appointment.reasonForVisit,
              style: TextStyle(fontSize: 14, color: medicalGray),
            ),
            if (appointment.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Notes: ${appointment.notes}',
                style: TextStyle(fontSize: 13, color: medicalGray.withOpacity(0.8)),
              ),
            ],
            const SizedBox(height: 16),
            if (appointment.status == AppointmentStatus.pending)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.close_rounded, size: 18, color: errorRed),
                      label: Text(
                        'Reject',
                        style: TextStyle(color: errorRed),
                      ),
                      onPressed: () => _rejectAppointment(appointment),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: errorRed),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.check_rounded, size: 18, color: Colors.white),
                      label: Text(
                        'Accept',
                        style: TextStyle(color: Colors.white),
                      ),
                      onPressed: () => _acceptAppointment(appointment),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: successGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              )
            else
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: appointment.status == AppointmentStatus.accepted
                      ? successGreen
                      : errorRed,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  appointment.status.toString().split('.').last.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            if (appointment.status == AppointmentStatus.rejected &&
                appointment.rejectionReason != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Rejection Reason: ${appointment.rejectionReason}',
                  style: TextStyle(fontSize: 13, color: errorRed),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGray,
      appBar: AppBar(
        backgroundColor: medicalBlue,
        foregroundColor: Colors.white,
        title: const Text('Appointment Requests'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: () {
              // Add filter UI here if needed
            },
            tooltip: 'Filter',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: medicalBlue))
          : _errorMessage != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: errorRed),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(color: medicalGray, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      )
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(_padding),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by patient or reason...',
                prefixIcon: Icon(Icons.search_rounded, color: medicalGray),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: Icon(Icons.clear_rounded, color: medicalGray),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                    _filterAppointments();
                  },
                )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: medicalBlue, width: 2),
                ),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
                _filterAppointments();
              },
            ),
          ),
          Expanded(
            child: _filteredAppointments.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
              padding: const EdgeInsets.all(_padding),
              itemCount: _filteredAppointments.length,
              itemBuilder: (context, index) {
                final appointment = _filteredAppointments[index];
                return _buildAppointmentCard(appointment);
              },
            ),
          ),
        ],
      ),
    );
  }
}