import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

class PatientDashboardWidgets {
  static const Color patientBlue = Color(0xFF1565C0);
  static const Color patientTeal = Color(0xFF00838F);
  static const Color patientGreen = Color(0xFF2E7D32);
  static const Color lightPatientBlue = Color(0xFF42A5F5);
  static const Color patientGray = Color(0xFF546E7A);
  static const Color lightGray = Color(0xFFF5F7FA);
  static const Color successGreen = Color(0xFF43A047);
  static const Color warningOrange = Color(0xFFFF9800);
  static const Color errorRed = Color(0xFFE53935);
  static const double _padding = 16.0;
  static const double _cardRadius = 12.0;
  static const double _spacing = 16.0;

  static final Logger _logger = Logger();

  static Widget buildHealthMetricCard(BuildContext context, String title, double? value, Color color) {
    final displayValue = value ?? 0.0;
    if (displayValue.isNaN || displayValue.isInfinite) {
      _logger.w('Invalid value for $title: $displayValue, defaulting to 0.0');
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardRadius)),
        child: const Padding(
          padding: EdgeInsets.all(_padding),
          child: Center(child: Text('Data unavailable')),
        ),
      );
    }
    final status = displayValue > 70 ? 'High' : (displayValue > 40 ? 'Moderate' : 'Low');
    final statusColor = displayValue > 70 ? errorRed : (displayValue > 40 ? warningOrange : patientBlue);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardRadius)),
      child: Padding(
        padding: const EdgeInsets.all(_padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: patientGray,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 12,
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: displayValue.clamp(0.0, 100.0) / 100,
                    backgroundColor: lightGray,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${displayValue.toInt().clamp(0, 100)}%',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: patientGray,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget buildTrendChart(BuildContext context, List<Map<String, dynamic>> stressData,
      List<Map<String, dynamic>> anxietyData, List<Map<String, dynamic>> depressionData, bool isLoading) {
    if (stressData.isEmpty && anxietyData.isEmpty && depressionData.isEmpty) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardRadius)),
        child: SizedBox(
          height: 300,
          child: Center(
            child: Text(
              isLoading ? 'Loading data...' : 'No data available. Please complete a self-assessment to view trends.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }

    final now = DateTime(2025, 8, 4, 14, 5); // 02:05 PM SAST, August 04, 2025
    List<BarChartGroupData> barGroups = [];
    for (int i = 0; i < 7; i++) {
      final currentDate = DateTime(now.year, now.month, now.day - i);
      final stressValue = stressData.firstWhere(
            (d) => (d['date'] as DateTime).isAtSameMomentAs(currentDate),
        orElse: () => {'date': currentDate, 'value': 0.0},
      )['value'] as double? ?? 0.0;
      final anxietyValue = anxietyData.firstWhere(
            (d) => (d['date'] as DateTime).isAtSameMomentAs(currentDate),
        orElse: () => {'date': currentDate, 'value': 0.0},
      )['value'] as double? ?? 0.0;
      final depressionValue = depressionData.firstWhere(
            (d) => (d['date'] as DateTime).isAtSameMomentAs(currentDate),
        orElse: () => {'date': currentDate, 'value': 0.0},
      )['value'] as double? ?? 0.0;

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: stressValue.clamp(0.0, 100.0),
              color: errorRed,
              width: 16,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            BarChartRodData(
              toY: anxietyValue.clamp(0.0, 100.0),
              color: warningOrange,
              width: 16,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            BarChartRodData(
              toY: depressionValue.clamp(0.0, 100.0),
              color: patientBlue,
              width: 16,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardRadius)),
      child: Padding(
        padding: const EdgeInsets.all(_padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mental Health Trends (Last 7 Days)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: patientGray,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 100,
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          final date = DateTime(now.year, now.month, now.day - value.toInt());
                          return Text(
                            DateFormat('MM/dd').format(date),
                            style: TextStyle(
                              fontSize: 12,
                              color: patientGray,
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
                            '${value.toInt()}%',
                            style: TextStyle(
                              fontSize: 12,
                              color: patientGray,
                            ),
                          );
                        },
                        interval: 20,
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  gridData: const FlGridData(show: true),
                  barGroups: barGroups,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Row(
                  children: [
                    Container(width: 12, height: 12, color: errorRed),
                    const SizedBox(width: 4),
                    Text('Stress', style: TextStyle(fontSize: 12, color: patientGray)),
                  ],
                ),
                Row(
                  children: [
                    Container(width: 12, height: 12, color: warningOrange),
                    const SizedBox(width: 4),
                    Text('Anxiety', style: TextStyle(fontSize: 12, color: patientGray)),
                  ],
                ),
                Row(
                  children: [
                    Container(width: 12, height: 12, color: patientBlue),
                    const SizedBox(width: 4),
                    Text('Depression', style: TextStyle(fontSize: 12, color: patientGray)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget buildMoodTrackingCard(BuildContext context, String? selectedMood,
      TextEditingController moodNoteController, bool isSubmittingMood, Function(String?) onMoodSelected,
      Function() onSubmitMood) {
    final moodOptions = [
      {'label': '😊 Great', 'value': 'great'},
      {'label': '🙂 Good', 'value': 'good'},
      {'label': '😐 Neutral', 'value': 'neutral'},
      {'label': '😟 Low', 'value': 'low'},
      {'label': '😔 Depressed', 'value': 'depressed'},
      {'label': '😰 Anxious', 'value': 'anxious'},
      {'label': '😡 Angry', 'value': 'angry'},
    ];

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardRadius)),
      child: Padding(
        padding: const EdgeInsets.all(_padding),
        child: Builder(
          builder: (context) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Mood Check-in',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: patientGray,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Tracking your mood helps identify patterns and improve your treatment.',
                  style: TextStyle(
                    fontSize: 14,
                    color: patientGray.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: moodOptions.map((mood) {
                    final isSelected = selectedMood == mood['value'];
                    return ChoiceChip(
                      label: Text(mood['label']!),
                      selected: isSelected,
                      onSelected: (selected) => onMoodSelected(selected ? mood['value'] as String : null),
                      selectedColor: lightPatientBlue.withOpacity(0.2),
                      backgroundColor: lightGray,
                      labelStyle: TextStyle(
                        color: isSelected ? patientBlue : patientGray,
                      ),
                      side: BorderSide(
                        color: isSelected ? patientBlue : patientGray.withOpacity(0.3),
                        width: 1,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: moodNoteController,
                  decoration: InputDecoration(
                    labelText: 'Add notes about your mood (optional)',
                    labelStyle: TextStyle(color: patientGray),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: patientGray.withOpacity(0.3)),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  maxLines: 3,
                  maxLength: 500,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: selectedMood == null || isSubmittingMood
                      ? null
                      : () => onSubmitMood(),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: patientBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: isSubmittingMood
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text('Submit Mood Check-in'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static Widget buildAppointmentCard(
      BuildContext context, Map<String, dynamic> appointment, VoidCallback onTap) {
    final dateTime = appointment['dateTime'] as DateTime;
    final isToday = dateTime.day == DateTime.now().day &&
        dateTime.month == DateTime.now().month &&
        dateTime.year == DateTime.now().year;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardRadius)),
      margin: const EdgeInsets.only(bottom: _spacing),
      child: InkWell(
        borderRadius: BorderRadius.circular(_cardRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(_padding),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 60,
                decoration: BoxDecoration(
                  color: isToday ? patientBlue : patientGray.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isToday ? 'Today' : DateFormat('MMM dd, yyyy').format(dateTime),
                      style: TextStyle(
                        fontSize: 12,
                        color: patientGray,
                      ),
                    ),
                    Text(
                      appointment['doctor'] as String? ?? 'Unknown',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: patientGray,
                      ),
                    ),
                    Text(
                      appointment['specialty'] as String? ?? 'Unknown',
                      style: TextStyle(
                        fontSize: 14,
                        color: patientGray.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Text(
                    DateFormat('h:mm a').format(dateTime),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: patientGray,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Chip(
                    label: Text(isToday ? 'Today' : 'Upcoming'),
                    backgroundColor: isToday ? patientBlue.withOpacity(0.2) : patientGray.withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: isToday ? patientBlue : patientGray,
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

  static Widget buildEmergencySupportCard(BuildContext context, VoidCallback onGetHelp) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: errorRed.withOpacity(0.05),
          border: Border.all(color: errorRed.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: errorRed,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Emergency Support',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: errorRed,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'If you need immediate help, click here for emergency resources.',
              style: TextStyle(
                fontSize: 14,
                color: patientGray,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onGetHelp,
              style: ElevatedButton.styleFrom(
                backgroundColor: errorRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Get Help Now'),
            ),
          ],
        ),
      ),
    );
  }
}