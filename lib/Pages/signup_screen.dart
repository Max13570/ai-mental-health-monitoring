import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'role_constants.dart';

class SignupScreen extends StatefulWidget {
  final String role;
  const SignupScreen({super.key, required this.role});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with TickerProviderStateMixin {
  // Design Constants (matching LoginScreen)
  static const double _padding = 24.0;
  static const double _spacing = 16.0;
  static const double _avatarRadius = 40.0;
  static const double _inputBorderRadius = 8.0;
  static const double _buttonBorderRadius = 8.0;
  static const double _buttonHeight = 50.0;

  // Color Scheme (matching LoginScreen)
  static const Color primaryColor = Color(0xFF1E3A8A); // Medical Blue
  static const Color errorColor = Color(0xFFC62828);
  static const Color textColor = Colors.white;

  // Gradient background (matching LoginScreen)
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
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // State Variables
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  _PasswordStrength _strength = _PasswordStrength('Too Weak', errorColor);

  // Animations
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
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

    _animationController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  // Validation Methods
  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your full name';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your email';
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) return 'Please enter a valid email';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your password';
    if (value.length < 8) return 'Password must be at least 8 characters';
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Add at least one uppercase letter';
    }
    if (!value.contains(RegExp(r'[0-9]'))) return 'Add at least one number';
    if (!value.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) {
      return 'Add at least one special character';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  _PasswordStrength _getPasswordStrength(String password) {
    if (password.length < 6) return _PasswordStrength("Too Weak", errorColor);
    if (password.length < 8) return _PasswordStrength("Weak", Colors.orange);

    bool hasUpper = password.contains(RegExp(r'[A-Z]'));
    bool hasLower = password.contains(RegExp(r'[a-z]'));
    bool hasDigit = password.contains(RegExp(r'[0-9]'));
    bool hasSpecial = password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));

    int strength = 0;
    if (hasUpper) strength++;
    if (hasLower) strength++;
    if (hasDigit) strength++;
    if (hasSpecial) strength++;

    if (password.length >= 12 && strength >= 3) {
      return _PasswordStrength("Very Strong", Colors.green);
    } else if (strength >= 3) {
      return _PasswordStrength("Strong", Colors.green);
    } else if (strength >= 2) {
      return _PasswordStrength("Medium", Colors.blue);
    }
    return _PasswordStrength("Weak", Colors.orange);
  }

  // Authentication Methods
  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final auth = FirebaseAuth.instance;
      final userCredential = await auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      await userCredential.user?.updateDisplayName(_nameController.text.trim());

      final firestore = FirebaseFirestore.instance;
      await firestore.collection('users').doc(userCredential.user?.uid).set({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'role': widget.role,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      _showSuccessSnackBar();
      _navigateAfterSignup();
    } on FirebaseAuthException catch (e) {
      _handleFirebaseError(e);
    } catch (e) {
      _handleGenericError();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Account created successfully for ${_nameController.text.trim()}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_inputBorderRadius),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    );
  }

  void _navigateAfterSignup() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pushReplacementNamed('/login', arguments: widget.role);
    } else {
      navigator.pushNamed('/login', arguments: widget.role);
    }
  }

  void _handleFirebaseError(FirebaseAuthException e) {
    setState(() {
      _errorMessage = _mapFirebaseError(e.code);
    });
  }

  void _handleGenericError() {
    setState(() {
      _errorMessage = 'Signup failed. Please try again.';
    });
  }

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Please use a stronger password.';
      case 'operation-not-allowed':
        return 'Sign-up is currently disabled.';
      default:
        return 'An error occurred. Please try again.';
    }
  }

  // UI Components
  Widget _buildHeader() {
    final roleIcon = {
      Roles.patient: Icons.self_improvement_outlined,
      Roles.provider: Icons.psychology_alt_outlined,
      Roles.receptionist: Icons.support_agent_outlined,
      Roles.admin: Icons.security_outlined,
    }[widget.role] ?? Icons.person;

    return SlideTransition(
      position: _slideAnimation,
      child: Column(
        children: [
          Container(
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
          const SizedBox(height: 24),
          Text(
            'MindCare',
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
          const SizedBox(height: 8),
          Text(
            'Create your ${RoleLabels.getDisplayLabel(widget.role)} account',
            style: TextStyle(
              fontSize: 16,
              color: textColor.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameField() {
    return SlideTransition(
      position: _slideAnimation,
      child: _buildTextField(
        controller: _nameController,
        label: 'Full Name',
        icon: Icons.person,
        validator: _validateName,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
          TextInputFormatter.withFunction((oldValue, newValue) {
            return newValue.copyWith(text: newValue.text.trimLeft());
          }),
        ],
      ),
    );
  }

  Widget _buildEmailField() {
    return SlideTransition(
      position: _slideAnimation,
      child: _buildTextField(
        controller: _emailController,
        label: 'Email',
        icon: Icons.email,
        keyboardType: TextInputType.emailAddress,
        validator: _validateEmail,
      ),
    );
  }

  Widget _buildPasswordField() {
    return SlideTransition(
      position: _slideAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField(
            controller: _passwordController,
            label: 'Password',
            icon: Icons.lock,
            obscureText: _obscurePassword,
            validator: _validatePassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility : Icons.visibility_off,
                color: primaryColor,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            onChanged: (value) {
              setState(() => _strength = _getPasswordStrength(value));
            },
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: _strength.level,
            color: _strength.color,
            backgroundColor: Colors.white.withOpacity(0.3),
            minHeight: 5,
          ),
          const SizedBox(height: 4),
          Text(
            'Password Strength: ${_strength.label}',
            style: TextStyle(
              color: _strength.color,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmPasswordField() {
    return SlideTransition(
      position: _slideAnimation,
      child: _buildTextField(
        controller: _confirmPasswordController,
        label: 'Confirm Password',
        icon: Icons.lock,
        obscureText: _obscureConfirmPassword,
        validator: _validateConfirmPassword,
        suffixIcon: IconButton(
          icon: Icon(
            _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
            color: primaryColor,
          ),
          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
        ),
      ),
    );
  }

  Widget _buildErrorDisplay() {
    if (_errorMessage == null) return const SizedBox.shrink();

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: errorColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(_inputBorderRadius),
          border: Border.all(color: errorColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: errorColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignupButton() {
    return SlideTransition(
      position: _slideAnimation,
      child: SizedBox(
        width: double.infinity,
        height: _buttonHeight,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _handleSignup,
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
            'Create Account',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginLink() {
    return SlideTransition(
      position: _slideAnimation,
      child: Center(
        child: TextButton(
          onPressed: _isLoading ? null : _navigateToLogin,
          child: Text(
            'Already have an account? Sign In',
            style: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToLogin() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pushReplacementNamed('/login', arguments: widget.role);
    } else {
      navigator.pushNamed('/login', arguments: widget.role);
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    Widget? suffixIcon,
    Function(String)? onChanged,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      inputFormatters: inputFormatters,
      style: const TextStyle(color: Colors.black),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: primaryColor),
        suffixIcon: suffixIcon,
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
    );
  }

  Widget _buildBackButton() {
    return IconButton(
      icon: Icon(
        Icons.arrow_back,
        color: textColor,
        size: 28,
      ),
      onPressed: _isLoading ? null : () => Navigator.pop(context),
      tooltip: 'Go back',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  _buildHeader(),
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
                              'Sign Up',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            _buildNameField(),
                            const SizedBox(height: _spacing),
                            _buildEmailField(),
                            const SizedBox(height: _spacing),
                            _buildPasswordField(),
                            const SizedBox(height: _spacing),
                            _buildConfirmPasswordField(),
                            const SizedBox(height: _spacing),
                            _buildErrorDisplay(),
                            const SizedBox(height: 24),
                            _buildSignupButton(),
                            const SizedBox(height: 16),
                            _buildLoginLink(),
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
    );
  }
}

class _PasswordStrength {
  final String label;
  final Color color;

  _PasswordStrength(this.label, this.color);

  double get level {
    switch (label) {
      case "Too Weak":
        return 0.2;
      case "Weak":
        return 0.4;
      case "Medium":
        return 0.6;
      case "Strong":
        return 0.8;
      case "Very Strong":
        return 1.0;
      default:
        return 0.0;
    }
  }
}