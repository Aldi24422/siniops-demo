import 'dart:async';
import 'preview_mode_controller.dart';

/// Mock staff data model (replaces StaffData from auth_controller.dart)
class StaffData {
  final String uid;
  final String email;
  final String displayName;
  final String role;

  StaffData({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
  });
}

/// Result model for add/delete operations
class AuthResult {
  final bool success;
  final String? error;

  AuthResult({required this.success, this.error});
}

/// Mock Auth Controller — replaces Firebase AuthController for demo mode.
/// All data is stored in MockDataStore (in-memory).
class MockAuthController {
  // Singleton
  static final MockAuthController _instance = MockAuthController._internal();
  static MockAuthController get instance => _instance;
  MockAuthController._internal();

  // Stream controller for reactive UI updates
  final StreamController<List<StaffData>> _staffStreamController =
      StreamController<List<StaffData>>.broadcast();

  /// Initialize default staff data if not already present
  void _ensureDefaultStaff() {
    final store = MockDataStore.instance;
    if (store.staffList.isEmpty) {
      store.staffList.addAll([
        StaffData(
          uid: 'owner-001',
          email: 'owner@siniops.demo',
          displayName: 'Aldi (Owner)',
          role: 'owner',
        ),
        StaffData(
          uid: 'manager-001',
          email: 'manager@siniops.demo',
          displayName: 'Budi (Manager)',
          role: 'outlet_manager',
        ),
        StaffData(
          uid: 'crew-001',
          email: 'crew1@siniops.demo',
          displayName: 'Citra (Kasir)',
          role: 'crew',
        ),
        StaffData(
          uid: 'crew-002',
          email: 'crew2@siniops.demo',
          displayName: 'Dian (Kasir)',
          role: 'crew',
        ),
      ]);
    }
  }

  /// Get current demo user info
  String? get currentUserUid {
    final role = PreviewModeController.instance.previewRole;
    if (role == 'owner') return 'owner-001';
    return 'crew-001';
  }

  String? get currentUserDisplayName {
    final role = PreviewModeController.instance.previewRole;
    if (role == 'owner') return 'Aldi (Owner)';
    return 'Citra (Kasir)';
  }

  /// Get user role for a given UID
  Future<String?> getUserRole(String uid) async {
    _ensureDefaultStaff();
    final staff = MockDataStore.instance.staffList.cast<StaffData?>().firstWhere(
      (s) => s!.uid == uid,
      orElse: () => null,
    );
    return staff?.role;
  }

  /// Get staff list as a stream (reactive)
  Stream<List<StaffData>> getStaff(String currentUserRole) {
    _ensureDefaultStaff();
    // Emit current list immediately, then listen for updates
    final controller = StreamController<List<StaffData>>();

    // Send initial data
    Future.microtask(() {
      if (!controller.isClosed) {
        controller.add(List.from(MockDataStore.instance.staffList));
      }
    });

    // Listen for updates from broadcast stream
    final subscription = _staffStreamController.stream.listen((data) {
      if (!controller.isClosed) {
        controller.add(data);
      }
    });

    controller.onCancel = () {
      subscription.cancel();
    };

    return controller.stream;
  }

  /// Add new staff member
  Future<AuthResult> addStaff({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    _ensureDefaultStaff();

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Check if email already exists
    final exists = MockDataStore.instance.staffList.any(
      (s) => (s as StaffData).email == email,
    );
    if (exists) {
      return AuthResult(success: false, error: 'Email sudah terdaftar');
    }

    final newStaff = StaffData(
      uid: 'staff-${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      displayName: name,
      role: role,
    );

    MockDataStore.instance.staffList.add(newStaff);
    _notifyStaffChanged();

    return AuthResult(success: true);
  }

  /// Delete staff member
  Future<bool> deleteStaff(String uid) async {
    _ensureDefaultStaff();
    await Future.delayed(const Duration(milliseconds: 300));

    MockDataStore.instance.staffList.removeWhere(
      (s) => (s as StaffData).uid == uid,
    );
    _notifyStaffChanged();
    return true;
  }

  /// Request owner deletion (demo: just deletes immediately)
  Future<bool> requestOwnerDeletion(String uid) async {
    return deleteStaff(uid);
  }

  /// Notify listeners of staff list changes
  void _notifyStaffChanged() {
    if (!_staffStreamController.isClosed) {
      _staffStreamController.add(
        List.from(MockDataStore.instance.staffList),
      );
    }
  }
}
