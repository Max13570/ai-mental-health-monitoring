import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'accept_appointments_screen.dart';
import 'view_booked_appointments_screen.dart';
import 'set_appointment_reminders_screen.dart';
import 'receptionist_date_management_screen.dart';
import '../login_screen.dart';
import '../role_constants.dart';

class ReceptionistDashboardScreen extends StatefulWidget {
  const ReceptionistDashboardScreen({super.key});

  @override
  State<ReceptionistDashboardScreen> createState() => _ReceptionistDashboardScreenState();
}

class _ReceptionistDashboardScreenState extends State<ReceptionistDashboardScreen> {
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

  // Constants for styling
  static const double _padding = 16.0;
  static const double _cardElevation = 4.0;
  static const double _cardRadius = 12.0;
  static const double _spacing = 16.0;

  // Dashboard data
  int _pendingRequestsCount = 0;
  int _totalAppointmentsToday = 0;
  int _upcomingAppointmentsNext7Days = 0;
  int _completedAppointmentsToday = 0;
  bool _isLoading = true;
  String? _errorMessage;
  int _unreadNotifications = 0;
  int _selectedIndex = 0;
  StreamSubscription? _appointmentsSubscription;
  StreamSubscription? _notificationsSubscription;

  // Chart data
  List<String> _chartDays = [];
  List<int> _chartAppointmentCounts = [];

  // Navigation items
  final List<Map<String, dynamic>> _navigationItems = [
    {'icon': Icons.dashboard_rounded, 'title': 'Overview', 'isSelected': true},
    {'icon': Icons.calendar_today_rounded, 'title': 'Appointments', 'isSelected': false},
    {'icon': Icons.check_circle_rounded, 'title': 'Approvals', 'isSelected': false},
    {'icon': Icons.schedule_rounded, 'title': 'Manage Availability', 'isSelected': false},
    {'icon': Icons.notifications_rounded, 'title': 'Reminders', 'isSelected': false},
  ];

