import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'doctor_consultation_screen.dart';
import '../video_call_screen.dart'; // Add this import

class DoctorAppointmentsScreen extends StatefulWidget {
  const DoctorAppointmentsScreen({super.key});

  @override
  State<DoctorAppointmentsScreen> createState() => _DoctorAppointmentsScreenState();
}

class _DoctorAppointmentsScreenState extends State<DoctorAppointmentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  static const Color medicalBlue = Color(0xFF1E3A8A);
  static const Color medicalTeal = Color(0xFF0F766E);
  static const Color medicalGreen = Color(0xFF047857);
  static const Color lightMedicalBlue = Color(0xFF3B82F6);
  static const Color medicalGray = Color(0xFF64748B);
  static const Color lightGray = Color(0xFFF8FAFC);
  static const Color successGreen = Color(0xFF10B981);
  static const Color warningOrange = Color(0xFFF59E0B);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color purpleAccent = Color(0xFF7C3AED);
  static const double _padding = 16.0;
  static const double _cardRadius = 12.0;

  String? _doctorName;
  bool _isLoadingDoctorInfo = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadDoctorInfo();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDoctorInfo() async {
    setState(() => _isLoadingDoctorInfo = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoadingDoctorInfo = false);
        return;
      }

      // For now, use a simple doctor name
      setState(() {
        _doctorName = "Emily Davis"; // Hardcoded for testing
        _isLoadingDoctorInfo = false;
      });

    } catch (e) {
      debugPrint('Error loading doctor info: $e');
      final user = FirebaseAuth.instance.currentUser;
      setState(() {
        _doctorName = user?.displayName ?? user?.email?.split('@')[0] ?? 'Doctor';
        _isLoadingDoctorInfo = false;
      });
    }
  }

  Future<void> _startConsultation(String appointmentId, Map<String, dynamic> appointmentData) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Starting consultation...'),
            ],
          ),
        ),
      );

      // Create consultation document FIRST
      final consultationId = 'consult_$appointmentId';
      final patientName = appointmentData['patientName'] ?? 'Patient';

      // Get patient ID from the appointment data or use a default
      final patientId = appointmentData['patientId'] ??
          appointmentData['userId'] ??
          'patient_${appointmentId}';

      debugPrint('Creating consultation: $consultationId for patient: $patientId');

      await FirebaseFirestore.instance
          .collection('consultations')
          .doc(consultationId)
          .set({
        'consultationId': consultationId,
        'appointmentId': appointmentId,
        'doctorId': FirebaseAuth.instance.currentUser?.uid,
        'patientId': patientId, // This is crucial for patient screen
        'patientName': patientName,
        'doctorName': 'Dr. $_doctorName',
        'specialty': appointmentData['reasonForVisit'] ?? 'General Consultation',
        'status': 'Ongoing',
        'timestamp': FieldValue.serverTimestamp(),
        'startedAt': FieldValue.serverTimestamp(),
        'roomName': consultationId,
      });

      debugPrint('Consultation document created with patientId: $patientId');

      // Update appointment status
      await FirebaseFirestore.instance
          .collection('all_appointment_requests')
          .doc(appointmentId)
          .update({
        'status': 'ongoing',
        'startedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context);

      // Navigate directly to VideoCallScreen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoCallScreen(
            roomName: consultationId,
            isDoctor: true,
            participantName: patientName,
          ),
        ),
      );

    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start consultation: ${e.toString()}'),
          backgroundColor: errorRed,
        ),
      );
      debugPrint('Error starting consultation: $e');
    }
  }

  DateTime? _parseDateTime(dynamic dateTime) {
    try {
      if (dateTime is Timestamp) {
        return dateTime.toDate();
      } else if (dateTime is DateTime) {
        return dateTime;
      } else if (dateTime is String) {
        // Try to parse the date string
        return DateFormat('dd MMMM yyyy').parse(dateTime.split(' at ')[0]);
      }
      return null;
    } catch (e) {
      debugPrint('Error parsing date: $e');
      return null;
    }
  }

  String _formatDateTime(dynamic dateTime) {
    final date = _parseDateTime(dateTime);
    return date != null ? DateFormat('MMM dd, yyyy at hh:mm a').format(date) : 'Invalid date';
  }

  Widget _buildAppointmentCard(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final status = data['status']?.toString().toLowerCase() ?? 'scheduled';

    Color statusColor;
    String statusText;

    switch (status) {
      case 'ongoing':
        statusColor = Colors.orange;
        statusText = 'ONGOING';
        break;
      case 'completed':
        statusColor = Colors.green;
        statusText = 'COMPLETED';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusText = 'CANCELLED';
        break;
      default:
        statusColor = medicalTeal;
        statusText = 'SCHEDULED';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: medicalTeal.withOpacity(0.1),
                  child: Icon(Icons.person, color: medicalTeal),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['patientName'] ?? 'Unknown Patient',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        data['reasonForVisit'] ?? 'General Consultation',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(statusText),
                  backgroundColor: statusColor,
                  labelStyle: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(_formatDateTime(data['requestedDateTime'])),
              ],
            ),
            const SizedBox(height: 12),
            if (status == 'scheduled' || status == 'accepted')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _startConsultation(doc.id, data),
                  child: const Text('Start Consultation'),
                ),
              )
            else if (status == 'ongoing')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  onPressed: () {
                    // FIX: Navigate directly to VideoCallScreen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VideoCallScreen(
                          roomName: 'consult_${doc.id}',
                          isDoctor: true,
                          participantName: data['patientName'] ?? 'Patient',
                        ),
                      ),
                    );
                  },
                  child: const Text('Rejoin Consultation'),
                ),
              )
            else if (status == 'completed')
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: null,
                    child: const Text('Completed'),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentsStream(String statusFilter) {
    if (_isLoadingDoctorInfo) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('all_appointment_requests')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        List<DocumentSnapshot> appointments = snapshot.data!.docs;

        // Filter by doctor name
        appointments = appointments.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final doctorField = data['doctor']?.toString() ?? '';
          return doctorField.contains(_doctorName ?? '') ||
              _doctorName?.contains('Emily Davis') == true;
        }).toList();

        // Filter by status
        appointments = appointments.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status']?.toString().toLowerCase() ?? 'scheduled';

          switch (statusFilter) {
            case 'upcoming':
              return status == 'scheduled' || status == 'accepted' || status == 'ongoing';
            case 'today':
              final appointmentDate = _parseDateTime(data['requestedDateTime']);
              final today = DateTime.now();
              return appointmentDate != null &&
                  appointmentDate.year == today.year &&
                  appointmentDate.month == today.month &&
                  appointmentDate.day == today.day;
            case 'completed':
              return status == 'completed';
            case 'all':
              return true;
            default:
              return status == statusFilter;
          }
        }).toList();

        if (appointments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'No $statusFilter appointments',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: appointments.length,
          itemBuilder: (context, index) => _buildAppointmentCard(context, appointments[index]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGray,
      appBar: AppBar(
        title: Text('Appointments - Dr. $_doctorName'),
        backgroundColor: medicalBlue,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Today'),
            Tab(text: 'Completed'),
            Tab(text: 'All'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAppointmentsStream('upcoming'),
          _buildAppointmentsStream('today'),
          _buildAppointmentsStream('completed'),
          _buildAppointmentsStream('all'),
        ],
      ),
    );
  }
}