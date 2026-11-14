import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'Pages/common.dart';
import 'firebase_options.dart';

// Temporary SplashScreen widget
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

// Temporary ErrorScreen widget
class ErrorScreen extends StatelessWidget {
  const ErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('An error occurred. Please try again.')),
    );
  }
}

// Fallback MentalHealthReportScreen if not defined in common.dart
class FallbackMentalHealthReportScreen extends StatelessWidget {
  const FallbackMentalHealthReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: const Center(child: Text('Mental Health Report Screen')),
    );
  }
}

// AppState for managing the user's role globally using Provider
class AppState extends ChangeNotifier {
  String _role = 'patient';
  String get role => _role;

  void setRole(String role) {
    _role = role;
    notifyListeners();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Hive.initFlutter();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (!kIsWeb) {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    }
    await initializeDateFormatting();
    debugPrint('App initialization completed successfully');
  } catch (e) {
    debugPrint('Initialization failed: $e');
    runApp(const MaterialApp(home: ErrorScreen()));
    return;
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const MentalHealthApp(),
    ),
  );
}

class MentalHealthApp extends StatelessWidget {
  const MentalHealthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mental Health Monitoring System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
          surfaceContainerHighest: Colors.grey[100],
        ),
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Inter',
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
          ),
          bodyMedium: TextStyle(fontSize: 16, fontFamily: 'Inter'),
        ),
      ),
      routes: {
        '/login': (context) => LoginScreen(
          role: ModalRoute.of(context)?.settings.arguments as String? ?? 'patient',
        ),
        '/signup': (context) => SignupScreen(
          role: ModalRoute.of(context)?.settings.arguments as String? ?? 'patient',
        ),
        '/patient_reports': (context) => const FallbackMentalHealthReportScreen(),
        '/patient_dashboard': (context) => const PatientDashboardScreen(),
        '/doctor_dashboard': (context) => const DoctorDashboardScreen(),
        '/admin_dashboard': (context) => const AdminDashboardScreen(),
        '/receptionist_dashboard': (context) => const ReceptionistDashboardScreen(),
      },
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SplashScreen();
          }
          if (snapshot.hasError) {
            debugPrint('Auth state error: ${snapshot.error}');
            return const ErrorScreen();
          }
          final user = snapshot.data;
          if (user == null) {
            return const WelcomeScreen();
          }

          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SplashScreen();
              }
              if (snapshot.hasError ||
                  !snapshot.hasData ||
                  snapshot.data?.data() == null) {
                debugPrint('User data fetch error: ${snapshot.error}');
                FirebaseAuth.instance.signOut();
                return const WelcomeScreen();
              }

              final data = snapshot.data!.data() as Map<String, dynamic>;
              final role = data['role'] as String? ?? 'patient';
              Provider.of<AppState>(context, listen: false).setRole(role);

              if (role == 'patient') {
                return const PatientDashboardScreen();
              } else if (role == 'provider') {
                return const DoctorDashboardScreen();
              } else if (role == 'admin') {
                return const AdminDashboardScreen();
              } else if (role == 'receptionist') {
                return const ReceptionistDashboardScreen();
              } else {
                debugPrint('Unknown role: $role. Logging out.');
                FirebaseAuth.instance.signOut();
                return const WelcomeScreen();
              }
            },
          );
        },
      ),
    );
  }
}