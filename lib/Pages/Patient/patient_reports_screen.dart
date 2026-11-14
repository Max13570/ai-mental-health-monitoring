import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Enums for type safety
enum AppointmentStatus { pending, confirmed, completed, cancelled }
enum AppointmentType { consultation, therapy_session, follow_up }
enum Priority { normal, urgent, high }

// Extension for string formatting
extension StringCasingExtension on String {
  String toTitleCase() {
    return replaceAll(RegExp(' +'), ' ')
        .split(' ')
        .map((str) => str.isNotEmpty ? str[0].toUpperCase() + str.substring(1).toLowerCase() : '')
        .join(' ');
  }
}

class MentalHealthReportScreen extends StatefulWidget {
  const MentalHealthReportScreen({super.key});

  @override
  State<MentalHealthReportScreen> createState() => _MentalHealthReportScreenState();
}

class _MentalHealthReportScreenState extends State<MentalHealthReportScreen>
    with TickerProviderStateMixin {
  static const double _screenPadding = 24.0;
  static const double _cardElevation = 8.0;
  static const double _cardRadius = 20.0;
  static const double _widgetSpacing = 20.0;
  static const double _contentPadding = 24.0;
  static const double _iconSize = 24.0;

  static const Color _primaryBlue = Color(0xFF2E86AB);
  static const Color _secondaryTeal = Color(0xFF4ECDC4);
  static const Color _accentGreen = Color(0xFF45B7D1);
  static const Color _backgroundGray = Color(0xFFF8FAFB);
  static const Color _cardWhite = Color(0xFFFFFFFF);
  static const Color _textPrimary = Color(0xFF1A202C);
  static const Color _textSecondary = Color(0xFF718096);
  static const Color _textMuted = Color(0xFFA0AEC0);
  static const Color _borderLight = Color(0xFFE2E8F0);
  static const Color _successGreen = Color(0xFF38A169);
  static const Color _warningOrange = Color(0xFFED8936);
  static const Color _errorRed = Color(0xFFE53E3E);
  static const Color _infoBlue = Color(0xFF3182CE);

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isLoading = true;
  List<UserAssessment> _assessments = [];
  List<Appointment> _appointments = [];
  String? _errorMessage;
  int _selectedIndex = 0;

  Map<String, int> _assessmentStats = {};
  Map<String, int> _appointmentStats = {};

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadData();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) setState(() => _errorMessage = 'Authentication required. Please log in.');
        return;
      }

      await Future.wait([
        _loadAssessments(),
        _loadAppointments(),
      ]);
      _calculateStats();
      _fadeController.forward();
      _slideController.forward();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Failed to load data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAssessments() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('assessments')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();

      if (mounted) {
        setState(() {
          _assessments = querySnapshot.docs
              .map((doc) => UserAssessment.fromDocument(doc))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading assessments: $e');
      if (mounted) setState(() => _errorMessage ??= 'Failed to load assessments: $e');
    }
  }

  Future<void> _loadAppointments() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('appointments')
          .orderBy('requestedDateTime', descending: true)
          .limit(20)
          .get();

      if (mounted) {
        setState(() {
          _appointments = querySnapshot.docs
              .map((doc) => Appointment.fromDocument(doc))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading appointments: $e');
      if (mounted) setState(() => _errorMessage ??= 'Failed to load appointments: $e');
    }
  }

  void _calculateStats() {
    _assessmentStats = {
      'total': _assessments.length,
      'lowRisk': _assessments.where((a) =>
      ['low', 'mild'].contains(a.depressionRisk.toLowerCase()) ||
          ['low', 'mild'].contains(a.anxietyRisk.toLowerCase()) ||
          ['low', 'mild'].contains(a.stressRisk.toLowerCase())).length,
      'moderateRisk': _assessments.where((a) =>
      a.depressionRisk.toLowerCase() == 'moderate' ||
          a.anxietyRisk.toLowerCase() == 'moderate' ||
          a.stressRisk.toLowerCase() == 'moderate').length,
      'highRisk': _assessments.where((a) =>
      ['severe', 'high'].contains(a.depressionRisk.toLowerCase()) ||
          ['severe', 'high'].contains(a.anxietyRisk.toLowerCase()) ||
          ['severe', 'high'].contains(a.stressRisk.toLowerCase())).length,
    };

    _appointmentStats = {
      'total': _appointments.length,
      'pending': _appointments.where((a) => a.status.toLowerCase() == 'pending').length,
      'confirmed': _appointments.where((a) => a.status.toLowerCase() == 'confirmed').length,
      'completed': _appointments.where((a) => a.status.toLowerCase() == 'completed').length,
      'cancelled': _appointments.where((a) => a.status.toLowerCase() == 'cancelled').length,
    };
  }

  Widget _buildTabSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Expanded(child: _buildTab('Assessments', Icons.psychology_outlined, 0)),
          Expanded(child: _buildTab('Appointments', Icons.calendar_today_outlined, 1)),
        ],
      ),
    );
  }

  Widget _buildTab(String title, IconData icon, int index) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: isSelected ? _primaryBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? Colors.white : _textSecondary, size: 20),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(
              color: isSelected ? Colors.white : _textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 14,
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildAssessmentCard(UserAssessment assessment) {
    final timestamp = assessment.timestamp?.toDate() ?? DateTime.now();
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');
    return Container(
      margin: const EdgeInsets.only(bottom: _widgetSpacing),
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(_cardRadius),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(_contentPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _secondaryTeal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.psychology_outlined, color: _secondaryTeal, size: _iconSize),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mental Health Assessment', style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold, color: _textPrimary,
                  )),
                  const SizedBox(height: 4),
                  Text(dateFormat.format(timestamp), style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _textSecondary,
                  )),
                ],
              )),
            ]),
            const SizedBox(height: 20),
            _buildScoreIndicators(assessment),
            if (_hasRecommendations(assessment)) ...[
              const SizedBox(height: 20),
              _buildRecommendations(assessment),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScoreIndicators(UserAssessment assessment) {
    return Column(children: [
      _buildScoreIndicator('Depression', assessment.depressionScore, assessment.depressionRisk, Icons.sentiment_very_dissatisfied_outlined),
      const SizedBox(height: 16),
      _buildScoreIndicator('Anxiety', assessment.anxietyScore, assessment.anxietyRisk, Icons.psychology_outlined),
      const SizedBox(height: 16),
      _buildScoreIndicator('Stress', assessment.stressScore, assessment.stressRisk, Icons.whatshot_outlined),
    ]);
  }

  Widget _buildScoreIndicator(String label, int score, String risk, IconData icon) {
    Color riskColor = _getRiskColor(risk);
    double progress = (score / 27.0).clamp(0.0, 1.0);
    return Row(children: [
      Icon(icon, color: riskColor, size: 20),
      const SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: _textPrimary, fontSize: 14)),
            Text('$score ($risk)', style: TextStyle(fontWeight: FontWeight.w600, color: riskColor, fontSize: 14)),
          ]),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: _borderLight,
            valueColor: AlwaysStoppedAnimation<Color>(riskColor),
            minHeight: 6,
          ),
        ],
      )),
    ]);
  }

  Widget _buildRecommendations(UserAssessment assessment) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _infoBlue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _infoBlue.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.lightbulb_outline, color: _infoBlue, size: 20),
          const SizedBox(width: 8),
          Text('Recommendations', style: TextStyle(
            fontWeight: FontWeight.w600, color: _infoBlue, fontSize: 16,
          )),
        ]),
        const SizedBox(height: 12),
        if (assessment.depressionRecommendation?.isNotEmpty == true)
          _buildRecommendationItem('Depression', assessment.depressionRecommendation!),
        if (assessment.anxietyRecommendation?.isNotEmpty == true)
          _buildRecommendationItem('Anxiety', assessment.anxietyRecommendation!),
        if (assessment.stressRecommendation?.isNotEmpty == true)
          _buildRecommendationItem('Stress', assessment.stressRecommendation!),
      ]),
    );
  }

  Widget _buildRecommendationItem(String category, String recommendation) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 4, height: 4, margin: const EdgeInsets.only(top: 8, right: 8),
          decoration: BoxDecoration(color: _infoBlue, borderRadius: BorderRadius.circular(2)),
        ),
        Expanded(child: RichText(
          text: TextSpan(
            style: TextStyle(color: _textSecondary, fontSize: 14),
            children: [
              TextSpan(text: '$category: ', style: const TextStyle(fontWeight: FontWeight.w600)),
              TextSpan(text: recommendation),
            ],
          ),
        )),
      ]),
    );
  }

  Widget _buildAppointmentCard(Appointment appointment) {
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');
    final statusColor = _getStatusColor(appointment.status);
    return Container(
      margin: const EdgeInsets.only(bottom: _widgetSpacing),
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(_cardRadius),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(_contentPadding),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.event_outlined, color: statusColor, size: _iconSize),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(appointment.selectedDoctor, style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold, color: _textPrimary,
                )),
                const SizedBox(height: 4),
                Text(dateFormat.format(appointment.requestedDateTime), style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _textSecondary,
                )),
              ],
            )),
            _buildStatusChip(appointment.status),
          ]),
          const SizedBox(height: 20),
          _buildAppointmentDetails(appointment),
        ]),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color statusColor = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Text(status.toTitleCase(), style: TextStyle(
        color: statusColor, fontWeight: FontWeight.w600, fontSize: 12,
      )),
    );
  }

  Widget _buildAppointmentDetails(Appointment appointment) {
    return Column(children: [
      _buildDetailRow(Icons.person_outline_rounded, 'Patient', appointment.patientName),
      const SizedBox(height: 12),
      _buildDetailRow(Icons.medical_information_outlined, 'Reason', appointment.reasonForVisit),
      const SizedBox(height: 12),
      _buildDetailRow(Icons.category_outlined, 'Type', appointment.appointmentType.toTitleCase()),
      const SizedBox(height: 12),
      _buildDetailRow(Icons.priority_high_outlined, 'Priority', appointment.priority.toTitleCase()),
      if (appointment.notes?.isNotEmpty == true) ...[
        const SizedBox(height: 12),
        _buildDetailRow(Icons.note_outlined, 'Notes', appointment.notes!),
      ],
    ]);
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: _textSecondary, size: 18),
      const SizedBox(width: 12),
      Text('$label:', style: TextStyle(
        fontWeight: FontWeight.w600, color: _textSecondary, fontSize: 14,
      )),
      const SizedBox(width: 8),
      Expanded(child: Text(value, style: TextStyle(
        color: _textPrimary, fontSize: 14,
      ))),
    ]);
  }

  Widget _buildEmptyState() {
    bool isAssessments = _selectedIndex == 0;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(_screenPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: _primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                isAssessments ? Icons.assessment_outlined : Icons.calendar_today_outlined,
                size: 64,
                color: _primaryBlue,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isAssessments ? 'No assessments completed yet' : 'No appointments scheduled yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold, color: _textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              isAssessments
                  ? 'Take your first mental health assessment to get personalized insights and recommendations.'
                  : 'Book your first appointment with our mental health professionals.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: _textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: isAssessments ? _startNewAssessment : _bookNewAppointment,
              icon: Icon(isAssessments ? Icons.add_circle_outline : Icons.event_available),
              label: Text(isAssessments ? 'Start Assessment' : 'Book Appointment'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(_screenPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: _errorRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(Icons.error_outline_rounded, size: 64, color: _errorRed),
            ),
            const SizedBox(height: 24),
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold, color: _textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Please try again later.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: _textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () async {
                await Future.delayed(const Duration(seconds: 1));
                _loadData();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_selectedIndex == 0) {
      return _assessments.isEmpty ? _buildEmptyState() : ListView.builder(
        padding: const EdgeInsets.all(_screenPadding),
        itemCount: _assessments.length,
        itemBuilder: (context, index) => SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: _buildAssessmentCard(_assessments[index]),
          ),
        ),
      );
    } else {
      return _appointments.isEmpty ? _buildEmptyState() : ListView.builder(
        padding: const EdgeInsets.all(_screenPadding),
        itemCount: _appointments.length,
        itemBuilder: (context, index) => SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: _buildAppointmentCard(_appointments[index]),
          ),
        ),
      );
    }
  }

  void _startNewAssessment() async {
    try {
      final result = await Navigator.pushNamed(context, '/assessment');
      if (mounted && result == true) {
        _loadAssessments();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Assessment completed successfully!'),
            backgroundColor: _successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to open assessment screen: $e'),
            backgroundColor: _errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _bookNewAppointment() async {
    try {
      final result = await Navigator.pushNamed(context, '/book_appointment');
      if (mounted && result == true) {
        _loadAppointments();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Appointment booked successfully!'),
            backgroundColor: _successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to open booking screen: $e'),
            backgroundColor: _errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  bool _hasRecommendations(UserAssessment assessment) {
    return (assessment.depressionRecommendation?.isNotEmpty == true) ||
        (assessment.anxietyRecommendation?.isNotEmpty == true) ||
        (assessment.stressRecommendation?.isNotEmpty == true);
  }

  Color _getRiskColor(String risk) {
    switch (risk.toLowerCase()) {
      case 'low': return _successGreen;
      case 'mild': return _accentGreen;
      case 'moderate': return _warningOrange;
      case 'severe':
      case 'high': return _errorRed;
      default: return _textSecondary;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed': return _successGreen;
      case 'confirmed': return _infoBlue;
      case 'pending': return _warningOrange;
      case 'cancelled': return _errorRed;
      default: return _textSecondary;
    }
  }

  static DateTime _parseDateTime(dynamic timestamp) {
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is String) {
      try { return DateTime.parse(timestamp); } catch (e) { return DateTime.now(); }
    }
    if (timestamp is DateTime) return timestamp;
    return DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundGray,
      appBar: AppBar(
        title: const Text('My Care Overview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: _textPrimary,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: _primaryBlue),
            onPressed: _loadData,
            tooltip: 'Refresh Data',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _cardWhite,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_primaryBlue), strokeWidth: 3),
              ),
              const SizedBox(height: 24),
              Text('Loading your health data...', style: TextStyle(
                color: _textSecondary, fontSize: 16, fontWeight: FontWeight.w500,
              )),
            ],
          ),
        )
            : _errorMessage != null
            ? _buildErrorState()
            : RefreshIndicator(
          onRefresh: _loadData,
          color: _primaryBlue,
          backgroundColor: _cardWhite,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(_screenPadding),
                  child: Column(
                    children: [
                      const SizedBox(height: _widgetSpacing),
                      SlideTransition(position: _slideAnimation, child: _buildTabSelector()),
                      const SizedBox(height: _widgetSpacing),
                    ],
                  ),
                ),
              ),
              SliverFillRemaining(child: _buildContent()),
            ],
          ),
        ),
      ),
      floatingActionButton: _isLoading || _errorMessage != null
          ? null
          : FloatingActionButton.extended(
        onPressed: _selectedIndex == 0 ? _startNewAssessment : _bookNewAppointment,
        icon: Icon(_selectedIndex == 0 ? Icons.psychology_outlined : Icons.event_available_rounded, size: 24),
        label: Text(_selectedIndex == 0 ? 'New Assessment' : 'Book Appointment', style: const TextStyle(
          fontWeight: FontWeight.w600, fontSize: 16,
        )),
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        elevation: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

class UserAssessment {
  final int depressionScore;
  final int anxietyScore;
  final int stressScore;
  final String depressionRisk;
  final String anxietyRisk;
  final String stressRisk;
  final String? depressionRecommendation;
  final String? anxietyRecommendation;
  final String? stressRecommendation;
  final Timestamp? timestamp;

  UserAssessment({
    required this.depressionScore,
    required this.anxietyScore,
    required this.stressScore,
    required this.depressionRisk,
    required this.anxietyRisk,
    required this.stressRisk,
    this.depressionRecommendation,
    this.anxietyRecommendation,
    this.stressRecommendation,
    this.timestamp,
  });

  factory UserAssessment.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserAssessment(
      depressionScore: (data['depression']?['score'] as num?)?.toInt() ?? 0,
      anxietyScore: (data['anxiety']?['score'] as num?)?.toInt() ?? 0,
      stressScore: (data['stress']?['score'] as num?)?.toInt() ?? 0,
      depressionRisk: data['depression']?['risk'] as String? ?? 'Unknown',
      anxietyRisk: data['anxiety']?['risk'] as String? ?? 'Unknown',
      stressRisk: data['stress']?['risk'] as String? ?? 'Unknown',
      depressionRecommendation: data['depression']?['recommendation'] as String?,
      anxietyRecommendation: data['anxiety']?['recommendation'] as String?,
      stressRecommendation: data['stress']?['recommendation'] as String?,
      timestamp: data['timestamp'] as Timestamp?,
    );
  }
}

