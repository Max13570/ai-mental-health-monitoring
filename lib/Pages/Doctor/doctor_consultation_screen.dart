import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../video_call_screen.dart';

class DoctorConsultationScreen extends StatefulWidget {
  final String roomName;

  const DoctorConsultationScreen({super.key, required this.roomName});

  @override
  State<DoctorConsultationScreen> createState() => _DoctorConsultationScreenState();
}

class _DoctorConsultationScreenState extends State<DoctorConsultationScreen> {
  static const Color medicalTeal = Color(0xFF0F766E);
  static const Color lightGray = Color(0xFFF8FAFC);

  final user = FirebaseAuth.instance.currentUser;

  Future<void> _startConsultation(String consultationId, String patientName) async {
    try {
      // Update consultation status to "Ready to start"
      await FirebaseFirestore.instance
          .collection('consultations')
          .doc(consultationId)
          .update({
        'status': 'Ready to start',
        'startedAt': FieldValue.serverTimestamp(),
      });

      // Navigate to video call
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoCallScreen(
            roomName: consultationId,
            isDoctor: true,
            participantName: patientName,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting consultation: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGray,
      appBar: AppBar(
        backgroundColor: medicalTeal,
        title: Text("Doctor Consultations",
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('consultations')
            .where('doctorId', isEqualTo: user?.uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    "No consultations scheduled",
                    style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final status = data['status'] ?? 'Scheduled';
              final patientName = data['patientName'] ?? 'Patient';
              final patientId = data['patientId'] ?? '';
              final specialty = data['specialty'] ?? 'General Consultation';
              final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
              final dateStr = timestamp != null
                  ? DateFormat('dd MMM yyyy, hh:mm a').format(timestamp)
                  : "Unknown time";

              return Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                margin: const EdgeInsets.only(bottom: 16),
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
                                Text(patientName,
                                    style: GoogleFonts.poppins(
                                        fontSize: 16, fontWeight: FontWeight.w600)),
                                Text(specialty,
                                    style: GoogleFonts.poppins(
                                        fontSize: 14, color: Colors.grey[600])),
                              ],
                            ),
                          ),
                          _statusChip(status),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(dateStr,
                              style: GoogleFonts.poppins(
                                  fontSize: 14, color: Colors.grey[600])),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildActionButton(doc.id, status, patientName),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildActionButton(String consultationId, String status, String patientName) {
    switch (status) {
      case 'Scheduled':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: medicalTeal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => _startConsultation(consultationId, patientName),
            child: Text('Start Consultation', style: GoogleFonts.poppins()),
          ),
        );

      case 'Ready to start':
      case 'Ongoing':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VideoCallScreen(
                    roomName: consultationId,
                    isDoctor: true,
                    participantName: patientName,
                  ),
                ),
              );
            },
            child: Text('Join Consultation', style: GoogleFonts.poppins()),
          ),
        );

      case 'Completed':
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: null,
            child: Text('Completed', style: GoogleFonts.poppins()),
          ),
        );

      default:
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: null,
            child: Text(status, style: GoogleFonts.poppins()),
          ),
        );
    }
  }

  Widget _statusChip(String status) {
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
        color = medicalTeal;
    }
    return Chip(
      label: Text(status,
          style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: color,
    );
  }
}