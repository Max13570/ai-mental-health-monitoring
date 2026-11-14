import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ReceptionistDateManagementScreen extends StatefulWidget {
  const ReceptionistDateManagementScreen({super.key});

  @override
  State<ReceptionistDateManagementScreen> createState() =>
      _ReceptionistDateManagementScreenState();
}

class _ReceptionistDateManagementScreenState
    extends State<ReceptionistDateManagementScreen> {
  // Professional Medical Color Scheme (matching DoctorDashboardScreen)
  static const Color medicalBlue = Color(0xFF1E3A8A);
  static const Color medicalTeal = Color(0xFF0F766E);
  static const Color lightMedicalBlue = Color(0xFF3B82F6);
  static const Color medicalGray = Color(0xFF64748B);
  static const Color lightGray = Color(0xFFF8FAFC);
  static const Color successGreen = Color(0xFF10B981);
  static const Color errorRed = Color(0xFFEF4444);

  // Constants for styling (matching DoctorDashboardScreen)
  static const double _padding = 16.0;
  static const double _cardRadius = 12.0;
  static const double _spacing = 16.0;

  String? selectedDoctor;
  DateTime? selectedDate;
  TimeOfDay? selectedStartTime;
  TimeOfDay? selectedEndTime;
  bool _isLoading = false;

  // Consistent doctor list with patient app
  final List<String> doctors = [
    'Dr. Mancoba Shabalala - Psychiatrist',
    'Dr. Jessica Dlamini - Psychologist',
    'Dr. Emily Davis - Therapist',
    'Dr. Robert Wilson - Counselor',
  ];

  Future<void> _saveAvailability() async {
    if (selectedDoctor == null ||
        selectedDate == null ||
        selectedStartTime == null ||
        selectedEndTime == null) {
      _showSnackBar('Please fill all fields', errorRed);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Convert to 24-hour format for consistency
      final startTime =
          '${selectedStartTime!.hour.toString().padLeft(2, '0')}:${selectedStartTime!.minute.toString().padLeft(2, '0')}';
      final endTime =
          '${selectedEndTime!.hour.toString().padLeft(2, '0')}:${selectedEndTime!.minute.toString().padLeft(2, '0')}';

      await FirebaseFirestore.instance.collection('doctor_availability').add({
        'doctor': selectedDoctor,
        'date': Timestamp.fromDate(selectedDate!),
        'startTime': startTime,
        'endTime': endTime,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _showSnackBar('Availability saved successfully', successGreen);
      _clearForm();
    } catch (e) {
      _showSnackBar('Error saving availability: $e', errorRed);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    setState(() {
      selectedDoctor = null;
      selectedDate = null;
      selectedStartTime = null;
      selectedEndTime = null;
    });
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == successGreen ? Icons.check_circle_rounded : Icons.error_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGray,
      appBar: AppBar(
        backgroundColor: medicalBlue,
        foregroundColor: Colors.white,
        title: const Text('Manage Doctor Availability'),
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: medicalBlue))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(_padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDoctorDropdown(),
            const SizedBox(height: _spacing),
            _buildDatePicker(),
            const SizedBox(height: _spacing),
            _buildTimeRangePicker(),
            const SizedBox(height: _spacing * 2),
            _buildSaveButton(),
            const SizedBox(height: _spacing * 2),
            _buildAvailabilityList(),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Healthcare Provider',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: medicalBlue,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: selectedDoctor,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_cardRadius),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_cardRadius),
              borderSide: BorderSide(color: medicalBlue, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          items: doctors.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(
                value,
                style: TextStyle(color: medicalBlue),
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              selectedDoctor = newValue;
            });
          },
          hint: Text(
            'Select a healthcare provider',
            style: TextStyle(color: medicalGray),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: medicalBlue,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              builder: (context, child) {
                return Theme(
                  data: ThemeData.light().copyWith(
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
            if (picked != null) {
              setState(() {
                selectedDate = picked;
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  selectedDate != null
                      ? DateFormat('MMM dd, yyyy').format(selectedDate!)
                      : 'Select a date',
                  style: TextStyle(
                    fontSize: 14,
                    color: selectedDate != null ? medicalBlue : medicalGray,
                  ),
                ),
                Icon(Icons.calendar_today_rounded, color: medicalBlue, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeRangePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Available Time Range',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: medicalBlue,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () async {
                  final TimeOfDay? picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                    builder: (context, child) {
                      return Theme(
                        data: ThemeData.light().copyWith(
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
                  if (picked != null) {
                    setState(() {
                      selectedStartTime = picked;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        selectedStartTime != null
                            ? selectedStartTime!.format(context)
                            : 'Start Time',
                        style: TextStyle(
                          fontSize: 14,
                          color: selectedStartTime != null ? medicalBlue : medicalGray,
                        ),
                      ),
                      Icon(Icons.access_time_rounded, color: medicalBlue, size: 20),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final TimeOfDay? picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                    builder: (context, child) {
                      return Theme(
                        data: ThemeData.light().copyWith(
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
                  if (picked != null) {
                    setState(() {
                      selectedEndTime = picked;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        selectedEndTime != null
                            ? selectedEndTime!.format(context)
                            : 'End Time',
                        style: TextStyle(
                          fontSize: 14,
                          color: selectedEndTime != null ? medicalBlue : medicalGray,
                        ),
                      ),
                      Icon(Icons.access_time_rounded, color: medicalBlue, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _saveAvailability,
      style: ElevatedButton.styleFrom(
        backgroundColor: medicalBlue,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_cardRadius),
        ),
        padding: const EdgeInsets.symmetric(vertical: _padding),
      ),
      child: _isLoading
          ? const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 2,
        ),
      )
          : const Text(
        'Save Availability',
        style: TextStyle(fontSize: 16),
      ),
    );
  }

  Widget _buildAvailabilityList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Current Availability',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: medicalBlue,
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('doctor_availability')
              .orderBy('date')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: medicalBlue));
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Container(
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
                        Icons.calendar_today_rounded,
                        size: 48,
                        color: medicalGray,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No availability entries found',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: medicalBlue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add a new availability to see it here',
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

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final doc = snapshot.data!.docs[index];
                final data = doc.data() as Map<String, dynamic>;
                final date = (data['date'] as Timestamp).toDate();
                final isToday = date.day == DateTime.now().day &&
                    date.month == DateTime.now().month &&
                    date.year == DateTime.now().year;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
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
                  child: ListTile(
                    contentPadding: EdgeInsets.all(_padding),
                    leading: Container(
                      width: 4,
                      height: 60,
                      decoration: BoxDecoration(
                        color: isToday ? medicalTeal : lightMedicalBlue,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    title: Text(
                      data['doctor'] ?? 'Unknown Doctor',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: medicalBlue,
                      ),
                    ),
                    subtitle: Text(
                      '${DateFormat('MMM dd, yyyy').format(date)} | ${data['startTime']} - ${data['endTime']}',
                      style: TextStyle(
                        fontSize: 13,
                        color: medicalGray,
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.delete_rounded, color: errorRed),
                      onPressed: () => _deleteAvailability(doc.id),
                      tooltip: 'Delete availability',
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Future<void> _deleteAvailability(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('doctor_availability')
          .doc(docId)
          .delete();
      _showSnackBar('Availability deleted', successGreen);
    } catch (e) {
      _showSnackBar('Error deleting: $e', errorRed);
    }
  }
}