import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'common.dart' hide PatientDashboardScreen;
import 'Patient/patient_dashboard_screen.dart';
import 'Doctor/doctor_dashboard_screen.dart';
import 'Admin/admin_dashboard_screen.dart';
import 'Receptionist/receptionist_dashboard_screen.dart';
import 'signup_screen.dart';
import 'role_selection_screen.dart';

class LoginScreen extends StatefulWidget {
  final String role;
  const LoginScreen({super.key, required this.role});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  // Design Constants
  static const double _padding = 24.0;
  static const double _spacing = 16.0;
  static const double _avatarRadius = 40.0;
  static const double _inputBorderRadius = 8.0;
  static const double _buttonBorderRadius = 8.0;
  static const double _buttonHeight = 50.0;

  // Color Scheme - Matching first LoginScreen
  static const Color primaryColor = Color(0xFF1E3A8A); // Medical Blue
  static const Color errorColor = Color(0xFFC62828);
  static const Color textColor = Colors.white;

  // Gradient background
  static const Gradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF1E3A8A), // Medical Blue
      Color(0xFF3B82F6), // Lighter Blue
    ],
  );

  // Form Controllers
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // State Variables
  bool _obscurePassword = true;
  bool _isLoading = false;

  // Animations
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutQuart,
    ));
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  // Cross-platform back button handler
  Future<bool> _onWillPop() async {
    if (!_isLoading) {
      _navigateToRoleSelection();
      return false; // Prevent default back behavior
    }
    return false;
  }

  void _navigateToRoleSelection() {
    try {
      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('Haptic feedback not available: $e');
    }
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const RoleSelectionScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  // Validation Methods
  String? _validateEmail(String? value) {
    value = value?.trim();
    if (value == null || value.isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$');
    if (!emailRegex.hasMatch(value)) return 'Enter a valid email address';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  // Authentication Methods
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      final userDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid);
      final snapshotDoc = await userDocRef.get();
      String roleDoc = widget.role;
      if (snapshotDoc.data()?['role'] == null) {
        await userDocRef.set({'role': widget.role}, SetOptions(merge: true));
      } else {
        roleDoc = snapshotDoc.data()!['role'] as String;
      }
      _showSnackBar('Login successful!');
      _navigateToDashboardScreen(roleDoc);
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found with this email';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email address';
          break;
        default:
          errorMessage = 'Login failed: ${e.message ?? 'Unknown error'}';
      }
      _showSnackBar(errorMessage);
    } catch (e) {
      _showSnackBar('An unexpected error occurred: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToDashboardScreen(String role) {
    Widget destinationScreen;
    switch (role) {
      case Roles.provider:
        destinationScreen = const DoctorDashboardScreen();
        break;
      case Roles.admin:
        destinationScreen = const AdminDashboardScreen();
        break;
      case Roles.receptionist:
        destinationScreen = const ReceptionistDashboardScreen();
        break;
      case Roles.patient:
      default:
        destinationScreen = const PatientDashboardScreen();
        break;
    }
    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => destinationScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
          (route) => false,
    );
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? errorColor : primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    );
  }

  // UI Components
  Widget _buildRoleAvatar(Color roleColor, IconData roleIcon) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        height: 80,
        width: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          roleIcon,
          size: 40,
          color: primaryColor,
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return SlideTransition(
      position: _slideAnimation,
      child: TextFormField(
        controller: _emailController,
        autofocus: false,
        decoration: InputDecoration(
          labelText: 'Email',
          prefixIcon: Icon(Icons.email, color: primaryColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_inputBorderRadius),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_inputBorderRadius),
            borderSide: BorderSide(color: primaryColor, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_inputBorderRadius),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        ),
        style: const TextStyle(color: Colors.black),
        validator: _validateEmail,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
      ),
    );
  }

  Widget _buildPasswordField() {
    return SlideTransition(
      position: _slideAnimation,
      child: TextFormField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        decoration: InputDecoration(
          labelText: 'Password',
          prefixIcon: Icon(Icons.lock, color: primaryColor),
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility : Icons.visibility_off,
              color: primaryColor,
            ),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_inputBorderRadius),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_inputBorderRadius),
            borderSide: BorderSide(color: primaryColor, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_inputBorderRadius),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        ),
        style: const TextStyle(color: Colors.black),
        validator: _validatePassword,
        textInputAction: TextInputAction.done,
        onFieldSubmitted: (_) => _handleLogin(),
      ),
    );
  }

  Widget _buildForgotPasswordButton() {
    return SlideTransition(
      position: _slideAnimation,
      child: Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: _isLoading
              ? null
              : () async {
            if (_emailController.text.isEmpty) {
              _showSnackBar('Please enter your email first');
              return;
            }
            try {
              await FirebaseAuth.instance.sendPasswordResetEmail(
                email: _emailController.text.trim(),
              );
              _showSnackBar('Password reset email sent', isError: false);
            } catch (e) {
              _showSnackBar('Error sending reset email');
            }
          },
          child: Text(
            'Forgot Password?',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return SlideTransition(
      position: _slideAnimation,
      child: SizedBox(
        width: double.infinity,
        height: _buttonHeight,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _handleLogin,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_buttonBorderRadius),
            ),
            elevation: 8,
            shadowColor: Colors.black26,
          ),
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text(
            'Login',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignupButton() {
    return SlideTransition(
      position: _slideAnimation,
      child: Center(
        child: TextButton(
          onPressed: _isLoading
              ? null
              : () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    SignupScreen(role: widget.role),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
              ),
            );
          },
          child: Text(
            "Don't have an account? Sign up",
            style: TextStyle(
              color: Color(0xFF1E3A8A), // Medical Blue
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppTitle() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Text(
        'MindCare',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textColor,
          shadows: [
            Shadow(
              blurRadius: 10,
              color: Colors.black26,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return IconButton(
      icon: Icon(
        Icons.arrow_back,
        color: textColor,
        size: 28,
      ),
      onPressed: _isLoading ? null : _navigateToRoleSelection,
      tooltip: 'Back to Role Selection',
    );
  }

  @override
  Widget build(BuildContext context) {
    final roleIcon = {
      Roles.patient: Icons.self_improvement_outlined,
      Roles.provider: Icons.psychology_alt_outlined,
      Roles.receptionist: Icons.support_agent_outlined,
      Roles.admin: Icons.security_outlined,
    }[widget.role] ?? Icons.person;
    final displayRole = RoleLabels.getDisplayLabel(widget.role);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(gradient: backgroundGradient),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(_padding),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        _buildBackButton(),
                        const Spacer(),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildRoleAvatar(primaryColor, roleIcon),
                    const SizedBox(height: 24),
                    _buildAppTitle(),
                    const SizedBox(height: 8),
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Text(
                        'Welcome Back',
                        style: TextStyle(
                          fontSize: 16,
                          color: textColor.withOpacity(0.9),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Text(
                        'Log in as $displayRole',
                        style: TextStyle(
                          fontSize: 16,
                          color: textColor.withOpacity(0.9),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Sign In',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              _buildEmailField(),
                              const SizedBox(height: 16),
                              _buildPasswordField(),
                              const SizedBox(height: 8),
                              _buildForgotPasswordButton(),
                              const SizedBox(height: 24),
                              _buildLoginButton(),
                              const SizedBox(height: 16),
                              _buildSignupButton(),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Text(
                        '© 2025 MindCare. All rights reserved.',
                        style: TextStyle(
                          color: textColor.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}