  // Get receptionist name
  String get _receptionistName {
    final user = FirebaseAuth.instance.currentUser;
    return user?.displayName ?? user?.email?.split('@').first ?? 'Receptionist';
  }

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
  }

  Future<void> _initializeDashboard() async {
    await _loadCachedData();
    _subscribeToDashboardData();
    _listenToNotifications();
  }

  @override
  void dispose() {
    _appointmentsSubscription?.cancel();
    _notificationsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _pendingRequestsCount = prefs.getInt('pendingRequestsCount') ?? 0;
        _totalAppointmentsToday = prefs.getInt('totalAppointmentsToday') ?? 0;
        _upcomingAppointmentsNext7Days = prefs.getInt('upcomingAppointmentsNext7Days') ?? 0;
        _completedAppointmentsToday = prefs.getInt('completedAppointmentsToday') ?? 0;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load cached data: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _saveCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('pendingRequestsCount', _pendingRequestsCount);
      await prefs.setInt('totalAppointmentsToday', _totalAppointmentsToday);
      await prefs.setInt('upcomingAppointmentsNext7Days', _upcomingAppointmentsNext7Days);
      await prefs.setInt('completedAppointmentsToday', _completedAppointmentsToday);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to save cached data: ${e.toString()}';
        });
      }
    }
  }

  void _listenToNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _notificationsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .listen(
          (snapshot) {
        if (mounted) {
          setState(() {
            _unreadNotifications = snapshot.docs.length;
          });
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to load notifications: ${e.toString()}';
          });
        }
      },
    );
  }

  void _subscribeToDashboardData() {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _errorMessage = 'You must be logged in to view data.';
          _isLoading = false;
        });
      }
      return;
    }

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final endOfToday = startOfToday.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
    final endOfNext7Days = startOfToday.add(const Duration(days: 7));
    final startOfPeriod = DateTime(now.year, now.month, now.day - 6);

    _appointmentsSubscription = FirebaseFirestore.instance
        .collection('all_appointment_requests')
        .orderBy('requestedDateTime', descending: false)
        .snapshots()
        .listen(
          (snapshot) {
        if (!mounted) return;

        final pendingRequests = snapshot.docs.where((doc) {
          final data = doc.data();
          return (data['status'] as String?)?.toLowerCase() == 'pending';
        }).length;

        final todayAppointments = snapshot.docs.where((doc) {
          final data = doc.data();
          final date = (data['requestedDateTime'] as Timestamp?)?.toDate() ?? DateTime.now();
          return date.isAfter(startOfToday) && date.isBefore(endOfToday);
        }).length;

        final upcomingAppointments = snapshot.docs.where((doc) {
          final data = doc.data();
          final date = (data['requestedDateTime'] as Timestamp?)?.toDate() ?? DateTime.now();
          return date.isAfter(startOfToday) && date.isBefore(endOfNext7Days);
        }).length;

        final completedAppointments = snapshot.docs.where((doc) {
          final data = doc.data();
          final status = (data['status'] as String?)?.toLowerCase();
          final date = (data['requestedDateTime'] as Timestamp?)?.toDate() ?? DateTime.now();
          return status == 'completed' && date.isAfter(startOfToday) && date.isBefore(endOfToday);
        }).length;

        // Compute chart data for past 7 days
        Map<DateTime, int> dailyCounts = {};
        for (int i = 0; i < 7; i++) {
          final day = startOfPeriod.add(Duration(days: i));
          dailyCounts[day] = 0;
        }

        for (var doc in snapshot.docs) {
          final data = doc.data();
          final timestamp = data['requestedDateTime'] as Timestamp?;
          if (timestamp == null) continue;
          final date = timestamp.toDate();
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
            _pendingRequestsCount = pendingRequests;
            _totalAppointmentsToday = todayAppointments;
            _upcomingAppointmentsNext7Days = upcomingAppointments;
            _completedAppointmentsToday = completedAppointments;
            _chartDays = tempDays;
            _chartAppointmentCounts = tempCounts;
            _isLoading = false;
          });
        }

        _saveCachedData();
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to load appointments: ${e.toString()}';
            _isLoading = false;
          });
        }
      },
    );
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
          MaterialPageRoute(builder: (context) => const ViewBookedAppointmentsScreen()),
        );
        break;
      case 2: // Approvals
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AcceptAppointmentsScreen()),
        );
        break;
      case 3: // Manage Availability
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ReceptionistDateManagementScreen()),
        );
        break;
      case 4: // Reminders
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SetAppointmentRemindersScreen()),
        );
        break;
    }
  }

  void _showNotificationsDialog() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Notifications',
          style: TextStyle(color: medicalBlue, fontWeight: FontWeight.bold),
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
                return Center(child: CircularProgressIndicator(color: medicalBlue));
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text('Error loading notifications',
                      style: TextStyle(color: errorRed)),
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
                        if (mounted) {
                          setState(() {
                            _unreadNotifications--;
                          });
                        }
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
                if (mounted) {
                  setState(() {
                    _unreadNotifications = 0;
                  });
                }
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
                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen(role: Roles.receptionist)),
                        (route) => false,
                  );
                }
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
                widthFactor: (value / 100).clamp(0.0, 1.0),
                child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    final date = (appointment['requestedDateTime'] as Timestamp?)?.toDate() ?? DateTime.now();
    final isToday = date.day == DateTime.now().day &&
        date.month == DateTime.now().month &&
        date.year == DateTime.now().year;
    final status = (appointment['status'] as String?)?.toLowerCase() ?? 'pending';
    final statusColor = status == 'accepted' ? successGreen :
    status == 'completed' ? medicalGreen :
    status == 'rejected' ? errorRed :
    warningOrange;

    return Container(
      margin: const EdgeInsets.only(bottom: _spacing),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_cardRadius),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(_cardRadius),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ViewBookedAppointmentsScreen()),
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
                      appointment['selectedDoctor'] ?? 'Unknown Doctor',
                      style: TextStyle(fontSize: 13, color: medicalGray, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    DateFormat('hh:mm a').format(date),
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppointmentChart() {
    if (_chartAppointmentCounts.isEmpty) {
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
                'No data available for the chart',
                style: TextStyle(fontSize: 14, color: medicalGray),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    double maxY = _chartAppointmentCounts.reduce((a, b) => a > b ? a : b).toDouble() + 5;

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
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (group) => Colors.white,
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
                  child: Icon(Icons.health_and_safety_rounded, color: medicalBlue, size: 28),
                ),
                const SizedBox(width: 12),
                Text(
                  'MedConnect Pro',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
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
    return Expanded(
      child: Container(
        color: lightGray,
        child: SingleChildScrollView(
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
                          _receptionistName.substring(0, 1),
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
                            _receptionistName,
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Receptionist Dashboard',
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
                  Expanded(
                    child: _buildMetricCard('Pending Approvals', _pendingRequestsCount, Icons.pending_actions_rounded, errorRed),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _buildMetricCard("Today's Appointments", _totalAppointmentsToday, Icons.today_rounded, medicalTeal),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _buildMetricCard('Upcoming (7 Days)', _upcomingAppointmentsNext7Days, Icons.date_range_rounded, lightMedicalBlue),
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
                                MaterialPageRoute(builder: (context) => const ViewBookedAppointmentsScreen()),
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
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('all_appointment_requests')
                              .where('status', isEqualTo: 'accepted')
                              .orderBy('requestedDateTime', descending: false)
                              .limit(5)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return Center(child: CircularProgressIndicator(color: medicalBlue));
                            }
                            if (snapshot.hasError) {
                              return Center(
                                child: Text('Error loading appointments',
                                    style: TextStyle(color: errorRed)),
                              );
                            }
                            final appointments = snapshot.data?.docs ?? [];
                            if (appointments.isEmpty) {
                              return Container(
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
                                        'Your schedule is clear for now',
                                        style: TextStyle(fontSize: 14, color: medicalGray),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            return Column(
                              children: appointments.map((doc) =>
                                  _buildAppointmentCard(doc.data() as Map<String, dynamic>))
                                  .toList(),
                            );
                          },
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
                                      'Receptionist Best Practices',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: medicalBlue),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                _buildInsightItem('Verify patient details at check-in', Icons.assignment_rounded),
                                _buildInsightItem('Send reminders 24 hours before appointments', Icons.notifications_rounded),
                                _buildInsightItem('Keep the waiting area organized', Icons.cleaning_services_rounded),
                                _buildInsightItem('Check doctor schedules regularly', Icons.schedule_rounded),
                                _buildInsightItem('Prioritize urgent appointment requests', Icons.priority_high_rounded),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGray,
      body: Row(
        children: [
          _buildSidebar(),
          _buildMainContent(),
        ],
      ),
    );
  }
}