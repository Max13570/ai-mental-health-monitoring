import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'doctor_consultation_screen.dart';
import 'doctor_appointments_screen.dart';
import 'doctor_patient_recommendations_screen.dart';
import '../login_screen.dart' as login_screen;
import '../role_constants.dart';

class DoctorDashboardScreen extends StatefulWidget {
  const DoctorDashboardScreen({super.key});

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> {
  // Professional Medical Color Scheme
  static const Color medicalBlue = Color(0xFF1E3A8A);
  static const Color medicalTeal = Color(0xFF0F766E);
  static const Color medicalGreen = Color(0xFF047857);
  static const Color lightMedicalBlue = Color(0xFF3B82F6);
  static const Color medicalGray = Color(0xFF64748B);
  static const Color lightGray = Color(0xFFF8FAFC);
  static const Color successGreen = Color(0xFF10B981);
  static const Color warningOrange = Color(0xFFF59E0B);
  static const Color errorRed = Color(0xFFEF4444);

  // Styling Constants
  static const double _padding = 16.0;
  static const double _cardRadius = 12.0;
  static const double _spacing = 16.0;

  // Dashboard Data
  int _totalAppointments = 0;
  int _appointmentsToday = 0;
  int _completedAppointments = 0;
  int _upcomingAppointmentsNext7Days = 0;
  bool _isLoading = true;
  String? _errorMessage;
  int _unreadNotifications = 0;
  int _selectedIndex = 0;
  List<Map<String, dynamic>> _upcomingAppointments = [];
  List<String> _chartDays = [];
  List<int> _chartAppointmentCounts = [];
  StreamSubscription? _appointmentsSubscription;
  StreamSubscription? _notificationsSubscription;
  String? _doctorName;
  Timer? _refreshTimer;

  // Navigation Items
  final List<Map<String, dynamic>> _navigationItems = [
    {'icon': Icons.dashboard_rounded, 'title': 'Overview', 'isSelected': true},
    {'icon': Icons.calendar_today_rounded, 'title': 'Appointments', 'isSelected': false},
    {'icon': Icons.medical_services_rounded, 'title': 'Recommendations', 'isSelected': false},
    {'icon': Icons.video_call_rounded, 'title': 'Consultations', 'isSelected': false},
  ];

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
  }

  @override
  void dispose() {
    _appointmentsSubscription?.cancel();
    _notificationsSubscription?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeDashboard() async {
    try {
      debugPrint('=== INITIALIZING DOCTOR DASHBOARD ===');
      await _loadDoctorInfo();
      await _loadCachedData();
      _subscribeToDashboardData();
      _listenToNotifications();
      _startPeriodicRefresh();
    } catch (e) {
      debugPrint('Error initializing dashboard: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to initialize dashboard: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (mounted) {
        debugPrint('Performing periodic refresh...');
        _subscribeToDashboardData();
      }
    });
  }

