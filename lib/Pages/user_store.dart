import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';

class UserStore {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final Logger _logger = Logger();

  static Future<bool> userExists({
    required String email,
    required String role,
  }) async {
    try {
      if (email.isEmpty || role.isEmpty) {
        _logger.w('Invalid input: email or role is empty');
        return false;
      }

      final methods = await _auth.fetchSignInMethodsForEmail(email);
      if (methods.isEmpty) {
        _logger.i('No account found for email: $email');
        return false;
      }

      final query = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .where('role', isEqualTo: role)
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      _logger.e('Error checking user existence: $e');
      return false;
    }
  }

  static Future<UserCredential> addUser({
    required String role,
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      if (email.isEmpty || password.isEmpty || name.isEmpty || role.isEmpty) {
        _logger.w('Invalid input: one or more fields are empty');
        throw Exception('All fields (email, password, name, role) are required');
      }

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await credential.user?.updateDisplayName(name);
      await _firestore.collection('users').doc(credential.user!.uid).set({
        'name': name,
        'email': email,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      });

      _logger.i('User created successfully: ${credential.user!.uid}');
      return credential;
    } on FirebaseAuthException catch (e) {
      _logger.e('Firebase Auth error creating user: ${e.code} - ${e.message}');
      throw e;
    } catch (e) {
      _logger.e('Error creating user: $e');
      throw Exception('Failed to create user: $e');
    }
  }

  static Future<User?> authenticate({
    required String email,
    required String password,
  }) async {
    try {
      if (email.isEmpty || password.isEmpty) {
        _logger.w('Invalid input: email or password is empty');
        return null;
      }

      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        await _firestore.collection('users').doc(credential.user!.uid).update({
          'lastLogin': FieldValue.serverTimestamp(),
        });
        _logger.i('User authenticated and lastLogin updated: ${credential.user!.uid}');
      }

      return credential.user;
    } on FirebaseAuthException catch (e) {
      _logger.w('Authentication failed: ${e.code} - ${e.message}');
      return null;
    } catch (e) {
      _logger.e('Unexpected error during authentication: $e');
      return null;
    }
  }
}