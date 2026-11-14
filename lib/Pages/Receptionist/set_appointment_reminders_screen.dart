import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppointmentReminder {
  final String id;
  final String patientName;
  final String doctorName;
  final DateTime appointmentTime;
  final DateTime reminderTime;
  final String notes;
  final ReminderStatus status;

  AppointmentReminder({
    required this.id,
    required this.patientName,
    required this.doctorName,
    required this.appointmentTime,
    required this.reminderTime,
    this.notes = '',
    this.status = ReminderStatus.pending,
  });

  Map<String, dynamic> toMap() {
    return {
      'patientName': patientName,
      'doctorName': doctorName,
      'appointmentTime': Timestamp.fromDate(appointmentTime),
      'reminderTime': Timestamp.fromDate(reminderTime),
      'notes': notes,
      'status': status.toString().split('.').last,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory AppointmentReminder.fromMap(String id, Map<String, dynamic> data) {
    return AppointmentReminder(
      id: id,
      patientName: data['patientName'] ?? '',
      doctorName: data['doctorName'] ?? '',
      appointmentTime: (data['appointmentTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reminderTime: (data['reminderTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notes: data['notes'] ?? '',
      status: ReminderStatus.values.firstWhere(
            (e) => e.toString().split('.').last == (data['status'] as String? ?? 'pending'),
        orElse: () => ReminderStatus.pending,
      ),
    );
  }
}

enum ReminderStatus { pending, sent, cancelled }

class SetAppointmentRemindersScreen extends StatefulWidget {
  const SetAppointmentRemindersScreen({super.key});

  @override
  State<SetAppointmentRemindersScreen> createState() =>
      _SetAppointmentRemindersScreenState();
}

class _SetAppointmentRemindersScreenState
    extends State<SetAppointmentRemindersScreen>
    with SingleTickerProviderStateMixin {
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
  static const double _cardElevation = 4.0;
  static const double _cardRadius = 12.0;
  static const double _spacing = 16.0;

  final TextEditingController _patientNameController = TextEditingController();
  final TextEditingController _doctorNameController = TextEditingController();
  final TextEditingController _appointmentTimeController = TextEditingController();
  final TextEditingController _reminderTimeController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final List<AppointmentReminder> _reminders = [];
  bool _isLoading = false;
  DateTime? _selectedAppointmentDateTime;
  DateTime? _selectedReminderDateTime;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _loadReminders();
  }

  @override
  void dispose() {
    _patientNameController.dispose();
    _doctorNameController.dispose();
    _appointmentTimeController.dispose();
    _reminderTimeController.dispose();
    _notesController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadReminders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showErrorSnackBar('You must be logged in to view reminders.');
      return;
    }

    setState(() => _isLoading = true);

    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('reminders')
            .orderBy('createdAt', descending: true)
            .get();

        if (!mounted) return;

        setState(() {
          _reminders.clear();
          _reminders.addAll(
            snapshot.docs.map((doc) {
              final data = doc.data();
              final appointmentTime = data['appointmentTime'] as Timestamp?;
              final reminderTime = data['reminderTime'] as Timestamp?;
              if (appointmentTime == null || reminderTime == null) {
                print('Warning: Invalid timestamp in reminder ${doc.id}');
                return AppointmentReminder.fromMap(doc.id, {
                  ...data,
                  'appointmentTime': Timestamp.fromDate(DateTime.now()),
                  'reminderTime': Timestamp.fromDate(DateTime.now()),
                });
              }
              return AppointmentReminder.fromMap(doc.id, data);
            }).where((reminder) =>
            reminder.appointmentTime != null && reminder.reminderTime != null).toList(),
          );
          _isLoading = false;
        });
        break;
      } catch (e) {
        retryCount++;
        if (retryCount == maxRetries) {
          if (mounted) {
            setState(() => _isLoading = false);
            _showErrorSnackBar('Failed to load reminders after $maxRetries attempts: $e');
          }
        }
        await Future.delayed(Duration(seconds: retryCount * 2));
      }
    }
  }

  String? _validatePatientName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Patient name is required';
    }
    if (value.trim().length < 2) {
      return 'Patient name must be at least 2 characters';
    }
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value.trim())) {
      return 'Patient name should only contain letters and spaces';
    }
    return null;
  }

  String? _validateDoctorName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Doctor name is required';
    }
    if (value.trim().length < 2) {
      return 'Doctor name must be at least 2 characters';
    }
    return null;
  }

  String? _validateDateTime(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  Future<void> _selectAppointmentDateTime() async {
    try {
      final DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: DateTime.now().add(const Duration(days: 1)),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: medicalBlue,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: medicalBlue,
              ),
              dialogBackgroundColor: Colors.white,
            ),
            child: child!,
          );
        },
      );

      if (pickedDate != null && mounted) {
        final TimeOfDay? pickedTime = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.now(),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: medicalBlue,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: medicalBlue,
                ),
                dialogBackgroundColor: Colors.white,
              ),
              child: child!,
            );
          },
        );

        if (pickedTime != null && mounted) {
          _selectedAppointmentDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );

          setState(() {
            _appointmentTimeController.text = _formatDateTime(
              _selectedAppointmentDateTime!,
            );
          });
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error selecting appointment time: $e');
    }
  }

  Future<void> _selectReminderDateTime() async {
    try {
      final DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: DateTime.now().add(const Duration(days: 1)),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: medicalBlue,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: medicalBlue,
              ),
              dialogBackgroundColor: Colors.white,
            ),
            child: child!,
          );
        },
      );

      if (pickedDate != null && mounted) {
        final TimeOfDay? pickedTime = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.now(),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: medicalBlue,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: medicalBlue,
                ),
                dialogBackgroundColor: Colors.white,
              ),
              child: child!,
            );
          },
        );

        if (pickedTime != null && mounted) {
          _selectedReminderDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );

          setState(() {
            _reminderTimeController.text = _formatDateTime(
              _selectedReminderDateTime!,
            );
          });
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error selecting reminder time: $e');
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('MMM d, yyyy hh:mm a').format(dateTime);
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: errorRed,
      ),
    );
  }

  Future<void> _saveReminder() async {
    if (_formKey.currentState!.validate() &&
        _selectedAppointmentDateTime != null &&
        _selectedReminderDateTime != null) {
      setState(() => _isLoading = true);

      try {
        final user = FirebaseAuth.instance.currentUser!;
        final reminder = AppointmentReminder(
          id: '',
          patientName: _patientNameController.text.trim(),
          doctorName: _doctorNameController.text.trim(),
          appointmentTime: _selectedAppointmentDateTime!,
          reminderTime: _selectedReminderDateTime!,
          notes: _notesController.text.trim(),
        );

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('reminders')
            .add(reminder.toMap());

        _showErrorSnackBar('Reminder set successfully');
        _formKey.currentState!.reset();
        _patientNameController.clear();
        _doctorNameController.clear();
        _appointmentTimeController.clear();
        _reminderTimeController.clear();
        _notesController.clear();
        setState(() {
          _selectedAppointmentDateTime = null;
          _selectedReminderDateTime = null;
        });
        _loadReminders();
      } catch (e) {
        _showErrorSnackBar('Failed to save reminder: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
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
        title: const Text('Set Appointment Reminders'),
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: medicalBlue))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(_padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'New Reminder',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: medicalBlue,
                    ),
                  ),
                  const SizedBox(height: _spacing),
                  TextFormField(
                    controller: _patientNameController,
                    decoration: InputDecoration(
                      labelText: 'Patient Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(_cardRadius),
                      ),
                    ),
                    validator: _validatePatientName,
                  ),
                  const SizedBox(height: _spacing),
                  TextFormField(
                    controller: _doctorNameController,
                    decoration: InputDecoration(
                      labelText: 'Doctor Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(_cardRadius),
                      ),
                    ),
                    validator: _validateDoctorName,
                  ),
                  const SizedBox(height: _spacing),
                  TextFormField(
                    controller: _appointmentTimeController,
                    decoration: InputDecoration(
                      labelText: 'Appointment Time',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(_cardRadius),
                      ),
                    ),
                    validator: (value) => _validateDateTime(value, 'Appointment time'),
                    onTap: _selectAppointmentDateTime,
                    readOnly: true,
                  ),
                  const SizedBox(height: _spacing),
                  TextFormField(
                    controller: _reminderTimeController,
                    decoration: InputDecoration(
                      labelText: 'Reminder Time',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(_cardRadius),
                      ),
                    ),
                    validator: (value) => _validateDateTime(value, 'Reminder time'),
                    onTap: _selectReminderDateTime,
                    readOnly: true,
                  ),
                  const SizedBox(height: _spacing),
                  TextFormField(
                    controller: _notesController,
                    decoration: InputDecoration(
                      labelText: 'Notes (Optional)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(_cardRadius),
                      ),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: _spacing * 2),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveReminder,
                    child: Text(
                      'Set Reminder',
                      style: const TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: medicalBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(_cardRadius),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: _padding * 2,
                        vertical: _padding,
                      ),
                    ),
                  ),
                  const SizedBox(height: _spacing * 2),
                  Text(
                    'Reminders',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: medicalBlue,
                    ),
                  ),
                  const SizedBox(height: _spacing),
                  if (_reminders.isEmpty && !_isLoading)
                    Container(
                      padding: const EdgeInsets.all(_padding),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(_cardRadius),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: medicalGray.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: Icon(
                              Icons.notifications_none_rounded,
                              size: 48,
                              color: medicalGray,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No reminders set yet',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: medicalBlue,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Set a new reminder to see it here',
                            style: TextStyle(
                              fontSize: 14,
                              color: medicalGray,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ..._reminders.map(
                        (reminder) => Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(_cardRadius),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Semantics(
                        label:
                        'Reminder for ${reminder.patientName} with Dr. ${reminder.doctorName}',
                        child: ListTile(
                          contentPadding: EdgeInsets.all(_padding),
                          leading: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: reminder.status == ReminderStatus.sent
                                  ? successGreen.withOpacity(0.1)
                                  : reminder.status == ReminderStatus.cancelled
                                  ? errorRed.withOpacity(0.1)
                                  : warningOrange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.notifications_active_rounded,
                              color: reminder.status == ReminderStatus.sent
                                  ? successGreen
                                  : reminder.status == ReminderStatus.cancelled
                                  ? errorRed
                                  : warningOrange,
                            ),
                          ),
                          title: Text(
                            '${reminder.patientName} with Dr. ${reminder.doctorName}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: medicalBlue,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Appointment: ${_formatDateTime(reminder.appointmentTime)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: medicalGray,
                                ),
                              ),
                              Text(
                                'Reminder: ${_formatDateTime(reminder.reminderTime)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: medicalGray,
                                ),
                              ),
                              if (reminder.notes.isNotEmpty)
                                Text(
                                  'Notes: ${reminder.notes}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: medicalGray.withOpacity(0.8),
                                  ),
                                ),
                            ],
                          ),
                          trailing: Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: reminder.status == ReminderStatus.sent
                                  ? successGreen.withOpacity(0.2)
                                  : reminder.status == ReminderStatus.cancelled
                                  ? errorRed.withOpacity(0.2)
                                  : warningOrange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              reminder.status.toString().split('.').last.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: reminder.status == ReminderStatus.sent
                                    ? successGreen
                                    : reminder.status == ReminderStatus.cancelled
                                    ? errorRed
                                    : warningOrange,
                              ),
                            ),
                          ),
                          isThreeLine: reminder.notes.isNotEmpty,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}