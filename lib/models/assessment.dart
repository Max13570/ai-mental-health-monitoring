// lib/models/assessment.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents the details of a single assessment category (Depression, Anxiety, Stress).
class AssessmentDetail {
  final int score;
  final String risk;
  final String recommendation;

  const AssessmentDetail({
    required this.score,
    required this.risk,
    required this.recommendation,
  });

  /// Factory constructor to create an AssessmentDetail from a Firestore map.
  factory AssessmentDetail.fromMap(Map<String, dynamic> map) {
    return AssessmentDetail(
      score:
          (map['score'] as num?)?.toInt() ??
          0, // Handle potential double from Firestore, convert to int
      risk: map['risk'] as String? ?? 'Unknown',
      recommendation: map['recommendation'] as String? ?? 'No recommendation',
    );
  }
}

/// Represents a complete user assessment entry from Firestore.
class UserAssessment {
  final String id;
  final DateTime timestamp;
  final AssessmentDetail? depression;
  final AssessmentDetail? anxiety;
  final AssessmentDetail? stress;

  const UserAssessment({
    required this.id,
    required this.timestamp,
    this.depression,
    this.anxiety,
    this.stress,
  });

  /// Factory constructor to create a UserAssessment from a Firestore DocumentSnapshot.
  factory UserAssessment.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    if (data == null) {
      throw StateError('Document data is null for assessment ID: ${doc.id}');
    }

    final timestamp =
        (data['timestamp'] as Timestamp?)?.toDate() ??
        DateTime.now(); // Provide a default or handle null

    return UserAssessment(
      id: doc.id,
      timestamp: timestamp,
      depression: data['depression'] != null
          ? AssessmentDetail.fromMap(data['depression'] as Map<String, dynamic>)
          : null,
      anxiety: data['anxiety'] != null
          ? AssessmentDetail.fromMap(data['anxiety'] as Map<String, dynamic>)
          : null,
      stress: data['stress'] != null
          ? AssessmentDetail.fromMap(data['stress'] as Map<String, dynamic>)
          : null,
    );
  }
}
