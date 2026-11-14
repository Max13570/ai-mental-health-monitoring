import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:intl/intl.dart';
import 'patient_dashboard_widgets.dart';

import 'assessment_screen.dart' as assessment;
import 'consultation_screen.dart' as consultation;
import '../Patient/patient_reports_screen.dart' as reports;
import '../login_screen.dart' as auth;
import 'appointment_booking_screen.dart';

class PatientDashboardScreen extends StatefulWidget {
  const PatientDashboardScreen({super.key});

  @override
  PatientDashboardScreenState createState() => PatientDashboardScreenState();
}

class PatientDashboardScreenState extends State<PatientDashboardScreen> {
  static const Color patientBlue = Color(0xFF1565C0);
  static const Color patientTeal = Color(0xFF00838F);
  static const Color patientGreen = Color(0xFF2E7D32);
  static const Color lightPatientBlue = Color(0xFF42A5F5);
  static const Color patientGray = Color(0xFF546E7A);
  static const Color lightGray = Color(0xFFF5F7FA);
  static const Color successGreen = Color(0xFF43A047);
  static const Color warningOrange = Color(0xFFFF9800);
  static const Color errorRed = Color(0xFFE53935);
  static const Color softPurple = Color(0xFF7E57C2);

  static const double _padding = 16.0;
  static const double _cardRadius = 12.0;
  static const double _spacing = 16.0;

  final Logger _logger = Logger();
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  late final String _userId = _currentUser?.uid ?? 'anonymous';
  int _selectedIndex = 0;
  int _unreadNotifications = 0;
  bool _isLoading = true;
  bool _isSubmittingMood = false;

  late final List<Map<String, dynamic>> _navigationItems;

