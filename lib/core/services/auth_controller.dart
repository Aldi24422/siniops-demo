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
  /// Returns 'owner', 'outlet_manager', 'crew', or null if not found
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

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Add a new staff member (crew or outlet_manager)
  /// Uses Secondary Firebase App to avoid session disruption
  Future<AddStaffResult> addStaff({
    required String email,
    required String password,
    required String name,
    String role = 'crew',
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
        return AddStaffResult(success: false, error: 'Gagal membuat akun');
      }

      // Save user data to Firestore
      await _firestore.collection('users').doc(credential.user!.uid).set({
        'email': email.trim(),
        'displayName': name.trim(),
        'role': role,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': currentUser?.uid,
      });

      debugPrint('[AuthController] Staff created: $email');

      return AddStaffResult(success: true, uid: credential.user!.uid);
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthController] Add staff error: ${e.code}');
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

      return AddStaffResult(success: false, error: errorMessage);
    } catch (e) {
      debugPrint('[AuthController] Add staff error: $e');
      return AddStaffResult(success: false, error: e.toString());
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

  /// Get stream of all staff (crew & outlet_manager) from Firestore
  Stream<List<StaffData>> getStaff(String currentUserRole) {
    // Default allowed roles for outlet_manager (can view managers, crew, and legacy cashier)
    List<String> allowedRoles = ['outlet_manager', 'crew', 'cashier'];

    if (currentUserRole == 'owner') {
      // Owner can view everyone including other owners
      allowedRoles = ['owner', 'outlet_manager', 'crew', 'cashier'];
    }

    return _firestore
        .collection('users')
        .where('role', whereIn: allowedRoles)
        .snapshots()
        .map((snapshot) {
          final staffList = snapshot.docs.map((doc) {
            final data = doc.data();
            return StaffData(
              uid: doc.id,
              email: data['email'] ?? '',
              displayName: data['displayName'] ?? 'Unknown',
              role: data['role'] ?? 'crew',
              isActive: data['isActive'] ?? true,
              createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
            );
          }).toList();

          // Sort client-side: newest first
          staffList.sort((a, b) {
            if (a.createdAt == null && b.createdAt == null) return 0;
            if (a.createdAt == null) return 1;
            if (b.createdAt == null) return -1;
            return b.createdAt!.compareTo(a.createdAt!);
          });

          return staffList;
        });
  }

  /// Delete staff permanently (Hard Delete)
  /// Only deletes Firestore data. Auth deletion requires Admin SDK or Cloud Functions.
  /// Without Firestore data, user cannot login.
  Future<bool> deleteStaff(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).delete();
      debugPrint('[AuthController] Staff deleted: $uid');
      return true;
    } catch (e) {
      debugPrint('[AuthController] Delete staff error: $e');
      return false;
    }
  }

  // --- Owner Deletion Request System ---

  /// Request deletion of another owner
  Future<bool> requestOwnerDeletion(String targetUid) async {
    try {
      final requesterUid = currentUser?.uid;
      if (requesterUid == null) return false;

      // Check if request already exists
      final existing = await _firestore
          .collection('deletion_requests')
          .where('targetUid', isEqualTo: targetUid)
          .where('requesterUid', isEqualTo: requesterUid)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existing.docs.isNotEmpty) return true; // Already requested

      await _firestore.collection('deletion_requests').add({
        'targetUid': targetUid,
        'requesterUid': requesterUid,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('[AuthController] Request deletion error: $e');
      return false;
    }
  }

  /// Get stream of deletion requests for the current user
  Stream<QuerySnapshot> getDeletionRequestsStream() {
    final myUid = currentUser?.uid;
    if (myUid == null) return const Stream.empty();

    return _firestore
        .collection('deletion_requests')
        .where('targetUid', isEqualTo: myUid)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  /// Approve deletion request (I agree to delete MY account)
  Future<void> approveOwnerDeletion(String requestId) async {
    final myUid = currentUser?.uid;
    if (myUid == null) return;

    try {
      await _firestore.runTransaction((transaction) async {
        // 1. Delete my user data
        final userRef = _firestore.collection('users').doc(myUid);
        transaction.delete(userRef);

        // 2. Delete the request
        final requestRef = _firestore
            .collection('deletion_requests')
            .doc(requestId);
        transaction.delete(requestRef);
      });

      // 3. Sign out
      await signOut();
    } catch (e) {
      debugPrint('[AuthController] Approve deletion error: $e');
      rethrow;
    }
  }

  /// Reject deletion request
  Future<void> rejectOwnerDeletion(String requestId) async {
    try {
      await _firestore.collection('deletion_requests').doc(requestId).delete();
    } catch (e) {
      debugPrint('[AuthController] Reject deletion error: $e');
    }
  }

  /// Reactivate a previously deactivated staff member
  Future<bool> reactivateStaff(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'isActive': true,
        'reactivatedAt': FieldValue.serverTimestamp(),
        'reactivatedBy': currentUser?.uid,
      });
      debugPrint('[AuthController] Staff reactivated: $uid');
      return true;
    } catch (e) {
      debugPrint('[AuthController] Reactivate staff error: $e');
      return false;
    }
  }
}

/// Result of addStaff operation
class AddStaffResult {
  final bool success;
  final String? uid;
  final String? error;

  AddStaffResult({required this.success, this.uid, this.error});
}

/// Staff data model
class StaffData {
  final String uid;
  final String email;
  final String displayName;
  final String role;
  final bool isActive;
  final DateTime? createdAt;

  StaffData({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
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
