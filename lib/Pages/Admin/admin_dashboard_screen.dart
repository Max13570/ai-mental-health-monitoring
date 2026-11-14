import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../login_screen.dart';
import 'manageAccountsScreen.dart';
import 'securitySettingsScreen.dart';
import '../role_constants.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  // Color Scheme for Admin Dashboard
  static const Color adminPrimary = Color(0xFF344955);
  static const Color adminPrimaryLight = Color(0xFF4A6572);
  static const Color adminAccent = Color(0xFFF9AA33);
  static const Color adminBackground = Color(0xFFF5F7FA);
  static const Color adminText = Color(0xFF232F34);
  static const Color adminTextLight = Color(0xFF4A6572);
  static const Color adminSuccess = Color(0xFF2E7D32);
  static const Color adminWarning = Color(0xFFFF8F00);
  static const Color adminError = Color(0xFFC62828);
  static const Color adminCard = Colors.white;

  static const double _padding = 16.0;
  static const double _cardRadius = 12.0;
  static const double _spacing = 16.0;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
  int _selectedIndex = 0;
  int _unreadNotifications = 0;
  int _totalUsers = 0;
  int _activeToday = 0;
  int _pendingApprovals = 0;

  DateTime? _lastLogin;

  @override
  void initState() {
    super.initState();
    _fetchLastLogin();
    _listenToNotifications();
    _fetchUserStats();
  }

  Future<void> _fetchUserStats() async {
    try {
      final usersCount = await _firestore.collection('users').count().get();
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final activeTodayQuery = await _firestore.collection('users')
          .where('lastLogin', isGreaterThanOrEqualTo: startOfDay)
          .count()
          .get();
      final pendingQuery = await _firestore.collection('users')
          .where('status', isEqualTo: 'pending')
          .count()
          .get();

      setState(() {
        _totalUsers = usersCount.count ?? 0;
        _activeToday = activeTodayQuery.count ?? 0;
        _pendingApprovals = pendingQuery.count ?? 0;
      });
    } catch (e) {
      debugPrint('Error fetching user stats: $e');
    }
  }

  Future<void> _fetchLastLogin() async {
    if (_userId == 'anonymous') return;
    try {
      final doc = await _firestore.collection('users').doc(_userId).get();
      if (doc.exists && doc.data()?['lastLogin'] != null) {
        setState(() {
          _lastLogin = (doc.data()!['lastLogin'] as Timestamp).toDate();
        });
      }
    } catch (e) {
      debugPrint('Error fetching last login: $e');
    }
  }

  void _listenToNotifications() {
    if (_userId == 'anonymous') return;

    _firestore.collection('admin_notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _unreadNotifications = snapshot.docs.length;
      });
    });
  }

  void _showNotificationsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.notifications, color: adminPrimary),
            const SizedBox(width: 12),
            Text('Admin Notifications', style: TextStyle(color: adminPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('admin_notifications')
                .orderBy('timestamp', descending: true)
                .limit(20)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: adminPrimary));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none, size: 48, color: adminTextLight),
                      const SizedBox(height: 16),
                      Text('No notifications yet', style: TextStyle(color: adminTextLight)),
                    ],
                  ),
                );
              }
              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (data['read'] ?? false) ? adminTextLight.withOpacity(0.1) : adminPrimary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.notifications,
                          color: (data['read'] ?? false) ? adminTextLight : adminPrimary),
                    ),
                    title: Text(data['title'] ?? 'Notification'),
                    subtitle: Text(data['message'] ?? ''),
                    trailing: Text(DateFormat('MMM dd, HH:mm').format((data['timestamp'] as Timestamp).toDate())),
                    onTap: () {
                      if (!(data['read'] ?? false)) {
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
              _firestore.collection('admin_notifications')
                  .where('read', isEqualTo: false)
                  .get()
                  .then((snapshot) {
                for (var doc in snapshot.docs) {
                  doc.reference.update({'read': true});
                }
              });
              setState(() => _unreadNotifications = 0);
            },
            child: Text('Mark All Read', style: TextStyle(color: adminPrimary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: adminPrimary),
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _navigateToScreen(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Logout', style: TextStyle(color: adminPrimary)),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: adminPrimary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: adminPrimary),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen(role: Roles.admin)),
                    (route) => false,
              );
            },
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    final navItems = [
      {'icon': Icons.dashboard, 'label': 'Dashboard', 'index': 0},
      {'icon': Icons.manage_accounts, 'label': 'Manage Accounts', 'index': 1},
      {'icon': Icons.security, 'label': 'Security Settings', 'index': 2},
    ];

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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
              color: adminPrimary,
              border: Border(bottom: BorderSide(color: adminPrimaryLight)),
            ),
            child: Row(
              children: [
                Icon(Icons.admin_panel_settings, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Text('Admin Portal', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: navItems.map((item) => _buildNavItem(item)).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ListTile(
              leading: Icon(Icons.logout, color: adminError),
              title: Text('Logout', style: TextStyle(color: adminError)),
              onTap: _showLogoutConfirmation,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: adminError.withOpacity(0.2)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(Map<String, dynamic> item) {
    final isSelected = _selectedIndex == item['index'];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? adminPrimary.withOpacity(0.1) : null,
        borderRadius: BorderRadius.circular(8),
        border: isSelected ? Border.all(color: adminPrimary.withOpacity(0.3)) : null,
      ),
      child: ListTile(
        leading: Icon(item['icon'] as IconData, color: isSelected ? adminPrimary : adminTextLight),
        title: Text(item['label'] as String, style: TextStyle(
          color: isSelected ? adminPrimary : adminTextLight,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        )),
        onTap: () {
          setState(() => _selectedIndex = item['index'] as int);
          if (item['index'] == 1) {
            _navigateToScreen(const ManageAccountsScreen());
          } else if (item['index'] == 2) {
            _navigateToScreen(const SecuritySettingsScreen());
          }
        },
      ),
    );
  }

  Widget _buildMetricCard(String title, int value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardRadius)),
      child: Padding(
        padding: const EdgeInsets.all(_padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: TextStyle(color: adminTextLight, fontWeight: FontWeight.w500)),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value.toString(),
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: adminText),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: value / (_totalUsers == 0 ? 1 : _totalUsers.toDouble()),
              backgroundColor: adminBackground,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserActivityChart() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardRadius)),
      child: Padding(
        padding: const EdgeInsets.all(_padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('User Activity (Last 7 days)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: adminText)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('user_activity')
                    .orderBy('date', descending: true)
                    .limit(7)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator(color: adminPrimary));
                  }

                  final docs = snapshot.data!.docs.reversed.toList();
                  final spots = docs.asMap().entries.map((entry) {
                    final data = entry.value.data() as Map<String, dynamic>;
                    return FlSpot(
                        entry.key.toDouble(),
                        (data['count'] ?? 0).toDouble()
                    );
                  }).toList();

                  return LineChart(
                    LineChartData(
                      gridData: FlGridData(show: true),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() >= docs.length) return const Text('');
                              final date = (docs[value.toInt()].data() as Map<String, dynamic>)['date'] as Timestamp;
                              return Text(DateFormat('MMM dd').format(date.toDate()));
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              return Text(value.toInt().toString());
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      minX: 0,
                      maxX: docs.isNotEmpty ? (docs.length - 1).toDouble() : 6,
                      minY: 0,
                      maxY: spots.isNotEmpty ? spots.map((e) => e.y).reduce((a, b) => a > b ? a : b) * 1.1 : 10,
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots.isNotEmpty ? spots : [
                            FlSpot(0, 3),
                            FlSpot(1, 1),
                            FlSpot(2, 4),
                            FlSpot(3, 2),
                            FlSpot(4, 5),
                            FlSpot(5, 1.5),
                            FlSpot(6, 3),
                          ],
                          isCurved: true,
                          color: adminPrimary,
                          barWidth: 3,
                          belowBarData: BarAreaData(show: true, color: adminPrimary.withOpacity(0.1)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Expanded(
      child: Container(
        color: adminBackground,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Admin Dashboard', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: adminText)),
                      Text(_lastLogin != null
                          ? 'Last login: ${DateFormat('MMM dd, yyyy HH:mm').format(_lastLogin!)}'
                          : 'Welcome back!',
                          style: TextStyle(color: adminTextLight)),
                    ],
                  ),
                  Stack(
                    children: [
                      IconButton(
                        icon: Icon(Icons.notifications, color: adminPrimary, size: 28),
                        onPressed: _showNotificationsDialog,
                      ),
                      if (_unreadNotifications > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: adminError,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              _unreadNotifications > 9 ? '9+' : _unreadNotifications.toString(),
                              style: const TextStyle(color: Colors.white, fontSize: 10),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Metrics Row
              Row(
                children: [
                  Expanded(child: _buildMetricCard('Total Users', _totalUsers, Icons.people, adminPrimary)),
                  const SizedBox(width: _spacing),
                  Expanded(child: _buildMetricCard('Active Today', _activeToday, Icons.person, adminSuccess)),
                  const SizedBox(width: _spacing),
                  Expanded(child: _buildMetricCard('Pending Approvals', _pendingApprovals, Icons.warning, adminWarning)),
                ],
              ),
              const SizedBox(height: _spacing),

              // Chart and Tips
              Column(
                children: [
                  _buildUserActivityChart(),
                  const SizedBox(height: _spacing),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardRadius)),
                    child: Padding(
                      padding: const EdgeInsets.all(_padding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Admin Tips', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: adminText)),
                          const SizedBox(height: 16),
                          _buildTipItem('Regularly review user permissions and roles', Icons.security),
                          _buildTipItem('Monitor user activity for unusual patterns', Icons.monitor),
                          _buildTipItem('Keep security settings up to date', Icons.security_update),
                        ],
                      ),
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

  Widget _buildTipItem(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: adminPrimary, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(color: adminText))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: adminBackground,
      body: Row(
        children: [
          _buildSidebar(),
          _buildMainContent(),
        ],
      ),
    );
  }
}