import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'common.dart'; // Roles, RoleLabels
import 'welcome_screen.dart'; // Import the WelcomeScreen

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with SingleTickerProviderStateMixin {
  String? selectedRole;
  bool _isLoading = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  static const List<Map<String, dynamic>> _roles = [
    {
      'key': Roles.patient,
      'label': 'Patient',
      'icon': Icons.self_improvement_outlined,
      'color': Color(0xFF2B6CB0), // Darker blue shade to complement Medical Blue
    },
    {
      'key': Roles.provider,
      'label': 'Professional',
      'icon': Icons.psychology_alt_outlined,
      'color': Color(0xFF0D9488), // Darker teal shade to complement Medical Teal
    },
    {
      'key': Roles.receptionist,
      'label': 'Receptionist',
      'icon': Icons.support_agent_outlined,
      'color': Color(0xFF4C9A9A), // Muted teal for variety
    },
    {
      'key': Roles.admin,
      'label': 'Admin',
      'icon': Icons.security_outlined,
      'color': Color(0xFF5B4A8C), // Purple shade to complement the palette
    },
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _navigateToLogin(String role) {
    try {
      HapticFeedback.lightImpact();
    } catch (e) {
      print('Haptic feedback not available: $e');
    }
    Navigator.pushNamed(context, '/login', arguments: role);
  }

  void _navigateToWelcome() {
    try {
      HapticFeedback.lightImpact();
    } catch (e) {
      print('Haptic feedback not available: $e');
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const WelcomeScreen()),
    );
  }

  void _onRoleSelected(String role) {
    try {
      HapticFeedback.selectionClick();
    } catch (e) {
      print('Haptic feedback not available: $e');
    }
    setState(() => selectedRole = role);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 600;
    final isLandscape = size.width > size.height;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E3A8A), // Medical Blue
              Color(0xFF0F766E), // Medical Teal
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? size.width * 0.1 : 24,
                vertical: 24,
              ),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    Text(
                      'Welcome to MindCare',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isLandscape ? 32 : 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            blurRadius: 10,
                            color: Colors.black26,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select your role to continue',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isLandscape ? 16 : 18,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 40),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: isLandscape ? 32 : 24,
                      runSpacing: isLandscape ? 32 : 24,
                      children: _roles.map((role) {
                        final isSelected = selectedRole == role['key'];
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          child: GestureDetector(
                            onTap: () => _onRoleSelected(role['key']),
                            child: Container(
                              width: isLandscape ? 160 : 140,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? role['color'].withOpacity(0.9)
                                    : Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? role['color']
                                      : Colors.white.withOpacity(0.2),
                                  width: 2,
                                ),
                                boxShadow: isSelected
                                    ? [
                                  BoxShadow(
                                    color: role['color'].withOpacity(0.4),
                                    blurRadius: 15,
                                    spreadRadius: 2,
                                  ),
                                ]
                                    : [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    role['icon'],
                                    size: 36,
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFFEDF1F5),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    role['label'],
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFFEDF1F5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(
                          onPressed: _navigateToWelcome,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 14),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.arrow_back, size: 20),
                              SizedBox(width: 8),
                              Text(
                                "Back",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: selectedRole == null
                              ? null
                              : () => _navigateToLogin(selectedRole!),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF1E3A8A), // Medical Blue
                            padding: const EdgeInsets.symmetric(
                                horizontal: 32, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 5,
                            shadowColor: Colors.black26,
                            minimumSize: const Size(120, 50),
                          ),
                          child: const Text(
                            "Continue",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E3A8A), // Medical Blue
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
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