  String get _patientName {
    if (_currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const auth.LoginScreen(role: 'patient')),
          );
        }
      });
      return 'Guest';
    }
    return _currentUser!.displayName ?? 'Patient';
  }

  DateTime? _lastLogin;
  String? _selectedMood;
  final TextEditingController _moodNoteController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _stressData = [];
  List<Map<String, dynamic>> _anxietyData = [];
  List<Map<String, dynamic>> _depressionData = [];
  List<Map<String, dynamic>> _upcomingAppointments = [];

  @override
  void initState() {
    super.initState();
    _logger.i('Initializing PatientDashboardScreen with userId: $_userId');
    _initializeNavigationItems();
    _fetchData();
    if (_userId != 'anonymous') {
      _listenToNotifications();
      _listenToAppointments();
    }
  }

  Future<void> _fetchData() async {
    _logger.i('Starting data fetch for userId: $_userId');
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _fetchLastLogin(),
        _fetchHealthMetrics(),
        _fetchAppointments(),
      ]);
      _logger.i('Data fetch completed successfully');
    } catch (e) {
      _logger.e('Error fetching dashboard data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: ${e.toString()}'),
            backgroundColor: errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
      _logger.i('Loading state set to false');
    }
  }

  void _initializeNavigationItems() {
    _navigationItems = [
      {'icon': Icons.dashboard_rounded, 'title': 'Overview', 'isSelected': true},
      {'icon': Icons.quiz_rounded, 'title': 'Assessment', 'isSelected': false},
      {'icon': Icons.calendar_today_rounded, 'title': 'Booking', 'isSelected': false},
      {'icon': Icons.video_call_rounded, 'title': 'Consultation', 'isSelected': false},
      {'icon': Icons.assessment_rounded, 'title': 'Reports', 'isSelected': false},
    ];
  }

  @override
  void dispose() {
    _moodNoteController.dispose();
    super.dispose();
  }

  Future<void> _fetchLastLogin() async {
    _logger.i('Fetching last login for userId: $_userId');
    try {
      final doc = await _firestore.collection('users').doc(_userId).get();
      if (doc.exists && doc.data()?['lastLogin'] != null) {
        if (mounted) {
          setState(() {
            _lastLogin = (doc.data()!['lastLogin'] as Timestamp).toDate();
            _logger.i('Last login fetched: $_lastLogin');
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _lastLogin = DateTime.now();
            _logger.i('No last login found, using current time: $_lastLogin');
          });
        }
      }
    } catch (e) {
      _logger.e('Error fetching last login: $e');
      if (mounted) {
        setState(() {
          _lastLogin = DateTime.now();
        });
      }
    }
  }

  Future<void> _fetchHealthMetrics() async {
    _logger.i('Fetching health metrics for userId: $_userId');
    try {
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));

      // Fetch assessments from the last 7 days (matching reports screen structure)
      final metricsSnapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('assessments')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(weekAgo))
          .orderBy('timestamp', descending: false)
          .get();

      if (metricsSnapshot.docs.isEmpty) {
        _logger.w('No health metrics found for userId: $_userId in the last 7 days');
        if (mounted) {
          setState(() {
            _stressData = [{'date': now, 'value': 0.0}];
            _anxietyData = [{'date': now, 'value': 0.0}];
            _depressionData = [{'date': now, 'value': 0.0}];
          });
        }
        return;
      }

      final metrics = metricsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'timestamp': (data['timestamp'] as Timestamp).toDate(),
          'stress': (data['stress']?['score'] as num?)?.toDouble() ?? 0.0,
          'anxiety': (data['anxiety']?['score'] as num?)?.toDouble() ?? 0.0,
          'depression': (data['depression']?['score'] as num?)?.toDouble() ?? 0.0,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _stressData = metrics.map((m) => {'date': m['timestamp'], 'value': m['stress']}).toList();
          _anxietyData = metrics.map((m) => {'date': m['timestamp'], 'value': m['anxiety']}).toList();
          _depressionData = metrics.map((m) => {'date': m['timestamp'], 'value': m['depression']}).toList();
          _logger.i('Health metrics fetched: ${_stressData.length} records');
        });
      }
    } catch (e) {
      _logger.e('Error fetching health metrics: $e');
      if (mounted) {
        setState(() {
          _stressData = [{'date': DateTime.now(), 'value': 0.0}];
          _anxietyData = [{'date': DateTime.now(), 'value': 0.0}];
          _depressionData = [{'date': DateTime.now(), 'value': 0.0}];
        });
      }
    }
  }

  Future<void> _fetchAppointments() async {
    _logger.i('Fetching appointments for userId: $_userId');
    try {
      final now = DateTime.now();
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('appointments')
          .where('requestedDateTime', isGreaterThanOrEqualTo: now)
          .orderBy('requestedDateTime')
          .limit(2)
          .get();

      if (mounted) {
        setState(() {
          _upcomingAppointments = snapshot.docs.map((doc) {
            final data = doc.data();
            final dateTime = (data['requestedDateTime'] as Timestamp).toDate();
            return {
              'id': doc.id,
              'dateTime': dateTime,
              'doctor': data['doctor'] ?? 'Unknown Doctor',
              'specialty': data['specialty'] ?? 'General',
              'status': data['status'] ?? 'scheduled',
            };
          }).toList();
          _logger.i('Fetched ${snapshot.docs.length} upcoming appointments');
        });
      }
    } catch (e) {
      _logger.e('Error fetching appointments: $e');
      if (mounted) {
        setState(() {
          _upcomingAppointments = [];
        });
      }
    }
  }

  void _listenToNotifications() {
    if (_userId == 'anonymous') return;
    _logger.i('Starting notification listener for userId: $_userId');

    _firestore
        .collection('users')
        .doc(_userId)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .listen(
          (snapshot) {
        if (mounted) {
          setState(() {
            _unreadNotifications = snapshot.docs.length;
            _logger.i('Updated unread notifications count: $_unreadNotifications');
          });
        }
      },
      onError: (e) => _logger.e('Notification listener error: $e'),
      onDone: () => _logger.i('Notification listener completed'),
      cancelOnError: true,
    );
  }

  void _listenToAppointments() {
    if (_userId == 'anonymous') return;
    _logger.i('Starting appointments listener for userId: $_userId');

    _firestore
        .collection('users')
        .doc(_userId)
        .collection('appointments')
        .where('requestedDateTime', isGreaterThanOrEqualTo: DateTime.now())
        .snapshots()
        .listen(
          (snapshot) {
        if (mounted) {
          setState(() {
            _upcomingAppointments = snapshot.docs.map((doc) {
              final data = doc.data();
              final dateTime = (data['requestedDateTime'] as Timestamp).toDate();
              return {
                'id': doc.id,
                'dateTime': dateTime,
                'doctor': data['doctor'] ?? 'Unknown Doctor',
                'specialty': data['specialty'] ?? 'General',
                'status': data['status'] ?? 'scheduled',
              };
            }).toList();
            _logger.i('Updated appointments count: ${snapshot.docs.length}');
          });
        }
      },
      onError: (e) => _logger.e('Appointments listener error: $e'),
      onDone: () => _logger.i('Appointments listener completed'),
      cancelOnError: true,
    );
  }

  void _showNotificationsDialog() {
    if (!mounted) return;
    _logger.i('Showing notifications dialog');
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: patientBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.notifications_rounded, color: patientBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Notifications',
                style: TextStyle(
                  color: patientBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('users')
                  .doc(_userId)
                  .collection('notifications')
                  .orderBy('timestamp', descending: true)
                  .limit(20)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: patientBlue));
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Failed to load notifications'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_none_rounded, size: 48, color: patientGray),
                        const SizedBox(height: 16),
                        Text('No notifications yet', style: TextStyle(color: patientGray)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final notificationDoc = snapshot.data!.docs[index];
                    final notification = notificationDoc.data() as Map<String, dynamic>;
                    final isRead = notification['read'] ?? false;
                    final timestamp = notification['timestamp'] as Timestamp?;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isRead ? lightGray : patientBlue.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isRead ? Colors.transparent : patientBlue.withOpacity(0.2),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isRead ? patientGray.withOpacity(0.1) : patientBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            notification['type'] == 'consultation'
                                ? Icons.video_call_rounded
                                : notification['type'] == 'appointment_accepted'
                                ? Icons.check_circle_rounded
                                : notification['type'] == 'appointment_rejected'
                                ? Icons.cancel_rounded
                                : Icons.calendar_today_rounded,
                            color: isRead ? patientGray : patientBlue,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          notification['title'] ?? 'Notification',
                          style: TextStyle(
                            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                            color: patientBlue,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notification['message'] ?? '',
                              style: TextStyle(color: patientGray),
                            ),
                            if (timestamp != null)
                              Text(
                                DateFormat('MMM dd, yyyy at HH:mm').format(timestamp.toDate()),
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                          ],
                        ),
                        isThreeLine: true,
                        onTap: () {
                          if (!isRead) {
                            notificationDoc.reference
                                .update({'read': true})
                                .catchError((e) => _logger.e('Error updating notification read status: $e'));
                            if (mounted) {
                              setState(() {
                                _unreadNotifications = (_unreadNotifications - 1).clamp(0, 999);
                              });
                            }
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _firestore
                    .collection('users')
                    .doc(_userId)
                    .collection('notifications')
                    .where('read', isEqualTo: false)
                    .get()
                    .then((snapshot) {
                  for (var doc in snapshot.docs) {
                    doc.reference.update({'read': true}).catchError((e) => _logger.e('Error marking notification as read: $e'));
                  }
                  if (mounted) {
                    setState(() {
                      _unreadNotifications = 0;
                    });
                  }
                }).catchError((e) => _logger.e('Error fetching unread notifications: $e'));
              },
              child: Text('Mark All Read', style: TextStyle(color: lightPatientBlue)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: patientBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                minimumSize: const Size(100, 48),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _navigateToScreen(BuildContext context, Widget screen) {
    if (!mounted) return;
    _logger.i('Navigating to screen: $screen');
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  void _handleNavigation(int index) {
    if (!mounted) return;
    _logger.i('Handling navigation to index: $index');
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        break;
      case 1:
        _navigateToScreen(context, const assessment.MentalHealthAssessmentScreen());
        break;
      case 2:
        _navigateToScreen(context, const AppointmentBookingScreen());
        break;
      case 3:
      // Fixed: Remove roomName parameter from ConsultationScreen constructor
        _navigateToScreen(context, const consultation.ConsultationScreen());
        break;
      case 4:
        _navigateToScreen(context, const reports.MentalHealthReportScreen());
        break;
    }
  }

  void _showEmergencyDialog(BuildContext context) {
    if (!mounted) return;
    _logger.i('Showing emergency dialog');
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: errorRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.warning_amber_rounded, color: errorRed, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Emergency Support',
                style: TextStyle(
                  color: patientBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: errorRed.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: errorRed.withOpacity(0.2)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "If you're experiencing a mental health emergency:",
                  style: TextStyle(fontWeight: FontWeight.w600, color: patientBlue),
                ),
                const SizedBox(height: 12),
                _buildEmergencyItem('Call 988 (Suicide & Crisis Lifeline)', Icons.phone_rounded),
                _buildEmergencyItem('Call 911 for immediate danger', Icons.emergency_rounded),
                _buildEmergencyItem('Go to your nearest emergency room', Icons.local_hospital_rounded),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: lightPatientBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Your therapist has been notified of this alert.',
                    style: TextStyle(
                      fontSize: 12,
                      color: patientBlue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: patientBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmergencyItem(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: errorRed),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: patientGray),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    if (!mounted) return;
    _logger.i('Showing logout confirmation');
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: errorRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.logout_rounded, color: errorRed, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Logout',
                style: TextStyle(
                  color: patientBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to logout?',
            style: TextStyle(color: patientGray),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: patientGray)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: errorRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                minimumSize: const Size(100, 48),
              ),
              onPressed: () async {
                try {
                  await FirebaseAuth.instance.signOut();
                  if (mounted) {
                    _logger.i('Logout successful, navigating to login screen');
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const auth.LoginScreen(role: 'patient')),
                          (route) => false,
                    );
                  }
                } catch (e) {
                  _logger.e('Error during logout: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Logout failed: ${e.toString()}'),
                        backgroundColor: errorRed,
                      ),
                    );
                  }
                }
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [patientBlue, lightPatientBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.health_and_safety_rounded,
                    color: patientBlue,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'WellCare Portal',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: ListView.builder(
                itemCount: _navigationItems.length,
                itemBuilder: (context, index) {
                  final item = _navigationItems[index];
                  final isSelected = _selectedIndex == index;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? lightPatientBlue.withOpacity(0.1) : null,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected ? Border.all(color: lightPatientBlue.withOpacity(0.3)) : null,
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected ? lightPatientBlue.withOpacity(0.2) : patientGray.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          item['icon'] as IconData,
                          color: isSelected ? lightPatientBlue : patientGray,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        item['title'] as String,
                        style: TextStyle(
                          color: isSelected ? patientBlue : patientGray,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      onTap: () => _handleNavigation(index),
                    ),
                  );
                },
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: errorRed.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: errorRed.withOpacity(0.2)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: errorRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.logout_rounded,
                    color: errorRed,
                    size: 20,
                  ),
                ),
                title: Text(
                  'Logout',
                  style: TextStyle(
                    color: errorRed,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                onTap: () => _showLogoutConfirmation(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthMetricCard(BuildContext context, String title, double? value, Color color) {
    return PatientDashboardWidgets.buildHealthMetricCard(context, title, value, color);
  }

  Widget _buildTrendChart(BuildContext context) {
    return PatientDashboardWidgets.buildTrendChart(
      context,
      _stressData,
      _anxietyData,
      _depressionData,
      _isLoading,
    );
  }

  Widget _buildMoodTrackingCard(BuildContext context) {
    return PatientDashboardWidgets.buildMoodTrackingCard(
      context,
      _selectedMood,
      _moodNoteController,
      _isSubmittingMood,
          (String? mood) {
        if (mounted) setState(() => _selectedMood = mood);
      },
          () async {
        if (!mounted || _selectedMood == null || _isSubmittingMood) return;
        setState(() => _isSubmittingMood = true);
        try {
          await _firestore
              .collection('users')
              .doc(_userId)
              .collection('moods')
              .add({
            'mood': _selectedMood,
            'note': _moodNoteController.text.trim(),
            'timestamp': FieldValue.serverTimestamp(),
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Mood recorded successfully'),
                backgroundColor: successGreen,
              ),
            );
            setState(() {
              _selectedMood = null;
              _moodNoteController.clear();
            });
          }
        } catch (e) {
          _logger.e('Error saving mood: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error saving mood: ${e.toString()}'),
                backgroundColor: errorRed,
              ),
            );
          }
        } finally {
          if (mounted) setState(() => _isSubmittingMood = false);
        }
      },
    );
  }

  Widget _buildAppointmentCard(BuildContext context, Map<String, dynamic> appointment) {
    return PatientDashboardWidgets.buildAppointmentCard(
      context,
      appointment,
          () {
        if (mounted) {
          // Fixed: No longer passing roomName parameter
          _navigateToScreen(context, const consultation.ConsultationScreen());
        }
      },
    );
  }

  Widget _buildMainContent(BuildContext context) {
    _logger.i('Building main content, isLoading: $_isLoading, userId: $_userId');
    if (_isLoading) {
      return const Expanded(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Fallback UI if data is empty
    if (_lastLogin == null && _stressData.isEmpty && _anxietyData.isEmpty &&
        _depressionData.isEmpty && _upcomingAppointments.isEmpty) {
      return const Expanded(
        child: Center(
          child: Text('No data available. Please check your Firestore setup or authentication.'),
        ),
      );
    }

    return Expanded(
      child: Container(
        color: lightGray,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [patientBlue, patientTeal],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: patientBlue.withOpacity(0.3),
                      spreadRadius: 1,
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(50),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        backgroundColor: Colors.white,
                        radius: 35,
                        child: Text(
                          _patientName.isNotEmpty ? _patientName.substring(0, 1) : '?',
                          style: TextStyle(
                            color: patientBlue,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back!',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _patientName,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Last login: ${_lastLogin != null ? DateFormat('yyyy-MM-dd HH:mm').format(_lastLogin!) : 'Not available'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.notifications_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                            onPressed: _showNotificationsDialog,
                          ),
                        ),
                        if (_unreadNotifications > 0)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: warningOrange,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    spreadRadius: 1,
                                    blurRadius: 3,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 18,
                                minHeight: 18,
                              ),
                              child: Text(
                                _unreadNotifications > 99 ? '99+' : _unreadNotifications.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: _buildHealthMetricCard(
                      context,
                      'Stress',
                      _stressData.isNotEmpty ? _stressData.last['value'] : 0.0,
                      errorRed,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildHealthMetricCard(
                      context,
                      'Anxiety',
                      _anxietyData.isNotEmpty ? _anxietyData.last['value'] : 0.0,
                      warningOrange,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildHealthMetricCard(
                      context,
                      'Depression',
                      _depressionData.isNotEmpty ? _depressionData.last['value'] : 0.0,
                      patientBlue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTrendChart(context),
                        const SizedBox(height: 24),
                        _buildMoodTrackingCard(context),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  SizedBox(
                    width: 350,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Upcoming Appointments',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: patientGray,
                              ),
                            ),
                            TextButton(
                              onPressed: () => _handleNavigation(4),
                              child: Text(
                                'View All',
                                style: TextStyle(color: lightPatientBlue),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_upcomingAppointments.isEmpty)
                          const Text('No upcoming appointments'),
                        ..._upcomingAppointments.map((appt) => _buildAppointmentCard(context, appt)),
                        const SizedBox(height: 24),
                        PatientDashboardWidgets.buildEmergencySupportCard(
                          context,
                              () => _showEmergencyDialog(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _logger.i('Building PatientDashboardScreen');
    return Scaffold(
      backgroundColor: lightGray,
      body: Row(
        children: [
          _buildSidebar(context),
          _buildMainContent(context),
        ],
      ),
    );
  }
}