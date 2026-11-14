import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ManageAccountsScreen extends StatefulWidget {
  const ManageAccountsScreen({super.key});

  @override
  State<ManageAccountsScreen> createState() => _ManageAccountsScreenState();
}

class _ManageAccountsScreenState extends State<ManageAccountsScreen> {
  // Professional Medical Color Scheme (matching DoctorDashboardScreen)
  static const Color medicalBlue = Color(0xFF1E3A8A);
  static const Color medicalTeal = Color(0xFF0F766E);
  static const Color lightMedicalBlue = Color(0xFF3B82F6);
  static const Color medicalGray = Color(0xFF64748B);
  static const Color lightGray = Color(0xFFF8FAFC);
  static const Color successGreen = Color(0xFF10B981);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color warningOrange = Color(0xFFF59E0B);

  // Constants for styling
  static const double _padding = 16.0;
  static const double _cardRadius = 12.0;
  static const double _spacing = 16.0;

  // Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Filter variables
  String _filterType = 'All';
  String _filterStatus = 'All';
  String _searchQuery = '';
  bool _isLoading = true;
  String? _error;

  // Text controller for search
  final TextEditingController _searchController = TextEditingController();

  // Get filtered users stream
  Stream<QuerySnapshot> get _filteredUsers {
    Query query = _firestore.collection('users');

    if (_filterType != 'All') {
      query = query.where('type', isEqualTo: _filterType);
    }

    if (_filterStatus != 'All') {
      query = query.where('status', isEqualTo: _filterStatus);
    }

    return query.snapshots();
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load accounts: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _safeUserData(DocumentSnapshot doc) {
    final userData = doc.data() as Map<String, dynamic>? ?? {};
    return {
      'id': doc.id,
      'name': userData['name']?.toString() ?? 'No Name',
      'email': userData['email']?.toString() ?? 'No Email',
      'type': userData['type']?.toString() ?? 'Unknown',
      'status': userData['status']?.toString() ?? 'Inactive',
      'specialization': userData['specialization']?.toString(),
      'createdAt': userData['createdAt'],
      'createdBy': userData['createdBy']?.toString() ?? 'System',
    };
  }

  void _showEditUserDialog(Map<String, dynamic> user) {
    // Placeholder for edit dialog (unchanged from original)
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit User: ${user['name']}'),
        content: const Text('Edit user dialog placeholder'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(color: medicalGray),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardRadius)),
        backgroundColor: Colors.white,
        title: Text(
          'Confirm Deletion',
          style: TextStyle(color: medicalBlue, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete the account for ${user['name']}?',
          style: TextStyle(color: medicalGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: medicalGray),
            ),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _firestore.collection('users').doc(user['id']).delete();
                if (mounted) {
                  Navigator.pop(context);
                  _showSnackBar('Deleted ${user['name']}', successGreen);
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  _showSnackBar('Error deleting user: ${e.toString()}', errorRed);
                }
              }
            },
            child: Text(
              'Delete',
              style: TextStyle(color: errorRed),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddUserDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    String selectedType = 'Patient';
    String selectedStatus = 'Active';
    String? selectedSpecialization;
    bool isLoading = false;

    // List of medical specializations for healthcare workers
    final List<String> specializations = [
      'General Medicine',
      'Cardiology',
      'Dermatology',
      'Neurology',
      'Orthopedics',
      'Pediatrics',
      'Psychiatry',
      'Radiology',
      'Surgery',
      'Emergency Medicine',
      'Internal Medicine',
      'Gynecology',
      'Ophthalmology',
      'Anesthesiology',
      'Pathology',
      'Other',
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardRadius)),
          backgroundColor: Colors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: medicalBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.person_add_rounded, color: medicalBlue),
              ),
              const SizedBox(width: 12),
              Text(
                'Add New User',
                style: TextStyle(color: medicalBlue, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Name Field
                    TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        labelStyle: TextStyle(color: medicalGray),
                        prefixIcon: Icon(Icons.person_rounded, color: medicalGray),
                        filled: true,
                        fillColor: lightGray,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: medicalBlue, width: 2),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: errorRed, width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a full name';
                        }
                        if (value.trim().length < 2) {
                          return 'Name must be at least 2 characters';
                        }
                        return null;
                      },
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: _spacing),

                    // Email Field
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        labelStyle: TextStyle(color: medicalGray),
                        prefixIcon: Icon(Icons.email_rounded, color: medicalGray),
                        filled: true,
                        fillColor: lightGray,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: medicalBlue, width: 2),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: errorRed, width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter an email address';
                        }
                        final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                        if (!emailRegex.hasMatch(value.trim())) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: _spacing),

                    // User Type Dropdown
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      items: const [
                        DropdownMenuItem(value: 'Patient', child: Text('Patient')),
                        DropdownMenuItem(value: 'Receptionist', child: Text('Receptionist')),
                        DropdownMenuItem(value: 'Healthcare Worker', child: Text('Healthcare Worker')),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedType = value!;
                          // Reset specialization when type changes
                          if (selectedType != 'Healthcare Worker') {
                            selectedSpecialization = null;
                          }
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'User Type',
                        labelStyle: TextStyle(color: medicalGray),
                        prefixIcon: Icon(_getUserIcon(selectedType), color: medicalGray),
                        filled: true,
                        fillColor: lightGray,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: medicalBlue, width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a user type';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: _spacing),

                    // Specialization Field (only for Healthcare Workers)
                    if (selectedType == 'Healthcare Worker') ...[
                      DropdownButtonFormField<String>(
                        value: selectedSpecialization,
                        items: specializations.map((spec) =>
                            DropdownMenuItem(value: spec, child: Text(spec))
                        ).toList(),
                        onChanged: (value) {
                          setDialogState(() => selectedSpecialization = value);
                        },
                        decoration: InputDecoration(
                          labelText: 'Medical Specialization',
                          labelStyle: TextStyle(color: medicalGray),
                          prefixIcon: Icon(Icons.medical_services_rounded, color: medicalGray),
                          filled: true,
                          fillColor: lightGray,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: medicalBlue, width: 2),
                          ),
                        ),
                        validator: (value) {
                          if (selectedType == 'Healthcare Worker' && (value == null || value.isEmpty)) {
                            return 'Please select a specialization';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: _spacing),
                    ],

                    // Status Dropdown
                    DropdownButtonFormField<String>(
                      value: selectedStatus,
                      items: const [
                        DropdownMenuItem(value: 'Active', child: Text('Active')),
                        DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
                      ],
                      onChanged: (value) {
                        setDialogState(() => selectedStatus = value!);
                      },
                      decoration: InputDecoration(
                        labelText: 'Account Status',
                        labelStyle: TextStyle(color: medicalGray),
                        prefixIcon: Icon(
                          selectedStatus == 'Active' ? Icons.check_circle_rounded : Icons.cancel_rounded,
                          color: selectedStatus == 'Active' ? successGreen : errorRed,
                        ),
                        filled: true,
                        fillColor: lightGray,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: medicalBlue, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: medicalGray),
              ),
            ),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                if (formKey.currentState!.validate()) {
                  setDialogState(() => isLoading = true);

                  try {
                    // Check if email already exists
                    final existingUsers = await _firestore
                        .collection('users')
                        .where('email', isEqualTo: emailController.text.trim().toLowerCase())
                        .get();

                    if (existingUsers.docs.isNotEmpty) {
                      setDialogState(() => isLoading = false);
                      _showSnackBar('Email already exists', errorRed);
                      return;
                    }

                    // Create user data
                    final userData = {
                      'name': nameController.text.trim(),
                      'email': emailController.text.trim().toLowerCase(),
                      'type': selectedType,
                      'status': selectedStatus,
                      'createdAt': FieldValue.serverTimestamp(),
                      'createdBy': 'Admin', // You can replace this with current user
                    };

                    // Add specialization if healthcare worker
                    if (selectedType == 'Healthcare Worker' && selectedSpecialization != null) {
                      userData['specialization'] = selectedSpecialization!;
                    }

                    // Add user to Firestore
                    await _firestore.collection('users').add(userData);

                    if (mounted) {
                      Navigator.pop(context);
                      _showSnackBar('User ${nameController.text.trim()} added successfully', successGreen);
                    }
                  } catch (e) {
                    setDialogState(() => isLoading = false);
                    _showSnackBar('Error adding user: ${e.toString()}', errorRed);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: medicalBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: isLoading
                  ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Text('Add User'),
            ),
          ],
        ),
      ),
    );
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
    if (_isLoading) {
      return Scaffold(
        backgroundColor: lightGray,
        body: Center(child: CircularProgressIndicator(color: medicalBlue)),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: lightGray,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_rounded, size: 48, color: errorRed),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(color: medicalGray, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadInitialData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: medicalBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_cardRadius),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Retry', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: lightGray,
      appBar: AppBar(
        backgroundColor: medicalBlue,
        foregroundColor: Colors.white,
        title: const Text('Manage Accounts'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              setState(() {
                _filterType = 'All';
                _filterStatus = 'All';
                _searchQuery = '';
                _searchController.clear();
              });
              _showSnackBar('Filters reset', successGreen);
            },
            tooltip: 'Reset filters',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddUserDialog,
        backgroundColor: medicalBlue,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
        elevation: 4,
      ),
      body: Padding(
        padding: const EdgeInsets.all(_padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by name or email...',
                      prefixIcon: Icon(Icons.search_rounded, color: medicalGray),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                        icon: Icon(Icons.clear_rounded, color: medicalGray),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: medicalBlue, width: 2),
                      ),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                  const SizedBox(height: _spacing),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _filterType,
                          items: const [
                            DropdownMenuItem(value: 'All', child: Text('All Types')),
                            DropdownMenuItem(value: 'Patient', child: Text('Patients')),
                            DropdownMenuItem(value: 'Receptionist', child: Text('Receptionists')),
                            DropdownMenuItem(value: 'Healthcare Worker', child: Text('Healthcare Workers')),
                          ],
                          onChanged: (value) => setState(() => _filterType = value!),
                          decoration: InputDecoration(
                            labelText: 'Filter by type',
                            labelStyle: TextStyle(color: medicalGray),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: medicalBlue, width: 2),
                            ),
                          ),
                          isExpanded: true,
                          style: TextStyle(color: medicalBlue),
                        ),
                      ),
                      const SizedBox(width: _spacing),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _filterStatus,
                          items: const [
                            DropdownMenuItem(value: 'All', child: Text('All Statuses')),
                            DropdownMenuItem(value: 'Active', child: Text('Active')),
                            DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
                          ],
                          onChanged: (value) => setState(() => _filterStatus = value!),
                          decoration: InputDecoration(
                            labelText: 'Filter by status',
                            labelStyle: TextStyle(color: medicalGray),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: medicalBlue, width: 2),
                            ),
                          ),
                          isExpanded: true,
                          style: TextStyle(color: medicalBlue),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: _spacing),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _filteredUsers,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_rounded, size: 48, color: errorRed),
                          const SizedBox(height: 16),
                          Text(
                            'Error: ${snapshot.error}',
                            style: TextStyle(color: medicalGray, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: medicalBlue));
                  }

                  final users = snapshot.data!.docs;
                  final filteredUsers = users.where((doc) {
                    final user = _safeUserData(doc);
                    final searchMatch = _searchQuery.isEmpty ||
                        user['name'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
                        user['email'].toLowerCase().contains(_searchQuery.toLowerCase());
                    return searchMatch;
                  }).toList();

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8),
                        child: Text(
                          '${filteredUsers.length} ${filteredUsers.length == 1 ? 'user' : 'users'} found',
                          style: TextStyle(
                            fontSize: 14,
                            color: medicalGray,
                          ),
                        ),
                      ),
                      Expanded(
                        child: filteredUsers.isEmpty
                            ? _buildEmptyState()
                            : ListView.separated(
                          itemCount: filteredUsers.length,
                          separatorBuilder: (context, index) => const SizedBox(height: _spacing),
                          itemBuilder: (context, index) {
                            final user = _safeUserData(filteredUsers[index]);
                            return _buildUserCard(context, user);
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: medicalGray.withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.people_alt_rounded,
                size: 48,
                color: medicalGray,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No users found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: medicalBlue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting the filters or adding a new user',
              style: TextStyle(
                fontSize: 14,
                color: medicalGray,
              ),
              textAlign: TextAlign.center,
            ),
            if (_filterType != 'All' || _filterStatus != 'All' || _searchQuery.isNotEmpty)
              TextButton(
                onPressed: () {
                  setState(() {
                    _filterType = 'All';
                    _filterStatus = 'All';
                    _searchQuery = '';
                    _searchController.clear();
                  });
                },
                child: Text(
                  'Clear filters',
                  style: TextStyle(color: medicalBlue),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, Map<String, dynamic> user) {
    String formattedDate = 'Unknown';
    if (user['createdAt'] != null) {
      try {
        final date = (user['createdAt'] as Timestamp).toDate();
        formattedDate = DateFormat('yyyy-MM-dd').format(date);
      } catch (e) {
        formattedDate = 'Invalid Date';
      }
    }

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
      child: InkWell(
        borderRadius: BorderRadius.circular(_cardRadius),
        onTap: () => _showEditUserDialog(user),
        child: Padding(
          padding: const EdgeInsets.all(_padding),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _getUserColor(user['type']).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getUserIcon(user['type']),
                  color: _getUserColor(user['type']),
                  size: 24,
                ),
              ),
              const SizedBox(width: _spacing),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user['name'],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: medicalBlue,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: user['status'] == 'Active'
                                ? successGreen.withOpacity(0.2)
                                : errorRed.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            user['status'],
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: user['status'] == 'Active' ? successGreen : errorRed,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user['email'],
                      style: TextStyle(
                        fontSize: 13,
                        color: medicalGray,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getUserColor(user['type']).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            user['type'],
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _getUserColor(user['type']),
                            ),
                          ),
                        ),
                        if (user['type'] == 'Healthcare Worker' && user['specialization'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: warningOrange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              user['specialization'],
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: warningOrange,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Created: $formattedDate',
                      style: TextStyle(
                        fontSize: 12,
                        color: medicalGray.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton(
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: medicalGray,
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit_rounded, color: medicalBlue),
                      title: Text('Edit', style: TextStyle(color: medicalBlue)),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_rounded, color: errorRed),
                      title: Text('Delete', style: TextStyle(color: errorRed)),
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'edit') _showEditUserDialog(user);
                  if (value == 'delete') _showDeleteConfirmation(user);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getUserColor(String type) {
    switch (type) {
      case 'Patient':
        return medicalBlue;
      case 'Receptionist':
        return medicalTeal;
      case 'Healthcare Worker':
        return lightMedicalBlue;
      default:
        return medicalGray;
    }
  }

  IconData _getUserIcon(String type) {
    switch (type) {
      case 'Patient':
        return Icons.person_rounded;
      case 'Receptionist':
        return Icons.desktop_mac_rounded;
      case 'Healthcare Worker':
        return Icons.medical_services_rounded;
      default:
        return Icons.help_rounded;
    }
  }
}