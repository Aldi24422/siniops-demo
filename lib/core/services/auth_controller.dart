import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../firebase_options.dart';

/// Authentication Controller for Firebase Auth & Firestore role management
class AuthController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Current user getter
  User? get currentUser => _auth.currentUser;

  /// Sign in with email and password
  /// Returns the User if successful, throws exception on failure
  Future<User?> signIn(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthController] Sign in error: ${e.code}');
      rethrow;
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Get user role from Firestore 'users' collection
  /// Returns 'owner', 'cashier', or null if not found
  Future<String?> getUserRole(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data()?['role'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('[AuthController] Get role error: $e');
      return null;
    }
  }

  /// Get full user data from Firestore
  /// Returns user document data or null if not found
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      debugPrint('[AuthController] Get user data error: $e');
      return null;
    }
  }

  // ============================================================
  // STAFF MANAGEMENT METHODS
  // ============================================================

  /// Add a new cashier without logging out the current owner
  /// Uses Secondary Firebase App to avoid session disruption
  Future<AddCashierResult> addCashier({
    required String email,
    required String password,
    required String name,
  }) async {
    FirebaseApp? secondaryApp;

    try {
      // Initialize secondary Firebase app
      secondaryApp = await Firebase.initializeApp(
        name: 'SecondaryApp_${DateTime.now().millisecondsSinceEpoch}',
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Get auth instance for secondary app
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      // Create user on secondary auth (doesn't affect main session)
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (credential.user == null) {
        return AddCashierResult(success: false, error: 'Gagal membuat akun');
      }

      // Save user data to Firestore
      await _firestore.collection('users').doc(credential.user!.uid).set({
        'email': email.trim(),
        'displayName': name.trim(),
        'role': 'cashier',
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': currentUser?.uid,
      });

      debugPrint('[AuthController] Cashier created: $email');

      return AddCashierResult(success: true, uid: credential.user!.uid);
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthController] Add cashier error: ${e.code}');
      String errorMessage = 'Gagal membuat akun';

      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'Email sudah digunakan';
          break;
        case 'weak-password':
          errorMessage = 'Password terlalu lemah (min 6 karakter)';
          break;
        case 'invalid-email':
          errorMessage = 'Format email tidak valid';
          break;
      }

      return AddCashierResult(success: false, error: errorMessage);
    } catch (e) {
      debugPrint('[AuthController] Add cashier error: $e');
      return AddCashierResult(success: false, error: e.toString());
    } finally {
      // Clean up secondary app
      if (secondaryApp != null) {
        try {
          await secondaryApp.delete();
        } catch (e) {
          debugPrint('[AuthController] Error deleting secondary app: $e');
        }
      }
    }
  }

  /// Get stream of all cashiers from Firestore
  /// Note: Sorting done client-side to avoid composite index requirement
  Stream<List<CashierData>> getCashiers() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'cashier')
        .snapshots()
        .map((snapshot) {
          final cashiers = snapshot.docs.map((doc) {
            final data = doc.data();
            return CashierData(
              uid: doc.id,
              email: data['email'] ?? '',
              displayName: data['displayName'] ?? 'Unknown',
              isActive: data['isActive'] ?? true,
              createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
            );
          }).toList();

          // Sort client-side: newest first
          cashiers.sort((a, b) {
            if (a.createdAt == null && b.createdAt == null) return 0;
            if (a.createdAt == null) return 1;
            if (b.createdAt == null) return -1;
            return b.createdAt!.compareTo(a.createdAt!);
          });

          return cashiers;
        });
  }

  /// Deactivate a cashier (soft delete)
  /// Sets isActive to false in Firestore
  Future<bool> deleteCashier(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'isActive': false,
        'deactivatedAt': FieldValue.serverTimestamp(),
        'deactivatedBy': currentUser?.uid,
      });
      debugPrint('[AuthController] Cashier deactivated: $uid');
      return true;
    } catch (e) {
      debugPrint('[AuthController] Delete cashier error: $e');
      return false;
    }
  }

  /// Reactivate a previously deactivated cashier
  Future<bool> reactivateCashier(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'isActive': true,
        'reactivatedAt': FieldValue.serverTimestamp(),
        'reactivatedBy': currentUser?.uid,
      });
      debugPrint('[AuthController] Cashier reactivated: $uid');
      return true;
    } catch (e) {
      debugPrint('[AuthController] Reactivate cashier error: $e');
      return false;
    }
  }

  // ============================================================
  // SEED DEFAULT USERS
  // ============================================================

  /// Seed default demo users (owner & kasir)
  /// Creates both Firebase Auth accounts and Firestore user documents
  Future<SeedResult> seedDefaultUsers() async {
    int created = 0;
    int skipped = 0;
    List<String> errors = [];

    // Default users configuration
    final defaultUsers = [
      {
        'email': 'owner@siniops.com',
        'password': '123456',
        'role': 'owner',
        'displayName': 'Owner Coffee',
      },
      {
        'email': 'kasir@siniops.com',
        'password': '123456',
        'role': 'cashier',
        'displayName': 'Staff Barista',
      },
    ];

    for (final userData in defaultUsers) {
      try {
        // Try to create user in Firebase Auth
        final credential = await _auth.createUserWithEmailAndPassword(
          email: userData['email']!,
          password: userData['password']!,
        );

        // Create Firestore document
        if (credential.user != null) {
          await _firestore.collection('users').doc(credential.user!.uid).set({
            'email': userData['email'],
            'role': userData['role'],
            'displayName': userData['displayName'],
            'isActive': true,
            'createdAt': FieldValue.serverTimestamp(),
          });
          created++;
          debugPrint('[AuthController] Created user: ${userData['email']}');
        }
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          skipped++;
          debugPrint(
            '[AuthController] User already exists: ${userData['email']}',
          );
        } else {
          errors.add('${userData['email']}: ${e.message}');
          debugPrint(
            '[AuthController] Error creating ${userData['email']}: ${e.code}',
          );
        }
      } catch (e) {
        errors.add('${userData['email']}: $e');
      }
    }

    // Sign out after seeding (so user can login fresh)
    await _auth.signOut();

    return SeedResult(created: created, skipped: skipped, errors: errors);
  }
}

/// Result of addCashier operation
class AddCashierResult {
  final bool success;
  final String? uid;
  final String? error;

  AddCashierResult({required this.success, this.uid, this.error});
}

/// Cashier data model
class CashierData {
  final String uid;
  final String email;
  final String displayName;
  final bool isActive;
  final DateTime? createdAt;

  CashierData({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.isActive,
    this.createdAt,
  });

  /// Get initials for avatar
  String get initials {
    if (displayName.isEmpty) return '?';
    final parts = displayName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return displayName[0].toUpperCase();
  }
}

/// Result of seedDefaultUsers operation
class SeedResult {
  final int created;
  final int skipped;
  final List<String> errors;

  SeedResult({
    required this.created,
    required this.skipped,
    required this.errors,
  });

  bool get hasErrors => errors.isNotEmpty;

  String get message {
    if (hasErrors) {
      return 'Error: ${errors.join(', ')}';
    }
    if (created > 0 && skipped > 0) {
      return '$created akun dibuat, $skipped sudah ada';
    }
    if (created > 0) {
      return '$created akun berhasil dibuat';
    }
    if (skipped > 0) {
      return 'Semua akun sudah ada ($skipped)';
    }
    return 'Tidak ada akun yang diproses';
  }
}
