import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AppointmentBookingScreen extends StatefulWidget {
  const AppointmentBookingScreen({super.key});

  @override
  State<AppointmentBookingScreen> createState() => _AppointmentBookingScreenState();
}

class _AppointmentBookingScreenState extends State<AppointmentBookingScreen> {
  static const Color patientBlue = Color(0xFF1565C0);
  static const Color patientTeal = Color(0xFF00838F);
  static const Color patientGreen = Color(0xFF2E7D32);
  static const Color lightPatientBlue = Color(0xFF42A5F5);
  static const Color patientGray = Color(0xFF546E7A);
  static const Color lightGray = Color(0xFFF5F7FA);
  static const Color successGreen = Color(0xFF43A047);
  static const Color warningOrange = Color(0xFFFF9800);
  static const Color errorRed = Color(0xFFE53935);

  String? selectedDoctor;
  DateTime? selectedDate;
  String? selectedTime;
  bool _isLoading = false;
  List<DateTime> _availableDates = [];
  List<String> _availableTimeSlots = [];

  final TextEditingController _patientNameController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _prefillUserData();
  }

  @override
  void dispose() {
    _patientNameController.dispose();
    _phoneNumberController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _prefillUserData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _patientNameController.text = user.displayName ?? '';
      _emailController.text = user.email ?? '';
    }
  }

  List<String> _generateTimeSlots(String startTime, String endTime) {
    final slots = <String>[];
    try {
      final startParts = startTime.split(':');
      final endParts = endTime.split(':');

      int startHour = int.parse(startParts[0]);
      int startMinute = int.parse(startParts[1]);
      int endHour = int.parse(endParts[0]);
      int endMinute = int.parse(endParts[1]);

      DateTime currentTime = DateTime(2023, 1, 1, startHour, startMinute);
      final endDateTime = DateTime(2023, 1, 1, endHour, endMinute);

      while (currentTime.isBefore(endDateTime) || currentTime.isAtSameMomentAs(endDateTime)) {
        slots.add(DateFormat('h:mm a').format(currentTime));
        currentTime = currentTime.add(const Duration(minutes: 30));
        if (currentTime.isAfter(endDateTime)) {
          break;
        }
      }
    } catch (e) {
      return [
        '9:00 AM', '9:30 AM', '10:00 AM', '10:30 AM', '11:00 AM', '11:30 AM',
        '12:00 PM', '12:30 PM', '1:00 PM', '1:30 PM', '2:00 PM', '2:30 PM',
        '3:00 PM', '3:30 PM', '4:00 PM'
      ];
    }
    return slots;
  }

  Future<void> _selectDate(BuildContext context) async {
    if (selectedDoctor == null) {
      _showSnackBar('Please select a healthcare provider first', warningOrange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final availabilitySnapshot = await FirebaseFirestore.instance
          .collection('doctor_availability')
          .where('doctor', isEqualTo: selectedDoctor)
          .get();

      if (availabilitySnapshot.docs.isEmpty) {
        _showSnackBar('No availability found for the selected healthcare provider', warningOrange);
        setState(() => _isLoading = false);
        return;
      }

      _availableDates = availabilitySnapshot.docs.map((doc) {
        final timestamp = doc['date'] as Timestamp;
        return timestamp.toDate();
      }).toList();

      _availableDates = _availableDates.toSet().toList()..sort((a, b) => a.compareTo(b));

      if (_availableDates.isEmpty) {
        _showSnackBar('No available dates for selected healthcare provider', warningOrange);
        setState(() => _isLoading = false);
        return;
      }

      DateTime initialDate = _availableDates.firstWhere(
            (date) => !date.isBefore(DateTime.now()),
        orElse: () => _availableDates.last,
      );

      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        selectableDayPredicate: (DateTime day) {
          return _availableDates.any((availableDate) =>
          day.year == availableDate.year &&
              day.month == availableDate.month &&
              day.day == availableDate.day);
        },
        builder: (context, child) {
          return Theme(
            data: ThemeData.light().copyWith(
              colorScheme: ColorScheme.light(
                primary: patientBlue,
                onPrimary: Colors.white,
                onSurface: patientBlue,
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: patientBlue,
                ),
              ),
            ),
            child: child!,
          );
        },
      );

      if (picked != null) {
        setState(() {
          selectedDate = picked;
          selectedTime = null;
        });

        await _loadAvailableTimeSlots(picked);
      }
    } catch (e) {
      _showSnackBar('Error loading available dates: ${e.toString()}', errorRed);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAvailableTimeSlots(DateTime date) async {
    if (selectedDoctor == null) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showSnackBar('Please log in to view available time slots', warningOrange);
        return;
      }

      final availabilitySnapshot = await FirebaseFirestore.instance
          .collection('doctor_availability')
          .where('doctor', isEqualTo: selectedDoctor)
          .where('date', isEqualTo: Timestamp.fromDate(date))
          .get();

      if (availabilitySnapshot.docs.isEmpty) {
        _showSnackBar('No availability found. Using default time slots for testing.', warningOrange);
        final defaultSlots = [
          '9:00 AM', '9:30 AM', '10:00 AM', '10:30 AM', '11:00 AM', '11:30 AM',
          '12:00 PM', '12:30 PM', '1:00 PM', '1:30 PM', '2:00 PM', '2:30 PM',
          '3:00 PM', '3:30 PM', '4:00 PM'
        ];
        setState(() {
          _availableTimeSlots = defaultSlots;
        });
        return;
      }

      final availabilityDoc = availabilitySnapshot.docs.first;
      final docData = availabilityDoc.data();

      final startTime = docData['startTime'] as String? ?? '09:00';
      final endTime = docData['endTime'] as String? ?? '17:00';

      final allSlots = _generateTimeSlots(startTime, endTime);

      final dateString = DateFormat('MM/dd/yyyy').format(date);

      final appointmentsSnapshot = await FirebaseFirestore.instance
          .collection('all_appointment_requests')
          .where('selectedDoctor', isEqualTo: selectedDoctor)
          .where('date', isEqualTo: dateString)
          .get();

      final bookedTimes = <String>[];
      for (var doc in appointmentsSnapshot.docs) {
        final appointmentData = doc.data();
        final bookedTime = appointmentData['selectedTime'] as String?;
        if (bookedTime != null) {
          bookedTimes.add(bookedTime);
        }
      }

      final availableSlots = allSlots.where((slot) => !bookedTimes.contains(slot)).toList();

      setState(() {
        _availableTimeSlots = availableSlots;
      });

      if (availableSlots.isEmpty) {
        _showSnackBar('All time slots are booked for this date', warningOrange);
      }
    } catch (e) {
      _showSnackBar('Error loading time slots: ${e.toString()}', errorRed);
      setState(() {
        _availableTimeSlots = [];
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    if (selectedDoctor == null || selectedDate == null) {
      _showSnackBar('Please select a healthcare provider and date first', warningOrange);
      return;
    }

    if (_availableTimeSlots.isEmpty) {
      setState(() => _isLoading = true);
      await _loadAvailableTimeSlots(selectedDate!);
      setState(() => _isLoading = false);
    }

    if (_availableTimeSlots.isEmpty) {
      _showSnackBar('No available time slots for the selected date', warningOrange);
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.access_time, color: patientBlue),
            SizedBox(width: 8),
            Text('Available Time Slots'),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: _availableTimeSlots.length,
            itemBuilder: (context, index) {
              final slot = _availableTimeSlots[index];
              return Card(
                margin: EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text(
                    slot,
                    style: TextStyle(
                      color: patientBlue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    setState(() => selectedTime = slot);
                    Navigator.pop(context);
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: patientGray)),
          ),
        ],
      ),
    );
  }

  void _confirmAppointment() {
    if (selectedDoctor == null ||
        selectedDate == null ||
        selectedTime == null ||
        _patientNameController.text.isEmpty ||
        _phoneNumberController.text.isEmpty ||
        _emailController.text.isEmpty) {
      _showSnackBar(
        'Please complete all required fields (Patient details, Doctor, Date, and Time).',
        warningOrange,
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: patientBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.calendar_today_rounded, color: patientBlue, size: 20),
            ),
            SizedBox(width: 12),
            Text(
              'Confirm Appointment',
              style: TextStyle(
                color: patientBlue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: lightGray,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: patientGray.withOpacity(0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildConfirmationRow('Healthcare Provider', selectedDoctor!, Icons.person_rounded),
              _buildConfirmationRow('Date', DateFormat('MM/dd/yyyy').format(selectedDate!), Icons.calendar_today_rounded),
              _buildConfirmationRow('Time', selectedTime!, Icons.access_time_rounded),
              _buildConfirmationRow('Patient', _patientNameController.text, Icons.badge_rounded),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: patientGray)),
          ),
          ElevatedButton(
            onPressed: () => _processBooking(),
            style: ElevatedButton.styleFrom(
              backgroundColor: patientBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_rounded, size: 16),
                SizedBox(width: 4),
                Text('Confirm'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processBooking() async {
    Navigator.pop(context); // Close confirmation dialog
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showSnackBar('Please log in or create an account to book an appointment.', warningOrange);
        return;
      }

      final timeFormat = DateFormat('h:mm a');
      final parsedTime = timeFormat.parse(selectedTime!);
      final combinedDateTime = DateTime(
        selectedDate!.year,
        selectedDate!.month,
        selectedDate!.day,
        parsedTime.hour,
        parsedTime.minute,
      );

      final appointmentData = {
        'patientName': _patientNameController.text,
        'phoneNumber': _phoneNumberController.text,
        'email': _emailController.text,
        'requestedDateTime': Timestamp.fromDate(combinedDateTime),
        'submittedAt': FieldValue.serverTimestamp(),
        'reasonForVisit': _notesController.text,
        'notes': _notesController.text,
        'status': 'pending',
        'userId': user.uid,
        'selectedDoctor': selectedDoctor,
        'selectedTime': selectedTime,
        'date': DateFormat('MM/dd/yyyy').format(selectedDate!),
        'time': selectedTime,
        'doctor': selectedDoctor,
        'specialty': selectedDoctor?.split(' - ').last ?? 'General',
        'appointmentType': 'consultation',
        'priority': 'normal',
      };

      DocumentReference newAppointmentRef = await FirebaseFirestore
          .instance
          .collection('all_appointment_requests')
          .add(appointmentData);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('appointments')
          .doc(newAppointmentRef.id)
          .set(appointmentData);

      await _sendReceptionistNotification(newAppointmentRef.id);

      _showSnackBar('Appointment request sent! Receptionist will review.', successGreen);
      _clearForm();
      Navigator.pop(context);
    } catch (e) {
      _showSnackBar('Error booking appointment: ${e.toString()}', errorRed);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendReceptionistNotification(String appointmentId) async {
    try {
      final receptionistsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'receptionist')
          .get();

      final batch = FirebaseFirestore.instance.batch();

      for (var doc in receptionistsSnapshot.docs) {
        final notificationRef = FirebaseFirestore.instance
            .collection('users')
            .doc(doc.id)
            .collection('notifications')
            .doc();

        batch.set(notificationRef, {
          'title': 'New Appointment Request',
          'message': 'Patient ${_patientNameController.text} requested an appointment',
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
          'type': 'appointment_request',
          'appointmentId': appointmentId,
          'patientId': FirebaseAuth.instance.currentUser?.uid,
        });
      }
      await batch.commit();
    } catch (e) {
      print('Error sending notification to receptionist: $e');
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == successGreen ? Icons.check_circle_rounded : Icons.error_rounded,
              color: Colors.white,
            ),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _clearForm() {
    setState(() {
      selectedDoctor = null;
      selectedDate = null;
      selectedTime = null;
      _patientNameController.clear();
      _phoneNumberController.clear();
      _emailController.clear();
      _notesController.clear();
      _availableDates = [];
      _availableTimeSlots = [];
    });
  }

  Widget _buildConfirmationRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: patientBlue),
          SizedBox(width: 8),
          Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: patientBlue,
              fontSize: 14,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: patientGray,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGray,
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(patientBlue),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading...',
              style: TextStyle(color: patientBlue, fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      )
          : Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 30),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [patientBlue, lightPatientBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'BOOK AN APPOINTMENT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 56),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildInputField(
                    label: 'Name',
                    controller: _patientNameController,
                    placeholder: 'Enter your name',
                    keyboardType: TextInputType.name,
                    icon: Icons.person_rounded,
                  ),
                  const SizedBox(height: 20),
                  _buildInputField(
                    label: 'Email',
                    controller: _emailController,
                    placeholder: 'Enter your email',
                    keyboardType: TextInputType.emailAddress,
                    icon: Icons.email_rounded,
                  ),
                  const SizedBox(height: 20),
                  _buildInputField(
                    label: 'Phone Number',
                    controller: _phoneNumberController,
                    placeholder: 'Enter your phone number',
                    keyboardType: TextInputType.phone,
                    icon: Icons.phone_rounded,
                  ),
                  const SizedBox(height: 20),
                  _buildServiceField(),
                  const SizedBox(height: 20),
                  _buildDateField(),
                  const SizedBox(height: 20),
                  _buildTimeField(),
                  const SizedBox(height: 20),
                  _buildInputField(
                    label: 'Additional Notes',
                    controller: _notesController,
                    placeholder: 'Enter any additional information',
                    keyboardType: TextInputType.multiline,
                    maxLines: 4,
                    icon: Icons.note_rounded,
                  ),
                  const SizedBox(height: 30),
                  _buildBookButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String placeholder,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: patientBlue,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: TextStyle(
                color: patientGray,
                fontSize: 15,
              ),
              prefixIcon: icon != null ? Icon(icon, color: patientBlue, size: 20) : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: patientBlue, width: 2),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: icon != null ? 12 : 16,
                vertical: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: patientBlue,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: InkWell(
            onTap: () => _selectDate(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, color: patientBlue, size: 20),
                      SizedBox(width: 12),
                      Text(
                        selectedDate != null
                            ? DateFormat('MM/dd/yyyy').format(selectedDate!)
                            : 'Select a date',
                        style: TextStyle(
                          fontSize: 15,
                          color: selectedDate != null ? patientBlue : patientGray,
                          fontWeight: selectedDate != null ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    color: patientGray,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Time',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: patientBlue,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: InkWell(
            onTap: () => _selectTime(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded, color: patientBlue, size: 20),
                      SizedBox(width: 12),
                      Text(
                        selectedTime ?? 'Select a time',
                        style: TextStyle(
                          fontSize: 15,
                          color: selectedTime != null ? patientBlue : patientGray,
                          fontWeight: selectedTime != null ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    color: patientGray,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (selectedDate != null && _availableTimeSlots.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Available time slots:',
                  style: TextStyle(
                    color: patientGray,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableTimeSlots.map((slot) =>
                      InkWell(
                        onTap: () {
                          setState(() {
                            selectedTime = slot;
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: selectedTime == slot
                                ? patientBlue
                                : lightPatientBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: selectedTime == slot
                                  ? patientBlue
                                  : lightPatientBlue.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            slot,
                            style: TextStyle(
                              color: selectedTime == slot
                                  ? Colors.white
                                  : patientBlue,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                  ).toList(),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildServiceField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Healthcare Provider',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: patientBlue,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            value: selectedDoctor,
            decoration: InputDecoration(
              hintText: 'Select a healthcare provider',
              hintStyle: TextStyle(
                color: patientGray,
                fontSize: 15,
              ),
              prefixIcon: Icon(Icons.medical_services_rounded, color: patientBlue, size: 20),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: patientBlue, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 16,
              ),
            ),
            dropdownColor: Colors.white,
            items: [
              'Dr. Mancoba Shabalala - Psychiatrist',
              'Dr. Jessica Dlamini - Psychologist',
              'Dr. Emily Davis - Therapist',
              'Dr. Robert Wilson - Counselor',
            ].map((doctor) => DropdownMenuItem(
              value: doctor,
              child: Text(
                doctor,
                style: TextStyle(
                  color: patientBlue,
                  fontSize: 15,
                ),
              ),
            ))
                .toList(),
            onChanged: (value) {
              setState(() {
                selectedDoctor = value;
                selectedDate = null;
                selectedTime = null;
                _availableDates = [];
                _availableTimeSlots = [];
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBookButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [patientBlue, lightPatientBlue],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: patientBlue.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _confirmAppointment,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today_rounded, size: 20),
            SizedBox(width: 8),
            Text(
              'Book Appointment',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}