  Future<void> _loadDoctorInfo() async {
    try {
      debugPrint('Loading doctor information...');
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('No authenticated user found');
        return;
      }
      debugPrint('User ID: ${user.uid}');
      debugPrint('User email: ${user.email}');
      debugPrint('User display name: ${user.displayName}');
      String doctorName = 'Doctor';
      // Try multiple collections and fields to find doctor name
      DocumentSnapshot? doctorDoc;
      // First try the doctors collection
      try {
        debugPrint('Checking doctors collection...');
        doctorDoc = await FirebaseFirestore.instance
            .collection('doctors')
            .doc(user.uid)
            .get();
        debugPrint('Doctors collection result: exists=${doctorDoc.exists}');
        if (doctorDoc.exists) {
          debugPrint('Doctor document data: ${doctorDoc.data()}');
        }
      } catch (e) {
        debugPrint('Error accessing doctors collection: $e');
      }
      // If not found, try users collection
      if (doctorDoc == null || !doctorDoc.exists) {
        try {
          debugPrint('Checking users collection...');
          doctorDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          debugPrint('Users collection result: exists=${doctorDoc.exists}');
          if (doctorDoc.exists) {
            debugPrint('User document data: ${doctorDoc.data()}');
          }
        } catch (e) {
          debugPrint('Error accessing users collection: $e');
        }
      }
      // Try to get doctor name from document
      if (doctorDoc != null && doctorDoc.exists) {
        final data = doctorDoc.data() as Map<String, dynamic>?;
        final possibleNameFields = [
          'name', 'fullName', 'displayName', 'firstName', 'doctorName',
          'first_name', 'full_name', 'display_name'
        ];
        for (String field in possibleNameFields) {
          if (data?[field] != null && data![field].toString().isNotEmpty) {
            doctorName = data[field].toString();
            debugPrint('Found doctor name in field $field: $doctorName');
            break;
          }
        }
      }
      // Fallback to user info
      if (doctorName == 'Doctor') {
        doctorName = user.displayName ??
            user.email?.split('@')[0] ??
            'Dr. ${user.uid.substring(0, 8)}';
        debugPrint('Using fallback doctor name: $doctorName');
      }
      if (mounted) {
        setState(() {
          _doctorName = doctorName;
        });
      }
      debugPrint('Final doctor name set to: $_doctorName');
    } catch (e) {
      debugPrint('Error in _loadDoctorInfo: $e');
      final user = FirebaseAuth.instance.currentUser;
      if (mounted) {
        setState(() {
          _doctorName = user?.displayName ?? user?.email?.split('@')[0] ?? 'Doctor';
        });
      }
    }
  }

  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _totalAppointments = prefs.getInt('doctor_totalAppointments') ?? 0;
          _appointmentsToday = prefs.getInt('doctor_appointmentsToday') ?? 0;
          _upcomingAppointmentsNext7Days = prefs.getInt('doctor_upcomingAppointmentsNext7Days') ?? 0;
          _completedAppointments = prefs.getInt('doctor_completedAppointments') ?? 0;
        });
      }
      debugPrint('Cached data loaded: Total=$_totalAppointments, Today=$_appointmentsToday');
    } catch (e) {
      debugPrint('Failed to load cached data: $e');
    }
  }

  Future<void> _saveCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('doctor_totalAppointments', _totalAppointments);
      await prefs.setInt('doctor_appointmentsToday', _appointmentsToday);
      await prefs.setInt('doctor_upcomingAppointmentsNext7Days', _upcomingAppointmentsNext7Days);
      await prefs.setInt('doctor_completedAppointments', _completedAppointments);
      debugPrint('Cached data saved successfully');
    } catch (e) {
      debugPrint('Failed to save cached data: $e');
    }
  }

  void _listenToNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    debugPrint('Setting up notifications listener...');
    try {
      _notificationsSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          setState(() {
            _unreadNotifications = snapshot.docs.length;
          });
          debugPrint('Unread notifications: $_unreadNotifications');
        }
      }, onError: (e) {
        debugPrint('Notifications error: $e');
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to load notifications: $e';
          });
        }
      });
    } catch (e) {
      debugPrint('Error setting up notifications listener: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to set up notifications: $e';
        });
      }
    }
  }

  void _subscribeToDashboardData() {
    if (!mounted) return;
    debugPrint('=== SUBSCRIBING TO DASHBOARD DATA ===');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _doctorName == null) {
      if (mounted) {
        setState(() {
          _errorMessage = 'You must be logged in with a valid doctor profile to view data.';
          _isLoading = false;
        });
      }
      return;
    }
    debugPrint('Doctor name for filtering: $_doctorName');
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final endOfToday = startOfToday.add(const Duration(days: 1));
    final endOfNext7Days = startOfToday.add(const Duration(days: 7));
    final startOfPeriod = DateTime(now.year, now.month, now.day - 6);
    _appointmentsSubscription?.cancel();
    try {
      _appointmentsSubscription = FirebaseFirestore.instance
          .collection('all_appointment_requests')
          .snapshots()
          .listen((snapshot) {
        if (!mounted) return;
        try {
          debugPrint('Processing ${snapshot.docs.length} total documents...');
          // FIRST: Let's see if we can find any appointments with "Jessica" or "Dlamini" in any field
          final debugDocs = snapshot.docs.where((doc) {
            final data = doc.data();
            final allFields = data.toString().toLowerCase();
            return allFields.contains('jessica') || allFields.contains('dlamini');
          }).toList();
          debugPrint('Found ${debugDocs.length} appointments containing "jessica" or "dlamini"');
          for (var doc in debugDocs.take(3)) {
            debugPrint('Debug appointment: ${doc.data()}');
          }
          // Filter appointments for this doctor using multiple possible field names
          final doctorDocs = snapshot.docs.where((doc) {
            final data = doc.data();
            if (data.isEmpty) return false;
            // Check multiple possible doctor field names
            final possibleDoctorFields = [
              'selectedDoctor',
              'doctorName',
              'doctor',
              'assignedDoctor',
              'providerName',
              'physicianName',
              'doctorId',
              'providerId'
            ];
            for (String field in possibleDoctorFields) {
              final fieldValue = data[field]?.toString();
              if (fieldValue != null) {
                // Check exact match, contains match, or partial match
                if (fieldValue.toLowerCase() == _doctorName!.toLowerCase() ||
                    fieldValue.toLowerCase().contains(_doctorName!.toLowerCase()) ||
                    _doctorName!.toLowerCase().contains(fieldValue.toLowerCase())) {
                  debugPrint('Found match in field $field: $fieldValue for doctor $_doctorName');
                  return true;
                }
              }
            }
            debugPrint('No match found for appointment: ${data['patientName']} - Doctor fields checked: ${possibleDoctorFields.map((f) => '$f: ${data[f]}').join(', ')}');
            return false;
          }).toList();
          debugPrint('Found ${doctorDocs.length} appointments for doctor $_doctorName');
          // Log ALL doctor appointments regardless of status for debugging
          for (int i = 0; i < doctorDocs.length; i++) {
            final data = doctorDocs[i].data();
            final date = _parseAppointmentDate(data['requestedDateTime']);
            debugPrint('Doctor appointment $i: Patient=${data['patientName']}, Status=${data['status']}, Date=$date, Future=${date.isAfter(now)}');
          }
          // Filter for confirmed/accepted appointments
          final confirmedDocs = doctorDocs.where((doc) {
            final data = doc.data();
            final status = data['status']?.toString().toLowerCase();
            return status == 'accepted' || status == 'approved' || status == 'confirmed';
          }).toList();
          debugPrint('Found ${confirmedDocs.length} confirmed appointments');
          // Compute metrics
          final totalAppointments = confirmedDocs.length;
          final appointmentsToday = confirmedDocs.where((doc) {
            final data = doc.data();
            final date = _parseAppointmentDate(data['requestedDateTime']);
            return date.isAfter(startOfToday) && date.isBefore(endOfToday);
          }).length;
          final upcomingAppointmentsNext7Days = confirmedDocs.where((doc) {
            final data = doc.data();
            final date = _parseAppointmentDate(data['requestedDateTime']);
            return date.isAfter(now) && date.isBefore(endOfNext7Days);
          }).length;
          final completedAppointments = doctorDocs.where((doc) {
            final status = doc.data()['status']?.toString().toLowerCase();
            return status == 'completed' || status == 'finished';
          }).length;
          // Get upcoming appointments - be more inclusive with status filtering
          final allUpcomingAppointments = doctorDocs.where((doc) {
            final data = doc.data();
            final status = data['status']?.toString().toLowerCase();
            final date = _parseAppointmentDate(data['requestedDateTime']);
            debugPrint('Checking upcoming appointment: Patient=${data['patientName']}, Status=$status, Date=$date, Future=${date.isAfter(now)}');
            // Include ANY appointment that's not explicitly cancelled or completed
            final excludedStatuses = ['cancelled', 'completed', 'rejected', 'declined'];
            final isValidStatus = status == null || !excludedStatuses.contains(status);
            final isFutureDate = date.isAfter(now);
            debugPrint('Status valid: $isValidStatus, Future date: $isFutureDate');
            return isFutureDate && isValidStatus;
          }).toList();
          debugPrint('Found ${allUpcomingAppointments.length} upcoming appointments (all valid statuses)');
          // Sort by date
          allUpcomingAppointments.sort((a, b) {
            final aDate = _parseAppointmentDate(a.data()['requestedDateTime']);
            final bDate = _parseAppointmentDate(b.data()['requestedDateTime']);
            return aDate.compareTo(bDate);
          });
          final upcomingAppointmentsList = allUpcomingAppointments.take(5).map((doc) {
            final data = doc.data();
            final date = _parseAppointmentDate(data['requestedDateTime']);
            // Try to get patient name from various possible fields
            String patientName = 'Unknown Patient';
            final possiblePatientFields = [
              'patientName', 'patient', 'clientName', 'userName', 'name',
              'patient_name', 'client_name', 'user_name'
            ];
            for (String field in possiblePatientFields) {
              if (data[field] != null && data[field].toString().isNotEmpty) {
                patientName = data[field].toString();
                break;
              }
            }
            debugPrint('Upcoming appointment: $patientName at ${DateFormat('MMM dd, hh:mm a').format(date)} - Status: ${data['status']}');
            return {
              'patientName': patientName,
              'time': DateFormat('hh:mm a').format(date),
              'date': date,
              'status': data['status'] ?? 'accepted',
              'appointmentId': doc.id,
              'reasonForVisit': data['reasonForVisit'] ?? data['reason'] ?? 'N/A',
            };
          }).toList();
          // Generate chart data for the past 7 days
          Map<DateTime, int> dailyCounts = {};
          for (int i = 0; i < 7; i++) {
            final day = startOfPeriod.add(Duration(days: i));
            dailyCounts[day] = 0;
          }
          for (var doc in confirmedDocs) {
            final data = doc.data();
            final date = _parseAppointmentDate(data['requestedDateTime']);
            final normalizedDate = DateTime(date.year, date.month, date.day);
            if (dailyCounts.containsKey(normalizedDate)) {
              dailyCounts[normalizedDate] = dailyCounts[normalizedDate]! + 1;
            }
          }
          List<String> tempDays = [];
          List<int> tempCounts = [];
          dailyCounts.forEach((date, count) {
            tempDays.add(DateFormat('MMM d').format(date));
            tempCounts.add(count);
          });
          if (mounted) {
            setState(() {
              _totalAppointments = totalAppointments;
              _appointmentsToday = appointmentsToday;
              _upcomingAppointmentsNext7Days = upcomingAppointmentsNext7Days;
              _completedAppointments = completedAppointments;
              _upcomingAppointments = upcomingAppointmentsList;
              _chartDays = tempDays;
              _chartAppointmentCounts = tempCounts;
              _isLoading = false;
              _errorMessage = null;
            });
          }
          _saveCachedData();
          debugPrint('Dashboard metrics updated:');
          debugPrint('Total: $_totalAppointments, Today: $_appointmentsToday');
          debugPrint('Upcoming 7 days: $_upcomingAppointmentsNext7Days, Completed: $_completedAppointments');
          debugPrint('Upcoming appointments list: ${_upcomingAppointments.length}');
          // Debug upcoming appointments details
          for (var appt in _upcomingAppointments) {
            debugPrint('Upcoming: ${appt['patientName']} - ${appt['time']} - Status: ${appt['status']}');
          }
        } catch (e, stackTrace) {
          debugPrint('Error processing appointment data: $e');
          debugPrint('Stack trace: $stackTrace');
          if (mounted) {
            setState(() {
              _errorMessage = 'Error processing appointment data. Please check your internet connection.';
              _isLoading = false;
            });
          }
        }
      }, onError: (e) {
        debugPrint('Dashboard subscription error: $e');
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to load appointments. Please check your connection and try again.';
            _isLoading = false;
          });
        }
      });
    } catch (e, stackTrace) {
      debugPrint('Error subscribing to dashboard data: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to subscribe to data: $e';
          _isLoading = false;
        });
      }
    }
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

  void _handleNavigation(int index) {
    if (!mounted) return;
    setState(() {
      _selectedIndex = index;
      for (var item in _navigationItems) {
        item['isSelected'] = false;
      }
      _navigationItems[index]['isSelected'] = true;
    });
    switch (index) {
      case 0: // Overview
        break;
      case 1: // Appointments
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const DoctorAppointmentsScreen()),
        );
        break;
      case 2: // Recommendations
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const DoctorPatientRecommendationsScreen()),
        );
        break;
      case 3: // Consultations
        _startConsultation(context);
        break;
    }
  }

  Future<void> _startConsultation(BuildContext context) async {
    if (_upcomingAppointments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.info_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text('No upcoming appointments available for consultation'),
            ],
          ),
          backgroundColor: warningOrange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }
    final nextAppointment = _upcomingAppointments.first;
    final appointmentId = nextAppointment['appointmentId'] as String?;
    if (appointmentId == null || appointmentId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text('Invalid appointment ID'),
            ],
          ),
          backgroundColor: errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }
    final roomName = 'consult_$appointmentId';
    try {
      // Show loading dialog
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
      await FirebaseFirestore.instance
          .collection('all_appointment_requests')
          .doc(appointmentId)
          .update({'status': 'ongoing'});
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DoctorConsultationScreen(
            roomName: roomName,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('Failed to start consultation: ${e.toString()}')),
            ],
          ),
          backgroundColor: errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  Future<void> _joinConsultation(Map<String, dynamic> appointment) async {
    final roomName = 'consult_${appointment['appointmentId']}';
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DoctorConsultationScreen(
          roomName: roomName,
        ),
      ),
    );
  }

  void _showNotificationsDialog() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: medicalBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.notifications_rounded, color: medicalBlue, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Notifications',
              style: TextStyle(color: medicalBlue, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('notifications')
                .orderBy('timestamp', descending: true)
                .limit(20)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: medicalBlue));
              }
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, color: errorRed, size: 48),
                      const SizedBox(height: 16),
                      Text('Error loading notifications', style: TextStyle(color: errorRed)),
                    ],
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none, size: 48, color: medicalGray),
                      const SizedBox(height: 16),
                      Text('No notifications yet', style: TextStyle(color: medicalGray)),
                    ],
                  ),
                );
              }
              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final isRead = data['read'] ?? false;
                  final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isRead ? medicalGray.withOpacity(0.1) : lightMedicalBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.notifications_rounded,
                        color: isRead ? medicalGray : lightMedicalBlue,
                      ),
                    ),
                    title: Text(
                      data['title'] ?? 'Notification',
                      style: TextStyle(
                        fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                        color: medicalBlue,
                      ),
                    ),
                    subtitle: Text(
                      data['message'] ?? '',
                      style: TextStyle(color: medicalGray),
                    ),
                    trailing: Text(
                      DateFormat('MMM dd, HH:mm').format(timestamp),
                      style: const TextStyle(fontSize: 12, color: medicalGray),
                    ),
                    onTap: () {
                      if (!isRead) {
                        doc.reference.update({'read': true});
                        setState(() => _unreadNotifications--);
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('notifications')
                  .where('read', isEqualTo: false)
                  .get()
                  .then((snapshot) {
                for (var doc in snapshot.docs) {
                  doc.reference.update({'read': true});
                }
                setState(() => _unreadNotifications = 0);
              });
            },
            child: Text('Mark All Read', style: TextStyle(color: lightMedicalBlue)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: medicalBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Logout', style: TextStyle(color: medicalBlue, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to logout?', style: TextStyle(color: medicalGray)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: medicalGray)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: errorRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              try {
                await FirebaseAuth.instance.signOut();
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const login_screen.LoginScreen(role: Roles.provider)),
                      (route) => false,
                );
              } catch (e) {
                if (mounted) {
                  setState(() {
                    _errorMessage = 'Failed to logout: ${e.toString()}';
                  });
                }
                Navigator.pop(context);
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, int value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_cardRadius),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(_padding + 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: medicalBlue),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: color, size: 24),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value.toString(),
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: medicalBlue),
            ),
            const SizedBox(height: 12),
            Container(
              height: 6,
              decoration: BoxDecoration(color: lightGray, borderRadius: BorderRadius.circular(3)),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (value / (value > 20 ? value * 1.2 : 20)).clamp(0.0, 1.0),
                child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    final date = appointment['date'] as DateTime;
    final isToday = date.day == DateTime.now().day &&
        date.month == DateTime.now().month &&
        date.year == DateTime.now().year;
    final status = appointment['status']?.toString().toLowerCase() ?? 'accepted';
    final statusColor = status == 'accepted' || status == 'confirmed' ? successGreen :
    status == 'ongoing' ? medicalGreen :
    status == 'approved' ? lightMedicalBlue : medicalTeal;
    return Container(
      margin: const EdgeInsets.only(bottom: _spacing),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_cardRadius),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(_cardRadius),
        onTap: status == 'ongoing' ? () => _joinConsultation(appointment) : () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const DoctorAppointmentsScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.all(_padding),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 60,
                decoration: BoxDecoration(color: isToday ? medicalTeal : lightMedicalBlue, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('MMM d, EEEE').format(date),
                      style: TextStyle(fontSize: 12, color: medicalGray, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      appointment['patientName'] ?? 'Unknown Patient',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: medicalBlue),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Status: ${status.toUpperCase()}',
                      style: TextStyle(fontSize: 13, color: statusColor, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    appointment['time'] ?? '--:--',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: medicalBlue),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      status.toUpperCase(),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  if (status == 'ongoing') ...[
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => _joinConsultation(appointment),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: medicalGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      child: const Text('Rejoin', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppointmentChart() {
    if (_chartAppointmentCounts.isEmpty || _chartDays.isEmpty) {
      return Container(
        height: 280,
        decoration: BoxDecoration(
          color: lightGray.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: medicalGray.withOpacity(0.2)),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bar_chart_rounded, size: 48, color: medicalGray),
              const SizedBox(height: 16),
              Text(
                'No Appointment Data',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: medicalBlue),
              ),
              const SizedBox(height: 8),
              Text(
                'Chart will appear when you have appointments',
                style: TextStyle(fontSize: 14, color: medicalGray),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    double maxY = (_chartAppointmentCounts.reduce((a, b) => a > b ? a : b).toDouble() + 2).ceilToDouble();
    List<BarChartGroupData> barGroups = _chartAppointmentCounts.asMap().entries.map((entry) {
      int index = entry.key;
      int count = entry.value;
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: count.toDouble(),
            color: medicalBlue,
            width: 16,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    }).toList();
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: lightGray.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: medicalGray.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxY,
            minY: 0,
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (group) => medicalBlue,
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= _chartDays.length) return const SizedBox();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        _chartDays[index],
                        style: const TextStyle(color: medicalGray, fontSize: 12),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      value.toInt().toString(),
                      style: const TextStyle(color: medicalGray, fontSize: 12),
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            barGroups: barGroups,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 1,
              getDrawingHorizontalLine: (value) {
                return const FlLine(
                  color: Colors.grey,
                  strokeWidth: 0.5,
                  dashArray: [5, 5],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInsightItem(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: successGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
            child: Icon(icon, size: 16, color: successGreen),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(fontSize: 14, color: medicalGray, height: 1.4))),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 10, offset: const Offset(2, 0))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [medicalBlue, lightMedicalBlue], begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.medical_services_rounded, color: medicalBlue, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'MedConnect Pro',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
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
                      color: isSelected ? lightMedicalBlue.withOpacity(0.1) : null,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected ? Border.all(color: lightMedicalBlue.withOpacity(0.3)) : null,
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected ? lightMedicalBlue.withOpacity(0.2) : medicalGray.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(item['icon'] as IconData, color: isSelected ? lightMedicalBlue : medicalGray, size: 20),
                      ),
                      title: Text(
                        item['title'] as String,
                        style: TextStyle(
                          color: isSelected ? medicalBlue : medicalGray,
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
                  decoration: BoxDecoration(color: errorRed.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.logout_rounded, color: errorRed, size: 20),
                ),
                title: Text(
                  'Logout',
                  style: TextStyle(color: errorRed, fontWeight: FontWeight.w500, fontSize: 14),
                ),
                onTap: _showLogoutConfirmation,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    try {
      return Expanded(
        child: Container(
          color: lightGray,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: medicalBlue))
              : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: errorRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(_cardRadius),
                      border: Border.all(color: errorRed.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: errorRed, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_errorMessage!, style: TextStyle(color: errorRed))),
                        TextButton(
                          onPressed: () {
                            setState(() => _errorMessage = null);
                            _subscribeToDashboardData();
                          },
                          child: Text('Retry', style: TextStyle(color: errorRed)),
                        ),
                      ],
                    ),
                  ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(colors: [medicalBlue, medicalTeal], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    boxShadow: [
                      BoxShadow(color: medicalBlue.withOpacity(0.3), spreadRadius: 1, blurRadius: 15, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(50),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.1), spreadRadius: 1, blurRadius: 8, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: CircleAvatar(
                          backgroundColor: Colors.white,
                          radius: 35,
                          child: Text(
                            (_doctorName ?? 'D').substring(0, 1).toUpperCase(),
                            style: TextStyle(color: medicalBlue, fontSize: 28, fontWeight: FontWeight.bold),
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
                              style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Dr. ${_doctorName ?? "Doctor"}',
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Doctor Dashboard',
                              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8)),
                            ),
                          ],
                        ),
                      ),
                      Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                            child: IconButton(
                              icon: Icon(Icons.notifications_rounded, color: Colors.white, size: 24),
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
                                    BoxShadow(color: Colors.black.withOpacity(0.2), spreadRadius: 1, blurRadius: 3, offset: const Offset(0, 1)),
                                  ],
                                ),
                                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                                child: Text(
                                  _unreadNotifications > 99 ? '99+' : _unreadNotifications.toString(),
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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
                    Flexible(
                      flex: 1,
                      child: _buildMetricCard('Total Appointments', _totalAppointments, Icons.calendar_today_rounded, medicalBlue),
                    ),
                    const SizedBox(width: 20),
                    Flexible(
                      flex: 1,
                      child: _buildMetricCard("Today's Appointments", _appointmentsToday, Icons.today_rounded, medicalTeal),
                    ),
                    const SizedBox(width: 20),
                    Flexible(
                      flex: 1,
                      child: _buildMetricCard('Completed', _completedAppointments, Icons.check_circle_rounded, successGreen),
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
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(_cardRadius),
                              boxShadow: [
                                BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 8, offset: const Offset(0, 2)),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: lightMedicalBlue.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(Icons.analytics_rounded, color: lightMedicalBlue, size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Appointments Overview',
                                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: medicalBlue),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  _buildAppointmentChart(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    SizedBox(
                      width: 380,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Upcoming Appointments',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: medicalBlue),
                              ),
                              TextButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const DoctorAppointmentsScreen()),
                                ),
                                icon: Icon(Icons.arrow_forward_rounded, size: 16, color: lightMedicalBlue),
                                label: Text(
                                  'View All',
                                  style: TextStyle(color: lightMedicalBlue, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _isLoading
                              ? Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(_cardRadius),
                              boxShadow: [
                                BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 6, offset: const Offset(0, 2)),
                              ],
                            ),
                            child: Center(child: CircularProgressIndicator(color: medicalBlue)),
                          )
                              : _upcomingAppointments.isEmpty
                              ? Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(_cardRadius),
                              boxShadow: [
                                BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 6, offset: const Offset(0, 2)),
                              ],
                            ),
                            child: Center(
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: medicalGray.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(50),
                                    ),
                                    child: Icon(Icons.calendar_today_outlined, size: 40, color: medicalGray),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No Upcoming Appointments',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: medicalBlue),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _totalAppointments > 0
                                        ? 'You have appointments but none are upcoming'
                                        : 'Your schedule is clear for now',
                                    style: TextStyle(fontSize: 14, color: medicalGray),
                                  ),
                                  if (_doctorName != null) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      'Logged in as: Dr. $_doctorName',
                                      style: TextStyle(fontSize: 12, color: medicalGray, fontStyle: FontStyle.italic),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Total appointments in system: $_totalAppointments',
                                      style: TextStyle(fontSize: 11, color: medicalGray.withOpacity(0.8)),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          )
                              : Column(
                            children: _upcomingAppointments.map((appt) => _buildAppointmentCard(appt)).toList(),
                          ),
                          const SizedBox(height: 32),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(_cardRadius),
                              boxShadow: [
                                BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 8, offset: const Offset(0, 2)),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: medicalGreen.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(Icons.lightbulb_rounded, color: medicalGreen, size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Doctor Best Practices',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: medicalBlue),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  _buildInsightItem('Review patient history before consultations', Icons.folder_open_rounded),
                                  _buildInsightItem('Document findings promptly after appointments', Icons.note_add_rounded),
                                  _buildInsightItem('Communicate clearly with patients', Icons.chat_rounded),
                                  _buildInsightItem('Stay updated with medical guidelines', Icons.book_rounded),
                                  _buildInsightItem('Ensure timely follow-ups', Icons.schedule_rounded),
                                ],
                              ),
                            ),
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
    } catch (e, stackTrace) {
      debugPrint('Error building main content: $e');
      debugPrint('Stack trace: $stackTrace');
      return Center(
        child: Text(
          'Error rendering dashboard: $e',
          style: TextStyle(color: errorRed),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      return Scaffold(
        backgroundColor: lightGray,
        body: LayoutBuilder(
          builder: (context, constraints) {
            return Row(
              children: [
                if (constraints.maxWidth > 600) // Show sidebar only on larger screens
                  SizedBox(
                    width: 260,
                    child: _buildSidebar(),
                  ),
                _buildMainContent(),
              ],
            );
          },
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('Error building UI: $e');
      debugPrint('Stack trace: $stackTrace');
      return Scaffold(
        body: Center(
          child: Text(
            'Error rendering dashboard: $e',
            style: TextStyle(color: errorRed),
          ),
        ),
      );
    }
  }
}