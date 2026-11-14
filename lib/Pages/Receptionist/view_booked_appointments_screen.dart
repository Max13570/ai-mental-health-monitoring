import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ViewBookedAppointmentsScreen extends StatefulWidget {
  const ViewBookedAppointmentsScreen({super.key});

  @override
  State<ViewBookedAppointmentsScreen> createState() => _ViewBookedAppointmentsScreenState();
}

class _ViewBookedAppointmentsScreenState extends State<ViewBookedAppointmentsScreen> {
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
  static const double _cardRadius = 12.0;
  static const double _spacing = 16.0;

  final List<Map<String, dynamic>> _appointments = [];
  List<Map<String, dynamic>> _filteredAppointments = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  StreamSubscription? _appointmentsSubscription;
  Timer? _pollingTimer;
  bool _usePolling = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  @override
  void dispose() {
    _appointmentsSubscription?.cancel();
    _pollingTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAppointments({bool retry = false}) async {
    // Cancel existing subscriptions
    await _appointmentsSubscription?.cancel();
    _appointmentsSubscription = null;
    _pollingTimer?.cancel();
    _pollingTimer = null;

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      debugPrint('=== DIAGNOSTIC MODE ===');
      debugPrint('Loading appointments - retry: $retry, usePolling: $_usePolling');

      // Check authentication first
      final user = FirebaseAuth.instance.currentUser;
      debugPrint('Current user: ${user?.uid ?? "No user"}');
      if (user == null) {
        if (mounted) {
          setState(() {
            _errorMessage = 'User not authenticated. Please log in first.';
            _isLoading = false;
          });
        }
        return;
      }

      // Test Firestore connection with a simple query first
      debugPrint('Step 1: Testing Firestore connection...');
      final testQuery = await FirebaseFirestore.instance
          .collection('all_appointment_requests')
          .limit(1)
          .get();

      debugPrint('Step 2: Connection test successful. Found ${testQuery.docs.length} documents');

      // Log first document structure if exists
      if (testQuery.docs.isNotEmpty) {
        final firstDoc = testQuery.docs.first;
        debugPrint('First document ID: ${firstDoc.id}');
        debugPrint('First document data: ${firstDoc.data()}');
        debugPrint('Available fields: ${firstDoc.data().keys.toList()}');
      }

      // Check all documents without filter first
      debugPrint('Step 3: Checking all documents in collection...');
      final allDocs = await FirebaseFirestore.instance
          .collection('all_appointment_requests')
          .get();

      debugPrint('Total documents in collection: ${allDocs.docs.length}');

      // Check status values
      final statusValues = <String>[];
      for (var doc in allDocs.docs) {
        final status = doc.data()['status'];
        if (status != null && !statusValues.contains(status)) {
          statusValues.add(status.toString());
        }
      }
      debugPrint('Available status values: $statusValues');

      // Now get the actual appointments with accepted status
      debugPrint('Step 4: Fetching accepted appointments...');
      final snapshot = await FirebaseFirestore.instance
          .collection('all_appointment_requests')
          .where('status', isEqualTo: 'accepted')
          .get();

      debugPrint('Step 5: Query completed. Found ${snapshot.docs.length} accepted appointments');

      if (!mounted) return;

      setState(() {
        _appointments.clear();

        if (snapshot.docs.isEmpty) {
          debugPrint('No accepted appointments found');
        }

        for (var doc in snapshot.docs) {
          final data = doc.data();
          debugPrint('Processing document: ${doc.id}');
          debugPrint('Document data keys: ${data.keys.toList()}');
          debugPrint('requestedDateTime value: ${data['requestedDateTime']} (${data['requestedDateTime'].runtimeType})');

          // Handle both Timestamp and DateTime objects
          DateTime? dateTime;
          if (data['requestedDateTime'] is Timestamp) {
            dateTime = (data['requestedDateTime'] as Timestamp).toDate();
            debugPrint('Converted Timestamp to DateTime: $dateTime');
          } else if (data['requestedDateTime'] is DateTime) {
            dateTime = data['requestedDateTime'] as DateTime;
            debugPrint('Already DateTime: $dateTime');
          } else if (data['requestedDateTime'] is String) {
            try {
              dateTime = DateTime.parse(data['requestedDateTime'] as String);
              debugPrint('Parsed string to DateTime: $dateTime');
            } catch (e) {
              debugPrint('Failed to parse date string: ${data['requestedDateTime']} - Error: $e');
            }
          } else if (data['requestedDateTime'] == null) {
            debugPrint('requestedDateTime is null for document ${doc.id}');
          } else {
            debugPrint('Unknown requestedDateTime type: ${data['requestedDateTime'].runtimeType}');
          }

          if (dateTime != null) {
            _appointments.add({
              'id': doc.id,
              ...data,
              'requestedDateTime': dateTime,
            });
            debugPrint('Successfully added appointment: ${data['patientName'] ?? 'Unknown'} at $dateTime');
          } else {
            debugPrint('Skipping document ${doc.id} due to invalid requestedDateTime');
          }
        }

        // Sort appointments by date
        _appointments.sort((a, b) => (a['requestedDateTime'] as DateTime).compareTo(b['requestedDateTime'] as DateTime));

        debugPrint('Step 6: Processing complete. Total appointments added: ${_appointments.length}');

        _filterAppointments();
        _isLoading = false;
      });

      debugPrint('Step 7: Successfully loaded ${_appointments.length} appointments');
      debugPrint('Filtered appointments: ${_filteredAppointments.length}');

      // Set up real-time updates if not retrying and conditions are good
      if (!retry && !_usePolling && !kIsWeb) {
        _setupStreamSubscription();
      } else if (_usePolling || kIsWeb) {
        _startPolling();
      }
    } catch (e, stackTrace) {
      debugPrint('ERROR in _loadAppointments: $e');
      debugPrint('Stack trace: $stackTrace');

      if (!mounted) return;

      String errorMsg = 'Failed to load appointments: ${e.toString()}';
      if (e.toString().contains('PERMISSION_DENIED')) {
        errorMsg = 'Permission denied. Please check Firestore security rules.';
      } else if (e.toString().contains('FAILED_PRECONDITION')) {
        errorMsg = 'Index required. Please create a composite index in Firestore.';
      }

      setState(() {
        _errorMessage = errorMsg;
        _isLoading = false;
      });

      // Enable polling as fallback for certain errors
      if (retry == false && !e.toString().contains('PERMISSION_DENIED')) {
        debugPrint('Enabling polling fallback due to error');
        _usePolling = true;
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _startPolling();
          }
        });
      }
    }
  }

  void _setupStreamSubscription() {
    try {
      debugPrint('Setting up stream subscription...');
      _appointmentsSubscription = FirebaseFirestore.instance
          .collection('all_appointment_requests')
          .where('status', isEqualTo: 'accepted')
          .snapshots()  // Remove orderBy from stream to avoid index issues
          .listen(
            (snapshot) {
          debugPrint('Stream update received: ${snapshot.docs.length} documents');
          if (!mounted) return;
          setState(() {
            _appointments.clear();
            for (var doc in snapshot.docs) {
              final data = doc.data();
              DateTime? dateTime;

              if (data['requestedDateTime'] is Timestamp) {
                dateTime = (data['requestedDateTime'] as Timestamp).toDate();
              } else if (data['requestedDateTime'] is DateTime) {
                dateTime = data['requestedDateTime'] as DateTime;
              }

              if (dateTime != null) {
                _appointments.add({
                  'id': doc.id,
                  ...data,
                  'requestedDateTime': dateTime,
                });
              }
            }
            // Sort in memory after getting data
            _appointments.sort((a, b) => (a['requestedDateTime'] as DateTime).compareTo(b['requestedDateTime'] as DateTime));
            _filterAppointments();
          });
        },
        onError: (e, stackTrace) {
          debugPrint('Stream error: $e\nStack trace: $stackTrace');
          if (kIsWeb && e.toString().contains('INTERNAL ASSERTION FAILED')) {
            _usePolling = true;
            _appointmentsSubscription?.cancel();
            _startPolling();
          } else {
            if (mounted) {
              setState(() {
                _errorMessage = 'Real-time updates failed: $e';
              });
            }
          }
        },
        cancelOnError: false, // Don't cancel on error, just handle it
      );
    } catch (e) {
      debugPrint('Failed to setup stream: $e');
      if (kIsWeb || e.toString().contains('permission')) {
        _usePolling = true;
        _startPolling();
      }
    }
  }

  void _startPolling() {
    debugPrint('Starting polling mode...');
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (mounted) {
        await _loadAppointments(retry: true);
      } else {
        timer.cancel();
      }
    });
  }

  void _filterAppointments() {
    _filteredAppointments = _appointments.where((appt) {
      final patientName = appt['patientName'] as String?;
      final reasonForVisit = appt['reasonForVisit'] as String?;
      return _searchQuery.isEmpty ||
          (patientName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          (reasonForVisit?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
    }).toList();
  }

  Future<void> _cancelAppointment(String appointmentId) async {
    if (appointmentId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid appointment ID'), backgroundColor: errorRed),
        );
      }
      return;
    }

    // Show loading dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Cancelling appointment...'),
            ],
          ),
        ),
      );
    }

    try {
      await FirebaseFirestore.instance
          .collection('all_appointment_requests')
          .doc(appointmentId)
          .update({'status': 'cancelled'});

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment cancelled'), backgroundColor: successGreen),
        );
      }

      // Refresh the list
      await _loadAppointments();
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel: $e'), backgroundColor: errorRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGray,
      appBar: AppBar(
        backgroundColor: medicalBlue,
        foregroundColor: Colors.white,
        title: const Text('Booked Appointments'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _loadAppointments(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: medicalBlue),
            SizedBox(height: 16),
            Text('Loading appointments...', style: TextStyle(color: medicalGray)),
          ],
        ),
      )
          : _errorMessage != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: errorRed),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.grey, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _loadAppointments(),
                style: ElevatedButton.styleFrom(backgroundColor: medicalBlue),
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    _usePolling = true;
                    _errorMessage = null;
                  });
                  _startPolling();
                },
                child: const Text('Try Polling Mode'),
              ),
            ],
          ),
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
                prefixIcon: const Icon(Icons.search_rounded, color: medicalGray),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear_rounded, color: medicalGray),
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
                  borderSide: const BorderSide(color: medicalBlue, width: 2),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: medicalGray.withOpacity(0.1),
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Icon(
              Icons.calendar_today_rounded,
              size: 48,
              color: medicalGray,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No booked appointments',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: medicalBlue,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'All accepted appointments will appear here',
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

  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    final date = appointment['requestedDateTime'] as DateTime;
    final isToday = date.day == DateTime.now().day &&
        date.month == DateTime.now().month &&
        date.year == DateTime.now().year;

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
            offset: const Offset(0, 2),
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
                        DateFormat('MMM d, EEEE').format(date),
                        style: const TextStyle(
                          fontSize: 12,
                          color: medicalGray,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        appointment['patientName'] ?? 'Unknown Patient',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: medicalBlue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        appointment['selectedDoctor'] != null
                            ? 'Dr. ${appointment['selectedDoctor']}'
                            : 'No doctor assigned',
                        style: const TextStyle(
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
                      DateFormat('hh:mm a').format(date),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: medicalBlue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isToday ? medicalTeal.withOpacity(0.2) : lightMedicalBlue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isToday ? 'TODAY' : DateFormat('MM/dd').format(date),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isToday ? medicalTeal : lightMedicalBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              appointment['reasonForVisit'] ?? 'No reason provided',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: () => _cancelAppointment(appointment['id'] as String? ?? ''),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: errorRed),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text(
                  'Cancel Appointment',
                  style: TextStyle(color: errorRed),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}