class Appointment {
  final String priority;
  final DateTime submittedAt;
  final String? notes;
  final String status;
  final String id;
  final String patientName;
  final String phoneNumber;
  final String email;
  final DateTime requestedDateTime;
  final String reasonForVisit;
  final String appointmentType;
  final String userId;
  final String selectedDoctor;
  final String? selectedTime;

  Appointment({
    required this.id,
    required this.patientName,
    required this.phoneNumber,
    required this.email,
    required this.requestedDateTime,
    required this.reasonForVisit,
    required this.appointmentType,
    required this.priority,
    required this.submittedAt,
    this.notes,
    required this.status,
    required this.userId,
    required this.selectedDoctor,
    this.selectedTime,
  });

  factory Appointment.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Appointment(
      id: doc.id,
      patientName: data['patientName'] as String? ?? '',
      phoneNumber: data['phoneNumber'] as String? ?? '',
      email: data['email'] as String? ?? '',
      requestedDateTime: _MentalHealthReportScreenState._parseDateTime(data['requestedDateTime']),
      reasonForVisit: data['reasonForVisit'] as String? ?? '',
      appointmentType: data['appointmentType'] as String? ?? 'Consultation',
      priority: data['priority'] as String? ?? 'Normal',
      submittedAt: _MentalHealthReportScreenState._parseDateTime(data['submittedAt']),
      notes: data['notes'] as String?,
      status: data['status'] as String? ?? 'Pending',
      userId: data['userId'] as String? ?? '',
      selectedDoctor: data['selectedDoctor'] as String? ?? 'Unknown Therapist',
      selectedTime: data['selectedTime'] as String?,
    );
  }
}

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mental Health App',
      theme: ThemeData(primarySwatch: Colors.blue),
      routes: {
        '/': (context) => MentalHealthReportScreen(),
        '/assessment': (context) => AssessmentScreen(),
        '/book_appointment': (context) => BookingScreen(),
      },
      onUnknownRoute: (settings) => MaterialPageRoute(builder: (context) => UnknownScreen()),
      initialRoute: '/',
    );
  }
}

class AssessmentScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: Text('Assessment Screen')), body: Center(child: Text('This is the Assessment Screen')));
  }
}

class BookingScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: Text('Booking Screen')), body: Center(child: Text('This is the Booking Screen')));
  }
}

class UnknownScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: Text('Unknown Route')), body: Center(child: Text('Page not found')));
  }
}