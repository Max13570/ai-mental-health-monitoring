// consultation_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../video_call_screen.dart';
import 'appointment_booking_screen.dart';

class ConsultationScreen extends StatefulWidget {
  const ConsultationScreen({super.key});

  @override
  State<ConsultationScreen> createState() => _ConsultationScreenState();
}

class _ConsultationScreenState extends State<ConsultationScreen> {
  static const Color medicalBlue = Color(0xFF1E3A8A);
  static const Color lightGray = Color(0xFFF8FAFC);
  static const Color patientBlue = Color(0xFF1565C0);

  final User? user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGray,
      appBar: AppBar(
        backgroundColor: medicalBlue,
        title: Text(
          "My Consultations",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: user == null
          ? _buildLoginPrompt()
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('consultations')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          // Filter consultations for this patient
          final patientConsultations = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;

            // Multiple ways to identify patient consultations:
            final patientId = data['patientId']?.toString() ?? '';
            final patientName = data['patientName']?.toString() ?? '';
            final currentUserName = user?.displayName ?? user?.email?.split('@')[0] ?? '';

            // Safe null-checking for user.uid
            final userId = user?.uid ?? '';

            return patientId.contains(userId) ||
                patientId == userId ||
                patientName.contains(currentUserName) ||
                currentUserName.contains(patientName) ||
                _isUserInConsultation(data); // For testing
          }).toList();

          if (patientConsultations.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: patientConsultations.length,
            itemBuilder: (context, index) {
              final doc = patientConsultations[index];
              final data = doc.data() as Map<String, dynamic>;
              return _buildConsultationCard(doc.id, data);
            },
          );
        },
      ),
    );
  }

  // For testing - show consultations that might belong to this user
  bool _isUserInConsultation(Map<String, dynamic> data) {
    final patientName = data['patientName']?.toString().toLowerCase() ?? '';
    final currentUser = user?.displayName?.toLowerCase() ??
        user?.email?.split('@')[0].toLowerCase() ?? '';

    // Simple matching logic for testing
    return patientName.contains('nana') ||
        patientName.contains('sandile') ||
        patientName.contains('mandla');
  }

  Widget _buildConsultationCard(String docId, Map<String, dynamic> data) {
    final status = data['status'] ?? 'Scheduled';
    final doctorName = data['doctorName'] ?? 'Doctor';
    final specialty = data['specialty'] ?? 'General Consultation';
    final patientName = data['patientName'] ?? 'Patient';
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
    final dateStr = timestamp != null
        ? DateFormat('MMM dd, yyyy • hh:mm a').format(timestamp)
        : "Time not specified";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.medical_services, color: patientBlue),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(doctorName,
                          style: GoogleFonts.poppins(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      Text(specialty,
                          style: GoogleFonts.poppins(
                              fontSize: 14, color: Colors.grey)),
                      Text('Patient: $patientName',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                _buildStatusBadge(status),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(dateStr,
                    style: GoogleFonts.poppins(color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 12),
            _buildActionButton(docId, status, doctorName),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String roomName, String status, String doctorName) {
    final canJoin = status == 'Ready to start' || status == 'Ongoing';

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: canJoin ? patientBlue : Colors.grey,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: canJoin
            ? () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VideoCallScreen(
                roomName: roomName,
                isDoctor: false,
                participantName: doctorName,
              ),
            ),
          );
        }
            : null,
        child: Text(
          canJoin ? 'Join Video Call' : 'Waiting for Doctor',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'Ongoing':
        color = Colors.orange;
        break;
      case 'Completed':
        color = Colors.green;
        break;
      case 'Ready to start':
        color = Colors.blue;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(status,
          style: GoogleFonts.poppins(
              fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.video_call, size: 64, color: patientBlue),
          const SizedBox(height: 16),
          Text('No consultations scheduled',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Your consultations will appear here once scheduled',
              style: GoogleFonts.poppins(color: Colors.grey)),
          const SizedBox(height: 8),
          Text('Current user: ${user?.email ?? 'Not logged in'}',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AppointmentBookingScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: patientBlue,
              foregroundColor: Colors.white,
            ),
            child: Text('Book New Appointment'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text('Please log in to view consultations',
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey)),
        ],
      ),
    );
  }
}