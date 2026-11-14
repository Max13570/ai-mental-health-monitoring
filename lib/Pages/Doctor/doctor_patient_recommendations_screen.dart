import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class DoctorPatientRecommendationsScreen extends StatefulWidget {
  const DoctorPatientRecommendationsScreen({super.key});

  @override
  State<DoctorPatientRecommendationsScreen> createState() =>
      _DoctorPatientRecommendationsScreenState();
}

class _DoctorPatientRecommendationsScreenState
    extends State<DoctorPatientRecommendationsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  static const Color doctorBlue = Color(0xFF1565C0);
  static const Color lightDoctorBlue = Color(0xFF42A5F5);
  static const Color doctorTeal = Color(0xFF00ACC1);
  static const Color doctorGreen = Color(0xFF43A047);
  static const Color doctorGray = Color(0xFF546E7A);
  static const Color lightGray = Color(0xFFF5F7FA);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color warningOrange = Color(0xFFFF9800);
  static const Color errorRed = Color(0xFFE53935);
  static const Color infoBlue = Color(0xFF2196F3);

  bool _isLoading = true;
  List<PatientAppointmentData> _patientsWithRecommendations = [];
  String? _errorMessage;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadPatientRecommendations();
  }

  Future<void> _loadPatientRecommendations() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_currentUser == null) {
        setState(() => _errorMessage = 'Please log in to view patient data.');
        return;
      }

      final doctorName = _currentUser!.displayName ?? _currentUser!.email;
      debugPrint('Loading recommendations for doctor: $doctorName');

      // Use the same collection as the dashboard - all_appointment_requests
      final appointmentsQuery = await _firestore
          .collection('all_appointment_requests')
          .where('selectedDoctor', isEqualTo: doctorName)
          .where('status', whereIn: ['accepted', 'confirmed', 'ongoing', 'completed'])
          .get();

      debugPrint('Found ${appointmentsQuery.docs.length} appointments in all_appointment_requests');

      List<PatientAppointmentData> patientsData = [];

      for (var appointmentDoc in appointmentsQuery.docs) {
        final appointmentData = appointmentDoc.data();
        final patientName = appointmentData['patientName'] as String?;
        final userId = appointmentData['userId'] as String?;

        if (patientName == null) {
          debugPrint('No patientName found for appointment: ${appointmentDoc.id}');
          continue;
        }

        try {
          debugPrint('Processing patient: $patientName');

          // Get patient's latest assessment - try multiple collection names
          QuerySnapshot assessmentsQuery;

          // Try assessments collection first
          if (userId != null) {
            assessmentsQuery = await _firestore
                .collection('assessments')
                .where('userId', isEqualTo: userId)
                .orderBy('timestamp', descending: true)
                .limit(1)
                .get();
          } else {
            // Fallback: try to find by patient name
            assessmentsQuery = await _firestore
                .collection('assessments')
                .where('patientName', isEqualTo: patientName)
                .orderBy('timestamp', descending: true)
                .limit(1)
                .get();
          }

          List<RecommendationData> recommendations = [];

          if (assessmentsQuery.docs.isNotEmpty) {
            final latestAssessment = assessmentsQuery.docs.first;
            final latestAssessmentData = latestAssessment.data() as Map<String, dynamic>;
            final assessmentTimestamp = (latestAssessmentData['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();

            debugPrint('Found assessment for $patientName: ${latestAssessmentData.keys}');

            // Extract scores and generate recommendations
            final depressionScore = _extractScore(latestAssessmentData, 'depression');
            final anxietyScore = _extractScore(latestAssessmentData, 'anxiety');
            final stressScore = _extractScore(latestAssessmentData, 'stress');

            if (depressionScore != null) {
              recommendations.add(_generateRecommendation('Depression', depressionScore, assessmentTimestamp));
            }
            if (anxietyScore != null) {
              recommendations.add(_generateRecommendation('Anxiety', anxietyScore, assessmentTimestamp));
            }
            if (stressScore != null) {
              recommendations.add(_generateRecommendation('Stress', stressScore, assessmentTimestamp));
            }
          }

          // Also get any existing custom recommendations
          if (userId != null) {
            final customRecsQuery = await _firestore
                .collection('recommendations')
                .where('userId', isEqualTo: userId)
                .orderBy('createdAt', descending: true)
                .get();

            for (var recDoc in customRecsQuery.docs) {
              final recData = recDoc.data() as Map<String, dynamic>;
              recommendations.add(RecommendationData(
                category: recData['category'] ?? 'General',
                recommendation: recData['recommendation'] ?? 'No recommendation provided',
                risk: recData['riskLevel'] ?? 'Custom',
                score: (recData['score'] as int?) ?? 0,
                timestamp: (recData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
                isCustom: true,
              ));
            }
          }

          // If no assessments found, still show the patient but with a general recommendation
          if (recommendations.isEmpty) {
            recommendations.add(RecommendationData(
              category: 'General',
              recommendation: 'Patient has completed an appointment. Consider scheduling a follow-up assessment.',
              risk: 'No Assessment',
              score: 0,
              timestamp: DateTime.now(),
              isCustom: false,
            ));
          }

          patientsData.add(PatientAppointmentData(
            appointmentId: appointmentDoc.id,
            patientName: patientName,
            patientEmail: appointmentData['email'] ?? 'No email provided',
            appointmentDateTime: _parseAppointmentDate(appointmentData['requestedDateTime']),
            appointmentStatus: appointmentData['status'] ?? 'scheduled',
            reasonForVisit: appointmentData['reasonForVisit'] ?? appointmentData['reason'] ?? 'General Consultation',
            appointmentType: appointmentData['appointmentType'] ?? 'consultation',
            userId: userId ?? 'unknown',
            recommendations: recommendations,
          ));

          debugPrint('Added patient $patientName with ${recommendations.length} recommendations');

        } catch (e) {
          debugPrint('Error processing patient $patientName: $e');
          // Add patient even if there's an error, but with a basic recommendation
          patientsData.add(PatientAppointmentData(
            appointmentId: appointmentDoc.id,
            patientName: patientName,
            patientEmail: appointmentData['email'] ?? 'No email provided',
            appointmentDateTime: _parseAppointmentDate(appointmentData['requestedDateTime']),
            appointmentStatus: appointmentData['status'] ?? 'scheduled',
            reasonForVisit: appointmentData['reasonForVisit'] ?? appointmentData['reason'] ?? 'General Consultation',
            appointmentType: appointmentData['appointmentType'] ?? 'consultation',
            userId: userId ?? 'unknown',
            recommendations: [
              RecommendationData(
                category: 'General',
                recommendation: 'Error loading assessment data. Please check patient records manually.',
                risk: 'Unknown',
                score: 0,
                timestamp: DateTime.now(),
                isCustom: false,
              )
            ],
          ));
        }
      }

      // Sort by appointment date
      patientsData.sort((a, b) => b.appointmentDateTime.compareTo(a.appointmentDateTime));

      setState(() {
        _patientsWithRecommendations = patientsData;
        _isLoading = false;
      });

      debugPrint('Successfully loaded ${patientsData.length} patients with recommendations');

    } catch (e) {
      debugPrint('Error loading patient recommendations: $e');
      setState(() {
        _errorMessage = 'Error loading patient recommendations: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  int? _extractScore(Map<String, dynamic> assessmentData, String category) {
    // Try different field name patterns
    final possibleFields = [
      '${category}Score',
      '${category}_score',
      category,
      '${category}Value',
      '${category}_value'
    ];

    for (var field in possibleFields) {
      final value = assessmentData[field];
      if (value != null) {
        if (value is int) return value;
        if (value is double) return value.toInt();
        if (value is String) return int.tryParse(value);
      }
    }

    // Try nested structure
    if (assessmentData[category] is Map<String, dynamic>) {
      final categoryData = assessmentData[category] as Map<String, dynamic>;
      final score = categoryData['score'];
      if (score != null) {
        if (score is int) return score;
        if (score is double) return score.toInt();
        if (score is String) return int.tryParse(score);
      }
    }

    return null;
  }

  DateTime _parseAppointmentDate(dynamic dateTime) {
    try {
      if (dateTime is Timestamp) {
        return dateTime.toDate();
      } else if (dateTime is DateTime) {
        return dateTime;
      } else if (dateTime is String) {
        return DateTime.tryParse(dateTime) ?? DateTime.now();
      }
      return DateTime.now();
    } catch (e) {
      debugPrint('Error parsing appointment date: $e');
      return DateTime.now();
    }
  }

  RecommendationData _generateRecommendation(String category, int score, DateTime timestamp) {
    String risk;
    String recommendation;

    if (score <= 10) {
      risk = 'Low';
      recommendation = 'Patient shows normal $category levels. Continue with regular monitoring and maintain healthy lifestyle habits.';
    } else if (score <= 20) {
      risk = 'Moderate';
      recommendation = 'Patient shows moderate $category symptoms. Consider regular follow-ups, basic coping strategies, and lifestyle adjustments.';
    } else {
      risk = 'High';
      recommendation = 'Patient shows significant $category symptoms. Recommend professional intervention, close monitoring, and possible referral to specialist.';
    }

    return RecommendationData(
      category: category,
      recommendation: recommendation,
      risk: risk,
      score: score,
      timestamp: timestamp,
    );
  }

  List<PatientAppointmentData> get _filteredPatients {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    switch (_selectedTabIndex) {
      case 0: // Today
        return _patientsWithRecommendations.where((patient) {
          final appointmentDate = DateTime(
            patient.appointmentDateTime.year,
            patient.appointmentDateTime.month,
            patient.appointmentDateTime.day,
          );
          return appointmentDate == today;
        }).toList();

      case 1: // Upcoming
        return _patientsWithRecommendations.where((patient) {
          return patient.appointmentDateTime.isAfter(now);
        }).toList();

      case 2: // All
      default:
        return _patientsWithRecommendations;
    }
  }

  // UI Methods that were missing
  Widget _buildTabSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(child: _buildTab('Today', Icons.today_outlined, 0)),
          Expanded(child: _buildTab('Upcoming', Icons.schedule_outlined, 1)),
          Expanded(child: _buildTab('All', Icons.list_outlined, 2)),
        ],
      ),
    );
  }

  Widget _buildTab(String title, IconData icon, int index) {
    bool isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTabIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? doctorBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : doctorGray,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : doctorGray,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientCard(PatientAppointmentData patient) {
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Patient Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: doctorBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.person_outlined,
                    color: doctorBlue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.patientName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: doctorBlue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateFormat.format(patient.appointmentDateTime),
                        style: TextStyle(
                          fontSize: 14,
                          color: doctorGray,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(patient.appointmentStatus).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getStatusColor(patient.appointmentStatus).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    patient.appointmentStatus.toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(patient.appointmentStatus),
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Appointment Details
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: lightGray,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: doctorGray.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.medical_information_outlined, size: 16, color: doctorGray),
                      const SizedBox(width: 8),
                      Text(
                        'Appointment Details',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: doctorBlue,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow('Type', patient.appointmentType),
                  const SizedBox(height: 8),
                  _buildDetailRow('Reason', patient.reasonForVisit),
                  const SizedBox(height: 8),
                  _buildDetailRow('Email', patient.patientEmail),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Recommendations
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: infoBlue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: infoBlue.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.psychology_outlined, color: infoBlue, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Recommendations',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: infoBlue,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Based on assessment scores and doctor notes',
                    style: TextStyle(
                      fontSize: 12,
                      color: doctorGray,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...patient.recommendations.map((rec) => _buildRecommendationItem(rec)),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _createDoctorRecommendation(patient),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add Recommendation'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: doctorTeal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _viewFullAssessment(patient),
                    icon: Icon(Icons.visibility_outlined, size: 18, color: doctorBlue),
                    label: Text('View Details', style: TextStyle(color: doctorBlue)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: doctorBlue),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: doctorGray,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: doctorBlue,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendationItem(RecommendationData recommendation) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getCategoryColor(recommendation.category).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getCategoryIcon(recommendation.category),
                size: 16,
                color: _getCategoryColor(recommendation.category),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  recommendation.category,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _getCategoryColor(recommendation.category),
                    fontSize: 14,
                  ),
                ),
              ),
              if (recommendation.isCustom)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: successGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Custom',
                    style: TextStyle(
                      fontSize: 10,
                      color: successGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getRiskColor(recommendation.risk).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${recommendation.score}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _getRiskColor(recommendation.risk),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      recommendation.risk,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _getRiskColor(recommendation.risk),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            recommendation.recommendation,
            style: TextStyle(
              color: doctorBlue,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Generated: ${DateFormat('MMM dd, yyyy').format(recommendation.timestamp)}',
            style: TextStyle(
              fontSize: 10,
              color: doctorGray,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return successGreen;
      case 'confirmed':
      case 'accepted':
        return infoBlue;
      case 'scheduled':
        return doctorBlue;
      case 'ongoing':
        return warningOrange;
      case 'pending':
        return warningOrange;
      case 'cancelled':
        return errorRed;
      default:
        return doctorGray;
    }
  }

  Color _getRiskColor(String risk) {
    switch (risk.toLowerCase()) {
      case 'low': return successGreen;
      case 'moderate': return warningOrange;
      case 'high': return errorRed;
      default: return doctorGray;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'depression': return Icons.sentiment_very_dissatisfied_outlined;
      case 'anxiety': return Icons.psychology_outlined;
      case 'stress': return Icons.whatshot_outlined;
      default: return Icons.medical_information_outlined;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'depression': return errorRed;
      case 'anxiety': return warningOrange;
      case 'stress': return doctorTeal;
      default: return doctorGray;
    }
  }

  Future<void> _createDoctorRecommendation(PatientAppointmentData patient) async {
    final TextEditingController _noteController = TextEditingController();
    String _selectedCategory = 'General';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Add Recommendation for ${patient.patientName}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    items: ['General', 'Depression', 'Anxiety', 'Stress', 'Lifestyle', 'Medication']
                        .map((category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ))
                        .toList(),
                    onChanged: (value) => setState(() => _selectedCategory = value!),
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _noteController,
                    decoration: const InputDecoration(
                      labelText: 'Enter your recommendation',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 5,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (_noteController.text.trim().isNotEmpty) {
                    try {
                      await _firestore
                          .collection('recommendations')
                          .add({
                        'userId': patient.userId,
                        'doctorId': _currentUser!.uid,
                        'doctorName': _currentUser!.displayName ?? _currentUser!.email,
                        'patientName': patient.patientName,
                        'category': _selectedCategory,
                        'recommendation': _noteController.text.trim(),
                        'riskLevel': 'Custom',
                        'score': 0,
                        'createdAt': Timestamp.now(),
                        'appointmentId': patient.appointmentId,
                      });

                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Recommendation added successfully')),
                      );

                      // Reload to show the new recommendation
                      _loadPatientRecommendations();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error adding recommendation: $e')),
                      );
                    }
                  }
                },
                child: const Text('Save Recommendation'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _viewFullAssessment(PatientAppointmentData patient) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Patient Details - ${patient.patientName}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Appointment: ${DateFormat('MMM dd, yyyy hh:mm a').format(patient.appointmentDateTime)}'),
              Text('Status: ${patient.appointmentStatus}'),
              Text('Type: ${patient.appointmentType}'),
              const SizedBox(height: 16),
              Text('Total Recommendations: ${patient.recommendations.length}'),
              const SizedBox(height: 8),
              Text('Patient ID: ${patient.userId}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    String description;
    IconData icon;

    switch (_selectedTabIndex) {
      case 0:
        message = 'No Patients Today';
        description = 'No appointments scheduled for today. Check upcoming appointments or all patients.';
        icon = Icons.today_outlined;
        break;
      case 1:
        message = 'No Upcoming Appointments';
        description = 'No future appointments found. All appointments may be in the past or today.';
        icon = Icons.schedule_outlined;
        break;
      case 2:
      default:
        message = 'No Patients Found';
        description = 'No patients with appointments found. Please check if appointments exist in the system.';
        icon = Icons.people_outline;
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: doctorBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              icon,
              size: 64,
              color: doctorBlue,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: doctorBlue,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              color: doctorGray,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Column(
            children: [
              ElevatedButton(
                onPressed: _loadPatientRecommendations,
                style: ElevatedButton.styleFrom(
                  backgroundColor: doctorBlue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Refresh Data'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  debugPrint('Current doctor: ${_currentUser?.displayName ?? _currentUser?.email}');
                  debugPrint('Total patients found: ${_patientsWithRecommendations.length}');
                  debugPrint('Filtered patients: ${_filteredPatients.length}');
                  _showDebugInfo();
                },
                child: Text(
                  'Show Debug Info',
                  style: TextStyle(color: doctorBlue),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDebugInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Debug Information'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Doctor: ${_currentUser?.displayName ?? _currentUser?.email}'),
              Text('Doctor UID: ${_currentUser?.uid}'),
              Text('Total Patients: ${_patientsWithRecommendations.length}'),
              Text('Filtered Patients: ${_filteredPatients.length}'),
              Text('Selected Tab: $_selectedTabIndex'),
              const SizedBox(height: 16),
              const Text('Patient List:', style: TextStyle(fontWeight: FontWeight.bold)),
              ..._patientsWithRecommendations.take(5).map((patient) =>
                  Text('- ${patient.patientName} (${DateFormat('MMM dd').format(patient.appointmentDateTime)})')
              ),
              if (_patientsWithRecommendations.length > 5)
                Text('... and ${_patientsWithRecommendations.length - 5} more'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGray,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.psychology_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Patient Recommendations',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: doctorBlue,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [doctorBlue, lightDoctorBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.refresh_rounded, color: Colors.white),
            ),
            onPressed: _loadPatientRecommendations,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: doctorBlue),
            const SizedBox(height: 16),
            Text(
              'Loading patient recommendations...',
              style: TextStyle(color: doctorGray),
            ),
          ],
        ),
      )
          : _errorMessage != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: errorRed),
            const SizedBox(height: 16),
            Text(
              'Error Loading Data',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: doctorBlue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: TextStyle(color: doctorGray),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadPatientRecommendations,
              style: ElevatedButton.styleFrom(
                backgroundColor: doctorBlue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      )
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildTabSelector(),
          ),
          Expanded(
            child: _filteredPatients.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              onRefresh: _loadPatientRecommendations,
              color: doctorBlue,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filteredPatients.length,
                itemBuilder: (context, index) {
                  return _buildPatientCard(_filteredPatients[index]);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Data Models
class PatientAppointmentData {
  final String appointmentId;
  final String patientName;
  final String patientEmail;
  final DateTime appointmentDateTime;
  final String appointmentStatus;
  final String reasonForVisit;
  final String appointmentType;
  final String userId;
  final List<RecommendationData> recommendations;

  PatientAppointmentData({
    required this.appointmentId,
    required this.patientName,
    required this.patientEmail,
    required this.appointmentDateTime,
    required this.appointmentStatus,
    required this.reasonForVisit,
    required this.appointmentType,
    required this.userId,
    required this.recommendations,
  });
}

class RecommendationData {
  final String category;
  final String recommendation;
  final String risk;
  final int score;
  final DateTime timestamp;
  final bool isCustom;

  RecommendationData({
    required this.category,
    required this.recommendation,
    required this.risk,
    required this.score,
    required this.timestamp,
    this.isCustom = false,
  });
}