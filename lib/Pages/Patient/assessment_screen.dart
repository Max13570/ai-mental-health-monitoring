import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';

class MentalHealthAssessmentScreen extends StatefulWidget {
  const MentalHealthAssessmentScreen({super.key});

  @override
  State<MentalHealthAssessmentScreen> createState() =>
      _MentalHealthAssessmentScreenState();
}

enum Section { depression, anxiety, stress }

class _MentalHealthAssessmentScreenState
    extends State<MentalHealthAssessmentScreen> with SingleTickerProviderStateMixin {
  static const Color medicalBlue = Color(0xFF1E3A8A);
  static const Color medicalTeal = Color(0xFF0F766E);
  static const Color lightMedicalBlue = Color(0xFF3B82F6);
  static const Color medicalGray = Color(0xFF64748B);
  static const Color lightGray = Color(0xFFF8FAFC);
  static const Color successGreen = Color(0xFF10B981);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color warningOrange = Color(0xFFF59E0B);

  static const double _screenPadding = 16.0;
  static const double _cardRadius = 12.0;
  static const double _widgetSpacing = 16.0;
  static const double _contentPadding = 16.0;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  int _currentSection = 0;
  int _currentQuestion = 0;
  bool _isLoading = false;
  String? _backendError;
  String? _overallSeverityPrediction;

  final List<int> _depressionAnswers = [];
  final List<int> _anxietyAnswers = [];
  final List<int> _stressAnswers = [];

  static const List<String> _options = [
    'Not at all',
    'Several days',
    'More than half the days',
    'Nearly every day',
  ];

  static const List<Map<String, dynamic>> _sections = [
    {
      'type': Section.depression,
      'title': 'Depression Assessment (PHQ-9)',
      'introduction': 'Over the last 2 weeks, how often have you been bothered by any of the following problems?',
      'questions': [
        'Little interest or pleasure in doing things?',
        'Feeling down, depressed, or hopeless?',
        'Trouble falling or staying asleep, or sleeping too much?',
        'Feeling tired or having little energy?',
        'Poor appetite or overeating?',
        'Feeling bad about yourself — or that you are a failure or have let yourself or your family down?',
        'Trouble concentrating on things, such as reading the newspaper or watching television?',
        'Moving or speaking so slowly that other people could have noticed? Or the opposite — being so fidgety or restless that you have been moving a lot more than usual?',
        'Thoughts that you would be better off dead or of hurting yourself in some way?',
      ],
    },
    {
      'type': Section.anxiety,
      'title': 'Anxiety Assessment (GAD-7)',
      'introduction': 'Over the last 2 weeks, how often have you been bothered by the following problems?',
      'questions': [
        'Feeling nervous, anxious, or on edge?',
        'Not being able to stop or control worrying?',
        'Worrying too much about different things?',
        'Trouble relaxing?',
        'Being so restless that it is hard to sit still?',
        'Becoming easily annoyed or irritable?',
        'Feeling afraid as if something awful might happen?',
      ],
    },
    {
      'type': Section.stress,
      'title': 'Stress Assessment (PSS-6 Adapted)',
      'introduction': 'In the last month, how often have you felt or experienced the following?',
      'questions': [
        'How often have you felt that you were unable to control the important things in your life?',
        'How often have you felt nervous and stressed?',
        'How often have you felt upset because of something that happened unexpectedly?',
        'How often have you found that you could not cope with all the things that you had to do?',
        'How often have you felt difficulties were piling up so high that you could not overcome them?',
        'How often have you felt that you were struggling to stay on top of things?',
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnswers();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _initializeAnswers() {
    _depressionAnswers.clear();
    _anxietyAnswers.clear();
    _stressAnswers.clear();
    _depressionAnswers.addAll(List.filled(_sections[0]['questions'].length, -1));
    _anxietyAnswers.addAll(List.filled(_sections[1]['questions'].length, -1));
    _stressAnswers.addAll(List.filled(_sections[2]['questions'].length, -1));
  }

  List<int> _currentAnswers() {
    return switch (_sections[_currentSection]['type'] as Section) {
      Section.depression => _depressionAnswers,
      Section.anxiety => _anxietyAnswers,
      Section.stress => _stressAnswers,
    };
  }

  void _selectAnswer(int selectedIndex) {
    setState(() {
      _currentAnswers()[_currentQuestion] = selectedIndex;
      _animationController.reset();
      _animationController.forward();
    });
  }

  Future<void> _saveAssessmentResults() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _backendError = null;
      _overallSeverityPrediction = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Please sign in to save your assessment.');
      }

      if (!_areAllQuestionsAnswered()) {
        throw Exception('Please complete all questions to proceed.');
      }

      final depressionScore = _depressionAnswers.fold(0, (a, b) => a + b);
      final anxietyScore = _anxietyAnswers.fold(0, (a, b) => a + b);
      final stressScore = _stressAnswers.fold(0, (a, b) => a + b);

      _overallSeverityPrediction = await _sendScores(
          stressScore, anxietyScore, depressionScore);

      final depressionResult = _riskAndRecommendationDepression(depressionScore);
      final anxietyResult = _riskAndRecommendationAnxiety(anxietyScore);
      final stressResult = _riskAndRecommendationStress(stressScore);

      // Write to user's assessments
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('assessments')
          .add({
        'timestamp': FieldValue.serverTimestamp(),
        'depression': {
          'score': depressionScore,
          'risk': depressionResult.$1,
          'recommendation': depressionResult.$2,
          'answers': _depressionAnswers,
        },
        'anxiety': {
          'score': anxietyScore,
          'risk': anxietyResult.$1,
          'recommendation': anxietyResult.$2,
          'answers': _anxietyAnswers,
        },
        'stress': {
          'score': stressScore,
          'risk': stressResult.$1,
          'recommendation': stressResult.$2,
          'answers': _stressAnswers,
        },
        'overallSeverity': _overallSeverityPrediction,
      });

      // Write to dashboard metrics collection for trend cards
      await FirebaseFirestore.instance
          .collection('patientMetrics')
          .doc(user.uid)
          .collection('scores')
          .add({
        'date': FieldValue.serverTimestamp(),
        'stress': stressScore,
        'anxiety': anxietyScore,
        'depression': depressionScore,
      });

      if (mounted) {
        _showSnackBar('Assessment successfully saved.', successGreen);
      }
    } catch (e) {
      debugPrint('Error saving assessment: $e');
      if (mounted) {
        _showSnackBar('Failed to save results: ${e.toString()}', errorRed);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSummary();
      }
    }
  }

  Future<String?> _sendScores(int stressScore, int anxietyScore, int depressionScore) async {
    final url = Uri.parse('http://10.0.2.2:8000/predict_severity/');
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          'stress_score': stressScore,
          'anxiety_score': anxietyScore,
          'depression_score': depressionScore,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        debugPrint("Severity Prediction: ${result['severity']}");
        return result['severity'] as String?;
      } else {
        debugPrint('Backend error: ${response.statusCode}: ${response.body}');
        setState(() {
          _backendError = 'Unable to fetch analysis: Server error ${response.statusCode}.';
        });
        return null;
      }
    } catch (e) {
      debugPrint('Network error: $e');
      setState(() {
        _backendError = 'Network issue: Unable to connect to analysis service.';
      });
      return null;
    }
  }

  bool _areAllQuestionsAnswered() {
    return !_depressionAnswers.contains(-1) &&
        !_anxietyAnswers.contains(-1) &&
        !_stressAnswers.contains(-1);
  }

  void _goNext() {
    final answers = _currentAnswers();
    if (_currentQuestion < answers.length && answers[_currentQuestion] == -1) {
      _showSnackBar('Please select an option to continue.', errorRed);
      return;
    }

    final questions = _sections[_currentSection]['questions'] as List<String>;

    setState(() {
      _animationController.reset();
      if (_currentQuestion < questions.length - 1) {
        _currentQuestion++;
      } else if (_currentSection < _sections.length - 1) {
        _currentSection++;
        _currentQuestion = 0;
      } else {
        _saveAssessmentResults();
      }
      _animationController.forward();
    });
  }

  void _goPrevious() {
    setState(() {
      _animationController.reset();
      if (_currentQuestion > 0) {
        _currentQuestion--;
      } else if (_currentSection > 0) {
        _currentSection--;
        final previousSectionQuestions =
        _sections[_currentSection]['questions'] as List<String>;
        _currentQuestion = previousSectionQuestions.length - 1;
      }
      _animationController.forward();
    });
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
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(_widgetSpacing),
      ),
    );
  }

  void _showSummary() {
    final depressionScore = _depressionAnswers.fold(0, (a, b) => a + b);
    final anxietyScore = _anxietyAnswers.fold(0, (a, b) => a + b);
    final stressScore = _stressAnswers.fold(0, (a, b) => a + b);

    final depressionResult = _riskAndRecommendationDepression(depressionScore);
    final anxietyResult = _riskAndRecommendationAnxiety(anxietyScore);
    final stressResult = _riskAndRecommendationStress(stressScore);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardRadius)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: successGreen, size: 28),
            const SizedBox(width: 12),
            Text(
              'Assessment Complete',
              style: GoogleFonts.inter(
                color: medicalBlue,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Your mental health assessment has been completed successfully.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: medicalGray,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: _widgetSpacing),
              Text(
                'Note: This assessment is for informational purposes only and does not replace professional medical advice. Please consult a qualified mental health professional for a comprehensive evaluation.',
                style: GoogleFonts.inter(
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                  color: medicalGray,
                  height: 1.5,
                ),
              ),
              if (_backendError != null) ...[
                const SizedBox(height: _widgetSpacing),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: errorRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Analysis Issue: $_backendError',
                    style: GoogleFonts.inter(
                      color: errorRed,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
              if (_overallSeverityPrediction != null) ...[
                const SizedBox(height: _widgetSpacing * 1.5),
                Text(
                  'Overall Severity (AI Analysis):',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: medicalBlue,
                  ),
                ),
                const SizedBox(height: _widgetSpacing / 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _getRiskColor(_overallSeverityPrediction!).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _overallSeverityPrediction!,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _getRiskColor(_overallSeverityPrediction!),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: _widgetSpacing * 1.5),
              Text(
                'Your Results:',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: medicalBlue,
                ),
              ),
              const SizedBox(height: _widgetSpacing),
              _buildSummaryRow('Depression', depressionScore, depressionResult),
              const SizedBox(height: _widgetSpacing),
              _buildSummaryRow('Anxiety', anxietyScore, anxietyResult),
              const SizedBox(height: _widgetSpacing),
              _buildSummaryRow('Stress', stressScore, stressResult),
              const SizedBox(height: _widgetSpacing * 1.5),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: errorRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'If you are in crisis or having thoughts of self-harm, please contact a mental health professional or emergency helpline immediately.',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: errorRed,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _restartAssessment();
            },
            style: TextButton.styleFrom(
              foregroundColor: medicalBlue,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: Text(
              'Retake Assessment',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/report');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: medicalBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              'View Detailed Report',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
            style: TextButton.styleFrom(
              foregroundColor: medicalGray,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: Text(
              'Close',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
      String title, int score, (String risk, String recommendation) result) {
    final color = _getRiskColor(result.$1);

    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(_contentPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$title Score: $score',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: medicalBlue,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                result.$1,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Recommendations:',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: medicalBlue,
              ),
            ),
            const SizedBox(height: 4),
            ...result.$2.split('\n').map((line) => Padding(
              padding: const EdgeInsets.only(left: 12, top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: medicalGray,
                      height: 1.5,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      line,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: medicalGray,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Color _getRiskColor(String risk) {
    final lowerRisk = risk.toLowerCase();
    if (lowerRisk.contains('minimal') || lowerRisk.contains('low') || lowerRisk.contains('none')) {
      return successGreen;
    }
    if (lowerRisk.contains('mild')) {
      return lightMedicalBlue;
    }
    if (lowerRisk.contains('moderate')) {
      return warningOrange;
    }
    if (lowerRisk.contains('severe') || lowerRisk.contains('high') || lowerRisk.contains('extreme')) {
      return errorRed;
    }
    return medicalGray;
  }

  void _restartAssessment() {
    setState(() {
      _currentSection = 0;
      _currentQuestion = 0;
      _initializeAnswers();
      _backendError = null;
      _overallSeverityPrediction = null;
      _animationController.reset();
      _animationController.forward();
    });
  }

  (String risk, String recommendation) _riskAndRecommendationDepression(int score) {
    if (score <= 4) {
      return (
      'Minimal Depression',
      'Maintain healthy routines: Regular exercise and balanced diet.\n'
          'Stay socially connected: Spend time with supportive friends and family.\n'
          'Practice mindfulness: Use apps or guided meditations for daily calm.\n'
          'Monitor your mood: Keep a simple mood journal to track any changes.'
      );
    } else if (score <= 9) {
      return (
      'Mild Depression',
      'Explore relaxation techniques: Deep breathing, yoga, or progressive muscle relaxation.\n'
          'Engage in enjoyable activities: Reconnect with hobbies or discover new ones.\n'
          'Talk with a trusted person: Share your feelings with a friend or family member.\n'
          'Consider initial support: Consult a counselor for early guidance.'
      );
    } else if (score <= 14) {
      return (
      'Moderate Depression',
      'Seek professional consultation: A mental health professional can provide a proper assessment.\n'
          'Consider structured therapy: Cognitive Behavioral Therapy (CBT) or Interpersonal Therapy (IPT).\n'
          'Utilize self-help resources: Reputable books or online programs on depression management.\n'
          'Ensure consistent sleep: Establish a regular sleep schedule.'
      );
    } else if (score <= 19) {
      return (
      'Moderately Severe Depression',
      'Urgent professional evaluation: Schedule an appointment with a psychiatrist promptly.\n'
          'Commit to consistent therapy: Regular sessions are crucial for managing symptoms.\n'
          'Discuss medication options: A psychiatrist can assess if antidepressants are suitable.\n'
          'Build a support network: Inform trusted individuals about your situation.'
      );
    } else {
      return (
      'Severe Depression',
      'Immediate professional help: Contact a crisis helpline or emergency mental health service.\n'
          'Develop a safety plan: Work with a professional to manage severe symptoms.\n'
          'Engage in consistent treatment: Therapy, medication, and possibly hospitalization.\n'
          'Focus on basic self-care: Ensure nutrition, hydration, and minimal activity.'
      );
    }
  }

  (String risk, String recommendation) _riskAndRecommendationAnxiety(int score) {
    if (score <= 4) {
      return (
      'Minimal Anxiety',
      'Maintain a healthy lifestyle: Regular exercise, balanced diet, and adequate sleep.\n'
          'Practice stress management: Incorporate daily relaxation and mindfulness.\n'
          'Limit caffeine and alcohol: These can exacerbate anxiety symptoms.\n'
          'Stay organized: Manage tasks efficiently to reduce overwhelm.'
      );
    } else if (score <= 9) {
      return (
      'Mild Anxiety',
      'Practice breathing exercises: Deep abdominal breathing to calm the nervous system.\n'
          'Engage in meditation or yoga: Improve focus and reduce anxious thoughts.\n'
          'Incorporate physical activity: Regular exercise is a powerful anxiety reducer.\n'
          'Journaling: Write down worries to process and gain perspective.'
      );
    } else if (score <= 14) {
      return (
      'Moderate Anxiety',
      'Seek guidance from a therapist: Cognitive Behavioral Therapy (CBT) is effective.\n'
          'Learn coping strategies: Manage anxious thoughts and physical symptoms.\n'
          'Join a support group: Connect with others for shared strategies.\n'
          'Limit exposure to stressors: Identify and minimize anxiety triggers.'
      );
    } else {
      return (
      'Severe Anxiety',
      'Consult a healthcare professional: Assess for underlying causes and treatment options.\n'
          'Explore specialized therapy: Exposure Therapy or Acceptance and Commitment Therapy (ACT).\n'
          'Discuss medication: Anti-anxiety medications may help manage symptoms.\n'
          'Develop a crisis plan: Strategies for managing panic attacks or overwhelming anxiety.'
      );
    }
  }

  (String risk, String recommendation) _riskAndRecommendationStress(int score) {
    if (score <= 6) {
      return (
      'Low Stress',
      'Continue effective stress management: Maintain your current strategies.\n'
          'Practice preventative self-care: Dedicate time to relaxation.\n'
          'Maintain work-life balance: Protect personal time from professional demands.\n'
          'Foster positive relationships: Strong social bonds buffer stress.'
      );
    } else if (score <= 12) {
      return (
      'Moderate Stress',
      'Integrate relaxation techniques: Deep breathing or guided imagery.\n'
          'Increase physical activity: Regular exercise relieves stress.\n'
          'Improve time management: Prioritize tasks and avoid overcommitment.\n'
          'Set healthy boundaries: Learn to say no to additional responsibilities.\n'
          'Pursue hobbies: Engage in activities for mental relaxation.'
      );
    } else {
      return (
      'High Stress',
      'Seek professional counseling: Identify stressors and develop coping skills.\n'
          'Explore stress reduction programs: Workshops on stress management techniques.\n'
          'Develop healthy coping mechanisms: Avoid unhealthy habits like emotional isolation.\n'
          'Consider a medical check-up: Rule out physical health issues contributing to stress.\n'
          'Prioritize sleep: Ensure 7-9 hours of quality sleep.'
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final section = _sections[_currentSection];
    final questions = section['questions'] as List<String>;
    final currentAnswers = _currentAnswers();
    final selectedAnswer = currentAnswers[_currentQuestion];
    final String introductionText = section['introduction'] as String;

    int totalQuestions = _sections.fold(0, (sum, section) => sum + (section['questions'] as List).length);
    int answeredQuestions =
        _depressionAnswers.where((a) => a != -1).length +
            _anxietyAnswers.where((a) => a != -1).length +
            _stressAnswers.where((a) => a != -1).length;

    return Scaffold(
      backgroundColor: lightGray,
      appBar: AppBar(
        title: Text(
          'Mental Health Assessment',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: medicalBlue,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded, color: Colors.white),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardRadius)),
                  backgroundColor: Colors.white,
                  title: Text(
                    'About This Assessment',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: medicalBlue,
                    ),
                  ),
                  content: Text(
                    'This assessment uses standardized tools (PHQ-9, GAD-7, PSS-6) to evaluate your mental health. Results are for informational purposes only. Consult a professional for a clinical diagnosis.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: medicalGray,
                      height: 1.5,
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: medicalGray,
                      ),
                      child: Text(
                        'Close',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
            tooltip: 'About',
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(medicalBlue),
                strokeWidth: 5,
              ),
              const SizedBox(height: _widgetSpacing),
              Text(
                'Processing your assessment...',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: medicalGray,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        )
            : Padding(
          padding: const EdgeInsets.all(_screenPadding),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  section['title'] as String,
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: medicalBlue,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: _widgetSpacing / 2),
                Text(
                  introductionText,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: medicalGray,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: _widgetSpacing),
                Stack(
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: medicalGray.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(_cardRadius),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: answeredQuestions / totalQuestions,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: successGreen,
                          borderRadius: BorderRadius.circular(_cardRadius),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: _widgetSpacing / 2),
                Text(
                  'Progress: $answeredQuestions/$totalQuestions questions completed',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: medicalGray,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: _widgetSpacing),
                Text(
                  'Question ${_currentQuestion + 1}/${questions.length}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: medicalGray,
                  ),
                ),
                const SizedBox(height: _widgetSpacing / 2),
                Container(
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
                  child: Padding(
                    padding: const EdgeInsets.all(_contentPadding),
                    child: Text(
                      questions[_currentQuestion],
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: medicalBlue,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: _widgetSpacing),
                Expanded(
                  child: ListView.builder(
                    itemCount: _options.length,
                    itemBuilder: (_, index) => GestureDetector(
                      onTap: () => _selectAnswer(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(_cardRadius),
                          border: Border.all(
                            color: selectedAnswer == index ? medicalBlue : medicalGray.withOpacity(0.2),
                            width: selectedAnswer == index ? 2 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: _contentPadding,
                            vertical: _contentPadding * 0.8,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _options[index],
                                  style: GoogleFonts.inter(
                                    color: selectedAnswer == index ? medicalBlue : medicalGray,
                                    fontWeight: selectedAnswer == index ? FontWeight.bold : FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              if (selectedAnswer == index)
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: medicalBlue,
                                  size: 24,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: _widgetSpacing),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: (_currentQuestion > 0 || _currentSection > 0)
                            ? _goPrevious
                            : null,
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                        label: Text(
                          'Previous',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: medicalBlue,
                          side: BorderSide(color: medicalBlue.withOpacity(0.5)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: _widgetSpacing,
                            vertical: _widgetSpacing,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: _widgetSpacing),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _goNext,
                        icon: Icon(
                          _currentSection == _sections.length - 1 &&
                              _currentQuestion == questions.length - 1
                              ? Icons.check_circle_rounded
                              : Icons.arrow_forward_ios_rounded,
                          size: 18,
                        ),
                        label: Text(
                          _currentSection == _sections.length - 1 &&
                              _currentQuestion == questions.length - 1
                              ? 'Complete'
                              : 'Next',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: medicalBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: _widgetSpacing,
                            vertical: _widgetSpacing,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}