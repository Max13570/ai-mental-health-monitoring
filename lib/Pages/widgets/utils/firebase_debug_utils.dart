// Create this file as: lib/utils/firebase_debug_utils.dart

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseDebugUtils {
  static const String tag = 'FirebaseDebug';

  /// Test Firebase Core initialization
  static Future<bool> testFirebaseCore() async {
    try {
      final app = Firebase.app();
      debugPrint('$tag: ✅ Firebase Core initialized successfully');
      debugPrint('$tag: Project ID: ${app.options.projectId}');
      debugPrint('$tag: App ID: ${app.options.appId}');
      return true;
    } catch (e) {
      debugPrint('$tag: ❌ Firebase Core error: $e');
      return false;
    }
  }

  /// Test Firebase Auth
  static Future<bool> testFirebaseAuth() async {
    try {
      final auth = FirebaseAuth.instance;
      final user = auth.currentUser;
      debugPrint('$tag: ✅ Firebase Auth accessible');
      debugPrint('$tag: Current user: ${user?.uid ?? 'None'}');
      return true;
    } catch (e) {
      debugPrint('$tag: ❌ Firebase Auth error: $e');
      return false;
    }
  }

  /// Test Firestore connection
  static Future<bool> testFirestore() async {
    try {
      final firestore = FirebaseFirestore.instance;
      debugPrint('$tag: 🔍 Testing Firestore connection...');

      // Test basic Firestore access
      final testDoc = firestore.collection('_debug_test').doc('connectivity');

      // Try to write a test document
      await testDoc.set({
        'timestamp': FieldValue.serverTimestamp(),
        'platform': kIsWeb ? 'web' : 'mobile',
        'test': 'connectivity_check'
      }).timeout(const Duration(seconds: 10));

      debugPrint('$tag: ✅ Firestore write test successful');

      // Try to read the test document
      final snapshot = await testDoc.get().timeout(const Duration(seconds: 10));
      if (snapshot.exists) {
        debugPrint('$tag: ✅ Firestore read test successful');
        debugPrint('$tag: Test data: ${snapshot.data()}');
      }

      // Clean up test document
      await testDoc.delete();
      debugPrint('$tag: ✅ Firestore cleanup successful');

      return true;
    } catch (e) {
      debugPrint('$tag: ❌ Firestore test failed: $e');
      return false;
    }
  }

  /// Test Firestore settings
  static Future<void> testFirestoreSettings() async {
    try {
      final firestore = FirebaseFirestore.instance;
      debugPrint('$tag: 🔍 Testing Firestore settings...');

      if (kIsWeb) {
        // Test web-specific settings
        await firestore.enableNetwork();
        debugPrint('$tag: ✅ Firestore network enabled for web');
      } else {
        // Mobile settings are applied during initialization
        debugPrint('$tag: ✅ Firestore configured for mobile');
      }
    } catch (e) {
      debugPrint('$tag: ❌ Firestore settings error: $e');
    }
  }

  /// Run comprehensive Firebase diagnostics
  static Future<Map<String, bool>> runDiagnostics() async {
    debugPrint('$tag: 🚀 Starting Firebase diagnostics...');

    final results = <String, bool>{};

    // Test Firebase Core
    results['core'] = await testFirebaseCore();

    // Test Firebase Auth
    results['auth'] = await testFirebaseAuth();

    // Test Firestore settings
    await testFirestoreSettings();

    // Test Firestore connectivity
    results['firestore'] = await testFirestore();

    // Summary
    final passed = results.values.where((v) => v).length;
    final total = results.length;

    debugPrint('$tag: 📊 Diagnostics complete: $passed/$total tests passed');

    if (passed == total) {
      debugPrint('$tag: 🎉 All Firebase services are working correctly!');
    } else {
      debugPrint('$tag: ⚠️ Some Firebase services have issues. Check logs above.');
    }

    return results;
  }

  /// Test user authentication and document access
  static Future<bool> testUserDocumentAccess(String uid) async {
    try {
      debugPrint('$tag: 🔍 Testing user document access for UID: $uid');

      final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);
      final snapshot = await userDoc.get().timeout(const Duration(seconds: 10));

      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>?;
        debugPrint('$tag: ✅ User document exists');
        debugPrint('$tag: User role: ${data?['role']}');
        debugPrint('$tag: User email: ${data?['email']}');
        return true;
      } else {
        debugPrint('$tag: ❌ User document does not exist');
        return false;
      }
    } catch (e) {
      debugPrint('$tag: ❌ User document access failed: $e');
      return false;
    }
  }

  /// Create a test user document (for debugging)
  static Future<bool> createTestUserDocument(String uid, String email, String role) async {
    try {
      debugPrint('$tag: 🔍 Creating test user document...');

      final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);
      await userDoc.set({
        'email': email,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
        'isTestUser': true,
      }).timeout(const Duration(seconds: 10));

      debugPrint('$tag: ✅ Test user document created successfully');
      return true;
    } catch (e) {
      debugPrint('$tag: ❌ Failed to create test user document: $e');
      return false;
    }
  }

  /// Monitor Firestore connection state
  static void monitorFirestoreConnection() {
    FirebaseFirestore.instance
        .collection('_connection_monitor')
        .doc('status')
        .snapshots()
        .listen(
          (snapshot) {
        if (snapshot.metadata.isFromCache) {
          debugPrint('$tag: ⚠️ Firestore data from cache (offline)');
        } else {
          debugPrint('$tag: ✅ Firestore data from server (online)');
        }
      },
      onError: (error) {
        debugPrint('$tag: ❌ Firestore connection monitor error: $error');
      },
    );
  }

  /// Print Firebase configuration details
  static void printFirebaseConfig() {
    try {
      final app = Firebase.app();
      final options = app.options;

      debugPrint('$tag: 📋 Firebase Configuration:');
      debugPrint('$tag: Project ID: ${options.projectId}');
      debugPrint('$tag: App ID: ${options.appId}');
      debugPrint('$tag: Auth Domain: ${options.authDomain}');
      debugPrint('$tag: Storage Bucket: ${options.storageBucket}');
      debugPrint('$tag: Platform: ${kIsWeb ? 'Web' : 'Mobile'}');

      if (options.measurementId != null) {
        debugPrint('$tag: Analytics ID: ${options.measurementId}');
      }
    } catch (e) {
      debugPrint('$tag: ❌ Could not print Firebase config: $e');
    }
  }
}